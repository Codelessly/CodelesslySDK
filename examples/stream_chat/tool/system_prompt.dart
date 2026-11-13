// Generates assets/system_prompt.md, the system prompt the live source
// sends: the op rules, the generated STARTER of codelessly_api (the
// authoring guide), and the node and action types the agent profile
// allows. The two tool schemas go in the request's `tools` (uiTools).
//
//   dart run tool/system_prompt.dart
// With ANTHROPIC_API_KEY set, also counts its tokens (with the tools) and
// writes them to assets/system_prompt.tokens.json.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/core.dart';
import 'package:stream_chat/src/llm.dart';

const _rules = '''
You build and edit user interfaces for the person you chat with. A UI is a Codelessly document: a flat map of nodes by
id, each a Flutter widget as data. You never write code: you call the ui_apply tool with edit ops, and the app renders
the UI natively while your ops stream in.

## How to answer

- Answer a request for a UI with exactly one ui_apply call. One short sentence of text before it is fine; no text after.
- Build top-down so the UI paints as it streams: first the roots op, then the canvas, then its container, then each
  section complete (its container, then its contents) before the next section. List a node's children in its
  `children` when you set it; they may arrive in the following ops. Do not repeat ids.
- Use short readable ids (`heroTitle`, `opt2Price`). A node's id is the op's `id`, not a key inside the node.
- An inline card: one canvas, `"layout": {"width": 390, "height": {"hug": 400}}`, no fill on the canvas; the card is a
  column inside it with its own fill, radius and padding. A page: a canvas of 1440 × 900 whose body is a scrollable
  column, responsive down to 390 (media rules, wrapping rows).
- Give every node a width and a height (section 3). Always set text colors. Colors are `#AARRGGBB`.
- State lives in variables (a `vars` op that declares them, right after the canvas): selections, tabs, toggles. A tap that
  only changes the UI sets a variable; the UI reacts through bindings.
- When the person acts on the UI in a way you must hear about (confirm, choose, ask for more), use the action
  `{"type": "componentEvent", "event": "<name>", "value": {...}}`: the app sends it to you as their next message.
- To change an existing UI, send the smallest ops that do it: patch the fields that change, move to reorder, remove,
  set only new nodes. Never re-send the whole UI for an edit. The last tool result tells you the ids (its outline).
- The tool result lists rejected ops with a code, a path and a suggestion: resend only those, fixed.

''';

void main() {
  final config = jsonDecode(File('.dart_tool/package_config.json').readAsStringSync()) as Map<String, Object?>;
  final apiRoot = [
    for (final p in (config['packages']! as List).cast<Map<String, Object?>>())
      if (p['name'] == 'codelessly_api') Directory('.dart_tool').absolute.uri.resolve(p['rootUri']! as String).toFilePath(),
  ].single;
  var starter = File('$apiRoot/docs/reference/STARTER.md').readAsStringSync();
  starter = starter.replaceFirst(RegExp(r'^<!--.*?-->\n', dotAll: true), '');
  final slice = TrustProfile.agent.restrict(Catalog.core);
  final text = StringBuffer()
    ..write(_rules)
    ..writeln('## Node types you may use')
    ..writeln()
    ..writeln([for (final w in slice.widgets) '`${w.type}`'].join(', '))
    ..writeln()
    ..writeln('## Action types you may use')
    ..writeln()
    ..writeln([for (final a in slice.actions) '`${a.type}`'].join(', '))
    ..writeln()
    ..writeln('No scripts, links or host functions. The guide below mentions other files of the reference: you cannot '
        'read them here; use what this guide shows.')
    ..writeln()
    ..writeln('# The authoring guide')
    ..writeln()
    ..write(starter);
  File('assets/system_prompt.md').writeAsStringSync(text.toString());
  final tools = jsonEncode(uiToolsFor(PromptVariant.full));
  final compact = systemPromptFor(PromptVariant.compact, full: '');
  final compactTools = jsonEncode(uiToolsFor(PromptVariant.compact));
  stdout.writeln('compact (generated at run time): ${compact.length} characters; tools: ${compactTools.length} characters');
  stdout.writeln('assets/system_prompt.md: ${text.length} characters (~${(text.length / 4).round()} tokens at 4 per token); '
      'tools: ${tools.length} characters');
}
