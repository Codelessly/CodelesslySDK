// The live model path, in pure Dart (the app and tool/record.dart share it):
// a streaming Messages request with the UI tools, whose ui_apply tool input
// arrives as input_json_delta text that goes straight into
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

/// Which system prompt and tools a request sends.
enum PromptVariant {
  /// The base, runtime form ([api.runtimeStarter]: codelessly_api's
  /// RUNTIME_STARTER.md, ≈ 44k characters) with the compact tools and
  /// `ui_docs`, which serves the reference's pages, the link to the rest.
  compact,

  /// The rules plus the base's file form (codelessly_api's STARTER.md,
  /// assets/system_prompt.md, ≈ 50k characters) with tool schemas that
  /// enumerate every node type.
  full,
}

/// One tool call a turn made before (or instead of) ui_apply: a lookup.
class Lookup {
  Lookup(this.tool, this.input, this.ms, this.outputTokens, this.resultChars);
  final String tool;
  final Map<String, Object?> input;
  final int ms, outputTokens, resultChars;
  Map<String, Object?> toJson() => {
    'tool': tool,
    'input': input,
    'ms': ms,
    'outputTokens': outputTokens,
    'resultChars': resultChars,
  };
}

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

  /// The tool call's input, when it was not ui_apply (a lookup).
  Map<String, Object?>? toolInputJson;

  /// The lookups (ui_docs, ui_read) answered before the ui_apply call, in
  /// order, with their requests' times and tokens.
  final List<Lookup> lookups = [];

  /// Whether the turn ended without a ui_apply call after a nudge.
  bool nudged = false;

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
    if (lookups.isNotEmpty) 'lookups': [for (final l in lookups) l.toJson()],
    if (nudged) 'nudged': true,
  };
}

/// Builds and runs the streaming requests of a UI conversation.
class UiModel {
  UiModel({
    required String apiKey,
    required this.model,
    required this.systemPrompt,
    required this.tools,
    this.maxTokens = 32000,
  }) : _client = AnthropicClient(config: AnthropicConfig(authProvider: ApiKeyProvider(apiKey)));

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
      ToolDefinition.custom(
        Tool(
          name: t['name']! as String,
          description: t['description'] as String?,
          inputSchema: _schema(t['input_schema']! as Map<String, Object?>),
          // Tool input streams as it is generated, not buffered.
          eagerInputStreaming: true,
        ),
      ),
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
  /// answers), off between tools on Sonnet 5.5 (it cannot be disabled), and
  /// the model's default (adaptive, low effort) where it cannot be turned
  /// off.
  ThinkingConfig? get _thinking => switch (model) {
    'claude-haiku-5-5' => ThinkingConfig.disabled(),
    'claude-sonnet-5-5' => const ThinkingConfig.betweenTools(),
    _ => null,
  };

  /// Whether this model takes a forced tool choice: only with thinking off
  /// (Haiku 5.5 here). Sonnet 5.5, Opus 5.5 and Fable 5.2 reject `any` and
  /// `tool` with a 400; they get `auto`, the prompt's rule and a nudge when
  /// a turn ends without the call.
  static bool canForceTools(String model) => model == 'claude-haiku-5-5';

  /// The request [send] streams (for a check without a network). A forced
  /// choice is `any` (a lookup or ui_apply), so a turn cannot end without a
  /// tool call where the model allows forcing it.
  MessageCreateRequest buildRequest() => MessageCreateRequest(
    model: model,
    maxTokens: maxTokens,
    system: SystemPrompt.blocks([SystemTextBlock(text: systemPrompt, cacheControl: const CacheControlEphemeral())]),
    tools: _tools,
    toolChoice: canForceTools(model)
        ? ToolChoice.any(disableParallelToolUse: true)
        : ToolChoice.auto(disableParallelToolUse: true),
    thinking: _thinking,
    outputConfig: const OutputConfig(effort: EffortLevel.low),
    messages: messages,
  );

  /// The system prompt and tools, counted by the API.
  Future<int> countInputTokens() async {
    final r = await _client.messages.countTokens(
      TokenCountRequest(
        model: model,
        system: SystemPrompt.text(systemPrompt),
        tools: _tools,
        messages: [InputMessage.user('Hi')],
      ),
    );
    return r.inputTokens;
  }

