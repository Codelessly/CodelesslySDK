// A text field whose decoration sets its content padding is as tall on a
// desktop platform (compact density) as on a phone: the padding is the design.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'actions/wiring_test.dart' show show;

Map<String, Map<String, Object?>> _field({bool padded = true}) => {
      'col': {'type': 'column', 'children': ['f'], 'layout': {'width': 300, 'height': 200}},
      'f': {
        'type': 'textField',
        'layout': {'width': 300, 'height': {'hug': 0}},
        'props': {
          'style': {'fontSize': 13, 'height': 1.35},
          'decoration': {
            'isDense': true,
            if (padded) 'contentPadding': [10, 8, 10, 8],
            'border': {'type': 'outline', 'borderSide': {'color': '#FFB8C2CE', 'width': 1}, 'borderRadius': 4},
          },
        },
      },
    };

Future<double> _height(WidgetTester tester, TargetPlatform platform, {bool padded = true}) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    final s = await show(tester, _field(padded: padded));
    await tester.pumpAndSettle();
    return s.tree.boxOf('f')!.size.height;
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  testWidgets('a padded field keeps its height on desktop', (tester) async {
    final phone = await _height(tester, TargetPlatform.android);
    final desktop = await _height(tester, TargetPlatform.macOS);
    expect(desktop, phone);
    expect(phone, closeTo(8 + 13 * 1.35 + 8, 1.5));
  });
}
