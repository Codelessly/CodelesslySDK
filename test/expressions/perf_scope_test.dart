// `perf`: a screen can show its own frame timings (Petri's Bench footer,
// "FRAME 6.2 ms"). Before, nothing gave a layout the frame time: a formula
// reading it got null.
import 'dart:ui' show FrameTiming;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// A frame starting at [startUs] that built for [buildUs] and rastered for
/// [rasterUs] microseconds.
FrameTiming _frame(int startUs, int buildUs, int rasterUs) => FrameTiming(
      vsyncStart: startUs,
      buildStart: startUs,
      buildFinish: startUs + buildUs,
      rasterStart: startUs + buildUs,
      rasterFinish: startUs + buildUs + rasterUs,
      rasterFinishWallTime: startUs + buildUs + rasterUs,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('perf averages the reported frames and notifies its watchers', () {
    final perf = PerfScope();
    addTearDown(perf.dispose);
    final screen = ValuesScope({'route': const {}}, perf);
    expect(readPath(screen, 'perf.frameMs'), 0.0, reason: 'idle until the first report');

    var notified = 0;
    perf.watch('perf').addListener(() => notified++);
    // 61 frames, 1/60 s apart: 4 ms build + 2 ms raster each.
    perf.report([for (var i = 0; i <= 60; i++) _frame(i * 16667, 4000, 2000)]);
    expect(notified, 1);
    expect(readPath(screen, 'perf.frameMs'), closeTo(6.0, 1e-9));
    expect(readPath(screen, 'perf.buildMs'), closeTo(4.0, 1e-9));
    expect(readPath(screen, 'perf.rasterMs'), closeTo(2.0, 1e-9));
    expect(readPath(screen, 'perf.fps') as double, closeTo(60, 0.1));

    // About the same: no new value, so a readout of it doesn't redraw itself
    // on and on.
    perf.report([for (var i = 0; i <= 60; i++) _frame(i * 16667, 4050, 2000)]);
    expect(notified, 1);
    // Slower frames: a new value.
    perf.report([for (var i = 0; i <= 30; i++) _frame(i * 33333, 9000, 3000)]);
    expect(notified, 2);
    expect(readPath(screen, 'perf.frameMs'), closeTo(12.0, 1e-9));
    expect(readPath(screen, 'perf.fps') as double, closeTo(30, 0.1));
  });

  testWidgets('a running screen reads perf from the engine\'s frame timings', (tester) async {
    final perf = PerfScope();
    addTearDown(perf.dispose);
    perf.watch('perf'); // starts listening
    // The binding hands frame timings to its callbacks.
    tester.binding.platformDispatcher.onReportTimings!([for (var i = 0; i <= 10; i++) _frame(i * 16667, 3000, 1000)]);
    expect(readPath(perf, 'perf.frameMs'), closeTo(4.0, 1e-9));
  });
}
