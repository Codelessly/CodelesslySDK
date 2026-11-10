import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'node_motion_test.dart' show box;

/// A shimmer sweeps a band of light across what a node paints: a loading
/// honeycomb with a honey wave passing over its cells.
void main() {
  const shimmer = MotionShimmer(
    color: '#FFFF0000',
    strength: 1,
    width: 0.2,
    durationMs: 1000,
  );

  Future<ui.Image> shot(WidgetTester tester, GlobalKey key) async {
    late ui.Image image;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      image = await boundary.toImage();
    });
    return image;
  }

  Future<Color> pixel(WidgetTester tester, GlobalKey key, int x) async {
    final ui.Image image = await shot(tester, key);
    late ByteData? data;
    await tester.runAsync(() async {
      data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    });
    final int i = (5 * image.width + x) * 4;
    return Color.fromARGB(
      data!.getUint8(i + 3),
      data!.getUint8(i),
      data!.getUint8(i + 1),
      data!.getUint8(i + 2),
    );
  }

  Widget plate(GlobalKey key, {required bool animate}) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: key,
        child: NodeMotion(
          motion: const MotionModel(shimmer: shimmer),
          animate: animate,
          child: const SizedBox(
            width: 100,
            height: 10,
            child: ColoredBox(color: Color(0xFF0000FF)),
          ),
        ),
      ),
    ),
  );

  testWidgets('the band sweeps across the node over its period', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(plate(key, animate: true));
    // Halfway through a sweep the band's centre is at the middle.
    await tester.pump(const Duration(milliseconds: 500));
    expect((await pixel(tester, key, 50)).r, greaterThan(0.9));
    expect((await pixel(tester, key, 5)).b, greaterThan(0.9));
    expect((await pixel(tester, key, 95)).b, greaterThan(0.9));
    // Later it has moved right.
    await tester.pump(const Duration(milliseconds: 200));
    expect((await pixel(tester, key, 50)).b, greaterThan(0.9));
    expect((await pixel(tester, key, 74)).r, greaterThan(0.7));
  });

  testWidgets('on the design canvas the band stands halfway across', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(plate(key, animate: false));
    await tester.pump(const Duration(seconds: 2));
    expect((await pixel(tester, key, 50)).r, greaterThan(0.9));
    expect((await pixel(tester, key, 5)).b, greaterThan(0.9));
  });

  test('a shimmer round-trips through a node', () {
    final json = box(motion: const MotionModel(shimmer: shimmer)).toJson();
    expect(RectangleNode.fromJson(json).motion!.shimmer, shimmer);
  });
}
