import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A centred scrolling column whose content grows after the first layout
/// (a form that finishes loading) without anything above it rebuilding.
Widget page(ValueNotifier<double> height, {bool expanded = false}) =>
    MaterialApp(
      home: SingleChildScrollView(
        child: ScrollContentExtent(
          axis: Axis.vertical,
          viewportExtent: 600,
          child: CodelesslyFlex(
            direction: Axis.vertical,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: height,
                builder: (context, h, _) =>
                    SizedBox(key: const ValueKey('content'), height: h),
              ),
              if (expanded) const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );

void main() {
  for (final expanded in [false, true]) {
    final label = expanded ? 'with a flex child' : 'centred';
    testWidgets('$label content that grows past the viewport scrolls', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final height = ValueNotifier<double>(300);
      await tester.pumpWidget(page(height, expanded: expanded));
      expect(tester.getSize(find.byType(CodelesslyFlex)).height, 600);

      height.value = 1000;
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(CodelesslyFlex)).height, 1000);

      // And shrinks back to fill the viewport.
      height.value = 200;
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(CodelesslyFlex)).height, 600);
      expect(
        tester.getCenter(find.byKey(const ValueKey('content'))).dy,
        expanded ? 100 : 300,
      );
    });
  }
}
