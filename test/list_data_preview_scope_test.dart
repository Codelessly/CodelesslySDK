// A list's `data` on the design canvas reads the editor's preview values
// (VariablePreview.scopeResolver), previewed predefined values such as
// `drag` included, as the bindings on the same nodes do; list literals
// (`${= [{...}]}`) give their items like `map(...)`. A running app (under an
// ActionChainHost: a CodelesslyWidget or an editor's run window) reads its
// own values, never the design canvas's.
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  tearDown(() => VariablePreview.scopeResolver = null);

  ({NodeRegistry registry, ListViewNode list}) build(
    String data, {
    ListLayout layout = ListLayout.list,
  }) {
    final TextNode label = TextNode(
      id: 'label',
      name: 'label',
      basicBoxLocal: NodeBox(0, 0, 100, 20),
      data: r'row ${item.p}',
      textMixedProps: [StartEndProp(start: 0, end: 13, fontSize: 12)],
    )..parentID = 'list';
    final ListViewNode list = ListViewNode(
      id: 'list',
      name: 'list',
      basicBoxLocal: NodeBox(0, 0, 300, 200),
      properties: ListViewProperties(layout: layout),
      children: ['label'],
      variables: {'data': data},
    )..parentID = kRootNode;
    return (
      registry: NodeRegistry()..setNodes({list.id: list, label.id: label}),
      list: list,
    );
  }

  Future<void> pump(
    WidgetTester tester,
    NodeRegistry registry,
    BaseNode root, {
    required bool withReactions,
    bool underHost = false,
  }) async {
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
      ..variables['spots'] = Observable(
        VariableData(
          id: 'spots',
          name: 'spots',
          type: VariableType.list,
          value: [7, 8],
        ),
      );
    Widget child = Builder(
      builder: (context) => manager.buildWidgetFromNode(
        root,
        context,
        settings: WidgetBuildSettings(
          debugLabel: 'test',
          withReactions: withReactions,
        ),
      ),
    );
    if (underHost) child = ActionChainHost(child: child);
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 300, height: 200, child: child),
          ),
        ),
      ),
    );
  }

  /// The design canvas's values: `spots` and a previewed drag.
  ScopedValues canvasValues(BaseNode? node) => ScopedValues.preview(
    variables: {
      'spots': VariableData(
        id: 'spots',
        name: 'spots',
        type: VariableType.list,
        value: [7, 8],
      ),
    },
    predefinedOverrides: {
      'drag': {
        'active': true,
        'data': {'id': 'l3'},
      },
    },
  );

  for (final ListLayout layout in [ListLayout.list, ListLayout.stack]) {
    testWidgets('a list literal gives its items ($layout)', (tester) async {
      final t = build(r'${= [{p: spots[0]}, {p: spots[1] + 1}]}', layout: layout);
      await pump(tester, t.registry, t.list, withReactions: true);
      expect(find.text('row 7'), findsOneWidget);
      expect(find.text('row 9'), findsOneWidget);
    });

    testWidgets('on the design canvas, list data reads the previewed drag '
        '($layout)', (tester) async {
      VariablePreview.scopeResolver = canvasValues;
      final t = build(
        r'${= drag.active ? [{p: drag.data.id}] : []}',
        layout: layout,
      );
      await pump(tester, t.registry, t.list, withReactions: false);
      expect(find.text('row l3'), findsOneWidget);
    });
  }

  testWidgets('at runtime list data reads the app\'s drag, not the canvas '
      'preview', (tester) async {
    VariablePreview.scopeResolver = canvasValues;
    final t = build(r'${= drag.active ? [{p: drag.data.id}] : [{p: 0}]}');
    await pump(tester, t.registry, t.list, withReactions: true);
    expect(find.text('row 0'), findsOneWidget);
    expect(find.text('row l3'), findsNothing);
  });

  testWidgets('a running app under a host ignores the design canvas\'s '
      'values', (tester) async {
    VariablePreview.scopeResolver = canvasValues;
    final t = build(r'${= drag.active ? [{p: drag.data.id}] : [{p: 0}]}');
    // No reactions, but in a running app: still the app's own values.
    await pump(
      tester,
      t.registry,
      t.list,
      withReactions: false,
      underHost: true,
    );
    expect(find.text('row 0'), findsOneWidget);
    expect(find.text('row l3'), findsNothing);
  });
}
