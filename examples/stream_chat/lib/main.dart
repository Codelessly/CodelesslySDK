// A minimal chat whose replies carry inline generative UI: each reply is a
// UiSession shown by CodelesslyView, filling in as the model's ui_apply tool
// call streams. Taps in the UI (confirm, choose) come back as the user's
// next turn; a follow-up ("make it dark", "sort by price") edits the same
// UI with a few ops instead of regenerating it.
//
//   flutter run                                   # recorded streams, offline
//   flutter run --dart-define=ANTHROPIC_API_KEY=... [--dart-define=MODEL=claude-sonnet-5-5]   # live
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_api/validate.dart' show ValidateOptions, strictEditCheck;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart'; // ignore: deprecated_member_use
import 'package:flutter/services.dart' show rootBundle;

import 'src/llm.dart' show kDefaultModel;
import 'src/sources.dart';

export 'src/sources.dart';

void main() {
  runApp(const StreamChatApp());
}

class StreamChatApp extends StatelessWidget {
  const StreamChatApp({super.key, this.source});

  /// The source of replies; null: live when ANTHROPIC_API_KEY was defined,
  /// else recorded.
  final StreamSource? source;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Generative UI chat',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF2563EB), useMaterial3: true),
        home: ChatScreen(source: source),
      );
}

/// One message of the chat.
sealed class ChatMessage {}

class UserMessage extends ChatMessage {
  UserMessage(this.text, {this.action = false});
  final String text;

  /// An action taken on a UI (shown as the user's turn).
  final bool action;
}

class ReplyMessage extends ChatMessage {
  ReplyMessage(this.ui, this.session);
  final String ui;
  final UiSession session;
  String text = '';
  String? note;
  EditResult? result;
}

