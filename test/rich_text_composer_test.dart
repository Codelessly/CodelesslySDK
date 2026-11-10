import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// A text field that works as a rich text reply composer: live Markdown,
/// Edit Text actions from a toolbar, Key Down shortcuts on the field and the
/// cursor in its triggers' `${result}`.

TextEditingValue at(String text, int start, [int? end]) => TextEditingValue(
  text: text,
  selection: TextSelection(baseOffset: start, extentOffset: end ?? start),
);

Observable<VariableData> variable(String name, [Object value = '']) =>
    Observable(VariableData(id: name, name: name, value: value));

Reaction setVariable(
  String name,
  String value,
  TriggerModel trigger, {
  VariableType type = VariableType.text,
}) => Reaction(
  action: SetVariableAction(
    variable: VariableData(id: name, name: name, type: type),
    newValue: value,
  ),
  trigger: trigger,
);

class Composer {
  Composer(this.tester, this.codelesslyContext);

  final WidgetTester tester;
  final CodelesslyContext codelesslyContext;
  late BuildContext buttonContext;

  Object? valueOf(String name) =>
      codelesslyContext.variables[name]!.value.value;

  Future<void> run(EditTextAction action) async {
    FunctionsRepository.performAction(buttonContext, action);
    await tester.pumpAndSettle();
  }

  TextEditingController get controller =>
      tester.widget<EditableText>(find.byType(EditableText)).controller;

  FocusNode get focusNode =>
      tester.widget<EditableText>(find.byType(EditableText)).focusNode;
}

