// Render every state of a site from one manifest, compare each with its reference, and summarize.
//
//   tool/codelessly states <states.json> [--out dir] [--only name]... [--sizes WxH,...] [--no-sheet] [--outline] [--cold]
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
import 'render_client.dart';
import 'render_cmd.dart' show sheet;

/// A step as render options: `{"tap": "go"}` → `--tap go`, `{"unfocus": true}` → `--unfocus`, a list as it is.
/// A key written in camel case is the option's name (`{"longPress": "row"}` → `--long-press row`).
List<String> stepArgs(Object? steps) => [
      for (final s in (steps as List?) ?? const [])
        ...switch (s) {
          final String v => [v],
          final List l => [for (final x in l) '$x'],
          final Map m => [
              for (final e in m.entries)
                ...(e.value == true
                    ? ['--${_optionName('${e.key}')}']
                    : ['--${_optionName('${e.key}')}', e.value is Map || e.value is List ? jsonEncode(e.value) : '${e.value}']),
            ],
          _ => const <String>[],
        },
    ];

/// A step's key as the render option it names: `longPress` → `long-press`, `doubleTap` → `double-tap`.
String _optionName(String key) => key.replaceFirst(RegExp(r'^-+'), '').replaceAllMapped(RegExp(r'(?<=[a-z0-9])([A-Z])'), (m) => '-${m[1]!.toLowerCase()}');

/// [args] without `--outline`, and whether it was there: the states command's own option (each state's layout
/// dumped and outlined), which the render takes as `--dump-layout`, written in a manifest's or a state's args.
(List<String>, bool) takeOutline(List<String> args) => ([for (final x in args) if (x != '--outline') x], args.contains('--outline'));

const _pathOptions = {'--fonts', '--compare', '--slots', '--design-system', '--pick-file'};

/// Paths after --fonts, --compare, --slots, --design-system, --pick-file (and an --image-map's folder and table) are relative
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
  // `states <site> states.json`: one manifest only; the site's pages are its "documents". A second argument was
  // taken silently (the first was read as the manifest).
  if (a.positional.length > 1) {
    throw UsageError('states takes one argument, the manifest: tool/codelessly states <states.json> (given ${a.positional.length}: '
        '${a.positional.join(' ')}). The pages it renders are the manifest\'s "documents", relative to it.');
  }
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
  final states = pickStates((m['states'] as List? ?? const []).cast<Map>(), a.all('--only'));
  if (states.isEmpty) throw const UsageError('No states to render (the manifest has none, or --only matched none).');

  // One warm renderer for the whole manifest: the render server (tool/render/serve.sh), started for this run when
  // none is up and stopped at its end, so a state costs its rendering, not a start of Flutter. Each state is still a
  // run of its own from a fresh app (a new app, a new screen, nothing stored); a run that breaks the server's tree
  // stops it, and the next state starts another. `--cold` starts Flutter for each state instead.
  final cold = a.has('--cold') || states.length < 2;
  var owned = false;
  Future<bool> serverUp() async => (await runCaptured(serveScript, const ['--status'])).$2.startsWith('Render server up');
  Future<bool> startServer() async {
    final (code, _) = await runCaptured(serveScript, const ['--idle', '900'], timeout: const Duration(minutes: 15));
    return code == 0 && await serverUp();
  }

  if (cold) {
    stdout.writeln(a.has('--cold')
        ? 'Cold: Flutter starts for each state (--cold).'
        : 'One state: rendered the usual way (a render server already up is used).');
  } else if (await serverUp()) {
    stdout.writeln('Warm: the render server already up renders every state (left running).');
  } else if (await startServer()) {
    owned = true;
    stdout.writeln('Warm: a render server started for this manifest renders every state (stopped at the end).');
  } else {
    stdout.writeln('Cold: the render server did not start (tool/codelessly serve says why); Flutter starts for each state.');
  }
  try {
    return await _renderStates(states, a, m, manifestFile, out, docs, common, refs, minMatch, ignore, () async {
      // A server this run started that stopped (a run broke its tree, or the code changed): started again.
      if (owned && !await serverUp()) {
        stdout.writeln(await startServer()
            ? '(the render server had stopped; started a new one)'
            : '(the render server had stopped and did not start again: the next states start Flutter each)');
      }
    });
  } finally {
    if (owned) await runCaptured(serveScript, const ['--stop']);
  }
}

