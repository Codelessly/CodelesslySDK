// The same screen twice, timed: once as a document shown by the SDK, once
// written by hand in Flutter's Material widgets. Per run, one side:
//
//   flutter build web --release --no-web-resources-cdn -t lib/compare.dart && (serve build/web)
//   open /?side=sdk&groups=150   or   /?side=flutter&groups=150
//   →  the console prints "[bench-result] {...}"
//
// The screen is [groups] sections of a title, a switch, a slider, a text
// field and a button in one scrolling column, none of it built lazily, and
// a line at the top that shows a counter. Timed, on the UI thread: the
// first frame (runAppToFirstFrameMs from runApp to the end of the frame,
// which is inflating the widgets and the frame; firstFrameBuildMs the frame
// alone, which is layout, paint and scene building), 120 frames in which
// only the counter changes, and 240 frames of scrolling. Both sides run the
// same phases and the same number of frames.
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/notation.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// The screen in the compact notation.
String notationOf(int groups) {
  final b = StringBuffer('Column gap:16 pad:16\n  Text.sectionTitle "Tick {data.tick}"\n');
  for (var i = 0; i < groups; i++) {
    b.write('  Column gap:8\n'
        '    Text.sectionTitle "Section $i"\n'
        '    Toggle "Enabled" bind:on$i\n'
        '    Slider bind:level$i min:0 max:100\n'
        '    Input "Name" bind:name$i\n'
        '    Button "Save"\n');
  }
  return b.toString();
}

/// The screen as a document.
api.LayoutDocument documentOf(int groups) {
  final r = parseNotation(notationOf(groups));
  if (r.issues.isNotEmpty) throw StateError(r.issues.join('\n'));
  return api.LayoutDocument.fromJson(r.document);
}

/// The SDK's side: the document in a session.
class SdkScreen extends StatelessWidget {
  const SdkScreen({super.key, required this.session, required this.tick});
  final UiSession session;
  final ValueNotifier<int> tick;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: tick,
        builder: (context, t, _) => CodelesslyView(session: session, data: {'tick': t}),
      );
}

/// Flutter's side: the same screen in Material widgets, with only the
/// counter's text rebuilt when it changes.
class FlutterScreen extends StatelessWidget {
  const FlutterScreen({super.key, required this.groups, required this.tick});
  final int groups;
  final ValueNotifier<int> tick;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ValueListenableBuilder<int>(
              valueListenable: tick,
              builder: (context, t, _) => Text('Tick $t', style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          for (var i = 0; i < groups; i++) Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: _Group(i)),
        ],
      );
}

class _Group extends StatefulWidget {
  const _Group(this.index);
  final int index;

  @override
  State<_Group> createState() => _GroupState();
}

class _GroupState extends State<_Group> {
  bool on = false;
  double level = 0;
  final name = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Section ${widget.index}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(children: [
            Switch(value: on, onChanged: (v) => setState(() => on = v)),
            const SizedBox(width: 8),
            const Text('Enabled'),
          ]),
          const SizedBox(height: 8),
          Slider(value: level, max: 100, onChanged: (v) => setState(() => level = v)),
          const SizedBox(height: 8),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          FilledButton(onPressed: () {}, child: const Text('Save')),
        ],
      );
}

double _pct(List<double> xs, double p) {
  if (xs.isEmpty) return 0;
  final s = [...xs]..sort();
  return s[((s.length - 1) * p).round()];
}

Map<String, Object?> _stats(List<double> xs) => {
      'n': xs.length,
      'median': double.parse(_pct(xs, 0.5).toStringAsFixed(2)),
      'p90': double.parse(_pct(xs, 0.9).toStringAsFixed(2)),
      'max': double.parse(_pct(xs, 1).toStringAsFixed(2)),
    };

