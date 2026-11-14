// The same screen twice, timed: once as a document shown by the SDK, once
// written by hand in Flutter's Material widgets. Per run, one side:
//
//   flutter build web --release -t lib/compare.dart && (serve build/web)
//   open /?side=sdk&groups=150   or   /?side=flutter&groups=150
//   →  the console prints "[bench-result] {...}"
//
// The screen is [groups] sections of a title, a switch, a slider, a text
// field and a button in one scrolling column, none of it built lazily, and
// a line at the top that shows a counter. Timed: the first frame (from
// runApp to rasterized), 120 frames in which only the counter changes, and
// 240 frames of scrolling.
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
        '    Toggle "Enabled" =on$i\n'
        '    Slider =level$i min:0 max:100\n'
        '    Input "Name" =name$i\n'
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final q = Uri.base.queryParameters;
  final side = q['side'] ?? 'sdk';
  final groups = int.tryParse(q['groups'] ?? '') ?? 150;
  final tick = ValueNotifier(0);
  final scroll = ScrollController();

  final build = <double>[], raster = <double>[];
  SchedulerBinding.instance.addTimingsCallback((timings) {
    for (final t in timings) {
      build.add(t.buildDuration.inMicroseconds / 1000);
      raster.add(t.rasterDuration.inMicroseconds / 1000);
    }
  });
  Future<void> frames(int n, void Function(int i) each) async {
    for (var i = 0; i < n; i++) {
      each(i);
      SchedulerBinding.instance.scheduleFrame();
      await SchedulerBinding.instance.endOfFrame;
    }
    // The timings of the last frames are reported in batches.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
  }

  final sw = Stopwatch()..start();
  double? made;
  final Widget screen;
  if (side == 'sdk') {
    final session = UiSession(document: documentOf(groups));
    made = sw.elapsedMicroseconds / 1000;
    screen = SdkScreen(session: session, tick: tick);
  } else {
    screen = FlutterScreen(groups: groups, tick: tick);
  }
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: SingleChildScrollView(controller: scroll, child: screen)),
  ));
  await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
  final first = sw.elapsedMicroseconds / 1000;
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  final firstBuild = build.isEmpty ? null : build.first, firstRaster = raster.isEmpty ? null : raster.first;

  build.clear();
  raster.clear();
  await frames(120, (i) => tick.value = i + 1);
  final updateBuild = [...build], updateRaster = [...raster];

  build.clear();
  raster.clear();
  final extent = scroll.position.maxScrollExtent;
  await frames(240, (i) => scroll.jumpTo(extent * (i + 1) / 240));
  final result = {
    'side': side,
    'groups': groups,
    if (made != null) 'notationToDocumentMs': double.parse(made.toStringAsFixed(1)),
    'runAppToFirstFrameMs': double.parse(first.toStringAsFixed(1)),
    'firstFrameBuildMs': firstBuild,
    'firstFrameRasterMs': firstRaster,
    'scrollExtent': extent.round(),
    'updateBuildMs': _stats(updateBuild),
    'updateRasterMs': _stats(updateRaster),
    'scrollBuildMs': _stats(build),
    'scrollRasterMs': _stats(raster),
  };
  // ignore: avoid_print
  print('[bench-result] ${jsonEncode(result)}');
}
