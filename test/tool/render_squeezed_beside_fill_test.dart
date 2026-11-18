// A row's squeezable texts beside a child that fills keep their own width,
// and the filling child takes the room left, whatever order the boxes are
// applied in: a toolbar drawn at a wide size and then at a narrower one gave
// its subject a third of its room (the small texts shared it as flexible
// children) and left the rest of the bar empty (support desk, test 11: "in
// some runs the subject was cut to ~130 px and Close sat mid-bar").
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

Map<String, Object?> _text(String text, {bool fill = false}) => {
      'type': 'text',
      'layout': {
        'squeezable': true,
        if (fill) 'flex': 1,
        'width': fill ? {'fill': 0} : {'hug': 0},
        'height': {'hug': 0},
      },
      'props': {
        'text': text,
        'style': {'fontSize': 13, 'color': '#FF111827'},
      },
    };

Map<String, Object?> _doc() => {
      'schema': 3,
      'id': 'bar',
      'roots': ['bar'],
      'nodes': {
        'bar': {
          'type': 'canvas',
          'slots': {'body': 'row'},
          'layout': {'width': 1440, 'height': 200},
          'decoration': {
            'fills': [
              {'color': '#FFFFFFFF'},
            ],
          },
        },
        'row': {
          'type': 'row',
          'layout': {'width': {'fill': 0}, 'height': 48, 'padding': [16, 0, 16, 0]},
          'props': {'spacing': 8, 'crossAxisAlignment': 'center'},
          'children': ['back', 'pos', 'num', 'title', 'close'],
        },
        'back': {
          'type': 'iconButton',
          'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
          'props': {'icon': 'arrow_back'},
        },
        'pos': _text('1 of 6'),
        'num': _text('#4821'),
        'title': _text('Invoice shows the wrong VAT number', fill: true),
        'close': {
          'type': 'outlinedButton',
          'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
          'props': {'label': 'Close'},
        },
      },
    };

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_squeezed_beside_fill_test'));
  tearDown(() => out.deleteSync(recursive: true));

  testWidgets('at a narrower size after a wider one, the title takes the room left', (tester) async {
    final file = File('${out.path}/bar.json')..writeAsStringSync(jsonEncode(_doc()));
    final report = await runRender(tester,
        RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(1440, 200), Size(834, 200)], dumpLayout: true));
    expect(report.errors, 0, reason: '${report.diagnostics}');
    for (final w in [1440, 834]) {
      final boxes = (jsonDecode(File('${out.path}/o/bar@${w}x200.layout.json').readAsStringSync()) as List).cast<Map>();
      Map box(String id) => boxes.firstWhere((b) => b['id'] == id);
      final close = box('close');
      // The button sits at the bar's end: nothing is left over after it.
      expect((close['x'] as num) + (close['w'] as num), closeTo(w - 16, 1), reason: 'at $w: ${box('title')}');
      // The small texts keep their own width.
      expect(box('pos')['h'], box('num')['h'], reason: 'at $w');
      expect((box('title')['w'] as num), greaterThan(w / 2), reason: 'at $w');
    }
  });
}
