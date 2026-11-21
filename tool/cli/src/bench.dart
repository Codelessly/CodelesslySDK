// How much the render server gives: `tool/codelessly bench`.
//
//   tool/codelessly bench --site <site folder> [--shape layout|one|site|layout-site] [--clients 1,4,16]
//       [--seconds 5 | --requests n] [--screen name] [--size 390x844] [--out dir] [--json]
//
// Starts C clients at once, each asking the render server (tool/codelessly serve, which must be up) for the same
// kind of render again and again, as C separate agents would: each client has its own copy of the site and its
// own --out. Prints, for each number of clients, the requests and the captures a second, the time a request took
// (median, 95th percentile, longest) and how many failed. The clients ask from this one process over the server's
// socket, as tool/codelessly render does, so what is measured is the server, not the start of a command.
//
// The shapes: `layout` is one page at one size with --layout-only (the layout and the diagnostics, no picture);
// `one` is one page at one size with its picture; `site` is every page at the three default sizes with pictures;
// `layout-site` is that with --layout-only.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'common.dart';
import 'pool.dart';
import 'render_client.dart';

const _doc = '''tool/codelessly bench --site <site folder> [--shape layout|one|site|layout-site] [--clients 1,4,16]
    [--seconds 5 | --requests n] [--screen name] [--size 390x844] [--out dir] [--json]

How many layouts and captures a second the render server gives (tool/codelessly serve must be up): C clients at
once, each with its own copy of the site and its own output folder, each asking again and again for --seconds (or
--requests times). Shapes: layout (one page, one size, --layout-only: no picture), one (one page, one size, with
its picture), site (every page at the three default sizes), layout-site (that, --layout-only). --screen names the
page of the one-page shapes (default: the first site.json lists). Prints requests and captures a second, the
latency (median, p95, longest) and the failures for each number of clients; --json prints them as JSON.''';