/// A reply's session: its ops checked as they arrive with the strict
/// validator, the model's formulas read by the SDK's parser (a formula that
/// does not parse, an item's field read without its item), against the
/// design system's components and tokens.
UiSession newSession(DesignSystem? designSystem) => UiSession(
    designSystem: designSystem,
    check: strictEditCheck(
        ValidateOptions(formulas: FormulaEvaluator.report, components: designSystem?.components, theme: designSystem?.tokens)));

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.source});
  final StreamSource? source;

  @override
  State<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  StreamSource? _source;
  ReplyMessage? _lastUi;
  final List<StreamSubscription<UiEvent>> _subs = [];

  static const _asks = {
    'flights': 'Show me flights from London to Lisbon on Friday.',
    'weather': 'What\'s the weather in Lisbon?',
  };

  @override
  void initState() {
    super.initState();
    _source = widget.source;
    if (_source == null) unawaited(_pickSource());
  }

  /// The design system replies are made with: `--dart-define=DESIGN_SYSTEM=ssui`
  /// (assets/design_systems/<id>.json, made by tool/design_system_bundle.dart).
  DesignSystem? _designSystem;

  Future<void> _pickSource() async {
    const key = String.fromEnvironment('ANTHROPIC_API_KEY');
    const model = String.fromEnvironment('MODEL', defaultValue: kDefaultModel);
    const ds = String.fromEnvironment('DESIGN_SYSTEM');
    if (ds.isNotEmpty) {
      _designSystem = DesignSystem.fromJson(jsonDecode(await rootBundle.loadString('assets/design_systems/$ds.json')));
    }
    final StreamSource s = key.isEmpty
        ? RecordedStreamSource()
        : LlmStreamSource(
            apiKey: key,
            model: model,
            systemPrompt: await rootBundle.loadString('assets/system_prompt.md'),
            designSystem: _designSystem);
    if (mounted) setState(() => _source = s);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    for (final m in messages) {
      if (m is ReplyMessage) m.session.dispose();
    }
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Sends [text]: a new UI when it names one, else an edit of the last.
  Future<void> send(String text) async {
    final source = _source;
    if (source == null || text.trim().isEmpty) return;
    _input.clear();
    final ui = _asks.entries.where((e) => e.value == text || text.toLowerCase().contains(e.key)).firstOrNull?.key ??
        (text.toLowerCase().contains('flight') ? 'flights' : text.toLowerCase().contains('weather') ? 'weather' : null);
    setState(() => messages.add(UserMessage(text)));
    final last = _lastUi;
    if (ui == null && last != null) {
      await _stream(source.reply(EditTurn(last.ui, text, last.session, last.result)), last, edit: true);
    } else {
      final reply = ReplyMessage(ui ?? 'flights', newSession(_designSystem));
      _subs.add(reply.session.events.listen((e) => _action(reply, e)));
      setState(() => messages.add(reply));
      _lastUi = reply;
      await _stream(source.reply(AskTurn(reply.ui, text)), reply, edit: false);
    }
  }

  Future<void> _action(ReplyMessage reply, UiEvent e) async {
    final source = _source;
    if (source == null) return;
    setState(() => messages.add(UserMessage('${e.event} ${e.value ?? ''}'.trim(), action: true)));
    final r = source.reply(ActionTurn(reply.ui, e, reply.session));
    final answer = ReplyMessage(reply.ui, reply.session);
    answer.text = await r.text;
    // A reply to an action may also edit the UI.
    final result = await reply.session.applyStream(r.toolInput);
    if (result.appliedOps.isNotEmpty) reply.result = await _withShown(reply.session, result);
    if (mounted) setState(() => messages.add(_TextReply(answer.text)));
  }

  Future<void> _stream(SourceReply r, ReplyMessage target, {required bool edit}) async {
    final clock = Stopwatch()..start();
    int? firstPaint;
    final result = await target.session.applyStream(r.toolInput, onOp: (p) {
      firstPaint ??= target.session.node(target.session.document.roots.firstOrNull ?? '')?.type == 'canvas' ? clock.elapsedMilliseconds : null;
      _follow();
    });
    target.result = await _withShown(target.session, result);
    target.text = await r.text;
    final usage = await r.usage;
    final tokens = usage['outputTokens'];
    target.note = edit
        ? '${result.appliedOps.length} ops · $tokens output tokens (an edit, not a regeneration)'
        : '${result.appliedOps.length} ops · $tokens output tokens · first paint ${firstPaint ?? '-'} ms · ${clock.elapsedMilliseconds} ms'
            '${result.rejected.isEmpty ? '' : ' · ${result.rejected.length} rejected'}';
    if (mounted) setState(() {});
  }

  /// [result] with what the UI shows wrong once it is drawn
  /// (UiSession.shownDiagnostics: a valid UI that shows nothing, a list with
  /// no items, an empty label): the tool result the model reads next says so.
  Future<EditResult> _withShown(UiSession session, EditResult result) async {
    if (mounted) setState(() {});
    await WidgetsBinding.instance.endOfFrame;
    return result.withDiagnostics(session.shownDiagnostics());
  }

  void _follow() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(title: Text('Generative UI · ${_source?.label ?? '…'}', style: const TextStyle(fontSize: 16))),
      body: Column(children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            children: [for (final m in messages) _bubble(m)],
          ),
        ),
        _composer(),
      ]),
    );
  }

  Widget _bubble(ChatMessage m) => switch (m) {
        UserMessage(:final text, :final action) => Align(
            alignment: Alignment.centerRight,
            child: Container(
              key: ValueKey('user:$text'),
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(
                color: action ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(action ? '⟶ $text' : text, style: const TextStyle(color: Colors.white)),
            ),
          ),
        _TextReply(:final text) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(text)),
        ReplyMessage() => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (m.text.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(m.text)),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: CodelesslyView(key: ObjectKey(m.session), session: m.session),
              ),
              if (m.note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(m.note!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ),
            ]),
          ),
      };

  Widget _composer() => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(spacing: 8, children: [
              for (final a in _asks.values) ActionChip(label: Text(a), onPressed: () => send(a)),
              if (_lastUi != null) ...[
                ActionChip(label: const Text('Sort them by price.'), onPressed: () => send('Sort them by price.')),
                ActionChip(label: const Text('Make it dark.'), onPressed: () => send('Make it dark.')),
              ],
            ]),
            TextField(
              controller: _input,
              decoration: const InputDecoration(hintText: 'Ask for a UI, or change the last one'),
              onSubmitted: send,
            ),
          ]),
        ),
      );
}

/// A reply with text only.
class _TextReply extends ChatMessage {
  _TextReply(this.text);
  final String text;
}
