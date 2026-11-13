// The live model path, in pure Dart (the app and tool/record.dart share it):
// a streaming Messages request with the two UI tools, whose ui_apply tool
// input arrives as input_json_delta text that goes straight into
// UiSession.applyStream. Anthropic's API through package:anthropic_sdk_dart.
//
// The API key is read from the environment (ANTHROPIC_API_KEY) or a
// --dart-define of the same name, by the caller; it is never logged or
// written anywhere.
import 'dart:async';
import 'dart:convert';

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart';
import 'package:codelessly_api/core.dart' as api;

/// The models the demo supports, newest family first. The default is the
/// fast one, for inline answers.
const List<String> kModels = ['claude-haiku-5-5', 'claude-sonnet-5-5', 'claude-opus-5-5', 'claude-fable-5-2'];
const String kDefaultModel = 'claude-haiku-5-5';

/// One streamed model turn: its text, the ui_apply tool input as it
/// arrived, and what the API reported.
class LlmTurn {
  /// Each ui_apply input delta and when it arrived (ms from the request).
  final List<({int tMs, String delta})> deltas = [];

  /// Text the model wrote around its tool call.
  final StringBuffer text = StringBuffer();
  int? ttftMs, firstToolDeltaMs, totalMs;
  int inputTokens = 0, outputTokens = 0, cacheReadTokens = 0, cacheWriteTokens = 0;
  String? stopReason, toolUseId, toolName;

  /// The assistant message, to continue the conversation.
  InputMessage? assistant;

  String get toolInput => deltas.map((d) => d.delta).join();

  Map<String, Object?> usageJson() => {
        'inputTokens': inputTokens,
        'outputTokens': outputTokens,
        'cacheReadInputTokens': cacheReadTokens,
        'cacheCreationInputTokens': cacheWriteTokens,
        'ttftMs': ttftMs,
        'firstToolDeltaMs': firstToolDeltaMs,
        'totalMs': totalMs,
        'stopReason': stopReason,
      };
}

/// Builds and runs the streaming requests of a UI conversation.
class UiModel {
  UiModel({required String apiKey, required this.model, required this.systemPrompt, required this.tools, this.maxTokens = 32000})
      : _client = AnthropicClient(config: AnthropicConfig(authProvider: ApiKeyProvider(apiKey)));

  final AnthropicClient _client;
  final String model;
  final String systemPrompt;

  /// The tools as uiTools gives them (`name`, `description`, `input_schema`).
  final List<Map<String, Object?>> tools;
  final int maxTokens;

  /// The conversation so far.
  final List<InputMessage> messages = [];

  List<ToolDefinition> get _tools => [
        for (final t in tools)
          ToolDefinition.custom(Tool(
            name: t['name']! as String,
            description: t['description'] as String?,
            inputSchema: _schema(t['input_schema']! as Map<String, Object?>),
            // Tool input streams as it is generated, not buffered.
            eagerInputStreaming: true,
          )),
      ];

  static InputSchema _schema(Map<String, Object?> s) => InputSchema(
        properties: (s['properties'] as Map?)?.cast<String, dynamic>(),
        required: (s['required'] as List?)?.cast<String>(),
        extra: {
          for (final e in s.entries)
            if (!const {'type', 'properties', 'required'}.contains(e.key)) e.key: e.value,
        },
      );

  /// Thinking per model: off where the model allows it (fast inline
  /// answers), adaptive at low effort where it can't be turned off.
  ThinkingConfig? get _thinking => switch (model) {
        'claude-haiku-5-5' => ThinkingConfig.disabled(),
        'claude-sonnet-5-5' => const ThinkingConfig.betweenTools(),
        _ => null,
      };

  /// The request [send] streams (for a check without a network).
  MessageCreateRequest buildRequest() => MessageCreateRequest(
        model: model,
        maxTokens: maxTokens,
        system: SystemPrompt.blocks([SystemTextBlock(text: systemPrompt, cacheControl: const CacheControlEphemeral())]),
        tools: _tools,
        toolChoice: ToolChoice.auto(disableParallelToolUse: true),
        thinking: _thinking,
        outputConfig: const OutputConfig(effort: EffortLevel.low),
        messages: messages,
      );

  /// The system prompt and tools, counted by the API.
  Future<int> countInputTokens() async {
    final r = await _client.messages.countTokens(TokenCountRequest(
      model: model,
      system: SystemPrompt.text(systemPrompt),
      tools: _tools,
      messages: [InputMessage.user('Hi')],
    ));
    return r.inputTokens;
  }