  /// Sends [user] (a text turn, or the tool result for the last call with
  /// [toolResult]) and streams the reply: [onToolDelta] gets each ui_apply
  /// input delta as it arrives.
  Future<LlmTurn> send({
    String? user,
    Object? toolResult,
    String? toolUseId,
    void Function(String delta)? onToolDelta,
  }) async {
    if (toolResult != null && toolUseId != null) {
      messages.add(
        InputMessage.userBlocks([
          ToolResultInputBlock(
            toolUseId: toolUseId,
            content: [ToolResultContent.text(toolResult is String ? toolResult : jsonEncode(toolResult))],
          ),
          if (user != null) InputContentBlock.text(user),
        ]),
      );
    } else {
      messages.add(InputMessage.user(user ?? ''));
    }
    final turn = LlmTurn();
    final clock = Stopwatch()..start();
    final acc = MessageStreamAccumulator();
    var toolIndex = -1;
    var otherIndex = -1;
    final otherJson = StringBuffer();
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
            otherIndex = index;
            turn.toolUseId = contentBlock.id;
            turn.toolName = contentBlock.name;
          }
        case ContentBlockDeltaEvent(:final index, :final delta):
          turn.ttftMs ??= clock.elapsedMilliseconds;
          if (delta is InputJsonDelta && index == toolIndex && delta.partialJson.isNotEmpty) {
            turn.firstToolDeltaMs ??= clock.elapsedMilliseconds;
            turn.deltas.add((tMs: clock.elapsedMilliseconds, delta: delta.partialJson));
            onToolDelta?.call(delta.partialJson);
          } else if (delta is InputJsonDelta && index == otherIndex) {
            otherJson.write(delta.partialJson);
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
    if (otherIndex >= 0) {
      try {
        turn.toolInputJson = (jsonDecode(otherJson.isEmpty ? '{}' : otherJson.toString()) as Map)
            .cast<String, Object?>();
      } catch (_) {
        turn.toolInputJson = const {};
      }
    }
    final message = acc.toMessage();
    turn.assistant = message.toInputMessage();
    messages.add(turn.assistant!);
    return turn;
  }

  /// One user turn as a UI needs it: [send], then, while the model calls a
  /// lookup tool (ui_docs, ui_read), answer it with [lookup] and continue
  /// (at most [maxLookups]); if the turn ends with no tool call, nudge it
  /// once to make the ui_apply call. The returned turn is the one that made
  /// the ui_apply call (or the last), with every lookup before it and the
  /// times and tokens summed over the requests.
  Future<LlmTurn> turn({
    String? user,
    Object? toolResult,
    String? toolUseId,
    void Function(String delta)? onToolDelta,
    required Object? Function(String tool, Map<String, Object?> input) lookup,
    int maxLookups = 6,
  }) async {
    final clock = Stopwatch()..start();
    var t = await send(user: user, toolResult: toolResult, toolUseId: toolUseId, onToolDelta: onToolDelta);
    final lookups = <Lookup>[];
    var ttft = t.ttftMs,
        input = t.inputTokens,
        output = t.outputTokens,
        cacheRead = t.cacheReadTokens,
        cacheWrite = t.cacheWriteTokens;
    var nudged = false;
    final text = StringBuffer(t.text);
    for (var i = 0; i < maxLookups + 1; i++) {
      final offset = clock.elapsedMilliseconds;
      if (t.toolName != null && t.toolName != 'ui_apply' && lookups.length < maxLookups) {
        final answer = lookup(t.toolName!, t.toolInputJson ?? const {});
        final result = answer is String ? answer : jsonEncode(answer);
        lookups.add(Lookup(t.toolName!, t.toolInputJson ?? const {}, t.totalMs ?? 0, t.outputTokens, result.length));
        t = await send(toolResult: result, toolUseId: t.toolUseId, onToolDelta: onToolDelta);
      } else if (t.toolName == null && !nudged) {
        nudged = true;
        t = await send(
          user: 'Answer with the ui_apply tool call now: build the UI (or the change) with edit ops.',
          onToolDelta: onToolDelta,
        );
      } else {
        break;
      }
      // Times of the request that made the ui_apply call, from the turn's start.
      t.ttftMs = t.ttftMs == null ? null : t.ttftMs! + offset;
      t.firstToolDeltaMs = t.firstToolDeltaMs == null ? null : t.firstToolDeltaMs! + offset;
      for (var k = 0; k < t.deltas.length; k++) {
        t.deltas[k] = (tMs: t.deltas[k].tMs + offset, delta: t.deltas[k].delta);
      }
      input += t.inputTokens;
      output += t.outputTokens;
      cacheRead += t.cacheReadTokens;
      cacheWrite += t.cacheWriteTokens;
      text.write(t.text);
    }
    t.lookups.addAll(lookups);
    t.nudged = nudged && t.toolName == null;
    t.ttftMs = ttft;
    t.totalMs = clock.elapsedMilliseconds;
    t.inputTokens = input;
    t.outputTokens = output;
    t.cacheReadTokens = cacheRead;
    t.cacheWriteTokens = cacheWrite;
    t.text
      ..clear()
      ..write(text);
    return t;
  }

