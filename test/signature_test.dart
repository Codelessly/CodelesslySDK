import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

SignatureNode signature({
  Map<String, String> variables = const {},
  List<Reaction> reactions = const [],
}) => SignatureNode(
  id: 'signature',
  name: 'Signature',
  basicBoxLocal: NodeBox(0, 0, 320, 140),
  properties: SignatureProperties(),
  reactions: reactions,
)..variables.addAll(variables);

Observable<VariableData> listVariable(String name, [String value = '[]']) =>
    Observable(
      VariableData(id: name, name: name, value: value, type: VariableType.list),
    );

Future<void> pumpNode(
  WidgetTester tester,
  BaseNode node,
  CodelesslyContext codelesslyContext,
) async {
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext,
      child: MaterialApp(
        home: ActionChainHost(
          child: Scaffold(
            body: Center(
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
    ),
  );
}

/// The strokes the pad paints.
List<List<Offset>> paintedStrokes(WidgetTester tester) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is SignaturePainter,
    ),
  );
  return (paint.painter! as SignaturePainter).strokes;
}

void main() {
  testWidgets('drawing on the pad fills its variable and fires changed', (
    tester,
  ) async {
    final sig = listVariable('signature');
    final codelesslyContext = CodelesslyContext.empty()
      ..variables['signature'] = sig
      ..variables['changes'] = Observable(
        VariableData(
          id: 'changes',
          name: 'changes',
          value: '0',
          type: VariableType.integer,
        ),
      );
    final node = signature(
      variables: {'value': r'${signature}'},
      reactions: [
        Reaction(
          trigger: TriggerModel(type: TriggerType.changed),
          action: SetVariableAction(
            variable: VariableData(
              id: 'changes',
              name: 'changes',
              type: VariableType.integer,
            ),
            newValue: r'${= changes + 1}',
          ),
        ),
      ],
    );
    await pumpNode(tester, node, codelesslyContext);

    expect(find.byType(TransformerSignature), findsOneWidget);
    expect(paintedStrokes(tester), isEmpty);

    final Offset start = tester.getTopLeft(find.byType(TransformerSignature));
    await tester.dragFrom(start + const Offset(40, 40), const Offset(120, 30));
    await tester.pumpAndSettle();

    final Object? value = sig.value.getValue();
    expect(value, isA<List>());
    expect(value as List, hasLength(1));
    expect((value.single as List).length, greaterThan(1));
    expect((value.single as List).first, [40.0, 40.0]);
    expect(
      codelesslyContext.variables['changes']!.value.getValue(),
      1,
      reason: 'changed fires once per stroke',
    );
    expect(paintedStrokes(tester), hasLength(1));

    // A second stroke adds to the first.
    await tester.dragFrom(start + const Offset(60, 90), const Offset(0, -40));
    await tester.pumpAndSettle();
    expect(sig.value.getValue() as List, hasLength(2));
    expect(codelesslyContext.variables['changes']!.value.getValue(), 2);

    // Formulas see the signature as a list.
    final scoped = ScopedValues.preview(variables: {'signature': sig.value});
    expect(
      PropertyValueDelegate.substituteVariables(
        r'${signature.isEmpty} ${= length(signature) > 0}',
        scopedValues: scoped,
        nullSubstitutionMode: NullSubstitutionMode.nullValue,
      ),
      'false true',
    );

    // Clearing the variable clears the pad.
    sig.value = sig.value.copyWith(value: '[]');
    await tester.pumpAndSettle();
    expect(paintedStrokes(tester), isEmpty);
    expect(sig.value.getValue(), isEmpty);
  });

  testWidgets('a set variable action with [] clears the pad', (tester) async {
    final sig = listVariable('signature', '[[[1,2],[3,4]]]');
    final codelesslyContext = CodelesslyContext.empty()
      ..variables['signature'] = sig;
    await pumpNode(
      tester,
      signature(variables: {'value': r'${signature}'}),
      codelesslyContext,
    );
    expect(paintedStrokes(tester), [
      [const Offset(1, 2), const Offset(3, 4)],
    ]);

    final BuildContext context = tester.element(
      find.byType(TransformerSignature),
    );
    await FunctionsRepository.performAction(
      context,
      SetVariableAction(
        variable: VariableData(
          id: 'signature',
          name: 'signature',
          type: VariableType.list,
        ),
        newValue: '[]',
      ),
    );
    await tester.pumpAndSettle();
    expect(paintedStrokes(tester), isEmpty);
  });

  testWidgets('a pad whose enabled binding is false takes no strokes', (
    tester,
  ) async {
    final sig = listVariable('signature');
    final node = signature(
      variables: {'value': r'${signature}', 'enabled': r'${locked.toggled}'},
    );
    await pumpNode(
      tester,
      node,
      CodelesslyContext.empty()
        ..variables['signature'] = sig
        ..variables['locked'] = Observable(
          VariableData(
            id: 'locked',
            name: 'locked',
            value: 'true',
            type: VariableType.boolean,
          ),
        ),
    );
    final Offset start = tester.getTopLeft(find.byType(TransformerSignature));
    await tester.dragFrom(start + const Offset(40, 40), const Offset(120, 30));
    await tester.pumpAndSettle();
    expect(sig.value.getValue(), isEmpty);
    expect(paintedStrokes(tester), isEmpty);
  });

  testWidgets('without a binding the pad keeps its strokes itself', (
    tester,
  ) async {
    await pumpNode(tester, signature(), CodelesslyContext.empty());
    final Offset start = tester.getTopLeft(find.byType(TransformerSignature));
    await tester.dragFrom(start + const Offset(40, 40), const Offset(120, 30));
    await tester.pumpAndSettle();
    expect(paintedStrokes(tester), hasLength(1));
  });

  testWidgets('without a runtime the pad keeps its strokes itself', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PassiveSignatureWidget(
            node: signature(variables: {'value': r'${signature}'}),
            settings: const WidgetBuildSettings(
              debugLabel: 'test',
              isPreview: true,
            ),
          ),
        ),
      ),
    );
    final Offset start = tester.getTopLeft(find.byType(TransformerSignature));
    await tester.dragFrom(start + const Offset(40, 40), const Offset(120, 30));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(paintedStrokes(tester), hasLength(1));
  });
}
