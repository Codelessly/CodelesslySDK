import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A rectangle's `path` binds like any property: Lamplight's dashed sun
/// path follows the sky's size (`${= sunPath(w, h)}`), on the design canvas
/// and at runtime.
void main() {
  RectangleNode line() => RectangleNode.fromJson({
    'id': 'sunPath',
    'name': 'Sun path',
    'type': 'rectangle',
    'basicBoxLocal': [0, 0, 200, 200],
    'path': 'M0 20 L200 20',
    'fills': <Object>[],
    'strokes': [
      {'id': 's1', 'type': 'solid', 'color': ColorRGBA.white.toJson()},
    ],
    'strokeWeight': 8,
    'variables': {'path': r'${skyPath}'},
  })..parentID = kRootNode;

  Future<(ByteData, int)> paint(
    WidgetTester tester,
    CodelesslyContext codelesslyContext, {
    required bool runtime,
  }) async {
    final GlobalKey key = GlobalKey();
    final RectangleNode node = line();
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: key,
              child: ColoredBox(
                color: Colors.black,
                child: Builder(
                  builder: (context) => manager.buildWidgetFromNode(
                    node,
                    context,
                    settings: WidgetBuildSettings(
                      debugLabel: 'test',
                      isPreview: !runtime,
                      withReactions: runtime,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
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

  int red((ByteData, int) image, int x, int y) {
    final (ByteData data, int width) = image;
    return data.getUint8((y * width + x) * 4);
  }

  CodelesslyContext withPath(String path) => CodelesslyContext.empty()
    ..variables['skyPath'] = Observable(
      VariableData(
        id: 'skyPath',
        name: 'skyPath',
        type: VariableType.text,
        value: path,
      ),
    );

  for (final bool runtime in [true, false]) {
    testWidgets(
      'a bound path replaces the saved one (${runtime ? 'runtime' : 'design canvas'})',
      (tester) async {
        // A diagonal from the bottom left to the top right.
        final CodelesslyContext context = withPath('M0 200 L200 0');
        final image = await paint(tester, context, runtime: runtime);
        expect(red(image, 100, 100), greaterThan(200));
        // Not the saved line along y = 20.
        expect(red(image, 20, 20), lessThan(40));
      },
    );
  }

  testWidgets('a changed path variable redraws the path', (tester) async {
    final CodelesslyContext context = withPath('M0 100 L200 100');
    var image = await paint(tester, context, runtime: true);
    expect(red(image, 150, 100), greaterThan(200));
    expect(red(image, 100, 30), lessThan(40));
    context.updateVariable('skyPath', 'M100 0 L100 200');
    await tester.pump();
    image = await paint(tester, context, runtime: true);
    expect(red(image, 100, 30), greaterThan(200));
    expect(red(image, 150, 100), lessThan(40));
  });

  testWidgets('an empty bound path keeps the saved one', (tester) async {
    final image = await paint(tester, withPath(''), runtime: true);
    expect(red(image, 100, 20), greaterThan(200));
  });
}
