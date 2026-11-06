import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The Lamplight Scenes grid: a horizontal wrapping list with stretchItems
// whose cards hold a "Scene dots" list shown only while lamps are placed
// (`${= length(placed) > 0}`), and a 14 px "No dots gap" shown otherwise.
// A hidden dots list must not add its height to the run, also when the
// lamps are taken off after the grid was first laid out (the boot action
// emptying the tray). The real dots read their scene as `parent.item`,
// which was taken for reading the parent's size: the cards then couldn't be
// measured and took their design height (solved with the dots shown).

RectangleNode _rect(
  String id,
  String parentID,
  double width,
  double height, {
  SizeFit horizontalFit = SizeFit.fixed,
  Map<String, String> variables = const {},
}) =>
    RectangleNode(
        id: id,
        name: id,
        basicBoxLocal: NodeBox(0, 0, width, height),
        horizontalFit: horizontalFit,
      )
      ..parentID = parentID
      ..variables.addAll(variables);

List<BaseNode> _scenesGrid({bool realistic = false}) {
  final ListViewNode grid =
      ListViewNode(
          id: 'grid',
          name: 'Scene grid',
          basicBoxLocal: NodeBox(0, 0, 700, 200),
          horizontalFit: SizeFit.fixed,
          verticalFit: SizeFit.shrinkWrap,
          scrollDirection: AxisC.horizontal,
          properties: ListViewProperties(
            wrap: true,
            wrapSpacing: 16,
            wrapRunSpacing: 16,
            stretchItems: true,
          ),
          children: ['card'],
          variables: {
            'data': r'${scenes}',
            if (realistic) 'itemKey': r'${item.id}',
          },
        )
        ..isScrollable = false
        ..parentID = kRootNode;
  final RowColumnNode card = RowColumnNode(
    id: 'card',
    name: 'Scene card',
    basicBoxLocal: NodeBox(0, 0, 340, 200),
    rowColumnType: RowColumnType.column,
    crossAxisAlignment: CrossAxisAlignmentC.stretch,
    horizontalFit: SizeFit.fixed,
    verticalFit: SizeFit.expanded,
    padding: const EdgeInsetsModel.all(18),
    children: ['blurb', 'dots', 'gap', 'spacer', 'buttons'],
  )..parentID = 'grid';
  final ListViewNode dots =
      ListViewNode(
          id: 'dots',
          name: 'Scene dots',
          basicBoxLocal: NodeBox(0, 0, 300, 18),
          margin: const EdgeInsetsModel.only(top: 14),
          horizontalFit: SizeFit.expanded,
          verticalFit: SizeFit.shrinkWrap,
          scrollDirection: AxisC.horizontal,
          properties: ListViewProperties(
            wrap: true,
            wrapSpacing: 6,
            wrapRunSpacing: 6,
          ),
          children: ['dot'],
          variables: {
            'data': realistic
                ? r'${= filter(placed, l => item.states[l.id] != null)}'
                : r'${placed}',
            'visible': r'${= !(length(placed) == 0)}',
          },
        )
        ..isScrollable = false
        ..clipsContent = false
        ..parentID = 'card';
  final RowColumnNode spacer = RowColumnNode(
    id: 'spacer',
    name: 'Spacer',
    basicBoxLocal: NodeBox(0, 0, 100, 10),
    rowColumnType: RowColumnType.column,
    horizontalFit: SizeFit.expanded,
    verticalFit: SizeFit.expanded,
    children: [],
  )..parentID = 'card';
  return [
    grid,
    card,
    _rect('blurb', 'card', 300, 40, horizontalFit: SizeFit.expanded),
    dots,
    _rect(
      'dot',
      'dots',
      18,
      18,
      variables: {
        if (realistic)
          // A dot reads its scene as `parent.item`.
          'fill':
              r"${= parent.item.states[item.id].on ? '#FFCC00' : '#EADDD0'}",
      },
    ),
    _rect(
      'gap',
      'card',
      10,
      14,
      variables: {'visible': r'${= length(placed) == 0}'},
    ),
    spacer,
    _rect('buttons', 'card', 300, 42, horizontalFit: SizeFit.expanded),
  ];
}

