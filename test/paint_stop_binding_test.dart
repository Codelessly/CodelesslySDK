import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// A background whose gradient stops follow a palette map (`pal.bg`,
// `pal.bgAlt`) that shifts between day, dusk and night, bound per stop with
// `fill-<paint id>-stop-<index>` (StyleBindings.paintStop).

const ColorRGBA _placeholder = ColorRGBA(r: 0, g: 0, b: 0, a: 1);

PaintModel gradient(String id, PaintType type) => PaintModel.fromJson({
  'id': id,
  'type': type.name,
  'gradientTransform': [1, 0, 0, 0, 1, 0],
  'gradientBeginX': 0,
  'gradientBeginY': -1,
  'gradientEndX': 0,
  'gradientEndY': 1,
  'gradientStops': [
    {'position': 0, 'color': _placeholder.toJson()},
    {'position': 1, 'color': _placeholder.toJson()},
  ],
});

RectangleNode backdrop(
  Map<String, String> variables, {
  PaintType type = PaintType.gradientLinear,
  List<PaintModel>? fills,
  List<PaintModel> strokes = const [],
}) => RectangleNode.fromJson({
  ...RectangleNode(
    id: 'bg',
    name: 'Backdrop',
    basicBoxLocal: NodeBox(0, 0, 100, 100),
    fills: fills ?? [gradient('g', type)],
    strokes: strokes,
  ).toJson(),
  'variables': variables,
})..parentID = kRootNode;

Observable<VariableData> palette(Map<String, String> colors) => Observable(
  VariableData(id: 'pal', name: 'pal', type: VariableType.map, value: colors),
);

const Map<String, String> dusk = {'bg': '#F4ECE3', 'bgAlt': '#EBDCCD'};
const Map<String, String> night = {'bg': '#14171F', 'bgAlt': '#262B38'};

Map<String, String> boundStops(String paintKey) => {
  StyleBindings.paintStop(paintKey, 0): r'${pal.bg}',
  StyleBindings.paintStop(paintKey, 1): r'${= pal.bgAlt}',
};

int argb(ColorRGBA c) => c.toFlutterColor().toARGB32();

void main() {
  group('paintStop bindings', () {
    Map<String, dynamic> patchOf(BaseNode node) {
      final Map<String, dynamic> patch = {};
      StyleBindings.addTo(
        patch,
        node,
        scopedValues: ScopedValues.preview(
          variables: {
            'pal': VariableData(
              id: 'pal',
              name: 'pal',
              type: VariableType.map,
              value: dusk,
            ),
          },
        ),
      );
      return patch;
    }

    test('key is the paint binding key with -stop-<index>', () {
      expect(StyleBindings.paintStop('fill-g', 1), 'fill-g-stop-1');
    });

    for (final PaintType type in const [
      PaintType.gradientLinear,
      PaintType.gradientRadial,
      PaintType.gradientAngular,
    ]) {
      test('stops of a ${type.name} fill follow a path and a formula', () {
        final patch = patchOf(backdrop(boundStops('fill-g'), type: type));
        final PaintModel fill = PaintModel.fromJson(patch['fills'][0]);
        expect(fill.type, type);
        expect(argb(fill.gradientStops![0].color), 0xFFF4ECE3);
        expect(argb(fill.gradientStops![1].color), 0xFFEBDCCD);
      });
    }

    test('any fill, stroke or foreground paint, not just the first', () {
      final node = backdrop(
        {
          ...boundStops('fill-g2'),
          StyleBindings.paintStop('stroke-paint-s', 1): r'${pal.bg}',
        },
        fills: [
          PaintModel.solid(id: 'solid', color: ColorRGB.fromHex('#FFFFFF')),
          gradient('g2', PaintType.gradientLinear),
        ],
        strokes: [gradient('s', PaintType.gradientLinear)],
      );
      final patch = patchOf(node);
      expect(PaintModel.fromJson(patch['fills'][0]).type, PaintType.solid);
      final PaintModel second = PaintModel.fromJson(patch['fills'][1]);
      expect(argb(second.gradientStops![0].color), 0xFFF4ECE3);
      final PaintModel stroke = PaintModel.fromJson(patch['strokes'][0]);
      expect(argb(stroke.gradientStops![0].color), argb(_placeholder));
      expect(argb(stroke.gradientStops![1].color), 0xFFF4ECE3);
    });

    test('a per-paint key wins over fill-stop-<index>', () {
      final patch = patchOf(
        backdrop({
          StyleBindings.fillStop(0): r"${= '#FF0000'}",
          StyleBindings.paintStop('fill-g', 0): r'${pal.bg}',
          StyleBindings.fillStop(1): r"${= '#00FF00'}",
        }),
      );
      final PaintModel fill = PaintModel.fromJson(patch['fills'][0]);
      expect(argb(fill.gradientStops![0].color), 0xFFF4ECE3);
      expect(argb(fill.gradientStops![1].color), 0xFF00FF00);
    });

    test('a value that is no color keeps the stop', () {
      expect(
        patchOf(backdrop({StyleBindings.paintStop('fill-g', 0): r'${= 3}'})),
        isEmpty,
      );
    });
  });

  testWidgets('bound stops paint the palette and follow it when it changes', (
    tester,
  ) async {
    final Observable<VariableData> pal = palette(dusk);
    final CodelesslyContext context = CodelesslyContext.empty()
      ..variables['pal'] = pal;
    final RectangleNode node = backdrop(boundStops('fill-g'));
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: context,
        child: MaterialApp(
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: key,
                child: Builder(
                  builder: (context) => manager.buildWidgetFromNode(
                    node,
                    context,
                    settings: const WidgetBuildSettings(debugLabel: 'test'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    /// The colors at the top and bottom rows, in the middle.
    Future<(int, int)> edges() async {
      late (int, int) colors;
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final ui.Image image = await boundary.toImage();
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        int at(int y) {
          final int i = (y * image.width + image.width ~/ 2) * 4;
          return (data.getUint8(i) << 16) |
              (data.getUint8(i + 1) << 8) |
              data.getUint8(i + 2);
        }

        colors = (at(0), at(image.height - 1));
      });
      return colors;
    }

    bool near(int a, int b) =>
        ((a >> 16) - (b >> 16)).abs() <= 4 &&
        (((a >> 8) & 0xFF) - ((b >> 8) & 0xFF)).abs() <= 4 &&
        ((a & 0xFF) - (b & 0xFF)).abs() <= 4;

    var (top, bottom) = await edges();
    expect(near(top, 0xF4ECE3), isTrue, reason: top.toRadixString(16));
    expect(near(bottom, 0xEBDCCD), isTrue, reason: bottom.toRadixString(16));

    pal.value = pal.value.copyWith(value: night);
    await tester.pumpAndSettle();
    (top, bottom) = await edges();
    expect(near(top, 0x14171F), isTrue, reason: top.toRadixString(16));
    expect(near(bottom, 0x262B38), isTrue, reason: bottom.toRadixString(16));
  });
}
