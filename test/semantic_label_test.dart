import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Reaction click(ActionModel action) => Reaction(
  action: action,
  trigger: TriggerModel(type: TriggerType.click),
);

TextNode text(String id, String parent, String characters) => TextNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, 120, 24),
  characters: characters,
  textMixedProps: [
    StartEndProp(start: 0, end: characters.length, fontSize: 16),
  ],
)..parentID = parent;

/// A frame that reads "SIGN IN" and calls `signIn` when tapped.
FrameNode signInFrame({String semanticLabel = ''}) =>
    FrameNode(
        id: 'signIn',
        name: 'Sign in button',
        basicBoxLocal: NodeBox(0, 0, 160, 48),
        children: ['signInText'],
        reactions: [click(CallFunctionAction(name: 'signIn'))],
      )
      ..parentID = kRootNode
      ..semanticLabel = semanticLabel;

Future<void> pumpNodes(
  WidgetTester tester,
  List<BaseNode> nodes, {
  CodelesslyContext? codelesslyContext,
}) async {
  final registry = NodeRegistry()
    ..setNodes({for (final node in nodes) node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext ?? CodelesslyContext.empty(),
      child: MaterialApp(
        home: ActionChainHost(
          child: Align(
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
    ),
  );
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('without a label a tappable frame reads as its text', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpNodes(tester, [
      signInFrame(),
      text('signInText', 'signIn', 'SIGN IN'),
    ]);

    expect(
      tester.getSemantics(find.bySemanticsLabel('SIGN IN')),
      matchesSemantics(label: 'SIGN IN', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('a labelled tappable frame reads as its label, not its text', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    int taps = 0;
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
      ..functions = {'signIn': (context, reference, params) => taps++};
    await pumpNodes(tester, [
      signInFrame(semanticLabel: 'Sign in'),
      text('signInText', 'signIn', 'SIGN IN'),
    ], codelesslyContext: codelesslyContext);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Sign in')),
      matchesSemantics(label: 'Sign in', isButton: true, hasTapAction: true),
    );
    expect(find.bySemanticsLabel('SIGN IN'), findsNothing);

    // Assistive tech's tap runs the click reactions.
    tester.semantics.tap(find.semantics.byLabel('Sign in'));
    await tester.pump();
    expect(taps, 1);

    // So does a finger.
    await tester.tap(find.text('SIGN IN'));
    await tester.pump();
    expect(taps, 2);
    handle.dispose();
  });

  testWidgets('a labelled button node reads as its label', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final ButtonNode button =
        ButtonNode(
            id: 'startTrip',
            name: 'Start trip',
            basicBoxLocal: NodeBox(0, 0, 200, 48),
            properties: ButtonProperties(
              label: 'START PRE-TRIP',
              buttonType: ButtonTypeEnum.filled,
            ),
            reactions: [click(CallFunctionAction(name: 'start'))],
          )
          ..parentID = kRootNode
          ..semanticLabel = 'Start pre-trip';
    await pumpNodes(tester, [button]);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Start pre-trip')),
      matchesSemantics(
        label: 'Start pre-trip',
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(find.bySemanticsLabel('START PRE-TRIP'), findsNothing);
    handle.dispose();
  });

  testWidgets('a label substitutes its data and follows it', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final Observable<VariableData> truck = Observable(
      VariableData(id: 'truck', name: 'truck', value: 'Truck 12'),
    );
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
      ..variables['truck'] = truck;
    await pumpNodes(tester, [
      signInFrame(semanticLabel: r'Inspect ${truck}'),
      text('signInText', 'signIn', 'INSPECT'),
    ], codelesslyContext: codelesslyContext);

    expect(find.bySemanticsLabel('Inspect Truck 12'), findsOneWidget);

    truck.set(truck.value.copyWith(value: 'Truck 7'));
    await tester.pump();
    expect(find.bySemanticsLabel('Inspect Truck 7'), findsOneWidget);
    expect(find.bySemanticsLabel('INSPECT'), findsNothing);
    handle.dispose();
  });

  testWidgets('a label bound through variables wins over the typed one', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
      ..variables['status'] = Observable(
        VariableData(id: 'status', name: 'status', value: 'Pass'),
      );
    final FrameNode frame = signInFrame(semanticLabel: 'Status')
      ..variables['semanticLabel'] = 'status';
    await pumpNodes(tester, [
      frame,
      text('signInText', 'signIn', 'OK'),
    ], codelesslyContext: codelesslyContext);

    expect(find.bySemanticsLabel('Pass'), findsOneWidget);
    expect(find.bySemanticsLabel('Status'), findsNothing);
    handle.dispose();
  });

  testWidgets('a labelled node that is not tappable is a labelled container', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final TextNode badge = text('badge', kRootNode, 'OK')
      ..semanticLabel = 'Inspection passed';
    await pumpNodes(tester, [badge]);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Inspection passed')),
      matchesSemantics(label: 'Inspection passed', isButton: false),
    );
    expect(find.bySemanticsLabel('OK'), findsNothing);
    handle.dispose();
  });
}
