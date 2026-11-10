import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'viewport_layout_test.dart' as vp;

/// A row of plan cards with stretchItems, each card listing its own
/// features: the Pro card (second) has one feature more than the others.
Future<void> pumpPlans(
  WidgetTester tester, {
  required List<int> featureCounts,
  bool wrap = false,
  SizeFit mainFit = SizeFit.shrinkWrap,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final RectangleNode feature = vp.rect('feature', 'features', height: 20);
  final ListViewNode features =
      ListViewNode(
          id: 'features',
          name: 'features',
          basicBoxLocal: NodeBox(0, 0, 100, 100),
          horizontalFit: SizeFit.fixed,
          verticalFit: SizeFit.shrinkWrap,
          properties: ListViewProperties(),
          children: ['feature'],
          variables: {'data': r'${item.features}'},
        )
        ..isScrollable = false
        ..parentID = 'card';
  final RowColumnNode card = RowColumnNode(
    id: 'card',
    name: 'card',
    basicBoxLocal: NodeBox(0, 0, 100, 100),
    rowColumnType: RowColumnType.column,
    horizontalFit: SizeFit.fixed,
    verticalFit: SizeFit.expanded,
    children: ['features'],
  )..parentID = 'plans';
  final ListViewNode plans =
      ListViewNode(
          id: 'plans',
          name: 'plans',
          // The editor solves the design height from the first item alone.
          basicBoxLocal: NodeBox(0, 0, 600, 100),
          horizontalFit: mainFit,
          verticalFit: SizeFit.shrinkWrap,
          scrollDirection: AxisC.horizontal,
          properties: ListViewProperties(
            hasSeparator: true,
            separatorSpacing: 12,
            stretchItems: true,
            wrap: wrap,
          ),
          children: ['card'],
          variables: {'data': r'${plans}'},
        )
        ..isScrollable = false
        ..parentID = kRootNode;

  final registry = NodeRegistry()
    ..setNodes({
      for (final BaseNode node in [plans, card, features, feature])
        node.id: node,
    });
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
    ..variables['plans'] = Observable(
      VariableData(
        id: 'plans',
        name: 'plans',
        type: VariableType.list,
        value: [
          for (final int count in featureCounts)
            {
              'features': [for (int i = 0; i < count; i++) 'feature $i'],
            },
        ],
      ),
    );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext,
      child: MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: Builder(
            builder: (context) => manager.buildWidgetFromNode(
              plans,
              context,
              settings: const WidgetBuildSettings(debugLabel: 'test'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder cards() => find.byWidgetPredicate(
  (Widget w) => '${w.key}'.contains('[card]') && w is! KeyedSubtree,
);

void main() {
  for (final (bool wrap, SizeFit mainFit) in [
    (false, SizeFit.shrinkWrap),
    (true, SizeFit.shrinkWrap),
    (false, SizeFit.expanded),
    (false, SizeFit.fixed),
  ]) {
    testWidgets('the tallest card sets the height, wherever it sits '
        '(wrap: $wrap, ${mainFit.name} width)', (tester) async {
      for (final List<int> counts in [
        [5, 6, 5],
        [6, 5, 5],
        [5, 5, 6],
      ]) {
        await pumpPlans(
          tester,
          featureCounts: counts,
          wrap: wrap,
          mainFit: mainFit,
        );
        expect(tester.takeException(), isNull, reason: '$counts');
        expect(vp.rectOf('feature'), findsNWidgets(16), reason: '$counts');
        final List<double> heights = [
          for (final Element e in cards().evaluate())
            (e.renderObject! as RenderBox).size.height,
        ];
        expect(heights.toSet(), {120.0}, reason: '$counts');
        expect(find.byType(ViewportNodeBox), findsNothing);
        if (mainFit == SizeFit.expanded) {
          expect(
            tester.getSize(find.byType(PassiveListViewWidget).first).width,
            1440,
          );
        }
      }
    });
  }

  testWidgets('items past a fixed width run on instead of squeezing', (
    tester,
  ) async {
    // Ten 100 wide cards, 12 apart, in a 600 wide list.
    await pumpPlans(
      tester,
      featureCounts: [for (int i = 0; i < 10; i++) i.isEven ? 2 : 3],
      mainFit: SizeFit.fixed,
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(PassiveListViewWidget).first).width, 600);
    final List<Rect> rects = [
      for (final Element e in cards().evaluate())
        (e.renderObject! as RenderBox).paintBounds.shift(
          (e.renderObject! as RenderBox).localToGlobal(Offset.zero),
        ),
    ];
    expect(rects.map((r) => r.height).toSet(), {60.0});
    expect(rects.last.left, 9 * 112);
  });
}
