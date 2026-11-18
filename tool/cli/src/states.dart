// Render every state of a site from one manifest, compare each with its reference, and summarize.
//
//   tool/codelessly states <states.json> [--out dir] [--only name]... [--sizes WxH,...] [--no-sheet] [--outline]
//
// A screen is right only when every state of it is: empty, filled, errors, a dialog open, hovered, at each size.
// This runs the render command once per state (`--label <state>`), then writes `<out>/summary.md` and
// `summary.json` (worst first), `<out>/sheet.png` (one row per state) and each state's captures, diagnostics,
// compare images and layout dumps in `<out>/<state>/`. It exits 1 when any state has errors (or matches its
// reference less than `minMatch`), else 0. The manifest's format: `_doc` below.
import 'dart:convert';
import 'dart:io';

import 'common.dart';
import 'outline.dart';
import 'render_cmd.dart' show sheet;

/// A step as render options: `{"tap": "go"}` → `--tap go`, `{"unfocus": true}` → `--unfocus`, a list as it is.
List<String> stepArgs(Object? steps) => [
      for (final s in (steps as List?) ?? const [])
        ...switch (s) {
          final String v => [v],
          final List l => [for (final x in l) '$x'],
          final Map m => [
              for (final e in m.entries)
                ...(e.value == true
                    ? ['--${e.key}']
                    : ['--${e.key}', e.value is Map || e.value is List ? jsonEncode(e.value) : '${e.value}']),
            ],
          _ => const <String>[],
        },
    ];

const _pathOptions = {'--fonts', '--compare', '--slots', '--design-system'};

/// Paths after --fonts, --compare, --slots, --design-system (and an --image-map's folder and table) are relative
/// to the manifest.
List<String> absolutizeArgs(String base, List<String> args) => [
      for (var i = 0; i < args.length; i++)
        if (i > 0 && _pathOptions.contains(args[i - 1]) && args[i] != 'system')
          absolute(args[i], base)
        else if (i > 0 && args[i - 1] == '--image-map' && args[i].contains('='))
          () {
            final eq = args[i].lastIndexOf('=');
            final key = args[i].substring(0, eq);
            return '${key.endsWith('.json') ? absolute(key, base) : key}=${absolute(args[i].substring(eq + 1), base)}';
          }()
        else
          args[i],
    ];

String _relOrAbs(String base, String p) => p == 'system' ? p : absolute(p, base);

