import 'dart:convert';
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Orrery's conjunction search calls a chain of function variables
/// (Kepler's equation, 3D positions, angles) tens of thousands of times.
void main() {
  final File data = File('../references/orrery/editor/app_variables.json');
  test(
    'nested function variables are fast enough for a search',
    () {
      final vars = (jsonDecode(data.readAsStringSync()) as List).cast<Map>();
      final Map<String, Object?> values = {};
      Object? resolve(String path) {
        final Object? head = values[path];
        if (head != null || values.containsKey(path)) return head;
        // planets[1] and the like.
        final m = RegExp(r'^([a-zA-Z_]+)\[(\d+)\]$').firstMatch(path);
        if (m != null) return (values[m[1]] as List)[int.parse(m[2]!)];
        return null;
      }

      for (final v in vars) {
        if (v['parameters'] != null) {
          values[v['name'] as String] = FormulaFunction(
            (v['parameters'] as List).cast<String>(),
            FormulaEvaluator.exactExpression(v['formula'] as String)!,
            resolve,
          );
        } else if (v['value'] != null) {
          values[v['name'] as String] = v['value'];
        }
      }
      FormulaEvaluator.evaluate(
        'geoSep(planets[1], planets[4], planets[2], 9805)',
        resolve,
      );
      final sw = Stopwatch()..start();
      final r = FormulaEvaluator.evaluate(
        'min(map(range(5000), i => geoSep(planets[1], planets[4], planets[2], 9805 + i * 4)))',
        resolve,
      );
      sw.stop();
      // ignore: avoid_print
      print('5000 separations: ${sw.elapsedMilliseconds} ms, result $r');
      expect(r, isA<num>());
      // A separation is ~30 nested calls; keep it well under a millisecond.
      expect(sw.elapsedMilliseconds, lessThan(2500));
    },
    skip: data.existsSync()
        ? false
        : 'needs the Orrery reference (CodelesslyEditor checkout)',
  );
}
