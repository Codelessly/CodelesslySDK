// The formula parser and evaluator import no Flutter, so a tool that runs on
// the Dart VM alone (the stream chat's recorder, examples/stream_chat/
// tool/record.dart) can read a model's formulas with the same parser the
// runtime uses.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The files [entry] imports, transitively, within lib/ (package: imports
/// of other packages are listed as they are).
Set<String> _closure(String entry) {
  final seen = <String>{};
  final out = <String>{};
  final stack = [File(entry).absolute.path];
  final directive = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);
  while (stack.isNotEmpty) {
    final f = stack.removeLast();
    if (!seen.add(f)) continue;
    for (final m in directive.allMatches(File(f).readAsStringSync())) {
      final uri = m[1]!;
      if (uri.startsWith('package:codelessly_sdk/')) {
        stack.add(File('lib/${uri.substring('package:codelessly_sdk/'.length)}').absolute.path);
      } else if (uri.contains(':')) {
        out.add(uri);
      } else {
        stack.add(File(f).parent.uri.resolve(uri).toFilePath());
      }
    }
  }
  return out;
}

void main() {
  test('the formula library imports no Flutter, so a Dart VM tool can check formulas with it', () {
    final imports = _closure('lib/src/runtime/expressions/formula.dart');
    expect(imports.where((u) => u.startsWith('package:flutter') || u == 'dart:ui'), isEmpty, reason: '$imports');
  });
}
