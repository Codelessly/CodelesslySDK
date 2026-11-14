// Records one real generation written as A2UI v1.0 messages, for the
// comparison with the compact notation: the same briefs, A2UI's own
// published schemas and basic catalog as the instructions (tool/a2ui_v1),
// no tools, and the answer drawn by this renderer through
// package:codelessly_api's A2UI front end. The answer's
// text is saved delta by delta with its timing, then expanded, validated
// and summarised (prompt and output tokens, time to first token and to the
// end, nodes, what the notation could not read, validation errors).
//
//   ANTHROPIC_API_KEY=... dart run tool/record_a2ui.dart --ui approval \
//       --model claude-haiku-5-5 --out recordings/approval@claude-haiku-5-5.a2ui.jsonl
//
// The key is read from the environment only and never written anywhere.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/notation.dart';
import 'package:codelessly_api/validate.dart';
import 'package:stream_chat/src/llm.dart';

Future<void> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf(name);
    return i < 0 || i + 1 >= args.length ? null : args[i + 1];
  }

  final key = Platform.environment['ANTHROPIC_API_KEY'] ?? '';
  if (key.isEmpty) {
    stderr.writeln('ANTHROPIC_API_KEY is not set.');
    exit(2);
  }
  final ui = opt('--ui') ?? 'approval';
  final brief = kBriefs[ui];
  if (brief == null) {
    stderr.writeln('No brief "$ui". Briefs: ${kBriefs.keys.join(', ')}');
    exit(2);
  }
  final model = opt('--model') ?? 'claude-haiku-5-5';
  final out = opt('--out') ?? 'recordings/$ui@$model.a2ui.jsonl';
  final retries = int.tryParse(opt('--retries') ?? '') ?? 1;
  final dir = File.fromUri(Platform.script).parent.path;
  String spec(String name) => File('$dir/a2ui_v1/$name').readAsStringSync();
  // As A2UI's agent SDKs instruct a model: the message schema, the common
  // types and the catalog (with its own guidelines and examples).
  final system = 'You generate user interfaces as A2UI v1.0 messages. Answer with JSON Lines only: one A2UI message per line, '
      'no prose and no code fence. Create one surface, give it a component with the id "root", and put the data its components bind to in the data model.\n\n'
      '## Message schema (agent_to_renderer.json)\n${spec('agent_to_renderer.json')}\n\n'
      '## Common types (common_types.json)\n${spec('common_types.json')}\n\n'
      '## Catalog (catalog.json)\n${spec('catalog.json')}';
  final user = '${brief.prompt}\n\n(Answer with A2UI JSON Lines only: an inline card 390 wide.)';
  final messages = <Map<String, Object?>>[
    {'role': 'user', 'content': user},
  ];
  final summary = <String, Object?>{'ui': ui, 'kind': brief.kind, 'model': model, 'form': 'a2ui', 'systemPromptChars': system.length};
  final turns = <Object?>[];
  try {
    for (var n = 0; n <= retries; n++) {
      final turn = await _turn(key, model, system, messages);
      final r = Catalog.run(standardCatalog, () => parseA2ui(turn.text, catalog: standardCatalog));
      final problems = Catalog.run(standardCatalog, () => validateDocument(r.document))
          .where((d) => d.severity == Severity.error)
          .map((d) => '${d.code.name} ${d.path}: ${d.message}')
          .toList();
      final nodes = (r.document['nodes'] as Map).length;
      final lines = const LineSplitter().convert(turn.text).where((l) => l.trim().isNotEmpty).toList();
      final file = n == 0 ? out : out.replaceFirst(RegExp(r'\.jsonl$'), '.retry$n.jsonl');
      File(file).parent.createSync(recursive: true);
      File(file).writeAsStringSync([
        jsonEncode({
          'meta': {'ui': ui, 'model': model, 'form': 'a2ui', 'turn': n == 0 ? 'generate' : 'retry', 'prompt': brief.prompt, 'text': turn.text, 'usage': turn.usage, 'ttftMs': turn.ttftMs, 'totalMs': turn.totalMs},
        }),
        for (final d in turn.deltas) jsonEncode({'tMs': d.$1, 'delta': d.$2}),
      ].join('\n'));
      File(file.replaceFirst(RegExp(r'\.jsonl$'), '.json')).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(r.document));
      turns.add({
        ...turn.usage,
        'ttftMs': turn.ttftMs,
        'totalMs': turn.totalMs,
        'chars': turn.text.length,
        'lines': lines.length,
        'jsonTails': lines.where((l) => RegExp(r' \{.*\}\s*$').hasMatch(l)).length,
        'nodes': nodes,
        'outputTokensPerNode': nodes == 0 ? null : ((turn.usage['output_tokens'] as int? ?? 0) / nodes).toStringAsFixed(1),
        'notationIssues': [for (final i in r.issues) '$i'],
        'notes': r.notes,
        'messages': lines.length,
        'errors': problems,
      });
      if (nodes <= 1) problems.add('No surface with a root component could be read from the answer.');
      if (r.issues.isEmpty && problems.isEmpty) break;
      if (n == retries) break;
      messages
        ..add({'role': 'assistant', 'content': turn.text})
        ..add({
          'role': 'user',
          'content': 'That had problems. Write the whole UI again as A2UI JSON Lines, fixed:\n'
              '${[for (final i in r.issues) '- $i', for (final p in problems.take(12)) '- $p'].join('\n')}',
        });
    }
  } catch (e) {
    summary['error'] = '$e'.split('\n').first;
    exitCode = 1;
  }
  summary['turns'] = turns;
  final text = const JsonEncoder.withIndent(' ').convert(summary);
  stdout.writeln(text);
  File(out.replaceFirst(RegExp(r'\.jsonl$'), '.summary.json')).writeAsStringSync(text);
}

