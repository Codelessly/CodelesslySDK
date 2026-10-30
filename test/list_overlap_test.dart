import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A list with negative spacing overlaps its items, each drawn over the one
/// before (an avatar stack).
void main() {
  testWidgets('negative spacing overlaps the items of a list', (tester) async {
    final VariableData people = VariableData(
      id: 'people',
      name: 'people',
      type: VariableType.list,
      value: ['MO', 'DR', 'PN'],
    );
    final List<BaseNode> nodes = [
      ListViewNode(
        id: 'list',
        name: 'list',
        basicBoxLocal: NodeBox(0, 0, 200, 28),
        horizontalFit: SizeFit.shrinkWrap,
        scrollDirection: AxisC.horizontal,
        properties: ListViewProperties(
          hasSeparator: true,
          separator: ListItemSeparator.space,
          separatorSpacing: -6,
        ),
        variables: {'data': r'${people}'},
        children: ['avatar'],
      )..parentID = kRootNode,
      RectangleNode(
        id: 'avatar',
        name: 'avatar',
        basicBoxLocal: NodeBox(0, 0, 28, 28),
      )..parentID = 'list',
    ];
    final registry = NodeRegistry()
      ..setNodes({for (final node in nodes) node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty().copyWith(
          variables: {people.id: Observable(people)},
        ),
        child: MaterialApp(
          home: Material(
            child: Align(
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
    final List<Rect> rects = [
      for (final Element e in find.byType(OverlapBox).evaluate())
        tester.getRect(find.byWidget(e.widget)),
    ];
    // The first two items take 22 instead of 28; the last keeps its size.
    expect(rects.map((r) => r.left), [0, 22]);
    expect(rects.map((r) => r.width), [22, 22]);
    expect(
      tester.getSize(find.byType(ListView)).width,
      28 + 22 + 22,
    );
  });
}