Future<int> benchMain(List<String> argv) async {
  final a = Args(argv, valued: const {'--site', '--shape', '--clients', '--seconds', '--requests', '--screen', '--size', '--out'});
  if (a.help || a['--site'] == null) return usage(_doc, asked: a.help);
  final site = Directory(absolute(a['--site']!));
  if (!File('${site.path}/site.json').existsSync()) throw UsageError('--site: no site.json in ${site.path}.');
  final shape = a['--shape'] ?? 'layout';
  if (!const {'layout', 'one', 'site', 'layout-site'}.contains(shape)) throw UsageError('--shape takes layout, one, site or layout-site (given "$shape").');
  final levels = [for (final c in (a['--clients'] ?? '1,4,16').split(',')) int.tryParse(c.trim()) ?? 0];
  if (levels.any((c) => c < 1)) throw UsageError('--clients takes numbers of clients, 1 or more each (1,4,16).');
  final seconds = double.tryParse(a['--seconds'] ?? '5') ?? 5;
  final requests = a['--requests'] == null ? null : int.tryParse(a['--requests']!);
  final size = a['--size'] ?? '390x844';
  var screen = a['--screen'];
  if (screen == null) {
    final pages = ((jsonDecode(File('${site.path}/site.json').readAsStringSync()) as Map)['pages'] as List?) ?? const [];
    if (pages.isEmpty) throw const UsageError('The site lists no pages: name one with --screen.');
    screen = '${pages.first}'.split('/').last.replaceFirst(RegExp(r'\.json$'), '');
  }
  final statusText = await askServer('status');
  if (statusText == null || !statusText.startsWith('{')) {
    stderr.writeln('No render server is up on this checkout: tool/codelessly serve [--workers n] starts one.');
    return 2;
  }
  final server = (jsonDecode(statusText) as Map).cast<String, Object?>();
  final at = File('$renderServerDir/port').readAsStringSync().trim().split(' ');
  final port = int.parse(at[0]), token = at[1];
  final ownOut = a['--out'] == null;
  final root = Directory(ownOut ? Directory.systemTemp.createTempSync('codelessly_bench').path : absolute(a['--out']!))..createSync(recursive: true);
  final base = root.path.replaceAll(r'\', '/');
  final most = levels.reduce(max);
  // Each client's own copy of the site, with what is beside it that a render reads (the vocabulary record).
  for (var c = 0; c < most; c++) {
    final copy = Directory('$base/c$c/site');
    if (copy.existsSync()) continue;
    _copy(site, copy);
    final record = File('${site.parent.path}/vocabulary.json');
    if (record.existsSync()) record.copySync('$base/c$c/vocabulary.json');
  }
  List<String> argsOf(int c) => [
        '$base/c$c/site', '--out', '$base/c$c/out',
        if (shape == 'layout' || shape == 'one') ...['--screen', screen!, '--sizes', size],
        if (shape == 'layout' || shape == 'layout-site') '--layout-only',
      ];
  final what = shape.startsWith('layout') ? 'layouts' : 'captures';
  final results = <Map<String, Object?>>[];
  if (!a.has('--json')) {
    stdout.writeln('Render server: ${server['workerCount']} workers (${(server['workers'] as List).length} up). Shape $shape'
        '${shape == 'layout' || shape == 'one' ? ' (screen $screen at $size)' : ''}, ${requests == null ? '${seconds}s' : '$requests requests'} for each number of clients.');
    stdout.writeln('clients  requests  failed  requests/s  $what/s  median ms  p95 ms  max ms');
  }
  // Once before measuring: the first render of a site on a worker reads its fonts and compiles what it runs.
  await Future.wait([for (var c = 0; c < most; c++) _ask(port, token, argsOf(c), '$base/c$c/out')]);
  for (final clients in levels) {
    final latencies = <int>[];
    var made = 0, failed = 0, count = 0;
    String? firstFailure;
    final clock = Stopwatch()..start();
    final until = Duration(microseconds: (seconds * 1000000).round());
    Future<void> client(int c) async {
      for (var n = 0; requests == null ? clock.elapsed < until : n < requests; n++) {
        final one = Stopwatch()..start();
        final r = await _ask(port, token, argsOf(c), '$base/c$c/out');
        latencies.add(one.elapsedMilliseconds);
        count++;
        made += r.wrote;
        if (r.problem != null) {
          failed++;
          firstFailure ??= r.problem;
        }
      }
    }

    await Future.wait([for (var c = 0; c < clients; c++) client(c)]);
    final wall = clock.elapsedMicroseconds / 1000000;
    latencies.sort();
    int at(double share) => latencies.isEmpty ? 0 : latencies[min(latencies.length - 1, (latencies.length * share).floor())];
    final row = {
      'shape': shape,
      'workers': server['workerCount'],
      'clients': clients,
      'requests': count,
      'failed': failed,
      'seconds': double.parse(wall.toStringAsFixed(2)),
      'requestsPerSecond': double.parse((count / wall).toStringAsFixed(1)),
      '${what}PerSecond': double.parse((made / wall).toStringAsFixed(1)),
      'medianMs': at(0.5),
      'p95Ms': at(0.95),
      'maxMs': latencies.isEmpty ? 0 : latencies.last,
      'firstFailure': ?firstFailure,
    };
    results.add(row);
    if (!a.has('--json')) {
      stdout.writeln('${'$clients'.padLeft(7)}  ${'$count'.padLeft(8)}  ${'$failed'.padLeft(6)}  ${'${row['requestsPerSecond']}'.padLeft(10)}  '
          '${'${row['${what}PerSecond']}'.padLeft(what.length + 2)}  ${'${row['medianMs']}'.padLeft(9)}  ${'${row['p95Ms']}'.padLeft(6)}  ${'${row['maxMs']}'.padLeft(6)}');
      if (firstFailure != null) stdout.writeln('         first failure: $firstFailure');
    }
  }
  if (a.has('--json')) stdout.writeln(jsonEncode(results));
  if (ownOut) {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Left in the system's temporary folder.
    }
  }
  return results.any((r) => r['failed'] != 0) ? 1 : 0;
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

/// One render asked of the server, as tool/codelessly render asks it: how many files its report says it wrote,
/// and what went wrong (null: nothing; the run's own errors in the document are not a failure of the render).
Future<({int wrote, String? problem})> _ask(int port, String token, List<String> args, String out) async {
  Directory? work;
  Socket? socket;
  try {
    Directory(out).createSync(recursive: true);
    work = Directory(out).createTempSync('.render.');
    final argsFile = '${work.path.replaceAll(r'\', '/')}/args';
    File(argsFile).writeAsStringSync(args.map((x) => '$x\u0000').join());
    socket = await Socket.connect(InternetAddress.loopbackIPv4, port, timeout: const Duration(seconds: 5));
    final answer = await askRender(socket, token, argsFile);
    if (answer != 'done') return (wrote: 0, problem: answer ?? 'the server went away');
    final status = int.tryParse(File('$argsFile.status').readAsStringSync().trim()) ?? 2;
    final report = File('$argsFile.report').readAsStringSync();
    final wrote = '\n$report'.split('\nwrote ').length - 1;
    return (wrote: wrote, problem: status >= 2 ? 'exit status $status: ${report.trim().split('\n').last}' : null);
  } on Object catch (e) {
    return (wrote: 0, problem: '$e');
  } finally {
    socket?.destroy();
    try {
      work?.deleteSync(recursive: true);
    } on FileSystemException {
      // Left behind: a dot folder in the output.
    }
  }
}
