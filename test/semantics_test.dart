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
        home: Material(
          child: Align(
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
    ),
  );
}

void main() {
  testWidgets('a semanticLabel formula names a node and replaces its text', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final node = tappable('day', 'Day')
      ..variables['semanticLabel'] =
          r'Sat, Oct 24${= 1 < 2 ? ", good pooling" : ""}'
      ..variables['semanticSelected'] = r'${= 2 > 1}';
    await pumpNode(tester, node);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Sat, Oct 24, good pooling')),
      matchesSemantics(
        label: 'Sat, Oct 24, good pooling',
        isButton: true,
        hasTapAction: true,
        hasSelectedState: true,
        isSelected: true,
      ),
    );
    // On a button with text, the label replaces the text (as the reference
    // app's buttons read) and the button keeps its tap.
    final withText = TextNode.fromJson({
      'id': 'label',
      'name': 'Label',
      'type': 'text',
      'basicBoxLocal': [0, 0, 40, 20],
      'characters': '24',
      'textMixedProps': [
        {'start': 0, 'end': 2},
      ],
    })..parentID = 'chip';
    final chip =
        RowColumnNode(
            id: 'chip',
            name: 'Chip',
            basicBoxLocal: NodeBox(0, 0, 60, 30),
            children: ['label'],
            rowColumnType: RowColumnType.row,
            reactions: [
              Reaction(
                action: LinkAction(url: ''),
                trigger: TriggerModel(type: TriggerType.click),
              ),
            ],
          )
          ..parentID = kRootNode
          ..variables['semanticLabel'] = 'Saturday';
    final registry = NodeRegistry()
      ..setNodes({'chip': chip, 'label': withText});
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
                chip,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Saturday')),
      matchesSemantics(label: 'Saturday', isButton: true, hasTapAction: true),
    );
    expect(find.bySemanticsLabel(RegExp('24')), findsNothing);
    handle.dispose();
  });

  testWidgets('a semanticLabel on a node that does not react adds a label', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final node =
        RectangleNode(
            id: 'reading',
            name: 'Reading',
            basicBoxLocal: NodeBox(0, 0, 40, 40),
          )
          ..parentID = kRootNode
          ..variables['semanticLabel'] = 'Tide now 2.0 ft, falling';
    await pumpNode(tester, node);
    expect(find.bySemanticsLabel('Tide now 2.0 ft, falling'), findsOneWidget);
    handle.dispose();
  });

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

  testWidgets('a semanticLabel on a field keeps the field', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final node = TextFieldNode(
      id: 'search',
      name: 'Search',
      basicBoxLocal: NodeBox(0, 0, 300, 48),
      properties: TextFieldProperties(),
    )..parentID = kRootNode;
    node.variables['semanticLabel'] = 'Search creatures';
    await pumpNode(tester, node);
    expect(tester.takeException(), isNull);
    final data = tester
        .getSemantics(find.bySemanticsLabel(RegExp('^Search creatures')))
        .getSemanticsData();
    expect(data.flagsCollection.isTextField, isTrue);
    handle.dispose();
  });

  testWidgets('a labelled button runs its reactions from its semantics tap', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final List<String> calls = [];
    final node =
        RectangleNode(
            id: 'settings',
            name: 'Settings',
            basicBoxLocal: NodeBox(0, 0, 40, 40),
            reactions: [
              Reaction(
                action: CallFunctionAction(name: 'record'),
                trigger: TriggerModel(type: TriggerType.click),
              ),
            ],
          )
          ..parentID = kRootNode
          ..variables['semanticLabel'] = 'Settings';
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty()
          ..functions['record'] = (context, reference, params) =>
              calls.add('tap'),
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
    tester.semantics.tap(find.semantics.byLabel('Settings'));
    await tester.pump();
    expect(calls, ['tap']);
    handle.dispose();
  });
}