/// Pumps a text field `composer` bound to `draft`, with [reactions], and a
/// button-like context to run actions from.
Future<Composer> pumpComposer(
  WidgetTester tester, {
  List<Reaction> reactions = const [],
  MarkdownStyle? markdown,
  int? maxLines,
  Map<String, Object> variables = const {},
}) async {
  final TextFieldNode node = TextFieldNode(
    id: 'composer',
    name: 'Composer',
    basicBoxLocal: NodeBox(0, 0, 300, 120),
    properties: TextFieldProperties(markdown: markdown, maxLines: maxLines),
    reactions: [...reactions],
  )..variables['inputValue'] = r'${draft}';
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  final CodelesslyContext codelesslyContext = CodelesslyContext.empty();
  for (final MapEntry(:key, :value) in {
    'draft': '',
    'last': '',
    ...variables,
  }.entries) {
    codelesslyContext.variables[key] = variable(key, value);
  }
  final Composer composer = Composer(tester, codelesslyContext);
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext,
      child: MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                width: 300,
                height: 120,
                child: Builder(
                  builder: (context) => manager.buildWidgetFromNode(
                    node,
                    context,
                    settings: const WidgetBuildSettings(debugLabel: 'test'),
                  ),
                ),
              ),
              Builder(
                builder: (context) {
                  composer.buttonContext = context;
                  return const SizedBox(width: 40, height: 40);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return composer;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('TextEdits', () {
    test('wrap wraps the selection or inserts an empty pair', () {
      final TextEditingValue wrapped = TextEdits.wrap(
        at('make it bold', 8, 12),
        '**',
        '**',
      );
      expect(wrapped.text, 'make it **bold**');
      expect(
        wrapped.selection,
        const TextSelection(baseOffset: 10, extentOffset: 14),
      );
      final TextEditingValue pair = TextEdits.wrap(at('code ', 5), '`', '`');
      expect(pair.text, 'code ``');
      expect(pair.selection, const TextSelection.collapsed(offset: 6));
      final TextEditingValue link = TextEdits.wrap(
        at('see docs', 4, 8),
        '[',
        '](https://)',
      );
      expect(link.text, 'see [docs](https://)');
    });

    test('toggleList turns the selected lines into a list and back', () {
      final TextEditingValue bullets = TextEdits.toggleList(
        at('intro\none\ntwo', 7, 12),
      );
      expect(bullets.text, 'intro\n- one\n- two');
      expect(bullets.selection, const TextSelection.collapsed(offset: 17));
      expect(
        TextEdits.toggleList(at(bullets.text, 8, 15)).text,
        'intro\none\ntwo',
      );
      expect(
        TextEdits.toggleList(at('one\ntwo', 0, 7), numbered: true).text,
        '1. one\n2. two',
      );
      expect(
        TextEdits.toggleList(at('- one\n- two', 0, 11), numbered: true).text,
        '1. one\n2. two',
      );
      expect(TextEdits.toggleList(at('', 0)).text, '- ');
    });

    test('insert adds a space after a word', () {
      final TextEditingValue mention = TextEdits.insert(at('Hi', 2), '@');
      expect(mention.text, 'Hi @');
      expect(mention.selection, const TextSelection.collapsed(offset: 4));
      expect(TextEdits.insert(at('Hi ', 3), '/').text, 'Hi /');
      expect(TextEdits.insert(at('', 0), '@').text, '@');
      expect(TextEdits.insert(at('a b', 0, 3), 'c').text, 'c');
    });

    test('replaceWord replaces the word ending at the cursor', () {
      final TextEditingValue picked = TextEdits.replaceWord(
        at('Thanks @ma for this', 10),
        '@maya ',
      );
      expect(picked.text, 'Thanks @maya  for this');
      expect(picked.selection, const TextSelection.collapsed(offset: 13));
      expect(
        TextEdits.replaceWord(at('/ref', 4), 'Refund issued.').text,
        'Refund issued.',
      );
    });

    test('continueList continues a list and ends it on an empty item', () {
      final TextEditingValue? next = TextEdits.continueList(at('- one', 5));
      expect(next!.text, '- one\n- ');
      expect(next.selection, const TextSelection.collapsed(offset: 8));
      expect(TextEdits.continueList(at('1. one', 6))!.text, '1. one\n2. ');
      final TextEditingValue? end = TextEdits.continueList(at('- one\n- ', 8));
      expect(end!.text, '- one\n');
      expect(end.selection, const TextSelection.collapsed(offset: 6));
      expect(TextEdits.continueList(at('plain', 5)), isNull);
      expect(TextEdits.continueList(at('- one', 0, 5)), isNull);
    });

    test('resultOf gives the word at the cursor and the selection', () {
      expect(TextEdits.resultOf(at('Hi @ma', 6)), {
        'value': 'Hi @ma',
        'word': '@ma',
        'cursor': 6,
        'selectionStart': 6,
        'selectionEnd': 6,
      });
      expect(TextEdits.resultOf(at('Hi there', 0, 2))['word'], '');
      expect(
        TextEdits.resultOf(const TextEditingValue(text: 'end'))['cursor'],
        3,
      );
    });
  });

  test('key triggers match combinations and their when', () {
    final ScopedValues scoped = ScopedValues.preview(
      variables: {
        'open': VariableData(
          id: 'open',
          name: 'open',
          type: VariableType.boolean,
          value: true,
        ),
      },
    );
    expect(
      triggerWhenHolds(
        TriggerModel(type: TriggerType.keyDown, when: r'${= open}'),
        scoped,
      ),
      isTrue,
    );
    expect(
      triggerWhenHolds(
        TriggerModel(type: TriggerType.keyDown, when: r'${= !open}'),
        scoped,
      ),
      isFalse,
    );
    expect(
      triggerWhenHolds(TriggerModel(type: TriggerType.keyDown), scoped),
      isTrue,
    );
  });

  testWidgets('a markdown field shows its text as live markdown', (
    tester,
  ) async {
    final Composer composer = await pumpComposer(
      tester,
      markdown: const MarkdownStyle(),
      maxLines: 5,
    );
    await tester.enterText(find.byType(TextField), 'a **bold** move');
    await tester.pump();
    final controller = composer.controller as MarkdownTextEditingController;
    final TextSpan span = controller.buildTextSpan(
      context: tester.element(find.byType(EditableText)),
      style: const TextStyle(fontSize: 14, color: Color(0xFF000000)),
      withComposing: false,
    );
    expect(span.toPlainText(), 'a **bold** move');
    final List<TextSpan> parts = span.children!.cast<TextSpan>();
    expect(
      parts.firstWhere((s) => s.text == 'bold').style!.fontWeight,
      FontWeight.w700,
    );
    expect(
      parts.firstWhere((s) => s.text == '**').style!.color!.a,
      lessThan(1),
    );
  });

  testWidgets('changed reactions read the word at the cursor', (tester) async {
    final Composer composer = await pumpComposer(
      tester,
      reactions: [
        setVariable(
          'last',
          r'${result.word}|${result.cursor}|${result.value}',
          TriggerModel(type: TriggerType.changed),
        ),
      ],
    );
    await tester.enterText(find.byType(TextField), 'Hi @ma');
    await tester.pumpAndSettle();
    expect(composer.valueOf('last'), '@ma|6|Hi @ma');
    expect(composer.valueOf('draft'), 'Hi @ma');
  });

  testWidgets('key down reactions on the field run for their combination '
      'while their when holds', (tester) async {
    final Composer composer = await pumpComposer(
      tester,
      markdown: const MarkdownStyle(),
      maxLines: 5,
      variables: {'menuOpen': false, 'picked': '', 'sent': ''},
      reactions: [
        setVariable(
          'sent',
          r'${result.value}',
          TriggerModel(type: TriggerType.keyDown, key: 'Meta+Enter'),
        ),
        setVariable(
          'picked',
          r'${result.word}',
          TriggerModel(
            type: TriggerType.keyDown,
            key: 'Enter',
            when: r'${= menuOpen}',
          ),
        ),
      ],
    );
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '- one');
    await tester.pump();

    // No reaction takes Enter: the list continues.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(composer.controller.text, '- one\n- ');
    expect(composer.valueOf('draft'), '- one\n- ');
    expect(composer.valueOf('picked'), '');
    // Enter on the empty item ends the list.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(composer.controller.text, '- one\n');

    // While the menu is open, Enter picks instead.
    composer.codelesslyContext.variables['menuOpen']!.value = composer
        .codelesslyContext
        .variables['menuOpen']!
        .value
        .copyWith(value: true);
    await tester.enterText(find.byType(TextField), '- hi @ma');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(composer.valueOf('picked'), '@ma');
    expect(composer.controller.text, '- hi @ma');

    // Meta+Enter (Control off macOS) sends.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(composer.valueOf('sent'), '- hi @ma');
    expect(composer.controller.text, '- hi @ma');
  });

  testWidgets('edit text actions edit the field at its cursor like typing', (
    tester,
  ) async {
    final Composer composer = await pumpComposer(
      tester,
      maxLines: 5,
      variables: {'handle': 'maya', 'changes': 0},
      reactions: [
        setVariable(
          'last',
          r'${result.value}',
          TriggerModel(type: TriggerType.changed),
        ),
      ],
    );
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'make it bold');
    composer.controller.selection = const TextSelection(
      baseOffset: 8,
      extentOffset: 12,
    );
    await tester.pump();
    // A toolbar button takes the focus first.
    composer.focusNode.unfocus();
    await tester.pump();
    expect(composer.focusNode.hasFocus, isFalse);

    await composer.run(
      EditTextAction(
        nodeId: 'composer',
        operation: EditTextOperation.wrap,
        before: '**',
      ),
    );
    expect(composer.controller.text, 'make it **bold**');
    expect(
      composer.controller.selection,
      const TextSelection(baseOffset: 10, extentOffset: 14),
    );
    expect(composer.focusNode.hasFocus, isTrue);
    expect(composer.valueOf('draft'), 'make it **bold**');
    expect(composer.valueOf('last'), 'make it **bold**');

    composer.controller.selection = const TextSelection.collapsed(offset: 16);
    await composer.run(EditTextAction(nodeId: 'composer', text: '@'));
    expect(composer.controller.text, 'make it **bold** @');

    await composer.run(
      EditTextAction(
        nodeId: 'composer',
        operation: EditTextOperation.replaceWord,
        text: r'@${handle} ',
      ),
    );
    expect(composer.controller.text, 'make it **bold** @maya ');
    expect(
      composer.controller.selection,
      const TextSelection.collapsed(offset: 23),
    );

    await composer.run(
      EditTextAction(
        nodeId: 'composer',
        operation: EditTextOperation.toggleList,
        numbered: true,
      ),
    );
    expect(composer.controller.text, '1. make it **bold** @maya ');

    composer.focusNode.unfocus();
    await tester.pump();
    await composer.run(
      EditTextAction(nodeId: 'composer', operation: EditTextOperation.clear),
    );
    expect(composer.controller.text, '');
    expect(composer.valueOf('draft'), '');
    expect(composer.valueOf('last'), '');
    expect(composer.focusNode.hasFocus, isFalse);

    await composer.run(
      EditTextAction(nodeId: 'composer', operation: EditTextOperation.focus),
    );
    expect(composer.focusNode.hasFocus, isTrue);

    await composer.run(
      EditTextAction(
        nodeId: 'composer',
        operation: EditTextOperation.setText,
        text: r'Hi ${handle}',
      ),
    );
    expect(composer.controller.text, 'Hi maya');
    expect(composer.valueOf('draft'), 'Hi maya');
  });

  testWidgets('an edit text action for a missing field does nothing', (
    tester,
  ) async {
    final Composer composer = await pumpComposer(tester);
    expect(
      FunctionsRepository.editText(
        composer.buttonContext,
        EditTextAction(nodeId: 'nope', text: 'x'),
      ),
      isFalse,
    );
  });
}
