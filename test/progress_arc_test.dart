import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

ProgressBarNode gauge(double value, {ColorRGBA? needle}) => ProgressBarNode(
  id: 'g',
  name: 'Gauge',
  basicBoxLocal: NodeBox(0, 0, 200, 156),
  currentValue: value,
  properties: ProgressBarProperties(
    shape: ProgressBarShape.arc,
    maxValue: 250,
    backgroundColor: const ColorRGBA(r: 0.87, g: 0.86, b: 0.83, a: 1),
    progressColor: ColorRGBA.black,
    arcStrokeWidth: 16,
    needleColor: needle,
    tickCount: 10,
    bands: const [
      ProgressBand(
        start: 0,
        end: 0.9,
        color: ColorRGBA(r: 0, g: 1, b: 0, a: 1),
      ),
      ProgressBand(
        start: 0.9,
        end: 1,
        color: ColorRGBA(r: 1, g: 0.5, b: 0, a: 1),
      ),
    ],
  ),
);

Future<ui.Image> render(WidgetTester tester, ProgressBarNode node) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 200,
              height: 156,
              child: PassiveProgressBarWidget(
                node: node,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  late ui.Image image;
  await tester.runAsync(() async {
    image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage();
  });
  return image;
}

void main() {
  testWidgets('an arc progress bar paints a dial for its value', (
    tester,
  ) async {
    await render(tester, gauge(125, needle: ColorRGBA.black));
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<ArcProgressPainter>()
        .single;
    expect(painter.progress, 0.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fills from the start of the arc', (tester) async {
    Future<int> redNearStart(double value) async {
      final ui.Image image = await render(tester, gauge(value));
      final data = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      // The dial opens at the bottom: 150° is lower left. Sample a point on
      // the track a little after the start.
      int red(int x, int y) => data.getUint8((y * image.width + x) * 4);
      return red(25, 120);
    }

    // Empty: the light track; nearly full: the black progress.
    expect(await redNearStart(0), greaterThan(150));
    expect(await redNearStart(240), lessThan(60));
  });

  test('a bar is still a bar', () {
    expect(ProgressBarProperties().shape, ProgressBarShape.bar);
  });
}
