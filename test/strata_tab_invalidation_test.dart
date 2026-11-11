import 'dart:convert';
import 'dart:io';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'actions/wiring_test.dart' as support;

void main() {
  testWidgets('Strata tab bindings survive glossary empty-state recovery', (tester) async {
    // Actual Strata tabs, reduced to one section and simplified path art.
    // Returning to descent used to dirty a reused child before its owner.
    final fixture = jsonDecode(File('test/fixtures/strata_tabs.json').readAsStringSync()) as Map<String, dynamic>;
    final vars = (fixture['variables'] as Map<String, dynamic>).entries
        .map(
          (v) => Variable.fromJson(
            v.value is Map
                ? {'name': v.key, ...v.value as Map<String, dynamic>}
                : {
                    'name': v.key,
                    'type': v.value is bool
                        ? 'boolean'
                        : v.value is num
                        ? 'decimal'
                        : v.value is List
                        ? 'list'
                        : 'text',
                    'value': v.value,
                  },
          ),
        )
        .whereType<Variable>()
        .toList();
    final s = await support.show(
      tester,
      (fixture['nodes'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as Map).cast<String, Object?>())),
      variables: vars,
      root: fixture['root'],
    );
    for (final change in [
      ('view', 'timeline'),
      ('view', 'descent'),
      ('view', 'glossary'),
      ('query', 'nomatch'),
      ('query', ''),
      ('view', 'descent'),
    ]) {
      setVariableIn(s.scope, change.$1, change.$2);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'after $change');
      if (change == ('view', 'glossary')) {
        setVariableIn(s.scope, 'currentLayer', 1);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'hidden gauge text changed');
      }
    }
  });
}
