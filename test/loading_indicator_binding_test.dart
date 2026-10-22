import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_actions_test.dart' show body, canvas, layoutOf, pumpLayouts;

void main() {
  testWidgets('a loading indicator draws its bound value and color', (
    tester,
  ) async {
    final ring =
        LoadingIndicatorNode(
            id: 'ring',
            name: 'ring',
            basicBoxLocal: NodeBox(0, 0, 120, 120),
            properties: MaterialLoadingIndicatorProperties(
              color: const ColorRGBA(r: 0, g: 0, b: 0, a: 1),
              value: 1,
            ),
          )
          ..parentID = 'mainBody'
          ..variables['value'] = r'${= 2832 / 3600}'
          ..variables['color'] = r"${= 1 > 0 ? '#C9A24A' : '#D2553F'}";
    await pumpLayouts(tester, [
      layoutOf('layout', [
        canvas('main', 'mainBody'),
        body('mainBody', 'main', ['ring']),
        ring,
      ]),
    ]);
    await tester.pump();

    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.value, closeTo(2832 / 3600, 1e-9));
    expect(indicator.color, const Color(0xFFC9A24A));
  });
}
