import 'dart:convert';
import 'dart:io';

import 'package:codelessly_genui/codelessly_genui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('catalog document', () {
    test('the published catalog JSON is up to date', () {
      final String published = File(
        'catalog/codelessly_genui_catalog.json',
      ).readAsStringSync();
      expect(
        jsonDecode(published),
        jsonDecode(jsonEncode(buildGenUiCatalogJson())),
        reason: 'Run dart run tool/generate_catalog.dart',
      );
    });

    test('parses as an A2UI v0.9 catalog with the basic and extension names', () {
      final api = genUiCatalogApi();
      expect(api.id, kGenUiCatalogId);
      expect(api.components.keys, containsAll(kGenUiBasicComponents));
      expect(api.components.keys, containsAll(kGenUiExtensionComponents));
      expect(api.functions.keys, containsAll(['formatString', 'formatNumber', 'calc']));
      // Media that loads from the network is not in the chat catalog.
      expect(api.components.keys, isNot(contains('Video')));
      expect(api.components.keys, isNot(contains('AudioPlayer')));
    });

    test('every extension is in the Codelessly namespace', () {
      for (final name in kGenUiExtensionComponents) {
        expect(name, startsWith('Codelessly'));
      }
    });

    test('every catalog component has a renderer', () {
      final impl = genUiCatalog();
      expect(
        impl.components.keys.toSet(),
        genUiCatalogApi().components.keys.toSet(),
      );
    });

    test('commit inputs accept an action, other basic schemas are unchanged', () {
      final Map<String, Object?> catalog = buildGenUiCatalogJson();
      final Map components = catalog['components']! as Map;
      expect(jsonEncode(components['Slider']), contains('"action"'));
      expect(jsonEncode(components['Slider']), contains('"step"'));
      expect(jsonEncode(components['CheckBox']), contains('"action"'));
      expect(jsonEncode(components['Text']), isNot(contains('Codelessly extension')));
    });

    test('the system prompt carries the catalog and the protocol', () {
      final String prompt = genUiSystemPrompt();
      expect(prompt, contains(kGenUiCatalogId));
      expect(prompt, contains('"version":"v0.9.1"'));
      expect(prompt, contains('CodelesslyVisualization'));
      expect(renderToolInputSchema()['required'], ['messages']);
    });
  });

  group('calc', () {
    test('evaluates pure formulas over a scope', () {
      expect(evaluateCalc('a * 2 + b', {'a': 3, 'b': 1}), 7);
      expect(
        evaluateCalc('sum(items, i => i.q * i.c)', {
          'items': [
            {'q': 2, 'c': 3},
            {'q': 1, 'c': 10},
          ],
        }),
        16,
      );
      expect(
        evaluateCalc("map(range(0, 3), w => object('w', w, 'v', w * k))", {'k': 2}),
        [
          {'w': 0, 'v': 0},
          {'w': 1, 'v': 2},
          {'w': 2, 'v': 4},
        ],
      );
    });

    test('refuses the clock and random ids', () {
      expect(calcExpressionError('now()'), contains('pure'));
      expect(calcExpressionError('newId()'), contains('pure'));
      expect(evaluateCalc('today()', {}), isNull);
      expect(calcExpressionError('1 +'), contains('parse'));
      expect(calcExpressionError('round(a, 1)'), isNull);
    });

    test('converts formula paths and JSON pointers', () {
      expect(formulaPathToPointer('items[0].qty'), 'items/0/qty');
      expect(formulaPathToPointer('a'), 'a');
      expect(pointerToFormulaPath('/items/0/qty'), 'items[0].qty');
      expect(pointerToFormulaPath('/a~1b'), 'a/b');
    });
  });
}
