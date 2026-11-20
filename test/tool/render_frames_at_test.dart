// `--frames` captures at an exact time after any step, with no settle first:
// after a tap (an optimistic row, a pending spinner before its delay ends),
// a set, a wait, a hold still in progress (`--long-press id=399,hold`), and
// from the load itself when it is the first step (a mount animation, a first
// timer). The page's clock is the test's: timers, delays and animations move
// only by the frames pumped, so each frame is the same on every run. Each
// frame has its outline too with --dump-layout. (NOCD friction register:
// "Capture an exact animation or interaction frame", 16 parts.)
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

Map<String, Object?> _doc() => {
      'schema': 3,
      'id': 'page',
      'roots': ['page'],
      'nodes': {
        'page': {
          'type': 'canvas',
          'slots': {'body': 'col'},
          'layout': {'width': 390, 'height': 400},
          'decoration': {
            'fills': [
              {'color': '#FFFFFFFF'},
            ],
          },
          'actions': [
            // A clock started by the load: one tick each 100 ms.
            {
              'trigger': {'type': 'timer', 'intervalMs': 100},
              'actions': [
                {'type': 'setVariable', 'variable': 'ticks', 'value': r'${= ticks+1}'},
              ],
            },
          ],
        },
        'col': {
          'type': 'column',
          'children': ['shown', 'send', 'hold'],
          'layout': {'width': {'fill': 390}, 'height': {'hug': 0}, 'padding': 24},
        },
        'shown': {
          'type': 'text',
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
          'props': {'text': r'${ticks} ${status} ${held} ${x}'},
        },
        // Send: pending for 300 ms, then sent.
        'send': {
          'type': 'box',
          'layout': {'width': 200, 'height': 60},
          'decoration': {
            'fills': [
              {'color': '#FFDDDDDD'},
            ],
          },
          'actions': [
            {
              'trigger': {'type': 'click'},
              'actions': [
                {'type': 'setVariable', 'variable': 'status', 'value': 'pending'},
                {'type': 'delay', 'ms': 300},
                {'type': 'setVariable', 'variable': 'status', 'value': 'sent'},
              ],
            },
          ],
        },
        'hold': {
          'type': 'box',
          'layout': {'width': 200, 'height': 60},
          'decoration': {
            'fills': [
              {'color': '#FFBBBBBB'},
            ],
          },
          'actions': [
            {
              'trigger': {'type': 'longPress'},
              'actions': [
                {'type': 'setVariable', 'variable': 'held', 'value': 'yes'},
              ],
            },
          ],
        },
      },
      'variables': {
        'page': [
          {'name': 'ticks', 'type': 'integer', 'value': 0},
          {'name': 'status', 'type': 'text', 'value': 'idle'},
          {'name': 'held', 'type': 'text', 'value': 'no'},
          {'name': 'x', 'type': 'integer', 'value': 0},
        ],
      },
    };

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_frames_at_test'));
  tearDown(() => out.deleteSync(recursive: true));

  Future<RenderReport> run(WidgetTester tester, List<Step> steps) async {
    final file = File('${out.path}/page.json')..writeAsStringSync(jsonEncode(_doc()));
    final report = await runRender(tester,
        RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(390, 400)], steps: steps, dumpLayout: true, now: DateTime.utc(2026, 11, 20)));
    expect(report.errors, 0, reason: '${report.diagnostics}');
    return report;
  }

  // What `shown` says in a capture's layout dump: ticks, status, held, x.
  List<String> shown(String capture) {
    final boxes = jsonDecode(File('${out.path}/o/$capture.layout.json').readAsStringSync()) as List;
    return (boxes.cast<Map>().firstWhere((b) => b['id'] == 'shown')['text'] as String).split(' ');
  }

  testWidgets('first, --frames films from the load: no settle passes before frame 0', (tester) async {
    final report = await run(tester, const [Step('frames', '0,250')]);
    expect(report.images.where((i) => i.contains('-f1-')).length, 2);
    expect(shown('page@390x400-f1-0000ms')[0], '0', reason: 'frame 0 is the first frame of the loaded page');
    expect(shown('page@390x400-f1-0250ms')[0], '2', reason: 'two ticks of the 100 ms clock in 250 ms');
  });

  testWidgets('after a tap, a frame at 120 ms shows the pending state its 300 ms delay ends', (tester) async {
    await run(tester, const [Step('tap', 'send'), Step('frames', '120')]);
    expect(shown('page@390x400-f1-0120ms')[1], 'pending');
    expect(shown('page@390x400')[1], 'sent', reason: 'the capture at the end comes after the settle');
  });

  testWidgets('after a wait and after a set, the frame is that many ms later on the same clock', (tester) async {
    // (A step before a wait settles as usual: `--tap send --frames 120`, not
    // `--tap send --wait 120`, catches the tap's first 120 ms.)
    await run(tester, const [Step('wait', '500'), Step('frames', '0,300')]);
    expect(int.parse(shown('page@390x400-f1-0300ms')[0]) - int.parse(shown('page@390x400-f1-0000ms')[0]), 3,
        reason: 'three ticks of the 100 ms clock between the frames at 0 and 300 ms');
    await run(tester, const [Step('set', 'x', '5'), Step('frames', '[0]')]);
    expect(shown('page@390x400-f1-0000ms')[3], '5', reason: 'a manifest list ([0]) is a list of times too');
  });

  testWidgets('--long-press id=<ms>,hold keeps the finger down: a frame inside the hold', (tester) async {
    await run(tester, const [Step('long-press', 'hold=300,hold'), Step('frames', '0')]);
    expect(shown('page@390x400-f1-0000ms')[2], 'no', reason: '300 ms into the hold: not a long press yet');
    expect(shown('page@390x400')[2], 'yes', reason: 'held on through the settle, it becomes one');
  });

  test('a manifest step {"frames": [0,120]} is a --frames step', () {
    final args = parseArgs(['doc.json', '--out', 'o', '--tap', 'send', '--frames', '[0,120]']);
    expect(args.steps.last.kind, 'frames');
  });
}
