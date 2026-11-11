// strokePath.fillColor fills the shape its points enclose, behind the line
// (a hand-drawn box with its own wobble), fading in as the line draws.
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/src/render/behaviors.dart' show StrokePathPainter;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<int>> _rgbaAt(WidgetTester tester, api.StrokePath path, List<Offset> at) async {
  final key = GlobalKey();
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(key: key, child: CustomPaint(size: const Size(100, 60), painter: StrokePathPainter(path))),
    ),
  ));
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!;
  }))!;
  return [for (final p in at) ...[for (var c = 0; c < 4; c++) bytes.getUint8((p.dy.toInt() * 100 + p.dx.toInt()) * 4 + c)]];
}

api.StrokePath _box({double progress = 1, String? fill = '#FFFF0000'}) => api.StrokePath.fromJson({
      'points': [[10, 10], [90, 12], [88, 50], [12, 48]],
      'xUnit': 'pixels',
      'yUnit': 'pixels',
      'color': '#FF000000',
      'width': 2,
      'progress': progress,
      'fillColor': ?fill,
    })!;

void main() {
  testWidgets('a filled stroke path paints its inside red, its outside clear', (tester) async {
    final px = await _rgbaAt(tester, _box(), const [Offset(50, 30), Offset(5, 5), Offset(95, 55)]);
    expect(px.sublist(0, 4), [255, 0, 0, 255], reason: 'inside');
    expect(px[7], 0, reason: 'outside, top left');
    expect(px[11], 0, reason: 'outside, bottom right');
  });

  testWidgets('half drawn, the fill is half as strong; without fillColor, nothing inside', (tester) async {
    final half = await _rgbaAt(tester, _box(progress: 0.5), const [Offset(50, 30)]);
    expect(half[3], inInclusiveRange(120, 135));
    final none = await _rgbaAt(tester, _box(fill: null), const [Offset(50, 30)]);
    expect(none[3], 0);
  });
}
