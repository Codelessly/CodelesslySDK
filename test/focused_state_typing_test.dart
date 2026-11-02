import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  // The Spellbop Welcome name field, as stored: a rounded box whose focused
  // state adds a spread-shadow ring, around a text field bound to a variable
  // its `changed` actions set.
  testWidgets('typing into a rounded box whose focus ring comes and goes', (
    tester,
  ) async {
    final Map json = jsonDecode(
      File('test/fixtures/welcome_name_field.json').readAsStringSync(),
    );
    final BaseNode box = NodeJsonConverter.instance.fromJson(
      Map<String, dynamic>.from(json['box']),
    )!..parentID = kRootNode;
    final BaseNode field = NodeJsonConverter.instance.fromJson(
      Map<String, dynamic>.from(json['field']),
    )!..parentID = box.id;
    const Map<String, String> ids = {
      'nameDraft': '0Sg1Zll1Xvm44i0nEXtq',
      'touched': '0Sg1Zll1WHlxLmLanzU5',
    };
    void add(CodelesslyContext context, String name, Object value) {
      final String id = ids[name] ?? name;
      context.variables[id] = Observable(
        VariableData(id: id, name: name, value: value),
      );
    }

    final CodelesslyContext codelesslyContext = CodelesslyContext.empty();
    add(codelesslyContext, 'nameDraft', '');
    add(codelesslyContext, 'touched', false);
    add(codelesslyContext, 'nameError', '');
    add(codelesslyContext, 'shakeCount', 0);
    final registry = NodeRegistry()..setNodes({box.id: box, field.id: field});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 318,
                child: Builder(
                  builder: (context) => manager.buildWidgetFromNode(
                    box,
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

    EditableTextState editable() => tester.state(find.byType(EditableText));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(
      editable().widget.focusNode.hasFocus,
      isTrue,
      reason: 'the focus ring rebuilt the field and dropped its focus',
    );
    final State first = editable();
    for (final String text in <String>['m', 'ma', 'mar', 'mary']) {
      tester.testTextInput.enterText(text);
      await tester.pumpAndSettle();
      expect(editable(), same(first), reason: 'rebuilt after "$text"');
    }
    expect(editable().textEditingValue.text, 'mary');
    expect(editable().widget.focusNode.hasFocus, isTrue);
    expect(codelesslyContext.variables[ids['nameDraft']]!.value.value, 'mary');
  });
}
