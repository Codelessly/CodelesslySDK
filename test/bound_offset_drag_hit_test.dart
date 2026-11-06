import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('a draggable node moved by bound x/y is grabbed where it is drawn', (
    tester,
  ) async {
    final FrameNode pin = FrameNode(
      id: 'pin',
      name: 'pin',
      basicBoxLocal: NodeBox(0, 0, 60, 60),
      children: const [],
      positioningMode: PositioningMode.pin,
      edgePins: const EdgePinsModel(left: 0, top: 0, right: null, bottom: null),
      fills: [PaintModel.solid(id: 'f', color: ColorRGB.black)],
    )
      ..variables['x'] = r'${= 300}'
      ..variables['y'] = r'${= 200}'
      ..drag = const DragModel(
        axis: DragAxis.free,
        release: DragRelease.stay,
        xVariable: 'px',
      );
    final FrameNode desk = FrameNode(
      id: 'desk',
      name: 'desk',
      basicBoxLocal: NodeBox(0, 0, 400, 300),
      children: ['pin'],
    )..parentID = kRootNode;
    pin.parentID = desk.id;
    final NodeRegistry registry = NodeRegistry()..setNodes({desk.id: desk, pin.id: pin});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final CodelesslyContext context = CodelesslyContext.empty()
      ..variables['px'] = Observable(
        VariableData(id: 'px', name: 'px', type: VariableType.decimal, value: 0),
      );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: context,
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 300,
              child: Builder(
                builder: (c) => manager.buildWidgetFromNode(
                  desk,
                  c,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final TestGesture gesture = await tester.startGesture(const Offset(330, 230));
    await gesture.moveBy(const Offset(25, 0));
    await gesture.moveBy(const Offset(25, 0));
    await tester.pump();
    expect(double.parse('${context.variables['px']!.value.value}'), greaterThan(20));
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
