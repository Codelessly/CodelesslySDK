import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// An image fill's imageColor tints the image like
// ColorFilter.mode(color, BlendMode.srcIn): a white texture drawn in a
// theme color.
void main() {
  Future<void> pumpFill(WidgetTester tester, PaintModel paint) =>
      tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: buildFill(
            RectangleNode(
              id: 'paper',
              name: 'Paper',
              basicBoxLocal: NodeBox(0, 0, 100, 100),
              fills: [paint],
            ),
            index: 0,
            useInk: false,
            settings: const WidgetBuildSettings(debugLabel: 'test'),
            scopedValues: ScopedValues.empty(),
          ),
        ),
      );

  PaintModel texture(String url, {ColorRGBA? tint, BlendModeC? mode}) =>
      PaintModel(
        id: 'topo',
        type: PaintType.image,
        downloadUrl: url,
        fit: Fit.cover,
        imageColor: tint,
        imageColorBlendMode: mode ?? BlendModeC.srcIn,
      );

  testWidgets('a tinted image takes the color with srcIn', (tester) async {
    await pumpFill(
      tester,
      texture('https://example.com/topo.png', tint: ColorRGBA.red),
    );
    final Image image = tester.widget(find.byType(Image));
    expect(image.color, const Color(0xFFFF0000));
    expect(image.colorBlendMode, BlendMode.srcIn);
  });

  testWidgets('the tint uses its blend mode', (tester) async {
    await pumpFill(
      tester,
      texture(
        'https://example.com/topo.png',
        tint: ColorRGBA.red,
        mode: BlendModeC.modulate,
      ),
    );
    final Image image = tester.widget(find.byType(Image));
    expect(image.colorBlendMode, BlendMode.modulate);
  });

  testWidgets('an untinted image has no color', (tester) async {
    await pumpFill(tester, texture('https://example.com/topo.png'));
    expect(tester.widget<Image>(find.byType(Image)).color, isNull);
  });
}
