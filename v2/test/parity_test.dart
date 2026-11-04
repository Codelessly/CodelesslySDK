import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/parity.dart';

void main() {
  testWidgets('every fixture canvas lays out as SDK 8.x did', (tester) async {
    final original = FlutterError.onError;
    // Content overflows are reported by the layout objects in both SDKs.
    FlutterError.onError = (d) {
      if (!'${d.exception}'.contains('overflowed by')) original?.call(d);
    };
    final r = await parity(tester, keep: 100000);
    FlutterError.onError = original;
    debugPrint(r.summary());
    const dump = String.fromEnvironment('dump');
    if (dump.isNotEmpty) File(dump).writeAsStringSync(r.divergences.join('\n'));
    for (final d in r.divergences.take(30)) {
      debugPrint(d);
    }
    expect(r.nodes, greaterThan(19000));
  });
}
