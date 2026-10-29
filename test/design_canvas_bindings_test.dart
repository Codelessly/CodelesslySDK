import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The design canvas evaluates bindings with its variables' default values:
/// an editor passes them as [ScopedValues.preview].
ScopedValues defaults(String authMode) => ScopedValues.preview(
  variables: {
    'authMode': VariableData(
      id: 'v1',
      name: 'authMode',
      value: authMode,
      type: VariableType.text,
    ),
  },
);

const String _signInFormula =
    r"${= authMode == 'signIn' ? 'Sign in' : 'Create account'}";

ButtonNode button({String label = ''}) => ElevatedButtonNode(
  id: 'button',
  name: 'Button',
  basicBoxLocal: NodeBox(0, 0, 200, 40),
  properties: ButtonProperties(label: label),
  variables: {'label': _signInFormula},
)..parentID = kRootNode;

Future<void> pumpHost(WidgetTester tester, WidgetBuilder builder) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: Builder(builder: builder),
          ),
        ),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
}

void main() {
  tearDown(() => VariablePreview.scopeResolver = null);

  group('a button label bound to a formula', () {
    testWidgets('shows the default-value result on a design canvas', (
      tester,
    ) async {
      VariablePreview.scopeResolver = (_, {item}) => defaults('signIn');
      await pumpHost(
        tester,
        (context) => PassiveButtonWidget(
          node: button(),
          settings: const WidgetBuildSettings(
            debugLabel: 'canvas',
            replaceVariablesWithSymbols: true,
          ),
        ),
      );
      expect(find.textContaining('Sign in', findRichText: true), findsOne);
    });

    testWidgets('a static label still shows when nothing is bound', (
      tester,
    ) async {
      final ButtonNode node = button(label: 'Continue')..variables.clear();
      await pumpHost(
        tester,
        (context) => PassiveButtonWidget(
          node: node,
          settings: const WidgetBuildSettings(
            debugLabel: 'canvas',
            replaceVariablesWithSymbols: true,
          ),
        ),
      );
      expect(find.textContaining('Continue', findRichText: true), findsOne);
    });

    testWidgets('evaluates with the scoped values it is given', (tester) async {
      await pumpHost(
        tester,
        (context) => PassiveButtonWidget(
          node: button(),
          scopedValues: defaults('signUp'),
          settings: const WidgetBuildSettings(debugLabel: 'runtime'),
        ),
      );
      expect(find.text('Create account'), findsOne);
    });

    test('the label template is the binding, else the label', () {
      expect(buttonLabelTemplateOf(button(label: 'x')), _signInFormula);
      expect(
        buttonLabelTemplateOf(
          button(label: 'x')..variables['label'] = 'authMode',
        ),
        r'${authMode}',
      );
      expect(buttonLabelTemplateOf(button(label: 'x')..variables.clear()), 'x');
    });
  });

  group('a visibility formula', () {
    final RectangleNode email =
        RectangleNode(
            id: 'email',
            name: 'Email',
            basicBoxLocal: NodeBox(0, 0, 100, 40),
          )
          ..parentID = kRootNode
          ..variables['visible'] =
              r"${= authMode == 'signIn' || authMode == 'signUp'}";
    final manager = PassiveNodeTransformerManager(
      (id) => email,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );

    Future<void> pumpVisibility(
      WidgetTester tester, {
      ScopedValues? scopedValues,
    }) => pumpHost(
      tester,
      (context) => manager.applyWidgetVisibility(
        context,
        email,
        const SizedBox(key: Key('email'), width: 100, height: 40),
        maintainState: true,
        scopedValues: scopedValues,
      ),
    );

    testWidgets('shows the node when the default values make it true', (
      tester,
    ) async {
      await pumpVisibility(tester, scopedValues: defaults('signIn'));
      expect(find.byKey(const Key('email')), findsOne);
      expect(
        tester.getSize(find.byKey(const Key('email'))),
        const Size(100, 40),
      );
    });

    testWidgets('collapses the node when they make it false', (tester) async {
      await pumpVisibility(tester, scopedValues: defaults('reset'));
      expect(find.byKey(const Key('email')), findsNothing);
      expect(
        manager.runtimeVisibility(
          tester.element(find.byType(Align)),
          email,
          scopedValues: defaults('reset'),
        ),
        isFalse,
      );
    });

    testWidgets('without values it reads the build context, as at runtime', (
      tester,
    ) async {
      // No variable: authMode is null, so the formula is false.
      await pumpVisibility(tester);
      expect(find.byKey(const Key('email')), findsNothing);
    });
  });

  group('a text in a list item', () {
    const String note = r'${= flags[item.id].note}';
    final TextNode text = TextNode(
      id: 'note',
      name: 'Note',
      basicBoxLocal: NodeBox(0, 0, 200, 20),
      data: note,
      textMixedProps: [StartEndProp(start: 0, end: note.length)],
    )..parentID = kRootNode;

    // The editor's values for the canvas: the first item of the list.
    setUp(
      () => VariablePreview.scopeResolver = (_) => ScopedValues.preview(
        variables: {
          'flags': VariableData(
            id: 'flags',
            name: 'flags',
            value: {
              '1a': {'note': 'Tread worn'},
              '1b': {'note': 'Brake hose leak'},
            },
            type: VariableType.map,
          ),
        },
        indexedItem: IndexedItem(0, {'id': '1a'}),
      ),
    );

    Future<void> pumpItem(WidgetTester tester, IndexedItem? item) =>
        pumpHost(tester, (context) {
          Widget build(BuildContext context) => TextUtils.buildTextForProps(
            context,
            note,
            node: text,
            props: text.textMixedProps,
            variablesOverrides: const [],
            nullSubstitutionMode: NullSubstitutionMode.noChange,
            replaceVariablesWithSymbol: true,
          );
          if (item == null) return build(context);
          return IndexedItemProvider(
            item: item,
            child: Builder(builder: build),
          );
        });

    testWidgets('reads the item it is built in, as its bindings do', (
      tester,
    ) async {
      await pumpItem(tester, IndexedItem(1, {'id': '1b'}));
      expect(find.text('Brake hose leak', findRichText: true), findsOne);
    });

    testWidgets('reads the first item when built without item data', (
      tester,
    ) async {
      await pumpItem(tester, IndexedItem(1, null));
      expect(find.text('Tread worn', findRichText: true), findsOne);
      await pumpItem(tester, null);
      expect(find.text('Tread worn', findRichText: true), findsOne);
    });
  });
}
