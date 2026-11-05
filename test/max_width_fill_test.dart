import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A centring column (`outer`, [outerWidth] wide) holding a card that fills
/// the width up to 440 px (`card`, expanded with maxWidth 440) around a
/// short line of text: Chairlift's state cards.
Future<Size> pumpCard(
  WidgetTester tester,
  double outerWidth, {
  CrossAxisAlignmentC cross = CrossAxisAlignmentC.center,
  SizeFit labelFit = SizeFit.shrinkWrap,
  CrossAxisAlignmentC cardCross = CrossAxisAlignmentC.start,
}) async {
  final TextNode label = TextNode(
    id: 'label',
    name: 'label',
    basicBoxLocal: NodeBox(0, 0, 60, 20),
    data: 'All clear',
    horizontalFit: labelFit,
    verticalFit: SizeFit.shrinkWrap,
    textMixedProps: [StartEndProp(start: 0, end: 9, fontSize: 16)],
  )..parentID = 'card';
  final RowColumnNode card = RowColumnNode(
    id: 'card',
    name: 'card',
    basicBoxLocal: NodeBox(0, 0, 440, 60),
    children: const ['label'],
    rowColumnType: RowColumnType.column,
    horizontalFit: SizeFit.expanded,
    verticalFit: SizeFit.shrinkWrap,
    constraints: const BoxConstraintsModel(maxWidth: 440),
    crossAxisAlignment: cardCross,
  )..parentID = 'outer';
  final RowColumnNode outer = RowColumnNode(
    id: 'outer',
    name: 'outer',
    basicBoxLocal: NodeBox(0, 0, outerWidth, 400),
    children: const ['card'],
    rowColumnType: RowColumnType.column,
    horizontalFit: SizeFit.fixed,
    verticalFit: SizeFit.fixed,
    crossAxisAlignment: cross,
  )..parentID = kRootNode;
  final registry = NodeRegistry()
    ..setNodes({for (final n in <BaseNode>[outer, card, label]) n.id: n});
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
                outer,
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
  return tester.getSize(find.byKey(const ValueKey('Rectangle Transformer of card [card]')).first);
}

void main() {
  testWidgets('a card that fills up to its max width fills a narrower '
      'centring column', (tester) async {
    expect((await pumpCard(tester, 358)).width, 358);
  });

  testWidgets('and stops at its max width in a wider one', (tester) async {
    expect((await pumpCard(tester, 900)).width, 440);
  });

  testWidgets('with a wrapping text inside, centred', (tester) async {
    expect(
      (await pumpCard(
        tester,
        358,
        labelFit: SizeFit.expanded,
        cardCross: CrossAxisAlignmentC.center,
      )).width,
      358,
    );
  });

  testWidgets('with a hugging text inside, centred', (tester) async {
    expect(
      (await pumpCard(tester, 358, cardCross: CrossAxisAlignmentC.center)).width,
      358,
    );
  });
}
