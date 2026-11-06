import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Cards in a stretching row (the Power screen's supplies) are as tall as
/// the tallest; when a card's hidden line shows, the row grows with it.
void main() {
  testWidgets('a stretch row of expanded cards grows when a card grows', (
    tester,
  ) async {
    final VariableData more = VariableData(
      id: 'm',
      name: 'more',
      type: VariableType.boolean,
      value: false,
    );
    RowColumnNode card(String id, List<String> kids) => RowColumnNode(
      id: id,
      name: id,
      basicBoxLocal: NodeBox(0, 0, 100, 40),
      children: kids,
      rowColumnType: RowColumnType.column,
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.expanded,
    )..parentID = 'row';
    RectangleNode line(String id, String parent, {String? visible}) =>
        RectangleNode(id: id, name: id, basicBoxLocal: NodeBox(0, 0, 100, 20))
          ..parentID = parent
          ..variables.addAll({if (visible != null) 'visible': visible});
    final RowColumnNode row = RowColumnNode(
      id: 'row',
      name: 'row',
      basicBoxLocal: NodeBox(0, 0, 300, 40),
      children: ['a', 'b'],
      rowColumnType: RowColumnType.row,
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.shrinkWrap,
      crossAxisAlignment: CrossAxisAlignmentC.stretch,
    )..parentID = kRootNode;
    final nodes = <BaseNode>[
      row,
      card('a', ['a1', 'a2']),
      card('b', ['b1']),
      line('a1', 'a'),
      line('a2', 'a', visible: r'${more}'),
      line('b1', 'b'),
    ];
    final registry = NodeRegistry()..setNodes({for (final n in nodes) n.id: n});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final Observable<VariableData> v = Observable(more);
    final CodelesslyContext c = CodelesslyContext.empty()..variables['m'] = v;
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: c,
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  row,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Rect of(String id) => tester.getRect(
      find.byKey(ValueKey('Rectangle Transformer of $id [$id]')),
    );
    final double before = of('b1').top;
    expect(tester.takeException(), isNull);
    v.set(more.copyWith(value: true));
    await tester.pump();
    expect(
      tester.takeException(),
      isNull,
      reason: 'no overflow when the card grows',
    );
    // A's second line shows, below its first.
    expect(of('a2').top, greaterThanOrEqualTo(of('a1').bottom - 0.5));
    expect(of('b1').top, before);
  });
}
