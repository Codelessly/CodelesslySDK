// A motion path in a viewBox, stretched over the node's parent (Strata v2:
// a trackmaker walks up a dune on a figure whose size follows the screen).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'actions/wiring_test.dart' as wiring show show;

Map<String, Json> figure(double width, double height, {List<double>? viewBox, double progress = 1}) => {
      'stage': {
        'type': 'stack',
        'layout': {'width': width, 'height': height},
        'children': ['walker'],
      },
      'walker': {
        'type': 'box',
        'layout': {'width': 10, 'height': 10},
        'motion': {
          'path': 'M0 0 L320 0 L320 180',
          'pathProgress': progress,
          'pathViewBox': ?viewBox,
        },
      },
    };

Offset _at(NodeTree tree, String id) => tree.boxOf(id)!.contentBox!.localToGlobal(Offset.zero) - tree.boxOf('stage')!.localToGlobal(Offset.zero);

void main() {
  testWidgets('without a viewBox the path is in pixels', (tester) async {
    final s = await wiring.show(tester, figure(640, 360), root: 'stage');
    await tester.pump();
    final p = _at(s.tree, 'walker');
    expect(p.dx, closeTo(320, 6));
    expect(p.dy, closeTo(180, 6));
  });

  testWidgets('with a viewBox it is stretched over the parent', (tester) async {
    final s = await wiring.show(tester, figure(640, 360, viewBox: [320, 180]), root: 'stage');
    await tester.pump();
    await tester.pump();
    final p = _at(s.tree, 'walker');
    expect(p.dx, closeTo(640, 6));
    expect(p.dy, closeTo(360, 6));
  });

  testWidgets('halfway along the first leg, stretched non-uniformly', (tester) async {
    // the path is 500 long: 0.32 of it is 160 along the first leg
    final s = await wiring.show(tester, figure(720, 180, viewBox: [320, 180], progress: 0.32), root: 'stage');
    await tester.pump();
    await tester.pump();
    final p = _at(s.tree, 'walker');
    expect(p.dx, closeTo(360, 6));
    expect(p.dy, closeTo(0, 6));
  });
}
