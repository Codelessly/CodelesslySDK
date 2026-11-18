// `--wait` lets the test's clock pass, and `now()` (and `nowMs()`) with it:
// a deadline or a clock written from now() passes with the timers that run
// in that time (round 10, R22: 14 runs; a timer ticked through a nine-second
// wait while now() stood still). `--now` still pins it for the whole run.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

Map<String, Object?> _doc() => {
      'schema': 3,
      'id': 'clock',
      'roots': ['clock'],
      'nodes': {
        'clock': {
          'type': 'canvas',
          'slots': {'body': 'col'},
          'layout': {'width': 390, 'height': 300},
          'decoration': {
            'fills': [
              {'color': '#FFFFFFFF'},
            ],
          },
          'actions': [
            {
              'trigger': {'type': 'timer', 'intervalMs': 1000},
              'actions': [
                {'type': 'setVariable', 'variable': 'el', 'value': r'${= nowMs()-t0}'},
                {'type': 'setVariable', 'variable': 'ticks', 'value': r'${= ticks+1}'},
              ],
            },
            {
              'trigger': {'type': 'load'},
              'actions': [
                {'type': 'setVariable', 'variable': 't0', 'value': r'${= nowMs()}'},
              ],
            },
          ],
        },
        'col': {
          'type': 'column',
          'children': ['shown'],
          'layout': {'width': {'fill': 390}, 'height': {'hug': 0}, 'padding': 24},
        },
        'shown': {
          'type': 'text',
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
          'props': {'text': r'${el} ${ticks}'},
        },
      },
      'variables': {
        'clock': [
          {'name': 't0', 'type': 'integer', 'value': 0},
          {'name': 'el', 'type': 'integer', 'value': 0},
          {'name': 'ticks', 'type': 'integer', 'value': 0},
        ],
      },
    };

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_wait_clock_test'));
  tearDown(() => out.deleteSync(recursive: true));

  Future<(int, int)> run(WidgetTester tester, {DateTime? now}) async {
    final file = File('${out.path}/clock.json')..writeAsStringSync(jsonEncode(_doc()));
    final report = await runRender(tester,
        RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(390, 300)], steps: const [Step('wait', '5000')], dumpLayout: true, now: now));
    expect(report.errors, 0, reason: '${report.diagnostics}');
    final boxes = jsonDecode(File('${out.path}/o/clock@390x300.layout.json').readAsStringSync()) as List;
    final text = boxes.cast<Map>().firstWhere((b) => b['id'] == 'shown')['text'] as String;
    final parts = text.split(' ').map(int.parse).toList();
    return (parts[0], parts[1]);
  }

  testWidgets('now() moves with the wait, as the timers do', (tester) async {
    final (elapsed, ticks) = await run(tester);
    expect(ticks, greaterThanOrEqualTo(5));
    // Each tick saw the clock a second further on.
    expect(elapsed, ticks * 1000);
  });

  testWidgets('--now pins it for the whole run, as before', (tester) async {
    final (elapsed, ticks) = await run(tester, now: DateTime.utc(2026, 11, 13, 9));
    expect(ticks, greaterThanOrEqualTo(5));
    expect(elapsed, 0);
  });
}
