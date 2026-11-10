import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// A switch with `fillTrack` draws its track to the node's bounds (a 46×28
/// toggle flush with its 46×28 node), where by default the whole Material
/// switch box, with its padding and tap target margin, is scaled to the
/// node's width and the track sits inside it.
void main() {
  const Color track = Color(0xFFFF0000);

  SwitchNode toggle(double width, double height, {required bool fillTrack}) =>
      SwitchNode(
        id: 's',
        name: 's',
        basicBoxLocal: NodeBox(0, 0, width, height),
        value: true,
        properties: SwitchProperties(
          activeTrackColor: ColorRGBA.fromHex('#FF0000')!,
          inactiveTrackColor: ColorRGBA.fromHex('#FF0000')!,
          activeThumbColor: ColorRGBA.white,
          inactiveThumbColor: ColorRGBA.white,
          uniformThumb: true,
          fillTrack: fillTrack,
        ),
      );

  /// The bounds of the track's red pixels in a [pad]-pixel margin around
  /// the node, relative to the node's top left.
  Future<Rect> trackBounds(
    WidgetTester tester,
    SwitchNode node, {
    bool useMaterial3 = true,
    bool value = true,
  }) async {
    const double pad = 10;
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: useMaterial3),
        home: Material(
          color: Colors.black,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: Padding(
                padding: const EdgeInsets.all(pad),
                child: TransformerSwitch(
                  node: node,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                  onChanged: (_, _) {},
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
    late int height;
    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage();
      width = image.width;
      height = image.height;
      data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    int left = width, top = height, right = -1, bottom = -1;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int o = (y * width + x) * 4;
        final bool red =
            data.getUint8(o) > 128 &&
            data.getUint8(o + 1) < 100 &&
            data.getUint8(o + 2) < 100;
        if (!red) continue;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
    return Rect.fromLTRB(
      left - pad,
      top - pad,
      right + 1 - pad,
      bottom + 1 - pad,
    );
  }

  testWidgets('by default the track sits inside the node', (tester) async {
    final Rect bounds = await trackBounds(
      tester,
      toggle(52.2, 35.4, fillTrack: false),
    );
    // 52 of the 60 px switch box's width, scaled to 52.2 px.
    expect(bounds.left, greaterThan(2));
    expect(bounds.width, lessThan(47));
  });

  for (final bool value in [true, false]) {
    testWidgets('a filled track is the node\'s bounds (value $value)', (
      tester,
    ) async {
      final Rect bounds = await trackBounds(
        tester,
        toggle(46, 28, fillTrack: true),
        value: value,
      );
      expect(bounds.left, closeTo(0, 1));
      expect(bounds.top, closeTo(0, 1));
      expect(bounds.right, closeTo(46, 1));
      expect(bounds.bottom, closeTo(28, 1));
    });
  }

  testWidgets('a filled track fills other sizes and Material 2', (
    tester,
  ) async {
    Rect bounds = await trackBounds(tester, toggle(52, 32, fillTrack: true));
    expect(bounds, _rectCloseTo(const Rect.fromLTWH(0, 0, 52, 32)));
    bounds = await trackBounds(tester, toggle(30, 18, fillTrack: true));
    expect(bounds, _rectCloseTo(const Rect.fromLTWH(0, 0, 30, 18)));
    // Material 2's thumb is wider than its track and hides one end of it:
    // the track shows on the left when on and on the right when off.
    final Rect on = await trackBounds(
      tester,
      toggle(33, 14, fillTrack: true),
      useMaterial3: false,
    );
    final Rect off = await trackBounds(
      tester,
      toggle(33, 14, fillTrack: true),
      useMaterial3: false,
      value: false,
    );
    expect(
      on.expandToInclude(off),
      _rectCloseTo(const Rect.fromLTWH(0, 0, 33, 14)),
    );
  });

  testWidgets('a filled-track switch toggles when tapped', (tester) async {
    bool? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: TransformerSwitch(
              node: toggle(46, 28, fillTrack: true),
              settings: const WidgetBuildSettings(debugLabel: 'test'),
              onChanged: (_, value) => changed = value,
              value: true,
              scopedValues: ScopedValues.empty(),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(TransformerSwitch)), const Size(46, 28));
    await tester.tap(find.byType(Switch));
    expect(changed, isFalse);
  });
}

Matcher _rectCloseTo(Rect expected) => predicate<Rect>(
  (r) =>
      (r.left - expected.left).abs() <= 1 &&
      (r.top - expected.top).abs() <= 1 &&
      (r.right - expected.right).abs() <= 1 &&
      (r.bottom - expected.bottom).abs() <= 1,
  'within 1 px of $expected',
);
