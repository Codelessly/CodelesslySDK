import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Hookline Home code blocks showed one word ("Send", "Verify") in
/// place of their code: the Node.js samples hold a template string,
/// `inv_${invoice.id}`, and the text the formula gave was read again as
/// text with variables. The canvas took the `${` in the value for an
/// unresolved variable and showed the placeholder named after the formula's
/// first path (`code.samples.send` -> "Send"); a running app substituted
/// `${invoice.id}` away.
void main() {
  final Map<String, dynamic> fixture =
      jsonDecode(
            File('test/fixtures/hookline_code_block.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final Map<String, dynamic> nodes = fixture['nodes'] as Map<String, dynamic>;
  final TextNode code = TextNode.fromJson(
    nodes['0SgHhHARA747bKYQqK0i'] as Map<String, dynamic>,
  );
  final TextNode lineNumbers = TextNode.fromJson(
    nodes['0SgHhHARpYbgWDXhh_f9'] as Map<String, dynamic>,
  );
  final Map<String, dynamic> codeData = fixture['code'] as Map<String, dynamic>;
  final String sample =
      (codeData['samples'] as Map)['send']['node']['code'] as String;

  final List<VariableData> variables = [
    VariableData(
      id: 'code',
      name: 'code',
      type: VariableType.map,
      value: codeData,
    ),
    VariableData(id: 'lang', name: 'lang', value: 'node'),
    VariableData(
      id: 'langInfo',
      name: 'bot_langInfo',
      type: VariableType.map,
      value: {'id': 'node', 'label': 'Node.js', 'highlighter': 'js'},
    ),
  ];

  tearDown(() => VariablePreview.scopeResolver = null);

  test('the sample holds a template string', () {
    expect(sample, contains(r'`inv_${invoice.id}`'));
    expect(code.data, r'${= code.samples.send[lang].code}');
  });

  Future<String> render(
    WidgetTester tester,
    TextNode node, {
    required bool canvas,
  }) async {
    late Text text;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            text = TextUtils.buildTextForTextNode(
              context,
              node,
              variablesOverrides: variables,
              nullSubstitutionMode: NullSubstitutionMode.emptyString,
              replaceVariablesWithSymbol: canvas,
            );
            return text;
          },
        ),
      ),
    );
    return text.textSpan!.toPlainText();
  }

  testWidgets('a running app shows the whole sample, highlighted', (
    tester,
  ) async {
    expect(await render(tester, code, canvas: false), sample);
    expect(
      await render(tester, lineNumbers, canvas: false),
      List.generate(14, (i) => '${i + 1}').join('\n'),
    );
    // Highlighted as JavaScript (bound codeLanguage), so it is split into
    // colored pieces.
    expect(
      TextUtils.codeLanguageOf(
        tester.element(find.byType(Text)),
        code,
        variables,
      ),
      SyntaxLanguage.javascript,
    );
  });

  testWidgets('the design canvas shows the whole sample', (tester) async {
    VariablePreview.scopeResolver = (_) =>
        ScopedValues.preview(variables: {for (final v in variables) v.name: v});
    expect(await render(tester, code, canvas: true), sample);
    expect(
      VariablePreview.textFor(r'${= code.samples.verify[lang].code}'),
      contains(r'${'),
    );
  });

  test('values holding \${...} are not substituted again', () {
    final ScopedValues values = ScopedValues.preview(
      variables: {
        'tpl': VariableData(id: 't', name: 'tpl', value: r'Hi ${name}!'),
        'name': VariableData(id: 'n', name: 'name', value: 'Ray'),
      },
    );
    String sub(String text) => PropertyValueDelegate.substituteVariables(
      text,
      scopedValues: values,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
    );
    expect(sub(r'${tpl}'), r'Hi ${name}!');
    expect(sub(r'${= tpl}'), r'Hi ${name}!');
    expect(sub(r'${name}: ${tpl}'), r'Ray: Hi ${name}!');
    expect(sub(r'\${name} ${name}'), r'\${name} Ray');
  });

  group('paths indexed by a value', () {
    final ScopedValues values = ScopedValues.preview(
      variables: {
        for (final v in variables) v.name: v,
        'plans': VariableData(
          id: 'p',
          name: 'plans',
          type: VariableType.list,
          value: [
            {'name': 'Free'},
            {'name': 'Pro'},
          ],
        ),
        'pick': VariableData(
          id: 'k',
          name: 'pick',
          type: VariableType.integer,
          value: 1,
        ),
      },
    );
    String sub(String text) => PropertyValueDelegate.substituteVariables(
      text,
      scopedValues: values,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
    );

    test(r'${a[b].c} reads like ${= a[b].c}', () {
      expect(sub(r'${code.samples.send[lang].filename}'), 'send.mjs');
      expect(sub(r'File: ${code.samples.send[lang].filename}!'), 'File: send.mjs!');
      expect(sub(r'${plans[pick].name}'), 'Pro');
      expect(sub(r'${plans[0].name}'), 'Free');
      expect(
        PropertyValueDelegate.getVariableValueFromPath<Object>(
          r'${plans[pick]}',
          scopedValues: values,
        ),
        {'name': 'Pro'},
      );
    });

    test('a missing value follows the null mode', () {
      expect(sub(r'[${plans[pick].missing}]'), '[]');
      expect(
        PropertyValueDelegate.substituteVariables(
          r'${plans[pick].missing}',
          scopedValues: values,
          nullSubstitutionMode: NullSubstitutionMode.noChange,
        ),
        r'${plans[pick].missing}',
      );
    });

    test('only path-shaped text counts', () {
      expect(PropertyValueDelegate.indexedPathExpression(r'${a[b].c}'), 'a[b].c');
      expect(PropertyValueDelegate.indexedPathExpression('a[0].c'), isNull);
      expect(PropertyValueDelegate.indexedPathExpression('a.b'), isNull);
      expect(PropertyValueDelegate.indexedPathExpression('a + b[c]'), isNull);
      expect(sub(r'${not a path}'), r'${not a path}');
    });
  });
}