Observable<VariableData> _list(String name, List<Object?> value) => Observable(
  VariableData(id: name, name: name, type: VariableType.list, value: value),
);

Future<CodelesslyContext> _pump(
  WidgetTester tester, {
  required List<Object?> placed,
  bool realistic = false,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final List<BaseNode> nodes = _scenesGrid(realistic: realistic);
  final registry = NodeRegistry()
    ..setNodes({for (final BaseNode node in nodes) node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
    ..variables['scenes'] = _list('scenes', [
      for (final String id in ['a', 'b', 'c'])
        {
          'id': id,
          'states': {
            'l1': {'on': true},
            'l2': {'on': false},
          },
        },
    ])
    ..variables['placed'] = _list('placed', placed);
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext,
      child: MaterialApp(
        home: Align(
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
  );
  await tester.pump();
  return codelesslyContext;
}

Set<double> _cardHeights() => {
  for (final Element e
      in find
          .byWidgetPredicate(
            (Widget w) => '${w.key}'.contains('[card]') && w is! KeyedSubtree,
          )
          .evaluate())
    (e.renderObject! as RenderBox).size.height,
};

void main() {
  test('parent.item and parent.index are not the parent\'s size', () {
    RectangleNode reading(String binding) =>
        _rect('r', 'p', 10, 10, variables: {'fill': binding});
    // The dot's colour, from its scene: measurable.
    expect(
      readsParentSize(
        reading(r"${= parent.item.states[item.id].on ? '#FFF' : '#000'}"),
      ),
      isFalse,
    );
    expect(readsParentSize(reading(r'${parent.index}')), isFalse);
    expect(readsParentSize(reading(r'${= parent.width / 2}')), isTrue);
    expect(readsParentSize(reading(r'${parent.height}')), isTrue);
    expect(readsParentSize(reading(r'${parent}')), isTrue);
    expect(readsParentSize(reading(r'${parent.items}')), isTrue);
  });

  // Padding 36 + blurb 40 + buttons 42, plus the dots (14 + 18) or the gap.
  const double withDots = 36 + 40 + 32 + 42;
  const double withoutDots = 36 + 40 + 14 + 42;

  testWidgets('a hidden dots list adds no height', (tester) async {
    await _pump(tester, placed: const []);
    expect(tester.takeException(), isNull);
    expect(_cardHeights(), {withoutDots});
  });

  testWidgets('the cards are measured again when the lamps are taken off', (
    tester,
  ) async {
    final CodelesslyContext context = await _pump(
      tester,
      placed: const ['l1', 'l2'],
    );
    expect(_cardHeights(), {withDots});

    final Observable<VariableData> placed = context.variables['placed']!;
    placed.value = placed.value.copyWith(value: const <Object?>[]);
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(_cardHeights(), {withoutDots});

    placed.value = placed.value.copyWith(value: const <Object?>['l1']);
    await tester.pump();
    await tester.pump();
    expect(_cardHeights(), {withDots});
  });

  // The boot action: the scene list (the grid's data) stays as it is, the
  // lamps move to the tray after the first frame (`placed` empties), so only
  // the dots' visibility and data change inside each card.
  testWidgets('a boot that empties the tray re-measures the runs', (
    tester,
  ) async {
    final CodelesslyContext context = await _pump(
      tester,
      placed: const [
        {'id': 'l1'},
        {'id': 'l2'},
      ],
      realistic: true,
    );
    expect(tester.takeException(), isNull);
    expect(_cardHeights(), {withDots});

    final Observable<VariableData> placed = context.variables['placed']!;
    placed.value = placed.value.copyWith(value: const <Object?>[]);
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(_cardHeights(), {withoutDots});

    placed.value = placed.value.copyWith(
      value: const <Object?>[
        {'id': 'l1'},
      ],
    );
    await tester.pump();
    await tester.pump();
    expect(_cardHeights(), {withDots});
  });
}
