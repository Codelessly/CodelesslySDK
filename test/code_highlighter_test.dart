import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The highlighted pieces of [code] as `kind:text`, in order.
List<String> tokensOf(String code, SyntaxLanguage language) => [
  for (final CodeToken token in CodeHighlighter.highlight(code, language))
    '${token.kind.name}:${code.substring(token.start, token.end)}',
];

/// The kind of the first token whose text is [text].
String? kindOf(String code, SyntaxLanguage language, String text) {
  for (final String token in tokensOf(code, language)) {
    final int colon = token.indexOf(':');
    if (token.substring(colon + 1) == text) return token.substring(0, colon);
  }
  return null;
}

void main() {
  group('CodeHighlighter', () {
    test('bash: prompt, command, flags, strings, variables, comments', () {
      const String code =
          '\$ curl -X POST https://api.hookline.dev/v1/events \\\n'
          '  -H "Authorization: Bearer \$TOKEN" \\\n'
          '  --data \'{"type": "ping"}\' # send one\n'
          'export KEY=\$HOOKLINE_KEY && npm install hookline';
      expect(kindOf(code, SyntaxLanguage.bash, r'$'), 'punctuation');
      expect(kindOf(code, SyntaxLanguage.bash, 'curl'), 'function');
      expect(kindOf(code, SyntaxLanguage.bash, '-X'), 'property');
      expect(kindOf(code, SyntaxLanguage.bash, '--data'), 'property');
      expect(kindOf(code, SyntaxLanguage.bash, 'POST'), isNull);
      expect(
        kindOf(code, SyntaxLanguage.bash, '"Authorization: Bearer \$TOKEN"'),
        'string',
      );
      expect(kindOf(code, SyntaxLanguage.bash, '# send one'), 'comment');
      expect(kindOf(code, SyntaxLanguage.bash, 'export'), 'keyword');
      expect(kindOf(code, SyntaxLanguage.bash, r'$HOOKLINE_KEY'), 'property');
      expect(kindOf(code, SyntaxLanguage.bash, 'npm'), 'function');
      expect(kindOf(code, SyntaxLanguage.bash, 'install'), isNull);
      // A continued line doesn't start a command.
      expect(kindOf(code, SyntaxLanguage.shell, '-H'), 'property');
    });

    test('javascript: keywords, template strings, calls, properties', () {
      const String code =
          "import { Hookline } from 'hookline';\n"
          '// Create a client\n'
          'const client = new Hookline({ apiKey: process.env.KEY });\n'
          r'await client.events.send(`order.${id}`, { retries: 3 });'
          '\n'
          '/* done */';
      final List<String> tokens = tokensOf(code, SyntaxLanguage.javascript);
      expect(tokens, contains('keyword:import'));
      expect(tokens, contains("string:'hookline'"));
      expect(tokens, contains('comment:// Create a client'));
      expect(tokens, contains('keyword:const'));
      expect(tokens, contains('function:Hookline'));
      expect(tokens, contains('property:apiKey'));
      expect(tokens, contains('type:process'));
      expect(tokens, contains('property:events'));
      expect(tokens, contains('function:send'));
      expect(tokens, contains(r'string:`order.${id}`'));
      expect(tokens, contains('number:3'));
      expect(tokens, contains('comment:/* done */'));
    });

    test('typescript: types and interfaces', () {
      const String code =
          'interface Event { id: string; at: number }\n'
          'type Handler = (e: Event) => Promise<void>;';
      expect(kindOf(code, SyntaxLanguage.typescript, 'interface'), 'keyword');
      expect(kindOf(code, SyntaxLanguage.typescript, 'string'), 'type');
      expect(kindOf(code, SyntaxLanguage.typescript, 'Event'), 'type');
      expect(kindOf(code, SyntaxLanguage.typescript, 'Promise'), 'type');
    });

    test('python: triple-quoted strings, decorators, defs, builtins', () {
      const String code =
          '@app.route("/hooks")\n'
          'def handle(request):\n'
          '    """Verify and store."""\n'
          '    sig = request.headers["X-Hookline-Signature"]  # header\n'
          '    print(f"got {sig}", len(sig) > 0, None)\n';
      expect(kindOf(code, SyntaxLanguage.python, '@app.route'), 'type');
      expect(kindOf(code, SyntaxLanguage.python, 'def'), 'keyword');
      expect(kindOf(code, SyntaxLanguage.python, 'handle'), 'function');
      expect(
        kindOf(code, SyntaxLanguage.python, '"""Verify and store."""'),
        'string',
      );
      expect(kindOf(code, SyntaxLanguage.python, '# header'), 'comment');
      expect(kindOf(code, SyntaxLanguage.python, 'f"got {sig}"'), 'string');
      expect(kindOf(code, SyntaxLanguage.python, 'print'), 'function');
      expect(kindOf(code, SyntaxLanguage.python, 'headers'), 'property');
      expect(kindOf(code, SyntaxLanguage.python, 'None'), 'keyword');
    });

    test('go: raw strings, funcs and builtin types', () {
      const String code =
          'func main() {\n'
          '  var n int64 = 0x1F\n'
          '  body := `{"ok": true}`\n'
          '  fmt.Println(body, n)\n'
          '}';
      expect(kindOf(code, SyntaxLanguage.go, 'func'), 'keyword');
      expect(kindOf(code, SyntaxLanguage.go, 'main'), 'function');
      expect(kindOf(code, SyntaxLanguage.go, 'int64'), 'type');
      expect(kindOf(code, SyntaxLanguage.go, '0x1F'), 'number');
      expect(kindOf(code, SyntaxLanguage.go, '`{"ok": true}`'), 'string');
      expect(kindOf(code, SyntaxLanguage.go, 'Println'), 'function');
    });

    test('ruby: symbols, instance variables, hash keys', () {
      const String code =
          "require 'hookline'\n"
          'client = Hookline::Client.new(api_key: @key)\n'
          'client.send(:ping) do |r| puts r end';
      expect(kindOf(code, SyntaxLanguage.ruby, 'require'), 'type');
      expect(kindOf(code, SyntaxLanguage.ruby, "'hookline'"), 'string');
      expect(kindOf(code, SyntaxLanguage.ruby, 'Hookline'), 'type');
      expect(kindOf(code, SyntaxLanguage.ruby, 'api_key'), 'property');
      expect(kindOf(code, SyntaxLanguage.ruby, '@key'), 'property');
      expect(kindOf(code, SyntaxLanguage.ruby, ':ping'), 'string');
      expect(kindOf(code, SyntaxLanguage.ruby, 'do'), 'keyword');
      expect(kindOf(code, SyntaxLanguage.ruby, 'end'), 'keyword');
    });

    test('json: keys, strings, numbers, literals', () {
      const String code =
          '{\n  "id": "evt_1", "attempts": 2, "ok": true, "x": null }';
      expect(tokensOf(code, SyntaxLanguage.json), [
        'punctuation:{',
        'property:"id"',
        'punctuation::',
        'string:"evt_1"',
        'punctuation:,',
        'property:"attempts"',
        'punctuation::',
        'number:2',
        'punctuation:,',
        'property:"ok"',
        'punctuation::',
        'keyword:true',
        'punctuation:,',
        'property:"x"',
        'punctuation::',
        'keyword:null',
        'punctuation:}',
      ]);
    });

    test('plain text and unterminated code never fail', () {
      expect(tokensOf('const x = 1', SyntaxLanguage.none), isEmpty);
      for (final SyntaxLanguage language in SyntaxLanguage.values) {
        for (final String code in [
          '"unterminated',
          '/* open',
          '`tick',
          '"""doc',
          r'${',
          '',
          '#',
          r'$',
        ]) {
          expect(
            () => CodeHighlighter.highlight(code, language),
            returnsNormally,
          );
        }
      }
    });

    test('spans keep their styles and split at token edges', () {
      const TextStyle base = TextStyle(fontSize: 14, color: Colors.white);
      final List<InlineSpan> spans = CodeHighlighter.highlightSpans(
        const [
          TextSpan(text: 'const a', style: base),
          TextSpan(text: ' = "x";', style: base),
        ],
        SyntaxLanguage.javascript,
        theme: CodeThemeModel(keyword: ColorRGBA.fromHex('#FF0000')),
      );
      final List<TextSpan> leaves = [];
      void collect(InlineSpan span) {
        if (span is TextSpan) {
          if (span.text != null) leaves.add(span);
          span.children?.forEach(collect);
        }
      }

      spans.forEach(collect);
      expect(leaves.map((s) => s.text).join(), 'const a = "x";');
      final TextSpan keyword = leaves.firstWhere((s) => s.text == 'const');
      expect(keyword.style!.color, const Color(0xFFFF0000));
      final TextSpan plain = leaves.firstWhere((s) => s.text == ' a');
      expect(plain.style, isNull);
      final TextSpan string = leaves.firstWhere((s) => s.text == '"x"');
      expect(
        string.style!.color,
        CodeThemeModel.defaults.string!.toFlutterColor(),
      );
      expect((spans.first as TextSpan).style, base);
    });
  });

  group('Text nodes', () {
    TextNode code({
      SyntaxLanguage language = SyntaxLanguage.none,
      Map<String, String> variables = const {},
    }) =>
        TextNode(
            id: 'code',
            name: 'code',
            basicBoxLocal: NodeBox(0, 0, 400, 40),
            data: 'def hi(): return 1',
            codeLanguage: language,
            textMixedProps: [
              StartEndProp.general().copyWith(start: 0, end: 18),
            ],
          )
          ..parentID = kRootNode
          ..variables = Map.of(variables);

    Future<void> pumpText(
      WidgetTester tester,
      TextNode node, {
      String language = 'python',
    }) async {
      final registry = NodeRegistry()..setNodes({node.id: node});
      final manager = PassiveNodeTransformerManager(
        registry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
      final codelesslyContext = CodelesslyContext.empty();
      codelesslyContext.variables['lang'] = Observable(
        VariableData(
          id: 'lang',
          name: 'lang',
          type: VariableType.text,
          value: language,
        ),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: codelesslyContext,
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

    /// The color of the drawn text's piece [text].
    Color? colorOf(WidgetTester tester, String text) {
      final RichText rich = tester.widget<RichText>(
        find.byType(RichText).first,
      );
      Color? found;
      rich.text.visitChildren((span) {
        if (span is TextSpan && span.text == text) {
          found = span.style?.color;
          return false;
        }
        return true;
      });
      return found;
    }

    testWidgets('are highlighted in their language', (tester) async {
      await pumpText(tester, code(language: SyntaxLanguage.python));
      expect(colorOf(tester, 'def'), const Color(0xFFFF7B72));
      expect(colorOf(tester, 'hi'), const Color(0xFFD2A8FF));
      expect(colorOf(tester, '1'), const Color(0xFF79C0FF));
    });

    testWidgets('plain text is not split', (tester) async {
      await pumpText(tester, code());
      expect(colorOf(tester, 'def'), isNull);
      expect(colorOf(tester, 'def hi(): return 1'), Colors.white);
    });

    testWidgets('the language can be bound', (tester) async {
      await pumpText(
        tester,
        code(variables: {'codeLanguage': r'${lang}'}),
        language: 'py',
      );
      expect(colorOf(tester, 'def'), const Color(0xFFFF7B72));
    });
  });
}
