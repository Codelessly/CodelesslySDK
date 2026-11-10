import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

TextFieldNode field({
  TextCapitalizationC capitalization = TextCapitalizationC.none,
  Map<String, String> variables = const {},
}) {
  final node = TextFieldNode(
    id: 'ref',
    name: 'Booking reference',
    basicBoxLocal: NodeBox(0, 0, 240, 48),
    properties: TextFieldProperties(
      textCapitalization: capitalization,
      decoration: InputDecorationModel(hintText: 'e.g. MX4821'),
    ),
  );
  node.variables.addAll(variables);
  return node;
}

Future<void> pumpField(
  WidgetTester tester,
  TextFieldNode node, {
  Map<String, Object?> values = const {},
}) => tester.pumpWidget(
  ChangeNotifierProvider<CodelesslyContext>(
    create: (_) => CodelesslyContext.empty(),
    child: MaterialApp(
      home: Material(
        child: PassiveTextFieldWidget(
          node: node,
          settings: const WidgetBuildSettings(debugLabel: 'test'),
          scopedValues: ScopedValues.preview(
            variables: {
              for (final MapEntry(:key, :value) in values.entries)
                key: VariableData(id: key, name: key, value: value),
            },
          ),
        ),
      ),
    ),
  ),
);

TextEditingValue format(String oldText, String newText, {int? caret}) =>
    const UpperCaseTextInputFormatter().formatEditUpdate(
      TextEditingValue(text: oldText),
      TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: caret ?? newText.length),
      ),
    );

void main() {
  group('upper case input', () {
    test('the formatter upper-cases and keeps the caret', () {
      expect(format('MX', 'MX4a').text, 'MX4A');
      final TextEditingValue mid = format('MX21', 'MxX21', caret: 2);
      expect(mid.text, 'MXX21');
      expect(mid.selection.baseOffset, 2);
      final TextEditingValue same = format('', 'AB');
      expect(same.text, 'AB');
      expect(format('', 'gate b12 · é').text, 'GATE B12 · É');
    });

    testWidgets('typing into a characters field gives capitals', (
      tester,
    ) async {
      await pumpField(
        tester,
        field(capitalization: TextCapitalizationC.characters),
      );
      await tester.enterText(find.byType(EditableText), 'mx4821');
      await tester.pump();
      final EditableText editable = tester.widget(find.byType(EditableText));
      expect(editable.controller.text, 'MX4821');
      expect(editable.textCapitalization, TextCapitalization.characters);
    });

    testWidgets('other capitalizations only hint the keyboard', (tester) async {
      await pumpField(tester, field(capitalization: TextCapitalizationC.words));
      await tester.enterText(find.byType(EditableText), 'new york');
      await tester.pump();
      final EditableText editable = tester.widget(find.byType(EditableText));
      expect(editable.controller.text, 'new york');
      expect(editable.textCapitalization, TextCapitalization.words);
    });

    test('textCapitalization survives JSON and defaults to none', () {
      final TextFieldProperties properties = TextFieldProperties(
        textCapitalization: TextCapitalizationC.characters,
      );
      final Map json = properties.toJson();
      expect(json['textCapitalization'], 'characters');
      expect(
        TextFieldProperties.fromJson(json).textCapitalization,
        TextCapitalizationC.characters,
      );
      expect(
        TextFieldProperties().toJson().containsKey('textCapitalization'),
        isFalse,
      );
      expect(
        TextFieldProperties.fromJson({'textCapitalization': 'shouting'})
            .textCapitalization,
        TextCapitalizationC.none,
      );
    });
  });

  group('bound colours', () {
    testWidgets('inputColor, hintColor and cursorColor follow variables', (
      tester,
    ) async {
      await pumpField(
        tester,
        field(
          variables: {
            'inputColor': r'${ink}',
            'hintColor': r"${= dark ? '#8A8F98' : '#B0A898'}",
            'cursorColor': r'${accent}',
          },
        ),
        values: {'ink': '#F4EFE6', 'dark': true, 'accent': '#D9A441'},
      );
      final EditableText editable = tester.widget(find.byType(EditableText));
      expect(editable.style.color, const Color(0xFFF4EFE6));
      expect(editable.cursorColor, const Color(0xFFD9A441));
      final Text hint = tester.widget(find.text('e.g. MX4821'));
      expect(hint.style?.color, const Color(0xFF8A8F98));
    });

    testWidgets('without bindings the styles keep their own colours', (
      tester,
    ) async {
      await pumpField(tester, field());
      final EditableText editable = tester.widget(find.byType(EditableText));
      expect(editable.style.color, const Color(0xFF000000));
      final Text hint = tester.widget(find.text('e.g. MX4821'));
      expect(hint.style?.color, isNot(const Color(0xFF8A8F98)));
    });

    testWidgets('a binding that is not a colour is ignored', (tester) async {
      await pumpField(
        tester,
        field(variables: {'inputColor': r'${ink}'}),
        values: {'ink': 'not a colour'},
      );
      final EditableText editable = tester.widget(find.byType(EditableText));
      expect(editable.style.color, const Color(0xFF000000));
    });
  });
}
