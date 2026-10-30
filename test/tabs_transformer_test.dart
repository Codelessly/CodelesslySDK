import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/load_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);

  final tabs = TabsNode(
    id: 'tabs',
    name: 'Tabs',
    basicBoxLocal: NodeBox(0, 0, 360, 180),
    tabs: const [
      TabsItem(title: 'First', child: 'first'),
      TabsItem(title: 'Second', child: 'second'),
    ],
  );
  final first = TextNode.fromJson({
    'id': 'first',
    'name': 'First content',
    'type': 'text',
    'basicBoxLocal': [0, 0, 300, 50],
    'data': 'First page',
    'textMixedProps': [
      {
        'start': 0,
        'end': 10,
        'fontName': {
          'family': 'TabsFixture',
          'style': 'Normal',
          'weight': 'w400',
        },
      },
    ],
  })..parentID = 'tabs';
  final second = TextNode.fromJson({
    'id': 'second',
    'name': 'Second content',
    'type': 'text',
    'basicBoxLocal': [0, 0, 300, 50],
    'data': 'Second page',
    'textMixedProps': [
      {
        'start': 0,
        'end': 11,
        'fontName': {
          'family': 'TabsFixture',
          'style': 'Normal',
          'weight': 'w400',
        },
      },
    ],
  })..parentID = 'tabs';

  Future<void> mount(
    WidgetTester tester,
    TabsNode node, {
    bool missing = false,
  }) async {
    final registry = NodeRegistry()
      ..setNodes({
        node.id: node,
        'first': first,
        if (!missing) 'second': second,
      });
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    expect(manager.getTransformerByNode(node), isA<PassiveTabsTransformer>());
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Roboto'),
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  node,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'tabs-test'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('switches actual scene content and keeps selection on rebuild', (
    tester,
  ) async {
    await mount(tester, tabs);
    expect(find.text('First page'), findsOneWidget);
    expect(find.text('Second page'), findsNothing);
    await tester.tap(find.text('Second'));
    await tester.pump();
    expect(find.text('First page'), findsNothing);
    expect(find.text('Second page'), findsOneWidget);
    final bar = tester.widget<TabBar>(find.byType(TabBar));
    expect(DefaultTabController.of(tester.element(find.byType(TabBar))).index, 1);
    final theme = Theme.of(tester.element(find.byType(TabBar)));
    expect(
      bar.labelColor ??
          theme.tabBarTheme.labelColor ??
          theme.colorScheme.primary,
      theme.colorScheme.primary,
    );
    expect(
      bar.indicatorColor ??
          theme.tabBarTheme.indicatorColor ??
          theme.colorScheme.primary,
      theme.colorScheme.primary,
    );
    await mount(tester, tabs);
    expect(find.text('Second page'), findsOneWidget);
  });

  testWidgets('one tab and missing child do not crash', (tester) async {
    final single = TabsNode(
      id: 'single',
      name: 'Single',
      basicBoxLocal: NodeBox(0, 0, 360, 180),
      tabs: const [TabsItem(title: 'Only', child: 'absent')],
    );
    await mount(tester, single, missing: true);
    expect(find.text('Only'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await mount(tester, tabs, missing: true);
    await tester.tap(find.text('Second'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('First page'), findsNothing);
  });

  testWidgets('closed and selected states use real-font goldens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await mount(tester, tabs);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/tabs_closed.png'),
    );
    await tester.tap(find.text('Second'));
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/tabs_selected.png'),
    );
  });
}
