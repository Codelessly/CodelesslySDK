import 'dart:math';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_actions_test.dart' show body, canvas, layoutOf, pumpLayouts;

void main() {
  testWidgets('a bound rotation turns the node by fractional degrees', (
    tester,
  ) async {
    final knob =
        FrameNode(
            id: 'knob',
            name: 'knob',
            basicBoxLocal: NodeBox(0, 0, 100, 100),
            children: [],
          )
          ..parentID = 'mainBody'
          ..variables['rotation'] = r'${= 360 * (1 - 2832 / 3600)}';
    await pumpLayouts(tester, [
      layoutOf('layout', [
        canvas('main', 'mainBody'),
        body('mainBody', 'main', ['knob']),
        knob,
      ]),
    ]);
    await tester.pump();

    final double expected = 360 * (1 - 2832 / 3600) * pi / 180;
    final Iterable<Transform> turned = tester
        .widgetList<Transform>(find.byType(Transform))
        .where(
          (t) =>
              (t.transform.getRotation().entry(1, 0) - sin(expected)).abs() <
              1e-6,
        );
    expect(turned, isNotEmpty);
  });
}
