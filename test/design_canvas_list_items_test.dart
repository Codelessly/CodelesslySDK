import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const List<Map<String, String>> crateItems = [
  {'id': 'jazz', 'name': 'Jazz'},
  {'id': 'soul', 'name': 'Soul'},
  {'id': 'hiphop', 'name': 'Hip hop'},
];

/// The crates a data-bound list shows, as a list variable's default value.
final VariableData crates = VariableData(
  id: 'crates',
  name: 'crates',
  type: VariableType.list,
  value: crateItems,
);

/// What an editor's resolver gives a node inside the list: it knows only the
/// node, which every row shares, so its item is the list's first.
ScopedValues editorScope() => ScopedValues.preview(
  variables: {'crates': crates},
  indexedItem: IndexedItem(0, crateItems.first),
);

List<BaseNode> crateList({bool stacked = false}) => [
  ListViewNode(
    id: 'list',
    name: 'list',
    basicBoxLocal: NodeBox(0, 0, 300, 200),
    properties: ListViewProperties(stacked: stacked),
    variables: {'data': r'${crates}'},
    children: ['label'],
  )..parentID = kRootNode,
  TextNode(
    id: 'label',
    name: 'label',
    basicBoxLocal: NodeBox(0, 0, 200, 24),
    horizontalFit: SizeFit.shrinkWrap,
    data: r'${item.name}',
    textMixedProps: [StartEndProp(start: 0, end: 12, fontSize: 16)],
  )..parentID = 'list',
];

Future<void> pumpCanvasList(WidgetTester tester, List<BaseNode> nodes) async {
  final registry = NodeRegistry()
    ..setNodes({for (final node in nodes) node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    // The render canvas gives its screen the variable defaults.
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty().copyWith(
        variables: {crates.id: Observable(crates)},
      ),
      child: MaterialApp(
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                nodes.first,
                context,
                settings: const WidgetBuildSettings(
                  debugLabel: 'design canvas',
                  isPreview: true,
                  withReactions: false,
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
  tearDown(() => VariablePreview.scopeResolver = null);

  group('VariablePreview.scopeOf', () {
    late BuildContext row;
    Future<void> pumpRow(WidgetTester tester, IndexedItem? item) async {
      Widget child = Builder(
        builder: (context) {
          row = context;
          return const SizedBox();
        },
      );
      if (item != null) child = IndexedItemProvider(item: item, child: child);
      await tester.pumpWidget(child);
    }

    testWidgets('gives a row its own item', (tester) async {
      VariablePreview.scopeResolver = (_) => editorScope();
      await pumpRow(tester, IndexedItem(2, {'name': 'Hip hop'}));
      final ScopedValues? values = VariablePreview.scopeOf(null, context: row);
      expect(values?.indexedItem, IndexedItem(2, {'name': 'Hip hop'}));
      // The canvas's variables stay.
      expect(values?.variables.keys, contains('crates'));
    });

    testWidgets('keeps the resolver scope outside a list', (tester) async {
      final ScopedValues scope = editorScope();
      VariablePreview.scopeResolver = (_) => scope;
      await pumpRow(tester, null);
      expect(VariablePreview.scopeOf(null, context: row), same(scope));
      expect(VariablePreview.scopeOf(null), same(scope));
    });

    testWidgets('a row without data keeps the sample item at its own index', (
      tester,
    ) async {
      VariablePreview.scopeResolver = (_) => editorScope();
      await pumpRow(tester, IndexedItem(4, null));
      final IndexedItem? item = VariablePreview.scopeOf(
        null,
        context: row,
      )?.indexedItem;
      expect(item?.index, 4);
      expect(item?.item, {'id': 'jazz', 'name': 'Jazz'});
    });

    testWidgets('is null without a resolver', (tester) async {
      await pumpRow(tester, IndexedItem(1, {'name': 'Soul'}));
      expect(VariablePreview.scopeOf(null, context: row), isNull);
    });
  });

  group('a data-bound list on the design canvas', () {
    testWidgets('previews each item in its own row', (tester) async {
      VariablePreview.scopeResolver = (_) => editorScope();
      await pumpCanvasList(tester, crateList());
      expect(find.text('Jazz', findRichText: true), findsOne);
      expect(find.text('Soul', findRichText: true), findsOne);
      expect(find.text('Hip hop', findRichText: true), findsOne);
    });

    testWidgets('a stacked list previews each item too', (tester) async {
      VariablePreview.scopeResolver = (_) => editorScope();
      await pumpCanvasList(tester, crateList(stacked: true));
      expect(find.text('Jazz', findRichText: true), findsOne);
      expect(find.text('Soul', findRichText: true), findsOne);
      expect(find.text('Hip hop', findRichText: true), findsOne);
    });
  });
}
