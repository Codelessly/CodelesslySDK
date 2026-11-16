// The pinch trigger (a node's `pinch` reaction): the scale of each step of
// a pinch and the point it is about, from two fingers on a touch screen or
// a trackpad, so one reaction zooms about the pinch point (Tablewright's
// plan: zoom = zoom * result.scale, the sheet point under x, y kept still).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screen.dart' as harness;

Map<String, Json> _page() => {
      'col': {
        'type': 'column',
        'layout': {'width': 400, 'height': 400},
        'children': ['board'],
      },
      'board': {
        'type': 'box',
        'layout': {'width': 400, 'height': 400},
        'decoration': {'fills': [{'color': '#FFEEEEEE'}]},
        'actions': [
          {
            'trigger': {'type': 'pinch'},
            'actions': [
              {'type': 'setVariable', 'variable': 'zoom', 'value': r'${= zoom * result.scale}'},
              {'type': 'setVariable', 'variable': 'fx', 'value': r'${result.x}'},
              {'type': 'setVariable', 'variable': 'fy', 'value': r'${result.y}'},
            ],
          },
        ],
      },
    };

const _vars = [
  Variable(name: 'zoom', type: VariableType.decimal, value: 1.0),
  Variable(name: 'fx', type: VariableType.decimal, value: 0.0),
  Variable(name: 'fy', type: VariableType.decimal, value: 0.0),
];

void main() {
  testWidgets('two fingers on a touch screen pinch: the scale of each step about the point between them', (tester) async {
    final s = await harness.show(tester, _page(), variables: _vars);
    final origin = s.tree.boxOf('board')!.localToGlobal(Offset.zero);
    final a = await tester.startGesture(origin + const Offset(150, 200), pointer: 1, kind: PointerDeviceKind.touch);
    final b = await tester.startGesture(origin + const Offset(250, 200), pointer: 2, kind: PointerDeviceKind.touch);
    await tester.pump();
    // The fingers move apart: 100 px apart becomes 200.
    await a.moveTo(origin + const Offset(100, 200));
    await tester.pump();
    await b.moveTo(origin + const Offset(300, 200));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(s['zoom'] as num, closeTo(2.0, 0.001));
    expect(s['fx'] as num, closeTo(200, 0.5));
    expect(s['fy'] as num, closeTo(200, 0.5));
  });

  testWidgets('a trackpad pinch says where the pointer is', (tester) async {
    final s = await harness.show(tester, _page(), variables: _vars);
    final origin = s.tree.boxOf('board')!.localToGlobal(Offset.zero);
    tester.binding.handlePointerEvent(PointerScaleEvent(position: origin + const Offset(120, 80), scale: 1.25));
    await tester.pumpAndSettle();
    expect(s['zoom'] as num, closeTo(1.25, 0.001));
    expect(s['fx'] as num, closeTo(120, 0.5));
    expect(s['fy'] as num, closeTo(80, 0.5));
  });
}
