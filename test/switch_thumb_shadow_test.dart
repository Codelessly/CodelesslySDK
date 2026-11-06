import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lamplight's power toggle: a 50×30 track with a 24 px white thumb 3 px
/// from its edges that casts a `0x33000000` shadow (blur 4, 1 px down), as
/// the reference's `AnimatedContainer` toggle draws it. Material's switch
/// has no thumb shadow and, scaled to 50×30, draws a 22.5 px oval thumb, so
/// a switch with thumbShadows or a thumbInset is a plain toggle.
void main() {
  final Effect shadow = Effect.dropShadow(
    id: 'thumb',
    color: ColorRGBA.fromHex('#33000000')!,
    offset: const Vec(0, 1),
    radius: 4,
    spread: 0,
  );

  SwitchProperties power({double? inset = 3, bool shadows = true}) =>
      SwitchProperties(
        activeTrackColor: ColorRGBA.fromHex('#FFB96E')!,
        inactiveTrackColor: ColorRGBA.fromHex('#D3CCC0')!,
        activeThumbColor: ColorRGBA.white,
        inactiveThumbColor: ColorRGBA.white,
        activeTrackBorderColor: ColorRGBA.transparent,
        inactiveTrackBorderColor: ColorRGBA.transparent,
        trackOutlineWidth: 0,
        useMaterial3: true,
        uniformThumb: true,
        fillTrack: true,
        thumbInset: inset,
        thumbShadows: shadows ? [shadow] : [],
      );

  SwitchNode node(SwitchProperties properties) => SwitchNode(
    id: 's',
    name: 's',
    basicBoxLocal: NodeBox(0, 0, 50, 30),
    properties: properties,
  );

  Future<(ByteData, int)> pump(
    WidgetTester tester,
    SwitchProperties properties, {
    required bool value,
    void Function(bool value)? onChanged,
  }) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          color: Colors.white,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: TransformerSwitch(
                  node: node(properties),
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                  onChanged: (_, v) => onChanged?.call(v),
                  value: value,
                  scopedValues: ScopedValues.empty(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    late ByteData data;
    late int width;
    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage();
      width = image.width;
      data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    return (data, width);
  }

  test('a 24 px round thumb 3 px from the edges of a 50x30 track', () {
    final PlainTogglePainter painter = PlainTogglePainter(
      position: const AlwaysStoppedAnimation<double>(1),
      properties: power(),
      textDirection: TextDirection.ltr,
    );
    const Size size = Size(50, 30);
    final on = painter.thumbAt(size, 1);
    expect(on.center, const Offset(35, 15));
    expect(on.radius, 12);
    final off = painter.thumbAt(size, 0);
    expect(off.center, const Offset(15, 15));
    expect(off.radius, 12);
    // Without an inset, Material 3's proportions: 4/32 of the height.
    expect(
      PlainToggle.thumbDiameters(power(inset: null), 32).on,
      24,
    );
    // A Material 3 thumb that isn't uniform is smaller off.
    expect(
      PlainToggle.thumbDiameters(power().copyWith(uniformThumb: false), 30),
      (on: 24.0, off: 16.0),
    );
  });

  test('effects become the thumb\'s box shadows', () {
    expect(PlainToggle.boxShadowsOf([shadow]), const [
      BoxShadow(color: Color(0x33000000), offset: Offset(0, 1), blurRadius: 4),
    ]);
    expect(
      PlainToggle.boxShadowsOf([shadow.copyWith(visible: false)]),
      isEmpty,
    );
  });

  testWidgets('the switch draws the plain toggle with the thumb shadow', (
    tester,
  ) async {
    final (ByteData data, int width) = await pump(
      tester,
      power(),
      value: true,
    );
    expect(find.byType(PlainToggle), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    // Pixel (x, y) in the node's box (the boundary adds 10 px).
    (int, int, int) at(int x, int y) {
      final int o = ((y + 10) * width + x + 10) * 4;
      return (data.getUint8(o), data.getUint8(o + 1), data.getUint8(o + 2));
    }

    // The thumb's middle is white, the track at its left orange.
    expect(at(35, 15), (255, 255, 255));
    expect(at(8, 15).$3, lessThan(150));
    // Just under the thumb (its bottom edge is at 27) the shadow darkens
    // the track; just above it (its top is at 3), less so: it falls 1 px
    // down.
    int sum((int, int, int) c) => c.$1 + c.$2 + c.$3;
    final int below = sum(at(35, 27));
    final int above = sum(at(35, 2));
    final int track = sum(at(8, 3));
    expect(below, lessThan(track));
    expect(below, lessThan(above));
  });

  testWidgets('tapping it toggles', (tester) async {
    bool? changed;
    await pump(tester, power(), value: false, onChanged: (v) => changed = v);
    await tester.tap(find.byType(PlainToggle));
    expect(changed, isTrue);
  });

  testWidgets('without a shadow or inset it is Material\'s switch', (
    tester,
  ) async {
    await pump(tester, power(inset: null, shadows: false), value: true);
    expect(find.byType(PlainToggle), findsNothing);
    expect(find.byType(Switch), findsOneWidget);
  });
}
