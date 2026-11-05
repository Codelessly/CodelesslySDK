import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A button inside a tappable row (an edit button on a song row that loads
/// the song when tapped) takes its own taps; the row gets the taps that land
/// outside the button.
void main() {
  late CodelesslyContext codelesslyContext;

  VariableData variable(String name, VariableType type, Object value) =>
      VariableData(id: name, name: name, type: type, value: value);

  Reaction setTo(String name, String value) => Reaction(
    trigger: TriggerModel(type: TriggerType.click),
    action: SetVariableAction(
      variable: VariableData(id: name, name: name),
      newValue: value,
    ),
  );

  Object? valueOf(String name) =>
      codelesslyContext.findVariableByName(name)!.value.getValue();

  Future<void> pump(WidgetTester tester, List<BaseNode> nodes) async {
    final registry = NodeRegistry()
      ..setNodes({for (final node in nodes) node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    codelesslyContext = CodelesslyContext.empty().copyWith(
      variables: {
        for (final v in [
          variable('row', VariableType.text, ''),
          variable('button', VariableType.text, ''),
          variable('songs', VariableType.list, [
            {'id': 'a', 'title': 'Superstition'},
            {'id': 'b', 'title': 'Take Five'},
          ]),
        ])
          v.id: Observable(v),
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: ChangeNotifierProvider<CodelesslyContext>.value(
            value: codelesslyContext,
            child: ActionChainHost(
              child: Align(
                alignment: Alignment.topLeft,
                child: Builder(
                  builder: (context) => manager.buildWidgetFromNode(
                    nodes.first,
                    context,
                    settings: const WidgetBuildSettings(
                      debugLabel: 'runtime',
                      withReactions: true,
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
  }

  RowColumnNode row({required List<String> children, String? parent}) =>
      RowColumnNode(
        id: 'row',
        name: 'row',
        basicBoxLocal: NodeBox(0, 0, 300, 60),
        rowColumnType: RowColumnType.row,
        reactions: [setTo('row', r'${item.id}tapped')],
        children: children,
      )..parentID = parent ?? kRootNode;

  RowColumnNode button() => RowColumnNode(
    id: 'button',
    name: 'Edit song',
    basicBoxLocal: NodeBox(260, 14, 32, 32),
    rowColumnType: RowColumnType.row,
    fills: [PaintModel.solid(id: 'fill', color: ColorRGBA.white)],
    reactions: [setTo('button', r'${item.id}edited')],
    children: [],
  )..parentID = 'row';

  FrameNode spacer({double x = 0, double width = 260}) => FrameNode(
    id: 'spacer',
    name: 'spacer',
    basicBoxLocal: NodeBox(x, 0, width, 60),
    horizontalFit: SizeFit.fixed,
    verticalFit: SizeFit.fixed,
    children: [],
  )..parentID = 'row';

  FrameNode handle() =>
      FrameNode(
          id: 'handle',
          name: 'handle',
          basicBoxLocal: NodeBox(0, 0, 40, 60),
          horizontalFit: SizeFit.fixed,
          verticalFit: SizeFit.fixed,
          children: [],
        )
        ..parentID = 'row'
        ..drag = const DragModel(reorder: true);

  ListViewNode list() => ListViewNode(
    id: 'list',
    name: 'list',
    basicBoxLocal: NodeBox(0, 0, 300, 120),
    isScrollable: false,
    verticalFit: SizeFit.shrinkWrap,
    properties: ListViewProperties(),
    variables: {'data': r'${songs}'},
    children: ['row'],
  )..parentID = kRootNode;

  testWidgets('a button in a tappable row takes its own tap', (tester) async {
    await pump(tester, [
      row(children: ['spacer', 'button']),
      spacer(),
      button(),
    ]);
    await tester.tapAt(const Offset(276, 30));
    await tester.pumpAndSettle();
    expect(valueOf('button'), 'edited');
    expect(valueOf('row'), '');
    await tester.tapAt(const Offset(100, 30));
    await tester.pumpAndSettle();
    expect(valueOf('row'), 'tapped');
  });

  testWidgets('a button in a tappable list row takes its own tap', (
    tester,
  ) async {
    await pump(tester, [
      list(),
      row(children: ['spacer', 'button'], parent: 'list'),
      spacer(),
      button(),
    ]);
    await tester.tapAt(const Offset(276, 30));
    await tester.pumpAndSettle();
    expect(valueOf('button'), 'aedited');
    expect(valueOf('row'), '');
    await tester.tapAt(const Offset(100, 90));
    await tester.pumpAndSettle();
    expect(valueOf('row'), 'btapped');
  });

  testWidgets('a button in a tappable reorderable row takes its own tap', (
    tester,
  ) async {
    await pump(tester, [
      list(),
      row(children: ['handle', 'spacer', 'button'], parent: 'list'),
      handle(),
      spacer(x: 40, width: 220),
      button(),
    ]);
    await tester.tapAt(const Offset(276, 30));
    await tester.pumpAndSettle();
    expect(valueOf('button'), 'aedited');
    expect(valueOf('row'), '');
    await tester.tapAt(const Offset(100, 90));
    await tester.pumpAndSettle();
    expect(valueOf('row'), 'btapped');
  });

  testWidgets('with semantics on, the button and the row are tapped apart', (
    tester,
  ) async {
    // A screen reader (and Flutter web once semantics is on) taps through
    // semantics nodes; the button needs its own node, not one merged into
    // the row's.
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pump(tester, [
      list(),
      row(children: ['handle', 'title', 'button'], parent: 'list'),
      handle(),
      TextNode(
        id: 'title',
        name: 'title',
        basicBoxLocal: NodeBox(40, 0, 200, 24),
        data: r'${item.title}',
        textMixedProps: [StartEndProp(start: 0, end: 13, fontSize: 16)],
      )..parentID = 'row',
      button(),
    ]);
    // One edit button per row, each its own node.
    expect(find.semantics.byLabel('Edit song'), findsExactly(2));
    for (final SemanticsNode node
        in find.semantics.byLabel('Edit song').evaluate()) {
      expect(node.isMergedIntoParent, isFalse);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    }
    // The row reads as its own text, not with the button's name mixed in.
    expect(find.semantics.byLabel('Superstition'), findsOne);
    tester.semantics.tap(find.semantics.byLabel('Edit song').at(1));
    await tester.pumpAndSettle();
    expect(valueOf('button'), 'bedited');
    expect(valueOf('row'), '');
    tester.semantics.tap(find.semantics.byLabel('Superstition'));
    await tester.pumpAndSettle();
    expect(valueOf('row'), 'atapped');
    semantics.dispose();
  });
}
