import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// `${parent.width}` in a frame child's x or width binding reads the frame's
// content box (the Sunrise sky: a 350-wide frame), not the child's own box,
// as a text's `${parent.width}` in the same frame does and the design
// canvas shows.

Finder _of(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]'));

RectangleNode _rect(String id, Map<String, String> variables) =>
    RectangleNode(id: id, name: id, basicBoxLocal: NodeBox(10, 40, 50, 20))
      ..parentID = 'sky'
      ..positioningMode = PositioningMode.pin
      ..variables.addAll(variables);

Future<void> _pump(
  WidgetTester tester,
  List<BaseNode> children, {
  SizeFit fit = SizeFit.fixed,
  double screen = 800,
}) async {
  tester.view.physicalSize = Size(screen, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final FrameNode sky = FrameNode(
    id: 'sky',
    name: 'sky',
    basicBoxLocal: NodeBox(0, 0, 350, 200),
    horizontalFit: fit,
    padding: const EdgeInsetsModel.all(10),
    children: [for (final c in children) c.id],
  )..parentID = kRootNode;
  final registry = NodeRegistry()
    ..setNodes({sky.id: sky, for (final n in children) n.id: n});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: fit == SizeFit.expanded ? 500 : null,
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  sky,
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
}

void main() {
  testWidgets('a bound x and width read the frame\'s content width', (
    tester,
  ) async {
    await _pump(tester, [
      _rect('mid', {'positionX': r'${= 0.5}', 'x': r'${= parent.width / 2}'}),
      _rect('half', {'width': r'${= parent.width / 2}'}),
    ]);
    // 350 - 2 * 10 padding = 330.
    expect(tester.getSize(_of('half')).width, 165);
    expect(tester.getSize(_of('mid')).width, 50);
  });

  testWidgets('x lands at the frame\'s half', (tester) async {
    await _pump(tester, [
      _rect('mid', {'x': r'${= parent.width / 2}'}),
    ]);
    final Offset frame = tester.getTopLeft(
      find.byKey(const ValueKey('Rectangle Transformer of sky [sky]')),
    );
    // x is in the frame's box, as its design x is: 330 / 2 (not 50 / 2,
    // the child's own width).
    expect(tester.getTopLeft(_of('mid')).dx - frame.dx, 165);
  });

  testWidgets('an expanded frame gives the width it fills', (tester) async {
    await _pump(tester, [
      _rect('half', {'width': r'${= parent.width / 2}'}),
    ], fit: SizeFit.expanded);
    // 500 - 20.
    expect(tester.getSize(_of('half')).width, 240);
  });
}
