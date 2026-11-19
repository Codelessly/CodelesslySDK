// What a frame of a drag costs: the engine's work and the panes' dataflow
// (graphic's operators run for the rows in view). Printed, not asserted
// tightly: a debug-mode VM, so a ceiling only.
import 'package:codelessly_sdk/graph.dart';
import 'package:codelessly_sdk/src/graph/graph_pane.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'stock.dart';

void main() {
  for (final (rows, spacing) in [(100, 8.0), (400, 2.0), (1600, 0.5)]) {
    testWidgets('a pan frame with $rows rows in view', (tester) async {
      final engine = GraphEngine(GraphSpec.fromJson(stockSpec()), data: stockRows(5000))
        ..resize(const Size(856, 424))
        ..applyView({'barSpacing': spacing, 'rightOffset': 0});
      final panes = [for (var i = 0; i < 2; i++) GraphPane(engine, i, const TestVSync(), () {})];
      expect(engine.visible.$2 - engine.visible.$1 + 1, closeTo(rows, 2));
      const frames = 200;
      final watch = Stopwatch()..start();
      for (var i = 0; i < frames; i++) {
        engine.panBy(i.isEven ? 3 : -3);
        for (final p in panes) {
          p.sync();
        }
      }
      final ms = watch.elapsedMicroseconds / 1000 / frames;
      // ignore: avoid_print
      print('GRAPH-PERF rows=$rows ms/frame=${ms.toStringAsFixed(2)}');
      expect(ms, lessThan(50));
      for (final p in panes) {
        p.dispose();
      }
    });
  }
}