  void close() => _client.close();
}

/// A brief: what a person asks for, the kind of UI, a follow-up edit, and
/// for apps the interaction that shows it works (tool/stream's checker).
typedef Brief = ({String kind, String prompt, String? followup});

/// The demo's UIs: what the user asks for, as a person would type it.
const Map<String, Brief> kBriefs = {
  'flights': (
    kind: 'card',
    prompt:
        'Show me the flight options from London to Lisbon this Friday as an inline card I can pick from: three options '
        '(times, airline, direct, duration, price, a tag for the cheapest and the best time), the first one selected, '
        'a total and a confirm button that tells you which one I chose.',
    followup: 'Sort them by price.',
  ),
  'weather': (
    kind: 'card',
    prompt:
        'Show the weather in Lisbon as an inline card: now (temperature, conditions, high and low), the next five hours, '
        'the next three days with a temperature range bar, and a button to alert me before it rains.',
    followup: 'Make it dark.',
  ),
  'restaurant_menu': (
    kind: 'page',
    prompt:
        'Build the menu page of a neighbourhood restaurant that cooks over fire: a header, a hero with the opening '
        'times, a featured dish, the menu in tabs (lunch, dinner, drinks, dessert) with prices and dietary tags, a short '
        'footer, and a reserve button pinned to the bottom. It must work on a phone and on a desktop.',
    followup: null,
  ),
  'saas_pricing': (
    kind: 'page',
    prompt:
        'Build the pricing page of a developer tools product: a header, a hero, a monthly/annual toggle, three plan '
        'cards with features and a highlighted middle plan, a feature comparison table, an FAQ and a final call to action. '
        'It must work on a phone and on a desktop.',
    followup: null,
  ),
  // Small interactive apps from one prompt: they need what the base set
  // only starts (drag and drop, timers, frames, animation, custom drawing,
  // validation, multi-step state), through ui_docs.
  'form_builder': (
    kind: 'app',
    prompt:
        'Make me a little form builder. On one side I pick field types to add: short text, long text, number, dropdown, '
        'checkbox and date. I can edit each field\'s label, mark it required, give a dropdown its options, reorder fields and '
        'remove them. Next to it, a live preview of the form that checks the required fields when I submit it.',
    followup: null,
  ),
  'sudoku': (
    kind: 'app',
    prompt:
        'I want to play sudoku. Give me a 9 by 9 puzzle to solve: I tap a cell and then a number on a pad to fill it in, '
        'there\'s a notes mode for pencil marks, conflicting numbers are highlighted, and I can undo. Show a timer, and tell '
        'me when I\'ve solved it.',
    followup: null,
  ),
  'basketball': (
    kind: 'app',
    prompt:
        'Make a basketball shooting mini game. I drag back on the ball to aim and set the power, let go and it flies in an '
        'arc toward the hoop. Keep score and my streak, give me 30 seconds per round with a countdown, and a play again screen '
        'at the end.',
    followup: null,
  ),
  'kanban': (
    kind: 'app',
    prompt:
        'A small kanban board for my week: three columns, To do, Doing and Done, with a few cards in each. I can drag cards '
        'between columns, add a card with a title, and see how many cards each column has.',
    followup: null,
  ),
  'habits': (
    kind: 'app',
    prompt:
        'A habit tracker: my habits down the side and this week\'s days across, tap a day to check it off, and show each '
        'habit\'s current streak with a little progress ring. Let me add a habit too.',
    followup: null,
  ),
  'memory': (
    kind: 'app',
    prompt:
        'A memory card game: a 4 by 4 grid of face-down cards with pairs of pictures. Tap two to flip them; if they match '
        'they stay up, if not they flip back after a moment. Count my moves and show a win screen with the time when all '
        'pairs are found.',
    followup: null,
  ),
  // The inline use cases competitors show (CodelesslyAPI docs/design/09-genui-use-cases.md).
  'dashboard': (
    kind: 'card',
    prompt:
        'Show me how the product did this month as an inline dashboard: four stat tiles (revenue, sign-ups, churn, active users) each with its change, a line chart of revenue, a bar chart of sign-ups by channel, a toggle between 7, 30 and 90 days that changes the numbers, and a table of the top five plans I can sort by any column.',
    followup: 'Add a tile for average order value.',
  ),
  'order_summary': (
    kind: 'card',
    prompt:
        'Show my grocery order as an inline card before you place it: five line items with a picture placeholder, price and a quantity I can raise or lower (removing at zero), a promo code field that takes SAVE10, the subtotal, delivery and total kept up to date, and confirm and cancel buttons that tell you what I decided.',
    followup: 'Add a tip row with 0, 10 and 15 percent.',
  ),
  'approval': (
    kind: 'card',
    prompt:
        'You are about to delete 214 old files from my shared drive. Ask me first with an approval card: what will happen, the folder, how many files and how much space, that it cannot be undone, a way to see the first few file names, and approve and deny buttons. After I choose, the card shows the decision and locks.',
    followup: null,
  ),
  'question_flow': (
    kind: 'card',
    prompt:
        'Help me pick a laptop with a short question flow, one question at a time: what I use it for, then a second question that depends on that answer, then budget. Show progress, let me go back, and end on one recommendation with the reasons and a start over button.',
    followup: null,
  ),
  'reservation': (
    kind: 'card',
    prompt:
        'Let me book a table at a restaurant as an inline card: pick one of the next seven days, a party size from 1 to 8, then time slots for that day where some are full (different days and bigger parties have different free slots), and a confirm button that tells you the day, size and time.',
    followup: 'Add a field for a note to the restaurant.',
  ),
  'checkout': (
    kind: 'app',
    prompt:
        'Build a small checkout in three steps: my cart (three items with quantities), a shipping form (name, address, city, postcode, email, all checked, with messages under the fields), then a payment summary with a choice of standard or express delivery changing the total, and a confirmation screen with an order number. I can go back a step without losing what I typed.',
    followup: null,
  ),
  'map_list': (
    kind: 'card',
    prompt:
        'Show five coffee shops near me as a list beside a simple drawn map (streets as lines, no real map tiles) with a numbered pin for each. Tapping a shop or its pin highlights both and shows its rating, distance and opening hours. On a narrow screen the map goes above the list.',
    followup: null,
  ),
  'carousel': (
    kind: 'card',
    prompt:
        'Show six running shoes as a carousel I can swipe or step through with arrows, with dots for the position: each has a picture placeholder, name, price and rating. Tapping one opens its details in place (description, sizes to pick, add to bag) with a way back to the carousel.',
    followup: null,
  ),
  'itinerary': (
    kind: 'card',
    prompt:
        'Plan two days in Kyoto as an inline itinerary: a timeline per day with times, places, how to get between them and how long it takes. Each stop expands for details, each day has a checklist of things to book that I can tick off, and a line at the top says how many are left.',
    followup: 'Swap the two days.',
  ),
  'comparison': (
    kind: 'card',
    prompt:
        'Compare two phone plans side by side for me: price, data, calls, roaming, contract length and extras, with the better value on each row marked, a recommendation at the bottom with one sentence of reasoning, and a choose button under each plan that tells you which I picked.',
    followup: null,
  ),
  'data_table': (
    kind: 'card',
    prompt:
        'Show the twelve invoices you found as a table: number, customer, date, amount and status. I can sort by any column, filter by status, type to search the customer, page through five at a time, tick rows (and a tick-all for the page), and a bar appears with the count and total of what I ticked and a button to send reminders for them.',
    followup: null,
  ),
  'message_draft': (
    kind: 'card',
    prompt:
        'Draft an email to my landlord about the broken heating and show it as an inline card I can edit before it goes: to, subject and body fields filled in, a tone switch between polite and firm that rewrites the body, and send and discard buttons. Sending needs a recipient and a subject, and afterwards the card shows it as sent.',
    followup: null,
  ),
  'plan_progress': (
    kind: 'card',
    prompt:
        'Show the plan for migrating my blog as steps: six steps with a short description each. A start button runs them one after another (a second or two each) with a spinner on the running step, ticks on the finished ones, a progress bar and the time elapsed, a pause button, and a summary when all are done.',
    followup: null,
  ),
  'code_diff': (
    kind: 'card',
    prompt:
        'Show the change you want to make to my config file as a diff I can review: three separate hunks with line numbers, removed lines in red and added lines in green in a monospace font, keep and discard buttons on each hunk, a count of what is kept, and an apply button that is only enabled once every hunk is decided.',
    followup: null,
  ),
  'image_gallery': (
    kind: 'card',
    prompt:
        'Show the nine photos from my trip as a gallery grid (use gradients as placeholders, each with a caption). Tapping one opens it large over the page with its caption, next and previous arrows, a counter like 3 of 9 and a close button; the arrow keys and escape work too.',
    followup: null,
  ),
};

