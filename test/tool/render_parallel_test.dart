// The render server renders in parallel (tool/codelessly serve --workers n: tool/cli/src/pool.dart,
// tool/render/src/fan.dart): several workers behind one address. What must hold whatever the number of workers:
// every request gets exactly what a run of its own gives (its files, its report in its order, its exit status),
// whoever else is rendering at the same moment.
//
// Run alone: `flutter test test/tool/render_parallel_test.dart` (two to four minutes: it starts render servers
// of its own, in a folder of its own beside the test's files, so a server already up on the checkout is neither
// used nor stopped). Skipped when there is no bash, or no server can start.
@Timeout(Duration(minutes: 30))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

final String _sdk = Directory.current.path.replaceAll(r'\', '/');
const _fixtures = 'test/tool/fixtures';

/// The folder of the server the commands of this test talk to (CODELESSLY_RENDER_SERVER).
late String _server;

/// Whether a server was started (so there is a folder to stop one in).
bool _started = false;

Map<String, String> get _env => {'CODELESSLY_RENDER_SERVER': _server};

Future<ProcessResult> _bash(List<String> args, {Map<String, String>? environment}) =>
    Process.run('bash', args, workingDirectory: _sdk, environment: environment ?? _env, stdoutEncoding: utf8, stderrEncoding: utf8);

/// One render: what it printed (the output folder's name taken out), its exit status, how long it took.
typedef _Run = ({String out, String said, String err, int exit, int ms});

Future<_Run> _render(String out, List<String> args, {Map<String, String>? environment}) async {
  final clock = Stopwatch()..start();
  final r = await _bash(['tool/codelessly', 'render', ...args, '--out', out], environment: environment);
  return (out: out, said: '${r.stdout}'.replaceAll('\r', '').replaceAll(out, 'OUT'), err: '${r.stderr}', exit: r.exitCode, ms: clock.elapsedMilliseconds);
}

Future<Map<String, Object?>?> _status() async {
  final r = await _bash(['tool/render/serve.sh', '--status', '--json']);
  final text = '${r.stdout}'.trim();
  return r.exitCode == 0 && text.startsWith('{') ? (jsonDecode(text) as Map).cast<String, Object?>() : null;
}

/// Starts a server in a fresh folder; null when it is up, else why not.
Future<String?> _serve(String dir, List<String> options) async {
  _server = dir;
  _started = true;
  final r = await _bash(['tool/codelessly', 'serve', '--idle', '900', ...options]);
  if (r.exitCode != 0) return '${r.stderr}'.trim().split('\n').last;
  // Every worker up and through its warm-up, so what is measured and compared is the server at work.
  for (var i = 0; i < 600; i++) {
    final s = await _status();
    if (s == null) return 'The render server stopped as it started.';
    final workers = (s['workers'] as List).cast<Map>();
    if (workers.length == s['workerCount'] && workers.every((w) => w['state'] == 'idle' && w['warmupsLeft'] == null)) return null;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  return 'The render server\'s workers did not all come up.';
}

Future<void> _stop() async {
  if (_started) await _bash(['tool/codelessly', 'serve', '--stop']);
}

/// The files a render left in [dir], by name (not the folders a command keeps for itself, whose names begin
/// with a dot).
Map<String, File> _files(String dir) => {
      for (final f in Directory(dir).listSync(recursive: true).whereType<File>())
        if (!f.path.replaceAll(r'\', '/').substring(dir.length).contains('/.')) f.path.replaceAll(r'\', '/').substring(dir.length + 1): f,
    };

Future<Uint8List> _pixels(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  final size = [image.width, image.height];
  image.dispose();
  return Uint8List.fromList([...size, ...data!.buffer.asUint8List()]);
}

/// Null when the two folders hold the same render, else what differs: the same file names; pictures the same
/// pixel for pixel (a channel of a pixel may differ by one: an encoder's rounding of a half-transparent one);
/// every other file the same text, the folders' own names aside.
Future<String?> _differ(String a, String b) async {
  final fa = _files(a), fb = _files(b);
  if (fa.keys.toSet().difference(fb.keys.toSet()).isNotEmpty || fb.keys.toSet().difference(fa.keys.toSet()).isNotEmpty) {
    return 'files: ${fa.keys.toList()..sort()} against ${fb.keys.toList()..sort()}';
  }
  for (final name in fa.keys) {
    final ba = fa[name]!.readAsBytesSync(), bb = fb[name]!.readAsBytesSync();
    if (name.endsWith('.png')) {
      if (_same(ba, bb)) continue;
      final pa = await _pixels(ba), pb = await _pixels(bb);
      if (pa.length != pb.length) return '$name: another size';
      for (var i = 0; i < pa.length; i++) {
        if ((pa[i] - pb[i]).abs() > (i < 2 ? 0 : 1)) return '$name: pixel ${(i - 2) ~/ 4} differs';
      }
    } else if (utf8.decode(ba).replaceAll(a, 'OUT') != utf8.decode(bb).replaceAll(b, 'OUT')) {
      return '$name differs';
    }
  }
  return null;
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void _copy(Directory from, Directory to) {
  to.createSync(recursive: true);
  for (final e in from.listSync()) {
    final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (e is Directory) {
      _copy(e, Directory('${to.path}/$name'));
    } else if (e is File) {
      e.copySync('${to.path}/$name');
    }
  }
}

void main() {
  late String root;
  String? skip;

  // What separate agents ask at the same moment: each a site of its own (two are the same site with another
  // text; two the same page at another time of day), with its own sizes and options.
  late final List<({String name, List<String> args})> jobs;
  // One request of many captures: the five pages of three sites at four sizes, with the layouts.
  late final List<String> many;
  final refs = <String, _Run>{};

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('render_parallel_test').path.replaceAll(r'\', '/');
    try {
      if ((await Process.run('bash', ['-c', 'true'])).exitCode != 0) skip = 'bash does not run here.';
    } on ProcessException {
      skip = 'No bash on the PATH.';
    }
    if (skip == null && !File('$_sdk/tool/codelessly').existsSync()) skip = 'Not run from the SDK\'s folder.';
    if (skip != null) return;
    for (final name in ['site', 'look', 'steps', 'components', 'capture', 'theme/named', 'theme/inline']) {
      _copy(Directory('$_sdk/$_fixtures/$name'), Directory('$root/sites/$name'));
    }
    // The same site as another agent's, at another place, saying something else.
    _copy(Directory('$_sdk/$_fixtures/site'), Directory('$root/sites/site2'));
    final home = File('$root/sites/site2/home.json');
    home.writeAsStringSync(home.readAsStringSync().replaceFirstMapped(RegExp(r'"text": "([^"{]+)"'), (m) => '"text": "Other ${m[1]}"'));
    expect(home.readAsStringSync(), isNot(File('$root/sites/site/home.json').readAsStringSync()));
    jobs = [
      (name: 'site', args: ['$root/sites/site', '--sizes', '390x844,1440x900', '--dump-layout']),
      (name: 'site2', args: ['$root/sites/site2', '--sizes', '390x844,1440x900', '--dump-layout']),
      (name: 'look', args: ['$root/sites/look']),
      (name: 'steps', args: ['$root/sites/steps', '--sizes', '834x1112']),
      (name: 'components', args: ['$root/sites/components', '--dump-layout']),
      (name: 'capture', args: ['$root/sites/capture', '--sizes', '390x844', '--full-page']),
      (name: 'morning', args: ['$root/sites/capture', '--sizes', '390x844', '--screen', 'tools', '--now', '2026-01-01T09:00:00Z', '--wait', '1500', '--dump-layout']),
      (name: 'evening', args: ['$root/sites/capture', '--sizes', '390x844', '--screen', 'tools', '--now', '2031-07-04T21:30:00Z', '--wait', '1500', '--dump-layout']),
      (name: 'named', args: ['$root/sites/theme/named', '--sizes', '390x844']),
      (name: 'inline', args: ['$root/sites/theme/inline', '--sizes', '390x844']),
    ];
    many = ['$root/sites/site', '$root/sites/capture', '$root/sites/look', '--sizes', '390x844,600x800,834x1112,1440x900', '--dump-layout'];
  });

  tearDownAll(() async {
    if (skip == null) await _stop();
    try {
      Directory(root).deleteSync(recursive: true);
    } on FileSystemException {
      // A worker still ending holds a file of it (Windows): left in the system's temporary folder.
    }
  });

  group('one worker', () {
    setUpAll(() async {
      if (skip != null) return;
      // (--queue 1: one request may wait; the next is told the server is busy.)
      skip = await _serve('$root/server1', ['--workers', '1', '--queue', '1']);
      if (skip != null) skip = 'No render server could start here: $skip';
    });
    tearDownAll(() async {
      if (skip == null) await _stop();
    });

    test('renders each request as a run of its own does: the references of the tests below', () async {
      if (skip != null) return markTestSkipped(skip!);
      for (final job in jobs) {
        final r = refs[job.name] = await _render('$root/ref/${job.name}', job.args);
        expect(r.err, contains(', the render server (pid '), reason: 'The render server did not take the run.');
        expect(r.exit, lessThan(2), reason: '${job.name}: ${r.said}\n${r.err}');
      }
      refs['many'] = await _render('$root/ref/many', many);
      expect(refs['many']!.exit, lessThan(2), reason: refs['many']!.said);
      expect('\n${refs['many']!.said}'.split('\nwrote ').length - 1, greaterThanOrEqualTo(20));
      // What tells the requests apart is in what they give: the two sites' pages, the two times of day.
      expect(await _differ('$root/ref/site', '$root/ref/site2'), isNotNull);
      expect(await _differ('$root/ref/morning', '$root/ref/evening'), isNotNull);
    });

    test('gives what a render with no server gives, file for file', () async {
      if (skip != null) return markTestSkipped(skip!);
      // No server in the folder named: Flutter is started for the run, as before there was a server.
      Directory('$root/none').createSync();
      final cold = await _render('$root/cold/many', many, environment: {'CODELESSLY_RENDER_SERVER': '$root/none'});
      expect(cold.err, isNot(contains('the render server (pid')));
      expect(cold.exit, refs['many']!.exit, reason: '${cold.said}\n${cold.err}');
      expect(cold.said, refs['many']!.said);
      expect(await _differ('$root/cold/many', '$root/ref/many'), isNull);
    });

    test('--layout-only gives the layouts of the run with pictures, and no picture', () async {
      if (skip != null) return markTestSkipped(skip!);
      final r = await _render('$root/layout/many', [...many, '--layout-only']);
      expect(r.exit, lessThan(2), reason: '${r.said}\n${r.err}');
      final got = _files('$root/layout/many'), ref = _files('$root/ref/many');
      expect(got.keys.where((n) => n.endsWith('.png')), isEmpty);
      final layouts = ref.keys.where((n) => n.endsWith('.layout.json')).toSet();
      expect(layouts.length, greaterThanOrEqualTo(20));
      expect(got.keys.where((n) => n.endsWith('.layout.json')).toSet(), layouts);
      for (final name in layouts) {
        expect(got[name]!.readAsStringSync(), ref[name]!.readAsStringSync(), reason: name);
      }
      // Its report names the layout files, in the order the pictures are named in.
      final wrote = [for (final l in r.said.split('\n')) if (l.startsWith('wrote ')) l];
      expect(wrote, [for (final l in refs['many']!.said.split('\n')) if (l.startsWith('wrote ')) l.replaceFirst(RegExp(r'\.png$'), '.layout.json')]);
    });

    test('a small request asked during a large one is not kept waiting for it; one more than the queue holds is told so', () async {
      if (skip != null) return markTestSkipped(skip!);
      // Large: some seconds of captures on the only worker.
      final sizes = [for (var w = 400; w < 400 + 20 * 16; w += 16) '${w}x800'].join(',');
      final clock = Stopwatch()..start();
      int? largeDone;
      final large = _render('$root/fair/large', ['$root/sites/site', '$root/sites/capture', '$root/sites/look', '--sizes', sizes]).then((r) {
        largeDone = clock.elapsedMilliseconds;
        return r;
      });
      // Once it is being rendered: two small ones at once. One waits its turn; the queue holds no second.
      for (var i = 0; i < 200 && ((await _status())?['rendering'] ?? 0) == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final asked = clock.elapsedMilliseconds;
      final small = await Future.wait([
        _render('$root/fair/a', jobs.first.args),
        _render('$root/fair/b', jobs.first.args),
      ]);
      final smallDone = clock.elapsedMilliseconds;
      final stillGoing = largeDone == null;
      final l = await large;
      expect(l.exit, lessThan(2), reason: '${l.said}\n${l.err}');
      final served = small.where((r) => r.exit == refs['site']!.exit && r.said == refs['site']!.said).toList();
      final refused = small.where((r) => r.exit == 2 && r.err.contains('The render server is busy')).toList();
      expect(served.length + refused.length, 2, reason: [for (final r in small) '${r.exit}: ${r.said}\n${r.err}'].join('\n'));
      expect(served, isNotEmpty, reason: 'Both were refused.');
      expect(await _differ(served.first.out, '$root/ref/site'), isNull);
      // ignore: avoid_print
      print('large request: ${largeDone!} ms; the small one asked at $asked ms was answered at $smallDone ms; ${refused.length} refused as busy');
      expect(stillGoing, isTrue, reason: 'The small request was answered only after the large one ($largeDone ms) was over.');
      expect(smallDone - asked, lessThan((largeDone! - asked) ~/ 2), reason: 'The small request waited for most of the large one.');
      // The large one went on from where it was: its captures are those of a run nothing interrupted.
      expect('\n${l.said}'.split('\nwrote ').length - 1, 20 * 5);
      final again = await _render('$root/fair/large2', ['$root/sites/site', '$root/sites/capture', '$root/sites/look', '--sizes', sizes]);
      expect(l.said, again.said);
      expect(await _differ('$root/fair/large', '$root/fair/large2'), isNull);
    });
  });

  group('four workers', () {
    setUpAll(() async {
      if (skip != null) return;
      skip = await _serve('$root/server4', ['--workers', '4']);
      if (skip != null) skip = 'No render server could start here: $skip';
    });

    test('separate agents rendering at the same moment each get their own site, time and sizes', () async {
      if (skip != null) return markTestSkipped(skip!);
      if (refs.length <= jobs.length) return markTestSkipped('No references were rendered.');
      for (var round = 0; round < 3; round++) {
        final runs = await Future.wait([
          for (final job in jobs) _render('$root/par$round/${job.name}', job.args),
          for (final job in jobs.take(4)) _render('$root/par$round/${job.name}-again', job.args),
        ]);
        for (final (i, r) in runs.indexed) {
          final name = i < jobs.length ? jobs[i].name : jobs[i - jobs.length].name;
          expect(r.err, contains(', the render server (pid '), reason: name);
          expect(r.exit, refs[name]!.exit, reason: '$name: ${r.said}\n${r.err}');
          expect(r.said, refs[name]!.said, reason: name);
          expect(await _differ(r.out, '$root/ref/$name'), isNull, reason: name);
        }
      }
      final s = (await _status())!;
      expect(s['failed'], 0);
      expect((s['workers'] as List).where((w) => ((w as Map)['requests'] as int) > 0).length, greaterThan(1), reason: 'One worker rendered everything.');
    });

    test('a request of many captures is shared among the workers and comes to the same files, in the same order', () async {
      if (skip != null) return markTestSkipped(skip!);
      if (refs['many'] == null) return markTestSkipped('No reference was rendered.');
      final before = {for (final w in ((await _status())!['workers'] as List).cast<Map>()) w['id']: w['captures'] as int};
      for (var round = 0; round < 3; round++) {
        final r = await _render('$root/fan$round/many', many);
        expect(r.exit, refs['many']!.exit, reason: '${r.said}\n${r.err}');
        expect(r.said, refs['many']!.said);
        expect(await _differ('$root/fan$round/many', '$root/ref/many'), isNull);
      }
      final after = {for (final w in ((await _status())!['workers'] as List).cast<Map>()) w['id']: w['captures'] as int};
      final took = after.keys.where((id) => after[id]! > (before[id] ?? 0)).length;
      expect(took, greaterThan(1), reason: 'One worker rendered every capture: $before, then $after');
    });

    test('a worker that stops during a request is replaced, and the request still gives its files', () async {
      if (skip != null) return markTestSkipped(skip!);
      final sizes = [for (var w = 400; w < 400 + 20 * 16; w += 16) '${w}x800'].join(',');
      final args = ['$root/sites/site', '$root/sites/capture', '$root/sites/look', '--sizes', sizes];
      final ref = await _render('$root/kill/ref', args);
      final run = _render('$root/kill/run', args);
      // The worker that leads it, once it is rendering.
      int? victim;
      for (var i = 0; i < 400 && victim == null; i++) {
        final s = await _status();
        victim = ((s?['workers'] as List?) ?? const []).cast<Map>().where((w) => w['state'] == 'busy').firstOrNull?['pid'] as int?;
        if (victim == null) await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      expect(victim, isNotNull, reason: 'No worker was seen rendering.');
      Process.killPid(victim!, ProcessSignal.sigkill);
      final r = await run;
      expect(r.exit, ref.exit, reason: '${r.said}\n${r.err}');
      expect(r.said, ref.said);
      expect(await _differ('$root/kill/run', '$root/kill/ref'), isNull);
      // Another is started in its place.
      Map<String, Object?>? s;
      for (var i = 0; i < 300; i++) {
        s = await _status();
        if (s != null && (s['workers'] as List).length == 4 && (s['workers'] as List).every((w) => (w as Map)['pid'] != victim)) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect((s!['workers'] as List).length, 4);
      expect((s['workers'] as List).map((w) => (w as Map)['pid']), isNot(contains(victim)));
      expect(s['workerRestarts'], greaterThanOrEqualTo(1));
      // And it renders.
      final next = await _render('$root/kill/next', jobs.first.args);
      expect(next.said, refs['site']!.said);
    });

    test('says where it stands: its workers, its queue, what it served and how fast', () async {
      if (skip != null) return markTestSkipped(skip!);
      final r = await _bash(['tool/codelessly', 'serve', '--status']);
      expect(r.exitCode, 0);
      final said = '${r.stdout}';
      expect(said, contains(RegExp(r'4 of 4 workers up \(\d+ busy, \d+ idle\); \d+ requests queued \(limit \d+\)')));
      expect(said, contains(RegExp(r'\d+ requests served \(\d+ captures\), \d+ failed, \d+ refused as busy; latency median \d+ ms, p95 \d+ ms; [\d.]+ captures a second')));
      expect(RegExp(r'^\s+w\d+\s+pid \d+', multiLine: true).allMatches(said).length, 4);
    });

    test('the bench command measures it', () async {
      if (skip != null) return markTestSkipped(skip!);
      final r = await _bash(['tool/codelessly', 'bench', '--site', '$root/sites/look', '--shape', 'layout', '--clients', '1,4', '--requests', '3', '--json']);
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      final rows = (jsonDecode('${r.stdout}'.trim().split('\n').last) as List).cast<Map>();
      expect(rows.map((m) => m['clients']), [1, 4]);
      expect(rows.map((m) => m['requests']), [3, 12]);
      expect(rows.every((m) => m['failed'] == 0 && (m['layoutsPerSecond'] as num) > 0), isTrue, reason: '$rows');
    });
  });

  // `serve` with no --workers: one worker, and more only while work waits (tool/cli/src/autoscale.dart, whose
  // decisions test/tool/render_autoscale_test.dart tests on a clock of its own).
  group('workers that follow the load', () {
    /// `serve` as a person runs it, and nothing waited for after it returns.
    Future<String?> serveNow(String dir, List<String> options, {Map<String, String> environment = const {}}) async {
      await _stop();
      _server = dir;
      _started = true;
      final r = await _bash(['tool/codelessly', 'serve', '--idle', '900', ...options], environment: {..._env, ...environment});
      return r.exitCode == 0 ? null : '${r.stderr}'.trim().split('\n').last;
    }

    Map<String, Object?> scaling(Map<String, Object?> status) => (status['scaling'] as Map).cast<String, Object?>();

    /// [clients] at once, each sending [args] again and again for [seconds].
    Future<List<_Run>> load(String name, int clients, int seconds, List<String> args) async {
      final until = DateTime.now().add(Duration(seconds: seconds));
      final runs = <_Run>[];
      await Future.wait([
        for (var c = 0; c < clients; c++)
          () async {
            while (DateTime.now().isBefore(until)) {
              runs.add(await _render('$root/$name/c$c', args));
            }
          }(),
      ]);
      return runs;
    }

    test('one client, one render after another: one worker, no request waits for a warm-up, nothing is shared', () async {
      if (skip != null) return markTestSkipped(skip!);
      final failed = await serveNow('$root/serverA', const ['--min-workers', '1']);
      if (failed != null) return markTestSkipped('No render server could start here: $failed');
      final atStart = (await _status())!;
      expect((atStart['workers'] as List).length, 1, reason: 'serve --min-workers 1 starts one worker.');
      expect(scaling(atStart)['mode'], 'auto');
      // The requests a client sends right after `serve` returns, back to back.
      final single = ['$root/sites/capture', '--screen', 'tools', '--sizes', '390x844', '--now', '2026-01-01T09:00:00Z', '--dump-layout', '--timings'];
      final runs = [for (var i = 0; i < 8; i++) await _render('$root/lone/$i', single)];
      for (final (i, r) in runs.indexed) {
        expect(r.err, contains(', the render server (pid '), reason: 'request ${i + 1}');
        expect(r.err, isNot(contains('waits its turn')), reason: 'Request ${i + 1} waited for the worker (a warm-up round?).');
        // A request of one capture is one worker's run, as a render with no server: no shared folder to gather.
        final timings = r.err.split('\n').firstWhere((l) => l.startsWith('timings: render'), orElse: () => '');
        expect(timings, isNot(isEmpty));
        expect(timings, isNot(contains('gather')), reason: timings);
      }
      // And it gives what a render with no server gives, file for file.
      Directory('$root/none').createSync(recursive: true);
      final cold = await _render('$root/lone/cold', single, environment: {'CODELESSLY_RENDER_SERVER': '$root/none'});
      expect(cold.err, isNot(contains('the render server (pid')));
      expect(runs.last.exit, cold.exit, reason: '${runs.last.said}\n${runs.last.err}');
      expect(runs.last.said, cold.said);
      expect(await _differ(runs.last.out, '$root/lone/cold'), isNull);
      final s = (await _status())!;
      final workers = (s['workers'] as List).cast<Map>();
      expect(workers.length, 1, reason: 'One client rendering one page at a time needs one worker.');
      expect(workers.single['requests'], 8);
      expect(workers.single['warmupsLeft'], isNull, reason: 'The requests it rendered warmed it: no round is left to do.');
      expect(scaling(s)['limit'], 1);
      expect(scaling(s)['lastDecision'], isNull);
      // A request of several captures still goes the shared way, and gives what it gave.
      final two = await _render('$root/lone/two', [...jobs.first.args, '--timings']);
      expect(two.err, contains('gather'));
      if (refs['site'] != null) expect(two.said, refs['site']!.said);
    });

    test('with no option, four workers to start with and to keep', () async {
      if (skip != null) return markTestSkipped(skip!);
      final failed = await serveNow('$root/serverFour', const []);
      if (failed != null) return markTestSkipped('No render server could start here: $failed');
      Map<String, Object?>? s;
      for (var i = 0; i < 150; i++) {
        s = await _status();
        if (s != null && (s['workers'] as List).length == 4) break;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      expect((s!['workers'] as List).length, 4, reason: 'serve starts four workers: ${s['workers']}');
      expect(scaling(s)['mode'], 'auto');
      expect(scaling(s)['min'], 4);
      final said = '${(await _bash(['tool/codelessly', 'serve', '--status'])).stdout}';
      expect(said, contains(RegExp(r'Workers follow the load: limit \d+ now \(least 4, most not fixed\)')));
    });

    test('requests that wait add workers; idle ones are ended, down to one; the status says why', () async {
      if (skip != null) return markTestSkipped(skip!);
      final failed = await serveNow('$root/serverB', const ['--min-workers', '1', '--retire-after', '4']);
      if (failed != null) return markTestSkipped('No render server could start here: $failed');
      var most = 1;
      var watching = true;
      final watch = () async {
        while (watching) {
          final s = await _status();
          if (s != null && (s['workers'] as List).length > most) most = (s['workers'] as List).length;
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }();
      final runs = await load('up', 6, 8, jobs.first.args);
      watching = false;
      await watch;
      for (final r in runs) {
        expect(r.err, contains(', the render server (pid '));
        if (refs['site'] != null) expect(r.said, refs['site']!.said);
      }
      expect(most, greaterThan(1), reason: 'Six clients kept waiting on one worker.');
      final busy = (await _status())!;
      expect(scaling(busy)['limit'], greaterThan(1));
      expect('${(scaling(busy)['lastDecision'] as Map)['reason']}', contains('waiting with all'));
      expect((busy['workers'] as List).where((w) => ((w as Map)['requests'] as int) > 0).length, greaterThan(1), reason: 'One worker rendered everything.');
      final said = '${(await _bash(['tool/codelessly', 'serve', '--status'])).stdout}';
      expect(said, contains(RegExp(r'Workers follow the load: limit \d+ now \(least 1, most not fixed\)')));
      expect(said, contains(RegExp(r'Last scaling decision: [\d:]+ \d+ -> \d+: \d+ waiting with all \d+ busy')));
      // Nothing asks: back to one worker.
      Map<String, Object?>? s;
      for (var i = 0; i < 150; i++) {
        s = await _status();
        if (s != null && (s['workers'] as List).length == 1) break;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      expect((s!['workers'] as List).length, 1, reason: 'Idle workers were not ended: ${s['workers']}');
      expect(scaling(s)['limit'], 1);
      expect('${(scaling(s)['lastDecision'] as Map)['reason']}', contains('idle for 4 s'));
      expect(s['workerRestarts'], 0, reason: 'A worker that was ended was started again.');
      // The one that stayed renders; and a request of many captures brings workers back.
      final r = await _render('$root/up/after', many);
      if (refs['many'] != null) {
        expect(r.said, refs['many']!.said);
        expect(await _differ('$root/up/after', '$root/ref/many'), isNull);
      }
      expect(scaling((await _status())!)['limit'], greaterThan(1), reason: 'Twenty captures waited on one worker.');
    });

    test('a worker that does not start cuts the pool to what runs, and that level is remembered', () async {
      if (skip != null) return markTestSkipped(skip!);
      // (The first two workers start; none after them does.)
      final failed = await serveNow('$root/serverC', const ['--min-workers', '1'], environment: {'CODELESSLY_RENDER_DEBUG_FAIL_START_FROM': '2'});
      if (failed != null) return markTestSkipped('No render server could start here: $failed');
      final runs = await load('fail', 8, 8, jobs.first.args);
      for (final r in runs) {
        expect(r.exit, lessThan(2), reason: '${r.said}\n${r.err}');
        if (refs['site'] != null) expect(r.said, refs['site']!.said);
      }
      final s = (await _status())!;
      expect((s['workers'] as List).length, 2);
      final g = scaling(s);
      expect(g['limit'], 2);
      expect(g['refusals'], greaterThanOrEqualTo(1));
      expect('${g['lastRefusal']}', contains('a worker did not start'));
      expect(g['ceiling'], isNotNull, reason: 'The level that failed is not remembered: $g');
      expect(g['ceiling'], lessThanOrEqualTo(4));
      expect(s['failed'], 0);
    });

    test('--workers and its bounds are checked', () async {
      if (skip != null) return markTestSkipped(skip!);
      await _stop();
      _server = '$root/serverD';
      _started = true;
      final bad = await _bash(['tool/codelessly', 'serve', '--workers', 'several']);
      expect(bad.exitCode, 2);
      expect('${bad.stderr}', contains('--workers takes a whole number, or auto'));
      final help = await _bash(['tool/codelessly', 'serve', '--help']);
      expect(help.exitCode, 0);
      expect('${help.stdout}', allOf(contains('--workers n|auto'), contains('--min-workers'), contains('--max-workers'), contains('--retire-after')));
    });
  });
}