/// Whether a render command's output says the render server drew it (else Flutter was started for it).
bool renderedWarm(String log) => log.contains(', the render server (pid ');

Future<int> _renderStates(List<Map> states, Args a, Map<String, Object?> m, File manifestFile, String out, List<String> docs,
    List<String> common, Object? refs, double? minMatch, Set<String> ignore, Future<void> Function() beforeState) async {
  final base = manifestFile.parent.path;
  final results = <Map<String, Object?>>[];
  String line(Map d) {
    final msg = '${d['message'] ?? ''}';
    return '${d['severity']} ${d['code']} ${d['nodeId'] ?? d['path'] ?? ''}: ${msg.length > 200 ? msg.substring(0, 200) : msg}';
  }

  // Problems of the site itself (site.json: a declared font file or the design system not there), met before any
  // screen: every state has them. Said once, first, not again in each state's list; still counted in each state.
  final siteProblems = <String>{};
  for (final s in states) {
    await beforeState();
    final name = '${s['name']}';
    final sdir = '$out/$name';
    Directory(sdir).createSync(recursive: true);
    final sizes = a['--sizes'] ?? s['sizes'] as String? ?? m['sizes'] as String? ?? '390x844,834x1112,1440x900';
    // `--outline` in the manifest's args or the state's is this command's own (the render takes --dump-layout).
    final (written, outlined) = takeOutline([
      ...common,
      ...absolutizeArgs(base, [for (final x in (s['args'] as List? ?? const [])) '$x']),
      if (s['screen'] != null) ...['--screen', '${s['screen']}'],
      ...stepArgs(s['steps']),
    ]);
    final outline = a.has('--outline') || outlined;
    final args = [
      ...written,
      '--label', name,
      if (outline && !written.contains('--dump-layout')) '--dump-layout',
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
      final (code, text) = await renderCaptured([...stateDocs, '--out', sdir, '--sizes', size, ...args, ...extra]);
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
    // A state is right only when it shows something: a run that wrote no picture (it stopped before the capture,
    // or the command never started: an argument the shell could not pass) fails, whatever its status said.
    if (noCapture(merged['images']!, status, log.toString()) case final d?) diags.add(d);
    final errors = diags.where((x) => x['severity'] == 'error').toList();
    final warnings = diags.where((x) => x['severity'] != 'error').toList();
    final comps = merged['comparisons']!.cast<Map>();
    final matches = [for (final c in comps) if (c['matching'] is num) (c['matching'] as num).toDouble()];
    final worst = matches.isEmpty ? null : matches.reduce((x, y) => x < y ? x : y);
    final failed = (status == 2 && !hasDiagnostics) || errors.isNotEmpty || (minMatch != null && worst != null && worst < minMatch);
    if (outline) {
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
    final ofSite = [for (final d in diags) if (isSiteProblem(d)) d];
    for (final d in ofSite) {
      final text = '${d['severity']} ${d['code']}: ${d['message']}';
      if (siteProblems.add(text)) stdout.writeln('site $text');
    }
    final logText = log.toString();
    final warm = renderedWarm(logText);
    results.add({
      'state': name,
      'status': status,
      'failed': failed,
      'seconds': (watch.elapsedMilliseconds / 100).round() / 10,
      'renderer': warm ? 'server' : 'cold',
      'errors': errors.length,
      'warnings': warnings.length,
      'codes': ({for (final d in diags) '${d['code']}'}.toList()..sort()),
      'matching': worst,
      'comparisons': comps,
      'images': [for (final i in merged['images']!) '$sdir/$i'],
      'problems': [for (final d in [...errors, ...warnings].where((d) => !isSiteProblem(d)).take(12)) line(d)],
      if (ofSite.isNotEmpty) 'siteProblems': ofSite.length,
      'log': hasDiagnostics || logText.isEmpty ? null : logText.substring(logText.length > 1500 ? logText.length - 1500 : 0),
    });
    final match = worst == null ? 'no reference' : '${(worst * 100).toStringAsFixed(1)}% match';
    stdout.writeln('${failed ? 'FAIL' : 'ok  '} ${name.padRight(32)} ${errors.length} errors, ${warnings.length} warnings, '
        '$match (${results.last['seconds']}s, ${warm ? 'warm' : 'cold'})');
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
    ..writeln('${results.length} states from `${manifestFile.path}`; worst first.\n');
  if (siteProblems.isNotEmpty) {
    md.writeln('## The site\n\nMet before any screen, so every state has them (counted in each state below, listed here once):\n');
    for (final p in siteProblems) {
      md.writeln('- $p');
    }
    md.writeln();
  }
  md
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
  final failedCount = results.where((r) => r['failed'] == true).length;
  stdout.writeln(failedCount == 0
      ? 'all ${results.length} states ok'
      : '$failedCount of ${results.length} states failed${siteProblems.isEmpty ? '' : ' (${siteProblems.length} problem${siteProblems.length == 1 ? '' : 's'} of the site itself in every state: see "The site" in summary.md)'}');
  return failedCount > 0 ? 1 : 0;
}

/// The states of [all] the `--only` names in [only] pick, in the manifest's order (none written: all): a name a
/// state has picks that state alone (`--only profile` is not also `profile-loading`); a name no state has picks
/// every state whose name contains it (`--only picker-` for a group).
List<Map> pickStates(List<Map> all, List<String> only) {
  if (only.isEmpty) return all;
  final names = {for (final s in all) '${s['name']}'};
  bool picks(String o, String name) => names.contains(o) ? name == o : name.contains(o);
  return [for (final s in all) if (only.any((o) => picks(o, '${s['name']}'))) s];
}

/// The `no_capture` error of a state whose runs wrote no picture ([images] empty), whatever their exit [status]:
/// a state is checked by its captures, so one with none failed (it stopped before the capture, or the render command
/// never ran). Null when there is a picture.
Map<String, Object?>? noCapture(List<Object?> images, int status, String log) {
  if (images.isNotEmpty) return null;
  final said = log.trim();
  return {
    'severity': 'error',
    'code': 'no_capture',
    'message': 'The state wrote no picture (render exit status $status'
        '${said.isEmpty ? ', and no output at all: the render command did not run' : ''}). '
        'A state is checked by its captures: see render.log in its folder.',
  };
}

/// A problem of the site itself, met before any screen was rendered (a font file or the design system site.json
/// names that is not there): the same in every state.
bool isSiteProblem(Map d) => d['file'] == 'site.json' && d['screen'] == null && d['nodeId'] == null;

const _doc = '''tool/codelessly states <states.json> [--out dir] [--only name]... [--sizes WxH,...] [--no-sheet] [--outline] [--cold]

Renders every state a manifest lists, compares each with its reference, and writes <out>/summary.md and
summary.json (worst first), <out>/sheet.png and each state's captures in <out>/<state>/. Exit 1 when a state has
errors, wrote no picture, or matches its reference less than minMatch. The manifest (paths relative to it):

  {
    "documents": ["site"],                 what to render: documents or a site folder
    "sizes": "390x844,834x1112,1440x900",  default sizes (a state can name its own)
    "args": ["--fonts", "fonts"],          passed to every render (--full-page, --theme dark, --now, --clock...)
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

--only <name> picks the state of that name alone; a name no state has picks every state whose name contains it
(--only picker- for a group). Repeatable. --outline (here, or in the manifest's or a state's "args") dumps each
capture's layout and writes the state's outline.txt.

A step is {"<render option without -->": value} (tap, hover, type, set, stage, scroll, drag, key, navigate, wait,
focus, long-press, frames; {"unfocus": true}; a key in camel case names the same option: longPress, doubleTap), or
a list of raw arguments; values reach the render as written ({"set": "items=[]"}, {"type": "note=one\\ntwo"} types
both lines; {"drag": "wrapper=100,-100,press=500"}). {"frames": [0, 120]} after a step captures what
it started at those ms with no settle first (`<png>-f<n>-<ms>ms.png`, with an outline under --outline); first in a
state, from the page's load: [{"tap": "send"}, {"frames": [120]}] catches a pending row, [{"long-press": "msg=399,hold"},
{"frames": [0]}] a hold in progress. A state that writes no picture fails (no_capture). Problems of the site itself
(a font file site.json declares that is not there) are said once, under "The site" in summary.md. A state's compare
is a file, a folder, or a map from size to file (each size then renders on its own); its documents replace the
manifest's for that state.

The states share one warm renderer: when no render server (tool/codelessly serve) is up, one is started for the run
and stopped at its end; each state is still its own run, from a fresh app. The first line says which renderer ran,
and each state's line says warm or cold. --cold starts Flutter for each state instead.''';
