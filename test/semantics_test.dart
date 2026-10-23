import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

RectangleNode tappable(String id, String name) => RectangleNode(
  id: id,
  name: name,
  basicBoxLocal: NodeBox(0, 0, 40, 40),
  reactions: [
    Reaction(
      action: LinkAction(url: ''),
      trigger: TriggerModel(type: TriggerType.click),
    ),
  ],
)..parentID = kRootNode;

Future<void> pumpNode(WidgetTester tester, BaseNode node) async {
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: Builder(
            builder: (context) => manager.buildWidgetFromNode(
              node,
              context,
              settings: const WidgetBuildSettings(debugLabel: 'test'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final (String kind, String binding) in [
    ('a formula', "\${= 'Open ' + 'Harbor View Lofts'}"),
  ]) {
    testWidgets('a bound semanticLabel names the button ($kind)', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final RectangleNode card = RectangleNode.fromJson({
        ...tappable('card', 'Project card').toJson(),
        'variables': {'semanticLabel': binding},
      })..parentID = kRootNode;
      await pumpNode(tester, card);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Open Harbor View Lofts')),
        matchesSemantics(
          label: 'Open Harbor View Lofts',
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(find.bySemanticsLabel('Project card'), findsNothing);
      handle.dispose();
    });
  }

  testWidgets('a tappable node without text reads as a named button', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpNode(tester, tappable('back', 'Back to menu'));

    expect(
      tester.getSemantics(find.bySemanticsLabel('Back to menu')),
      matchesSemantics(
        label: 'Back to menu',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('a bound semanticLabel replaces the text inside a card', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final FrameNode card = FrameNode.fromJson({
      ...FrameNode(
        id: 'card',
        name: 'Card',
        basicBoxLocal: NodeBox(0, 0, 300, 60),
        children: ['name'],
      ).toJson(),
      'reactions': [
        Reaction(
          action: LinkAction(url: ''),
          trigger: TriggerModel(type: TriggerType.click),
        ).toJson(),
      ],
      'variables': {'semanticLabel': "\${= 'Open ' + 'Harbor View Lofts'}"},
    })..parentID = kRootNode;
    final TextNode name = TextNode(
      id: 'name',
      name: 'name',
      basicBoxLocal: NodeBox(0, 0, 200, 24),
      characters: 'Harbor View Lofts 1420 Harbor Blvd',
      textMixedProps: [StartEndProp(start: 0, end: 34, fontSize: 16)],
    )..parentID = 'card';
    final registry = NodeRegistry()..setNodes({'card': card, 'name': name});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                card,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Open Harbor View Lofts')),
      matchesSemantics(
        label: 'Open Harbor View Lofts',
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(find.bySemanticsLabel(RegExp('1420 Harbor')), findsNothing);
    handle.dispose();
  });

  test('a default node name is not used as a label', () {
    expect(
      WidgetNodeTransformerManager.semanticLabelFor(
        tappable('r', 'Rectangle 2'),
        const [],
      ),
      '',
    );
    expect(
      WidgetNodeTransformerManager.semanticLabelFor(
        tappable('r', 'Add to bag'),
        const [],
      ),
      'Add to bag',
    );
  });

  testWidgets('tappables inside a tappable keep their own buttons', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final FrameNode plan = FrameNode.fromJson({
      ...FrameNode(
        id: 'plan',
        name: 'Plan',
        basicBoxLocal: NodeBox(0, 0, 200, 100),
        children: ['p1', 'p2'],
      ).toJson(),
      'reactions': [
        Reaction(
          action: LinkAction(url: ''),
          trigger: TriggerModel(type: TriggerType.click),
        ).toJson(),
      ],
    })..parentID = kRootNode;
    final RectangleNode p1 = tappable('p1', 'Pin one')..parentID = 'plan';
    final RectangleNode p2 = tappable('p2', 'Pin two')..parentID = 'plan';
    final registry = NodeRegistry()
      ..setNodes({
        for (final n in [plan, p1, p2]) n.id: n,
      });
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                plan,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    );
    for (final String name in ['Pin one', 'Pin two']) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(name)),
        matchesSemantics(label: name, isButton: true, hasTapAction: true),
      );
    }
    handle.dispose();
  });
}
