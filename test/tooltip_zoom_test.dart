import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  for (final Size screen in const [
    Size(390, 844),
    Size(834, 1194),
    Size(1440, 900),
  ]) {
    testWidgets('a zoomable node with a tooltip at ${screen.width.toInt()}', (
      tester,
    ) async {
      tester.view.physicalSize = screen;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final RectangleNode photo =
          RectangleNode(
              id: 'photo',
              name: 'Photo',
              basicBoxLocal: NodeBox(0, 0, 200, 150),
              fills: [
                PaintModel.solid(id: 'f', color: ColorRGB.fromHex('#336699')),
              ],
            )
            ..parentID = kRootNode
            ..tooltip = r'By ${author}'
            ..zoomable = true;
      final registry = NodeRegistry()..setNodes({photo.id: photo});
      final manager = PassiveNodeTransformerManager(
        registry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
      final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
        ..variables['a'] = Observable(
          VariableData(id: 'a', name: 'author', value: 'Ana'),
        );
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: codelesslyContext,
          child: MaterialApp(
            home: Align(
              alignment: Alignment.topLeft,
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  photo,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.widget<Tooltip>(find.byType(Tooltip)).message, 'By Ana');
      expect(tester.getSize(find.byType(ZoomableBox)), const Size(200, 150));

      final TransformationController controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      await tester.tapAt(const Offset(100, 75));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(100, 75));
      await tester.pumpAndSettle();
      expect(controller.value.getMaxScaleOnAxis(), greaterThan(1));
    });
  }
}
