import 'package:codelessly_example/main.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the entry screen of the bundled project', (tester) async {
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      // Test fonts are wider than the designs': overflows aren't failures.
      if (!'${d.exception}'.contains('overflowed by')) original?.call(d);
    };
    addTearDown(() => FlutterError.onError = original);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ExampleApp());
    // Loading the asset is real I/O.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(NodeView), findsOneWidget);
    expect(find.byType(CodelesslyErrorScreen), findsNothing);
  });
}
