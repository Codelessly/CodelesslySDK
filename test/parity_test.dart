import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/parity.dart';

/// `--dart-define=types=listView,gridView`: report and list divergences of
/// these types only. `--dart-define=dump=<file>`: write every first
/// divergence there. `--dart-define=sets=static,samples-inputs`: these sets.
const _types = String.fromEnvironment('types');
const _dump = String.fromEnvironment('dump');
const _sets = String.fromEnvironment('sets');

void main() {
  final sets = _sets.isEmpty ? goldenSets() : _sets.split(',');
  for (final set in sets) {
    testWidgets('golden set "$set" lays out as SDK 8.x did', (tester) async {
      final original = FlutterError.onError;
      // Content overflows are reported by the layout objects in both SDKs.
      FlutterError.onError = (d) {
        if (!'${d.exception}'.contains('overflowed by')) original?.call(d);
      };
      final r = await parity(tester, set: set, keep: 100000);
      FlutterError.onError = original;
      final types = _types.isEmpty ? null : _types.split(',').toSet();
      debugPrint('[$set] ${r.summary()}');
      final divergences = [
        for (final d in r.divergences)
          if (types == null || types.any((t) => d.contains(' $t "'))) d,
      ];
      if (_dump.isNotEmpty) File(_dump).writeAsStringSync(divergences.join('\n'));
      for (final d in divergences.take(30)) {
        debugPrint(d);
      }
      expect(r.nodes, greaterThan(0));
      // A set of samples is held to every node.
      if (set.startsWith('samples-')) expect(r.rate, 1.0, reason: divergences.take(10).join('\n'));
    });
  }
}