  /// Sends [user] (a text turn, or the tool result for the last call with
  /// [toolResult]) and streams the reply: [onToolDelta] gets each ui_apply
  /// input delta as it arrives.
  Future<LlmTurn> send({String? user, Map<String, Object?>? toolResult, String? toolUseId, void Function(String delta)? onToolDelta}) async {
    if (toolResult != null && toolUseId != null) {
      messages.add(InputMessage.userBlocks([
        ToolResultInputBlock(toolUseId: toolUseId, content: [ToolResultContent.text(jsonEncode(toolResult))]),
        if (user != null) InputContentBlock.text(user),
      ]));
    } else {
      messages.add(InputMessage.user(user ?? ''));
    }
    final turn = LlmTurn();
    final clock = Stopwatch()..start();
    final acc = MessageStreamAccumulator();
    var toolIndex = -1;
    await for (final event in _client.messages.createStream(buildRequest())) {
      acc.add(event);
      switch (event) {
        case MessageStartEvent(:final message):
          turn.inputTokens = message.usage.inputTokens;
          turn.cacheReadTokens = message.usage.cacheReadInputTokens ?? 0;
          turn.cacheWriteTokens = message.usage.cacheCreationInputTokens ?? 0;
        case ContentBlockStartEvent(:final index, :final contentBlock):
          turn.ttftMs ??= clock.elapsedMilliseconds;
          if (contentBlock is ToolUseBlock && contentBlock.name == 'ui_apply' && toolIndex < 0) {
            toolIndex = index;
            turn.toolUseId = contentBlock.id;
            turn.toolName = contentBlock.name;
          } else if (contentBlock is ToolUseBlock && turn.toolUseId == null) {
            turn.toolUseId = contentBlock.id;
            turn.toolName = contentBlock.name;
          }
        case ContentBlockDeltaEvent(:final index, :final delta):
          turn.ttftMs ??= clock.elapsedMilliseconds;
          if (delta is InputJsonDelta && index == toolIndex && delta.partialJson.isNotEmpty) {
            turn.firstToolDeltaMs ??= clock.elapsedMilliseconds;
            turn.deltas.add((tMs: clock.elapsedMilliseconds, delta: delta.partialJson));
            onToolDelta?.call(delta.partialJson);
          } else if (delta is TextDelta) {
            turn.text.write(delta.text);
          }
        case MessageDeltaEvent(:final delta, :final usage):
          turn.outputTokens = usage.outputTokens;
          turn.stopReason = delta.stopReason?.toString();
        default:
          break;
      }
    }
    turn.totalMs = clock.elapsedMilliseconds;
    final message = acc.toMessage();
    turn.assistant = message.toInputMessage();
    messages.add(turn.assistant!);
    return turn;
  }

  void close() => _client.close();
}

/// The demo's four UIs: what the user asks for (generic briefs only).
const Map<String, ({String kind, String prompt, String? followup})> kBriefs = {
  'flights': (
    kind: 'card',
    prompt: 'Show me the flight options from London to Lisbon this Friday as an inline card I can pick from: three options '
        '(times, airline, direct, duration, price, a tag for the cheapest and the best time), the first one selected, '
        'a total and a confirm button that tells you which one I chose.',
    followup: 'Sort them by price.',
  ),
  'weather': (
    kind: 'card',
    prompt: 'Show the weather in Lisbon as an inline card: now (temperature, conditions, high and low), the next five hours, '
        'the next three days with a temperature range bar, and a button to alert me before it rains.',
    followup: 'Make it dark.',
  ),
  'restaurant_menu': (
    kind: 'page',
    prompt: 'Build the menu page of a neighbourhood restaurant that cooks over fire: a header, a hero with the opening '
        'times, a featured dish, the menu in tabs (lunch, dinner, drinks, dessert) with prices and dietary tags, a short '
        'footer, and a reserve button pinned to the bottom. It must work on a phone and on a desktop.',
    followup: null,
  ),
  'saas_pricing': (
    kind: 'page',
    prompt: 'Build the pricing page of a developer tools product: a header, a hero, a monthly/annual toggle, three plan '
        'cards with features and a highlighted middle plan, a feature comparison table, an FAQ and a final call to action. '
        'It must work on a phone and on a desktop.',
    followup: null,
  ),
};

/// What the user's message says about the UI, beyond the brief.
String userMessage(String brief, String kind) => kind == 'card'
    ? '$brief\n\n(Answer with one ui_apply call: an inline card, canvas width 390 with a hug height.)'
    : '$brief\n\n(Answer with one ui_apply call: one page, canvas 1440 × 900, responsive down to 390.)';

/// The tools for the agent profile over the core catalog.
List<Map<String, Object?>> uiToolsForAgent() => api.uiTools(api.TrustProfile.agent.restrict(api.Catalog.core));