/// What the user's message says about the UI, beyond the brief.
String userMessage(String brief, String kind) => switch (kind) {
  'card' => '$brief\n\n(Answer with one ui_apply call: an inline card, canvas width 390 with a hug height.)',
  'app' => '$brief\n\n(Answer with one ui_apply call: one app screen, canvas 390 × 760.)',
  _ => '$brief\n\n(Answer with one ui_apply call: one page, canvas 1440 × 900, responsive down to 390.)',
};

/// The trust profile a brief's UI gets: [api.TrustProfile.agentApps] for
/// apps when [scripts] is on, else [api.TrustProfile.agent].
api.TrustProfile profileFor(String kind, {bool scripts = true}) =>
    kind == 'app' && scripts ? api.TrustProfile.agentApps : api.TrustProfile.agent;

/// The tools for [variant] and [profile] over the core catalog (with
/// [designSystem]'s components when there is one): compact tools with
/// ui_docs, or the full schemas.
List<Map<String, Object?>> uiToolsFor(PromptVariant variant, {api.TrustProfile? profile, api.DesignSystem? designSystem}) => api.uiTools(
  _allowed(profile ?? api.TrustProfile.agent, designSystem).restrict(designSystem?.catalogOver(api.Catalog.core) ?? api.Catalog.core),
  compact: variant == PromptVariant.compact,
  docs: variant == PromptVariant.compact,
);

