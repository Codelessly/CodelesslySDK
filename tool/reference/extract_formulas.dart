// Writes the formula language's function table as JSON, for the API
// reference (codelessly_api's docs/reference/formulas.md is generated from
// it). Run through extract_formulas.sh: `flutter test` gives it the Flutter
// libraries the SDK's formula engine imports.
//
// Output: {"functions": [{"name", "signature", "example"}], "undocumented":
// [names the engine has without an entry in functionDocs]}.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final out = Platform.environment['CODELESSLY_FORMULAS_OUT'];
  test('extract formulas', () {
    if (out == null) return;
    final docs = FormulaEvaluator.functionDocs;
    final documented = {for (final d in docs) d.name};
    final json = {
      'source': 'codelessly_sdk lib/src/runtime/expressions/formula.dart (FormulaEvaluator.functionDocs, FormulaEvaluator.functions)',
      'functions': [
        for (final d in docs) {'name': d.name, 'signature': d.signature, 'example': d.example},
      ],
      'undocumented': [
        for (final f in FormulaEvaluator.functions)
          if (!documented.contains(f)) f,
      ]..sort(),
    };
    File(out).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(json)}\n');
  });
}