/// One frame, timed on the UI thread: from the start of its begin-frame
/// callbacks to its post-frame callbacks, which is the build, layout, paint
/// and scene building. [before] runs first and is not timed. Returns the
/// milliseconds; the frame's number is added to [numbers].
Future<double> _timedFrame(Stopwatch sw, Set<int> numbers, {void Function()? before, bool schedule = true}) {
  final binding = SchedulerBinding.instance;
  final done = Completer<double>();
  var t0 = 0;
  before?.call();
  binding.scheduleFrameCallback((_) {
    t0 = sw.elapsedMicroseconds;
    numbers.add(binding.platformDispatcher.frameData.frameNumber);
  }, scheduleNewFrame: schedule);
  binding.addPostFrameCallback((_) => done.complete((sw.elapsedMicroseconds - t0) / 1000));
  return done.future;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final q = Uri.base.queryParameters;
  final side = q['side'] ?? 'sdk';
  final groups = int.tryParse(q['groups'] ?? '') ?? 150;
  final tick = ValueNotifier(0);
  final scroll = ScrollController();
  final sw = Stopwatch()..start();

  // The engine's own timings, by frame number. On the web they arrive in
  // batches, and only when a later frame is drawn at least 100 ms after the
  // last batch, so they are matched to the timed frames by number at the
  // end. The engine does not time the first (warm-up) frame's build.
  final engine = <int, FrameTiming>{};
  SchedulerBinding.instance.addTimingsCallback((timings) {
    for (final t in timings) {
      engine[t.frameNumber] = t;
    }
  });

  /// [n] frames, one after another, each timed.
  Future<(List<double>, Set<int>)> frames(int n, void Function(int i) each) async {
    final ms = <double>[], numbers = <int>{};
    for (var i = 0; i < n; i++) {
      ms.add(await _timedFrame(sw, numbers, before: () => each(i)));
    }
    return (ms, numbers);
  }

  final start = sw.elapsedMicroseconds;
  double? made;
  final Widget screen;
  if (side == 'sdk') {
    final session = UiSession(document: documentOf(groups));
    made = (sw.elapsedMicroseconds - start) / 1000;
    screen = SdkScreen(session: session, tick: tick);
  } else {
    screen = FlutterScreen(groups: groups, tick: tick);
  }
  // runApp inflates the widgets in one timer and draws the first frame (the
  // warm-up frame) in the next ones; the callbacks below are that frame's.
  final t0 = sw.elapsedMicroseconds;
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: SingleChildScrollView(controller: scroll, child: screen)),
  ));
  final firstBuild = await _timedFrame(sw, {}, schedule: false);
  final first = (sw.elapsedMicroseconds - t0) / 1000;
  await Future<void>.delayed(const Duration(milliseconds: 1500));

  final (updateBuild, updateFrames) = await frames(120, (i) => tick.value = i + 1);
  await Future<void>.delayed(const Duration(milliseconds: 1500));

  final extent = scroll.position.maxScrollExtent;
  final (scrollBuild, scrollFrames) = await frames(240, (i) => scroll.jumpTo(extent * (i + 1) / 240));

  // Two more frames, each over 100 ms after the last, bring in the engine's
  // timings of the frames above.
  for (var i = 0; i < 2; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _timedFrame(sw, {});
  }
  List<double> of(Set<int> numbers, Duration Function(FrameTiming t) get) =>
      [for (final n in numbers) if (engine[n] case final t?) get(t).inMicroseconds / 1000];

  final result = {
    'side': side,
    'groups': groups,
    if (made != null) 'notationToDocumentMs': double.parse(made.toStringAsFixed(1)),
    'runAppToFirstFrameMs': double.parse(first.toStringAsFixed(1)),
    'firstFrameBuildMs': double.parse(firstBuild.toStringAsFixed(1)),
    'scrollExtent': extent.round(),
    'updateBuildMs': _stats(updateBuild),
    'scrollBuildMs': _stats(scrollBuild),
    'engineUpdateBuildMs': _stats(of(updateFrames, (t) => t.buildDuration)),
    'engineScrollBuildMs': _stats(of(scrollFrames, (t) => t.buildDuration)),
    'updateRasterMs': _stats(of(updateFrames, (t) => t.rasterDuration)),
    'scrollRasterMs': _stats(of(scrollFrames, (t) => t.rasterDuration)),
  };
  // ignore: avoid_print
  print('[bench-result] ${jsonEncode(result)}');
}
