// Where a chat reply's UI comes from: a model streaming ui_apply tool input
// (LlmStreamSource), or a recording of one (RecordedStreamSource), behind
// one interface the chat screen reads.
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'llm.dart';

/// What the user did that the model answers.
sealed class ChatTurn {
  const ChatTurn();
}

/// "Show me ...": a new UI ([ui] names the demo brief, for recordings).
class AskTurn extends ChatTurn {
  const AskTurn(this.ui, this.text);
  final String ui;
  final String text;
}

/// "Make it dark": an edit of the UI [session] shows.
class EditTurn extends ChatTurn {
  const EditTurn(this.ui, this.text, this.session, this.lastResult);
  final String ui;
  final String text;
  final UiSession session;
  final EditResult? lastResult;
}

/// The user acted on the UI ([event]: confirm, choose...).
class ActionTurn extends ChatTurn {
  const ActionTurn(this.ui, this.event, this.session);
  final String ui;
  final UiEvent event;
  final UiSession session;
}

/// A model reply: its text, and the ui_apply input as it streams (empty for
/// a reply without UI).
class SourceReply {
  SourceReply({required this.toolInput, required this.text, required this.usage});

  /// The raw tool input deltas, as the API delivers them.
  final Stream<String> toolInput;

  /// The text around the tool call (complete when the reply is).
  final Future<String> text;

  /// Output tokens and times, when the reply is complete.
  final Future<Map<String, Object?>> usage;
}

/// Answers chat turns with streamed UI.
abstract interface class StreamSource {
  SourceReply reply(ChatTurn turn);

  /// A name for the UI ("Recorded", the model id).
  String get label;
}

/// Plays recorded streams (the files tool/stream/make_streams.dart and
/// tool/record.dart write) at their recorded pace, times [speed]. Offline:
/// the demo and its tests run without a model.
class RecordedStreamSource implements StreamSource {
  RecordedStreamSource({AssetBundle? bundle, this.speed = 1, this.rate = 150, this.prefix = 'assets/streams'})
      : bundle = bundle ?? rootBundle;

  final AssetBundle bundle;

  /// Playback speed (2: twice as fast).
  final double speed;

  /// Which synthetic recording to play (tokens per second).
  final int rate;
  final String prefix;

  @override
  String get label => 'Recorded · $rate tok/s';

  static const _followups = {'flights': 'flights_sort', 'weather': 'weather_dark'};

  @override
  SourceReply reply(ChatTurn turn) {
    final (file, text) = switch (turn) {
      AskTurn(:final ui) => ('$prefix/$ui@${rate}tps.jsonl', ui == 'flights' ? 'Here are Friday\'s flights:' : 'Here you go:'),
      EditTurn(:final ui) => ('$prefix/${_followups[ui] ?? ui}@150tps.jsonl', 'Done.'),
      ActionTurn(:final event) => (null, _actionAnswer(event)),
    };
    if (file == null) {
      return SourceReply(toolInput: const Stream.empty(), text: Future.value(text), usage: Future.value(const {}));
    }
    final usage = Completer<Map<String, Object?>>();
    Stream<String> play() async* {
      final lines = const LineSplitter().convert(await bundle.loadString(file));
      final meta = (jsonDecode(lines.first) as Map)['meta'] as Map<String, Object?>;
      var at = 0;
      for (final l in lines.skip(1)) {
        final m = jsonDecode(l) as Map<String, Object?>;
        final t = ((m['tMs']! as num) / speed).round();
        if (t > at) await Future<void>.delayed(Duration(milliseconds: t - at));
        at = t;
        yield m['delta']! as String;
      }
      usage.complete({'outputTokens': meta['outputTokens'], 'estimated': meta['tokensEstimated'] ?? false, 'totalMs': at});
    }

    return SourceReply(toolInput: play(), text: Future.value(text), usage: usage.future);
  }

  static String _actionAnswer(UiEvent e) => switch (e.event) {
        'confirmFlight' => 'Booked ${(e.value as Map?)?['flight'] ?? 'it'}. Your confirmation is on its way.',
        'rainAlert' => 'I\'ll let you know before it rains in ${(e.value as Map?)?['city'] ?? 'town'}.',
        _ => 'Got it: ${e.event}.',
      };
}

/// A model, live: Anthropic's Messages API with the two UI tools, streaming
/// the ui_apply input as it is generated (eager input streaming). Untested
/// in this repository's checks (they make no network calls).
///
/// The key comes from the caller (`--dart-define=ANTHROPIC_API_KEY=...`);
/// it is never written anywhere.
class LlmStreamSource implements StreamSource {
  /// [systemPrompt]: the full prompt (assets/system_prompt.md), sent with
  /// [variant] full; the compact variant (the default) generates the base
  /// set and offers ui_docs.
  ///
  /// With a [designSystem], the compact prompt is generated from it too and
  /// ui_docs answers its documents and components.
  LlmStreamSource(
      {required String apiKey,
      String model = kDefaultModel,
      required String systemPrompt,
      PromptVariant variant = PromptVariant.compact,
      this.designSystem})
      : _model = UiModel(
            apiKey: apiKey,
            model: model,
            systemPrompt: systemPromptFor(variant, full: systemPrompt, designSystem: designSystem),
            tools: uiToolsFor(variant));

  final UiModel _model;

  /// The design system the UIs are made with (null: none).
  final DesignSystem? designSystem;
  String? _lastToolUseId;

  @override
  String get label => _model.model;

  @override
  SourceReply reply(ChatTurn turn) {
    final deltas = StreamController<String>();
    final text = Completer<String>();
    final usage = Completer<Map<String, Object?>>();
    Future<void> run() async {
      try {
        final LlmTurn t;
        switch (turn) {
          case AskTurn(:final text):
            t = await _model.turn(
              user: userMessage(text, 'card'),
              toolResult: _lastToolUseId == null ? null : const {'ok': true},
              toolUseId: _lastToolUseId,
              onToolDelta: deltas.add,
              lookup: (tool, input) => answerLookup(tool, input, document: LayoutDocument(), designSystem: designSystem),
            );
          case EditTurn(:final text, :final session, :final lastResult):
            t = await _model.turn(
              toolResult: {...?lastResult?.toModelJson(), ...session.outline()},
              toolUseId: _lastToolUseId,
              user: text,
              onToolDelta: deltas.add,
              lookup: (tool, input) => answerLookup(tool, input, document: session.document, rev: session.rev, designSystem: designSystem),
            );
          case ActionTurn(:final event, :final session):
            t = await _model.turn(
              toolResult: {'rev': session.rev, 'ok': true},
              toolUseId: _lastToolUseId,
              user: event.toModelMessage(),
              onToolDelta: deltas.add,
              lookup: (tool, input) => answerLookup(tool, input, document: session.document, rev: session.rev, designSystem: designSystem),
            );
        }
        // The next turn answers this one's tool call, if it made one.
        _lastToolUseId = t.toolUseId;
        text.complete(t.text.toString());
        usage.complete(t.usageJson());
      } catch (e) {
        if (!text.isCompleted) text.complete('The model could not be reached: ${'$e'.split('\n').first}');
        if (!usage.isCompleted) usage.complete(const {});
      } finally {
        await deltas.close();
      }
    }

    unawaited(run());
    return SourceReply(toolInput: deltas.stream, text: text.future, usage: usage.future);
  }
}
