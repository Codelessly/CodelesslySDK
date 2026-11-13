// Writes the synthetic recorded streams the replay harness plays: each UI
// in tool/stream/ui as the ui_apply tool input a model would stream
// (opsFromDocument: roots, variables, then top-down, section by section),
// cut into deltas of 1-4 tokens (~4 characters per token) at a given output
// rate, each with its time. Also the follow-up edits in tool/stream/followups.
//
//   dart run tool/stream/make_streams.dart [--out tool/stream/streams] [--rates 60,150,400]
//
// File format (JSON lines): a first line {"meta": {...}}, then one line per
// delta, {"tMs": 1234, "delta": "..."}. Live recordings (record.dart in
// examples/stream_chat) use the same format with the model's real deltas.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:codelessly_api/core.dart';

const _uis = {
  'flights': (file: 'flights.json', kind: 'card', brief: 'A flight-options card for London to Lisbon: three selectable options and a confirm button.'),
  'weather': (file: 'weather.json', kind: 'card', brief: 'A weather card for Lisbon: now, the next hours and three days, with a rain alert button.'),
  'restaurant_menu': (file: 'restaurant_menu.json', kind: 'page', brief: 'A restaurant menu page (m05 experiment, restaurant-B).'),
  'saas_pricing': (file: 'saas_pricing.json', kind: 'page', brief: 'A SaaS pricing page (m05 experiment, saas-landing-B).'),
};

/// Synthetic time to first token, before the first delta.
const _ttftMs = 500;

void main(List<String> args) {
  String opt(String name, String fallback) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
  }

  final here = File.fromUri(Platform.script).parent.path;
  final out = Directory(opt('--out', '$here/streams'))..createSync(recursive: true);
  final rates = [for (final r in opt('--rates', '60,150,400').split(',')) int.parse(r)];
  for (final e in _uis.entries) {
    final doc = LayoutDocument.fromJson(jsonDecode(File('$here/ui/${e.value.file}').readAsStringSync()));
    final text = toolInputText(opsFromDocument(doc));
    for (final rate in rates) {
      final file = File('${out.path}/${e.key}@${rate}tps.jsonl');
      _write(file, text, rate, {
        'ui': e.key,
        'kind': e.value.kind,
        'brief': e.value.brief,
        'source': 'synthetic',
        'rateTokensPerSecond': rate,
        'ttftMs': _ttftMs,
        'tokensEstimated': true,
        'charsPerToken': 4,
        'assets': 'tool/stream/ui/assets',
      });
    }
  }
  for (final f in Directory('$here/followups').listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
    final j = jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
    final ops = [for (final o in j['ops']! as List) EditOp.fromJson(o)!];
    final text = toolInputText(ops);
    final name = f.uri.pathSegments.last.replaceAll('.json', '');
    final rate = 150;
    _write(File('${out.path}/$name@${rate}tps.jsonl'), text, rate, {
      'ui': j['ui'],
      'kind': 'card',
      'followup': j['prompt'],
      'base': '${j['ui']}@${rate}tps.jsonl',
      'source': 'synthetic',
      'rateTokensPerSecond': rate,
      'ttftMs': _ttftMs,
      'tokensEstimated': true,
      'charsPerToken': 4,
    });
  }
}

void _write(File file, String text, int rate, Map<String, Object?> meta) {
  final rnd = Random(text.length ^ rate);
  final b = StringBuffer()..writeln(jsonEncode({'meta': {...meta, 'chars': text.length, 'outputTokens': (text.length / 4).ceil()}}));
  var at = 0;
  var tokens = 0.0;
  while (at < text.length) {
    final n = 1 + rnd.nextInt(4);
    final end = min(text.length, at + n * 4);
    tokens += (end - at) / 4;
    final t = _ttftMs + (tokens / rate * 1000).round();
    b.writeln(jsonEncode({'tMs': t, 'delta': text.substring(at, end)}));
    at = end;
  }
  file.writeAsStringSync(b.toString());
  stdout.writeln('${file.path}: ${text.length} chars, ~${(text.length / 4).ceil()} tokens');
}
