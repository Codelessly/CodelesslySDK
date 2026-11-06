import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Lamplight's pills: a 15 px bulb centred in a 30 px pill sits at y 7.5.
// Flutter's Icon draws it as a MaterialIcons glyph whose baseline (the
// box's bottom: the font's ascent is its em, its descent 0) the rasterizer
// rounds to a whole device pixel, so the reference's bulb is drawn crisp
// half a pixel lower than an SVG drawn where its box is (the site's icons
// sat 0.5 px high and blurred over an extra row). An icon node's SVG is
// snapped the same way.

/// The rows of [image] (rgba) whose pixels in column [x] are opaque.
List<int> _opaqueRows(ByteData data, int width, int height, int x) => [
  for (int y = 0; y < height; y++)
    if (data.getUint8((y * width + x) * 4 + 3) > 250) y,
];

Future<(ByteData, int, int)> _paint(
  WidgetTester tester, {
  required double top,
  bool snapped = true,
  double devicePixelRatio = 1,
}) async {
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.reset);
  final GlobalKey key = GlobalKey();
  const Widget box = SizedBox.square(
    dimension: 15,
    child: ColoredBox(color: Color(0xFF000000)),
  );
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Padding(
              padding: EdgeInsets.only(top: top),
              child: Align(
                alignment: Alignment.topLeft,
                child: snapped ? const PixelSnappedBaseline(child: box) : box,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  late ByteData data;
  late int width;
  late int height;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(
      pixelRatio: devicePixelRatio,
    );
    width = image.width;
    height = image.height;
    data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  });
  return (data, width, height);
}

void main() {
  test('the shift to the nearest whole device pixel', () {
    double shift(double y, {double dpr = 1, double bottom = 15}) =>
        RenderPixelSnappedBaseline.snapShift(
          Matrix4.diagonal3Values(dpr, dpr, 1)
            ..multiply(Matrix4.translationValues(0, y, 0)),
          bottom,
        );
    // 7.5 + 15 = 22.5: a half rounds down the screen, as a glyph's
    // baseline does.
    expect(shift(7.5), 0.5);
    expect(shift(7.2), closeTo(-0.2, 1e-9));
    expect(shift(7.7), closeTo(0.3, 1e-9));
    expect(shift(7), 0);
    // At 2x, 22.5 is a whole device pixel (45).
    expect(shift(7.5, dpr: 2), 0);
    expect(shift(7.25, dpr: 2), 0.25);
    // Rotated: glyphs aren't snapped.
    expect(
      RenderPixelSnappedBaseline.snapShift(Matrix4.rotationZ(0.3), 15),
      0,
    );
  });

  testWidgets('a box at y 7.5 is painted from y 8, crisp', (tester) async {
    final (ByteData data, int width, int height) = await _paint(
      tester,
      top: 7.5,
    );
    expect(_opaqueRows(data, width, height, 7), [for (int y = 8; y < 23; y++) y]);
  });

  testWidgets('unsnapped it is blurred over 16 rows', (tester) async {
    final (ByteData data, int width, int height) = await _paint(
      tester,
      top: 7.5,
      snapped: false,
    );
    // Only the 14 rows fully inside 7.5..22.5 are opaque.
    expect(_opaqueRows(data, width, height, 7), hasLength(14));
  });

  testWidgets('on whole pixels it stays put', (tester) async {
    final (ByteData data, int width, int height) = await _paint(
      tester,
      top: 7,
    );
    expect(_opaqueRows(data, width, height, 7), [for (int y = 7; y < 22; y++) y]);
  });

  testWidgets('a Material icon\'s SVG is painted snapped', (tester) async {
    // A square icon, served instead of the network.
    SvgIcon.httpClient = MockClient(
      (_) async => http.Response(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
        '<rect width="24" height="24"/></svg>',
        200,
      ),
    );
    addTearDown(() => SvgIcon.httpClient = null);
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: key,
            child: const SizedBox(
              width: 30,
              height: 30,
              child: Padding(
                padding: EdgeInsets.only(top: 7.5),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SvgIcon(
                    icon: MaterialIcon(
                      codepoint: 0,
                      name: 'lightbulb',
                      style: MaterialIconStyle.rounded,
                      version: 18,
                    ),
                    size: 15,
                    color: Color(0xFF000000),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(PixelSnappedBaseline), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    late ByteData data;
    late int width;
    late int height;
    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage();
      width = image.width;
      height = image.height;
      data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    expect(_opaqueRows(data, width, height, 7), [for (int y = 8; y < 23; y++) y]);
  });
}