/// The tools for the agent profile over the core catalog (the full ones).
List<Map<String, Object?>> uiToolsForAgent() => uiToolsFor(PromptVariant.full);

/// The system prompt for [variant]: the base set generated now, or [full]
/// (assets/system_prompt.md).
///
/// With a [designSystem] the base is generated from it too: its principles,
/// tokens, components and patterns, without the base controls it replaces.
String systemPromptFor(
  PromptVariant variant, {
  required String full,
  String kind = 'card',
  api.TrustProfile? profile,
  api.DesignSystem? designSystem,
}) =>
    variant == PromptVariant.full
        ? full
        : api.runtimeStarter(profile: profile, kind: kind, designSystem: designSystem);

/// The answer to a lookup tool call, from the document the session holds.
Object? answerLookup(
  String tool,
  Map<String, Object?> input, {
  required api.LayoutDocument document,
  int rev = 0,
  api.TrustProfile? profile,
  api.DesignSystem? designSystem,
}) {
  final p = profile ?? api.TrustProfile.agent;
  final catalog = designSystem?.catalogOver(api.Catalog.core) ?? api.Catalog.core;
  final allowed = _allowed(p, designSystem);
  return switch (tool) {
    'ui_docs' => api.docsTopic('${input['topic'] ?? ''}', profile: p, designSystem: designSystem),
    'ui_read' => api.readUi(document, input, rev: rev, catalog: allowed.restrict(catalog)),
    _ => {'error': 'No tool "$tool".'},
  };
}

/// [profile] with [designSystem]'s components allowed, as
/// `UiSession(designSystem:)` has it.
api.TrustProfile _allowed(api.TrustProfile profile, api.DesignSystem? designSystem) =>
    designSystem == null ? profile : profile.withComponents(designSystem.components);