Future<int> statesMain(List<String> argv) async {
  final a = Args(argv, valued: {'--out', '--only', '--sizes'});
  if (a.help || a.positional.isEmpty) return usage(_doc, asked: a.help);
  final manifestFile = File(a.positional.first).absolute;
  final m = (jsonDecode(manifestFile.readAsStringSync()) as Map).cast<String, Object?>();
  final base = manifestFile.parent.path;
  final out = a['--out'] != null ? absolute(a['--out']!) : '$base/out/states';
  Directory(out).createSync(recursive: true);
  final docs = [for (final d in (m['documents'] as List? ?? const [])) _relOrAbs(base, '$d')];
  if (docs.isEmpty) throw const UsageError('The manifest names no "documents".');
  final common = absolutizeArgs(base, [for (final x in (m['args'] as List? ?? const [])) '$x']);
  final refs = m['references'];
  final minMatch = (m['minMatch'] as num?)?.toDouble();
  final ignore = {for (final c in (m['ignore'] as List? ?? const [])) '$c'};
  final only = a.all('--only');
  final states = [
    for (final s in (m['states'] as List? ?? const []).cast<Map>())
      if (only.isEmpty || only.any((o) => '${s['name']}'.contains(o))) s,
  ];
  if (states.isEmpty) throw const UsageError('No states to render (the manifest has none, or --only matched none).');

  final results = <Map<String, Object?>>[];
  for (final s in states) {
    final name = '${s['name']}';
    final sdir = '$out/$name';
    Directory(sdir).createSync(recursive: true);
    final sizes = a['--sizes'] ?? s['sizes'] as String? ?? m['sizes'] as String? ?? '390x844,834x1112,1440x900';
    final args = [
      ...common,
      ...absolutizeArgs(base, [for (final x in (s['args'] as List? ?? const [])) '$x']),
      if (s['screen'] != null) ...['--screen', '${s['screen']}'],
      ...stepArgs(s['steps']),
      '--label', name,
      if (a.has('--outline')) '--dump-layout',
      for (final e in ((s['compareMap'] as Map?) ?? const {}).entries) ...['--compare-map', '${e.key}=${e.value}'],
    ];
    final compare = s.containsKey('compare') ? s['compare'] : refs;
    final runs = <(String, List<String>)>[
      if (compare is Map)
        for (final size in sizes.split(','))
          (size, compare.containsKey(size) ? ['--compare', _relOrAbs(base, '${compare[size]}')] : <String>[])
      else
        (sizes, compare == null ? <String>[] : ['--compare', _relOrAbs(base, '$compare')]),
    ];
    final stateDocs = s['documents'] is List ? [for (final d in s['documents'] as List) _relOrAbs(base, '$d')] : docs;
    final watch = Stopwatch()..start();
    var status = 0;
    final log = StringBuffer();
    final diagFile = File('$sdir/diagnostics-$name.json');
    final merged = <String, List<Object?>>{'images': [], 'comparisons': [], 'diagnostics': []};
    final seen = <String>{};
    final startedOn = <String, String>{};
    // The diagnostics files a run writes in the state's folder (named by its label, its --screen and its sizes).
    List<File> diagnosticsFiles() => [
          for (final f in Directory(sdir).listSync().whereType<File>())
            if (RegExp(r'^diagnostics([-@].*)?\.json$').hasMatch(f.uri.pathSegments.last)) f,
        ];
    for (final (size, extra) in runs) {
      for (final f in diagnosticsFiles()) {
        f.deleteSync();
      }
      final (code, text) = await runCaptured(renderScript, [...stateDocs, '--out', sdir, '--sizes', size, ...args, ...extra]);
      if (code > status) status = code;
      log.write(text);
      for (final f in diagnosticsFiles()) {
        // Each run writes its own file: merge the runs (one per size) into one.
        final d = jsonDecode(f.readAsStringSync()) as Map;
        f.deleteSync();
        merged['images']!.addAll(d['images'] as List? ?? const []);
        merged['comparisons']!.addAll(d['comparisons'] as List? ?? const []);
        startedOn.addAll(((d['startedOn'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', '$v')));
        for (final x in d['diagnostics'] as List? ?? const []) {
          if (seen.add(jsonEncode(x))) merged['diagnostics']!.add(x); // a problem met before the first capture repeats in every run
        }
      }
    }
    final allDiags = merged['diagnostics']!.cast<Map>();
    final hasDiagnostics = merged['images']!.isNotEmpty || allDiags.isNotEmpty;
    if (hasDiagnostics) {
      final errorsAll = allDiags.where((x) => x['severity'] == 'error').length;
      diagFile.writeAsStringSync(
          prettyJson({'errors': errorsAll, 'warnings': allDiags.length - errorsAll, ...merged, if (startedOn.isNotEmpty) 'startedOn': startedOn}));
    }
    File('$sdir/render.log').writeAsStringSync(log.toString());
    final diags = allDiags.where((x) => !ignore.contains(x['code'])).toList();
    final errors = diags.where((x) => x['severity'] == 'error').toList();
    final warnings = diags.where((x) => x['severity'] != 'error').toList();
    final comps = merged['comparisons']!.cast<Map>();
    final matches = [for (final c in comps) if (c['matching'] is num) (c['matching'] as num).toDouble()];
    final worst = matches.isEmpty ? null : matches.reduce((x, y) => x < y ? x : y);
    final failed = (status == 2 && !hasDiagnostics) || errors.isNotEmpty || (minMatch != null && worst != null && worst < minMatch);
    if (a.has('--outline')) {
      final text = StringBuffer();
      final tree = DocumentTree.load(stateDocs);
      for (final f in layoutFiles(sdir)) {
        final cap = captureOf(f.path);
        text
          ..writeln('== $cap')
          ..writeln(outlineCapture(jsonDecode(f.readAsStringSync()) as List, tree, captureDiagnostics(sdir, cap)).join('\n'))
          ..writeln();
      }
      File('$sdir/outline.txt').writeAsStringSync(text.toString());
    }
    String line(Map d) {
      final msg = '${d['message'] ?? ''}';
      return '${d['severity']} ${d['code']} ${d['nodeId'] ?? d['path'] ?? ''}: ${msg.length > 200 ? msg.substring(0, 200) : msg}';
    }

    final logText = log.toString();
    results.add({
      'state': name,
      'status': status,
      'failed': failed,
      'seconds': (watch.elapsedMilliseconds / 100).round() / 10,
      'errors': errors.length,
      'warnings': warnings.length,
      'codes': ({for (final d in diags) '${d['code']}'}.toList()..sort()),
      'matching': worst,
      'comparisons': comps,
      'images': [for (final i in merged['images']!) '$sdir/$i'],
      'problems': [for (final d in [...errors, ...warnings].take(12)) line(d)],
      'log': hasDiagnostics ? null : logText.substring(logText.length > 1500 ? logText.length - 1500 : 0),
    });
    final match = worst == null ? 'no reference' : '${(worst * 100).toStringAsFixed(1)}% match';
    stdout.writeln('${failed ? 'FAIL' : 'ok  '} ${name.padRight(32)} ${errors.length} errors, ${warnings.length} warnings, '
        '$match (${results.last['seconds']}s)');
  }

  results.sort((x, y) {
    if (x['failed'] != y['failed']) return x['failed'] == true ? -1 : 1;
    final mx = (x['matching'] as double?) ?? 2, my = (y['matching'] as double?) ?? 2;
    if (mx != my) return mx.compareTo(my);
    return (y['errors'] as int).compareTo(x['errors'] as int);
  });
  File('$out/summary.json').writeAsStringSync(prettyJson(results));
  final md = StringBuffer()
    ..writeln('# States\n')
    ..writeln('${results.length} states from `${manifestFile.path}`; worst first.\n')
    ..writeln('| State | Result | Errors | Warnings | Worst match | Codes |')
    ..writeln('|---|---|---|---|---|---|');
  for (final r in results) {
    final mm = r['matching'] as double?;
    md.writeln('| ${r['state']} | ${r['failed'] == true ? 'FAIL' : 'ok'} | ${r['errors']} | ${r['warnings']} | '
        '${mm == null ? '' : '${(mm * 100).toStringAsFixed(1)}%'} | ${(r['codes'] as List).join(', ')} |');
  }
  for (final r in results) {
    final problems = r['problems'] as List;
    if (problems.isEmpty && r['log'] == null) continue;
    md.writeln('\n## ${r['state']}\n');
    for (final p in problems) {
      md.writeln('- $p');
    }
    if (r['log'] != null) md.writeln('\n```\n${r['log']}\n```');
  }
  File('$out/summary.md').writeAsStringSync(md.toString());
  if (!a.has('--no-sheet')) {
    final dirs = [for (final r in results.map((r) => '${r['state']}').toList()..sort()) '$out/$r'];
    final (code, text) = await sheet(dirs, '$out/sheet.png', height: 360,
        title: '${manifestFile.uri.pathSegments.last}: ${results.length} states');
    if (code == 0) {
      stdout.writeln('wrote $out/sheet.png');
    } else {
      stderr.writeln('(no sheet: ${text.trim().split('\n').last})');
    }
  }
  stdout.writeln('wrote $out/summary.md');
  return results.any((r) => r['failed'] == true) ? 1 : 0;
}

const _doc = '''tool/codelessly states <states.json> [--out dir] [--only name]... [--sizes WxH,...] [--no-sheet] [--outline]

Renders every state a manifest lists, compares each with its reference, and writes <out>/summary.md and
summary.json (worst first), <out>/sheet.png and each state's captures in <out>/<state>/. Exit 1 when a state has
errors or matches its reference less than minMatch. The manifest (paths relative to it):

  {
    "documents": ["site"],                 what to render: documents or a site folder
    "sizes": "390x844,834x1112,1440x900",  default sizes (a state can name its own)
    "args": ["--fonts", "fonts"],          passed to every render (--full-page, --theme dark, --now, --image-map...)
    "references": "screenshots",           optional: a folder of reference PNGs (render --compare's naming)
    "minMatch": 0.97,                      optional: below this share of matching pixels a state fails
    "ignore": ["unknown_screen"],          optional: codes left out of the counts (still in diagnostics)
    "states": [
      {"name": "home", "screen": "home"},
      {"name": "home-annual", "screen": "home", "steps": [{"tap": "billing-toggle"}], "sizes": "1440x900"},
      {"name": "speaker", "steps": [{"navigate": "speaker?id=ada"}], "args": ["--full-page"],
       "compare": {"390x844": "screenshots/mobile/07_speaker.png"}, "documents": ["speaker.json"]}
    ]
  }

A step is {"<render option without -->": value} (tap, hover, type, set, scroll, drag, key, navigate, wait, focus;
{"unfocus": true}), or a list of raw arguments. A state's compare is a file, a folder, or a map from size to file
(each size then renders on its own); its documents replace the manifest's for that state.''';
