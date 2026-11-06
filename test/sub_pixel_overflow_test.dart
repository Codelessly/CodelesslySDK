import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fixed column whose children fit to within a fraction of a pixel (text
/// heights from fonts are fractional) fits: no overflow warning, no clip.
void main() {
  Future<RenderCodelesslyFlex> pump(
    WidgetTester tester, {
    required double last,
    bool squeeze = true,
    double spacing = 0,
  }) async {
    // A 75 px column with padding 3 and 16.7: 55.3 px for its children.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 100,
            height: 75,
            child: Padding(
              padding: const EdgeInsets.only(top: 3, bottom: 16.7),
              child: CodelesslyFlex(
                direction: Axis.vertical,
                clipBehavior: Clip.hardEdge,
                squeeze: squeeze,
                spacing: spacing,
                children: [
                  const SizedBox(height: 30, width: 10),
                  SizedBox(height: last, width: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return tester.renderObject<RenderCodelesslyFlex>(
      find.byType(CodelesslyFlex),
    );
  }

  bool clips(WidgetTester tester) {
    final RenderCodelesslyFlex flex = tester.renderObject(
      find.byType(CodelesslyFlex),
    );
    return flex.describeApproximatePaintClip(flex.firstChild!) != null;
  }

  for (final bool squeeze in [true, false]) {
    testWidgets('overflow by 0.404 px fits (squeeze: $squeeze)', (
      tester,
    ) async {
      final flex = await pump(tester, last: 25.704, squeeze: squeeze);
      expect(flex.size.height, closeTo(55.3, 1e-9));
      // Painting reports no overflow (it would throw in a test).
      expect(tester.takeException(), isNull);
      expect(clips(tester), isFalse);
      expect(tester.layers.whereType<ClipRectLayer>(), isEmpty);
    });
  }

  testWidgets('sub-pixel overflow with spacing fits', (tester) async {
    await pump(tester, last: 15.704, spacing: 10);
    expect(tester.takeException(), isNull);
    expect(clips(tester), isFalse);
  });

  testWidgets('overflow by a pixel or more still warns and clips', (
    tester,
  ) async {
    await pump(tester, last: 26.5, squeeze: false);
    expect('${tester.takeException()}', contains('overflowed by 1.2 pixels'));
    expect(clips(tester), isTrue);
  });
}
