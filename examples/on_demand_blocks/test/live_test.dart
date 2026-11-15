import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_demand_blocks/main.dart';

void main() {
  test(
    'live fast compose, strong design, and replacement for three requests',
    () async {
      final cards = await loadCards();
      final results = <Map<String, Object?>>[];
      for (final (name, request) in requests) {
        final trial = await runTrial(name, request, cards);
        results.add(trial.summary());
        trial.session.dispose();
      }
      final path =
          Platform.environment['ON_DEMAND_RESULTS'] ?? '/tmp/on-demand-results.json';
      await File(
        path,
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
      expect(results, hasLength(3));
    },
    timeout: const Timeout(Duration(minutes: 45)),
  );
}
