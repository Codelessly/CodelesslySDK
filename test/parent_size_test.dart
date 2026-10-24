import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Finder _of(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]'));

RectangleNode _rect(String id, Map<String, String> variables) =>
    RectangleNode(id: id, name: id, basicBoxLocal: NodeBox(0, 0, 100, 40))
      ..parentID = 'panel'
      ..variables.addAll(variables);

/// A specs panel, 24 padding, with a 4-column and a 2-column grid stand-in
/// that show by the panel's content width, and a bar half as wide.
List<BaseNode> _panel() {
  final List<RectangleNode> children = [
    _rect('four', {'visible': r'${= parent.width > 520}'}),
    _rect('two', {'visible': r'${= parent.width <= 520}'}),
    _rect('half', {'width': r'${= parent.width / 2}'}),
  ];
  return [
    RowColumnNode(
      id: 'panel',
      name: 'panel',
      basicBoxLocal: NodeBox(0, 0, 600, 300),
      children: [for (final child in children) child.id],
      rowColumnType: RowColumnType.column,
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.shrinkWrap,
      crossAxisAlignment: CrossAxisAlignmentC.start,
      padding: const EdgeInsetsModel.all(24),
    )..parentID = kRootNode,
    ...children,
  ];
}

Future<void> _pump(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final List<BaseNode> nodes = _panel();
  final registry = NodeRegistry()..setNodes({for (final n in nodes) n.id: n});
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
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                nodes.first,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
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
  testWidgets('a panel wider than 520 shows four columns', (tester) async {
    await _pump(tester, 600);
    expect(_of('four'), findsOneWidget);
    expect(_of('two'), findsNothing);
    // 600 - 2 * 24 padding.
    expect(tester.getSize(_of('half')).width, 276);
  });

  testWidgets('a panel 520 or narrower shows two columns', (tester) async {
    await _pump(tester, 560);
    expect(_of('four'), findsNothing);
    expect(_of('two'), findsOneWidget);
    expect(tester.getSize(_of('half')).width, 256);
  });

  testWidgets('the layout follows the panel as the screen resizes', (
    tester,
  ) async {
    await _pump(tester, 600);
    expect(_of('four'), findsOneWidget);
    tester.view.physicalSize = const Size(500, 800);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(_of('four'), findsNothing);
    expect(_of('two'), findsOneWidget);
  });

  test('readsParentSize finds parent in bindings, formulas and text', () {
    expect(readsParentSize(_rect('a', {'visible': r'${parent.width}'})), true);
    expect(
      readsParentSize(_rect('b', {'visible': r'${= parent.width > 9}'})),
      true,
    );
    expect(readsParentSize(_rect('c', {'visible': r'${screen.width}'})), false);
    final TextNode text = TextNode(
      id: 't',
      name: 't',
      basicBoxLocal: NodeBox(0, 0, 10, 10),
      characters: r'Width ${= round(parent.width)}',
    );
    expect(readsParentSize(text), true);
  });

  test('the design canvas can give parent a size', () {
    final ScopedValues values = ScopedValues.preview(
      variables: const {},
      parentSize: parentVariableValue(698, null),
    );
    expect(
      PropertyValueDelegate.getVariableValueFromPath<bool>(
        r'${= parent.width > 520}',
        scopedValues: values,
      ),
      isTrue,
    );
    expect(
      PropertyValueDelegate.getVariableValueFromPath<Object>(
        r'${parent.height}',
        scopedValues: values,
      ),
      isNull,
    );
  });
}