typedef _Turn = ({String text, Map<String, Object?> usage, int ttftMs, int totalMs, List<(int, String)> deltas});

Future<_Turn> _turn(String key, String model, String system, List<Map<String, Object?>> messages) async {
  final client = HttpClient()..findProxy = HttpClient.findProxyFromEnvironment;
  final watch = Stopwatch()..start();
  try {
    final request = await client.postUrl(Uri.parse('https://api.anthropic.com/v1/messages'));
    request.headers
      ..set('content-type', 'application/json')
      ..set('x-api-key', key)
      ..set('anthropic-version', '2023-06-01');
    // As the ui_apply recorder: low effort, and thinking off where the model
    // allows it, so the two forms are compared on the same footing.
    request.add(utf8.encode(jsonEncode({
      'model': model,
      'max_tokens': 16000,
      'stream': true,
      'system': system,
      'messages': messages,
      'output_config': {'effort': 'low'},
      if (model == 'claude-haiku-5-5') 'thinking': {'type': 'disabled'},
    })));
    final response = await request.close();
    if (response.statusCode != 200) {
      final body = await utf8.decodeStream(response);
      throw StateError('HTTP ${response.statusCode}: ${body.length > 300 ? body.substring(0, 300) : body}');
    }
    final text = StringBuffer();
    final deltas = <(int, String)>[];
    final usage = <String, Object?>{};
    var ttft = -1;
    await for (final line in response.transform(utf8.decoder).transform(const LineSplitter())) {
      if (!line.startsWith('data: ')) continue;
      final Object? j;
      try {
        j = jsonDecode(line.substring(6));
      } catch (_) {
        continue;
      }
      if (j is! Map) continue;
      switch (j['type']) {
        case 'message_start':
          final u = ((j['message'] as Map?)?['usage'] as Map?)?.cast<String, Object?>();
          if (u != null) usage.addAll(u);
        case 'content_block_delta':
          final d = (j['delta'] as Map?)?['text'];
          if (d is String && d.isNotEmpty) {
            if (ttft < 0) ttft = watch.elapsedMilliseconds;
            deltas.add((watch.elapsedMilliseconds, d));
            text.write(d);
          }
        case 'message_delta':
          final u = (j['usage'] as Map?)?.cast<String, Object?>();
          if (u != null) usage.addAll(u);
      }
    }
    return (text: _unfenced(text.toString()), usage: usage, ttftMs: ttft, totalMs: watch.elapsedMilliseconds, deltas: deltas);
  } finally {
    client.close(force: true);
  }
}

/// The answer without a code fence, if the model wrote one.
String _unfenced(String s) {
  final m = RegExp(r'^\s*```[a-z]*\n([\s\S]*?)\n```\s*$').firstMatch(s);
  return m == null ? s : m[1]!;
}
