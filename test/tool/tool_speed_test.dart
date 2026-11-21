// The toolkit's commands stay fast when warm: with the render server up (tool/codelessly serve) and the commands
// compiled, expanding a site and rendering one page each take well under a second on a developer's machine (a
// third of a second each when this was written; before, three to six seconds whatever the work, spent starting
// processes and compiling the notation from source). The bounds here are generous, for a slow machine: what they
// catch is the old floor coming back, not a few milliseconds.
//
// Run alone: `flutter test test/tool/tool_speed_test.dart`. It uses the render server that is up, else starts one
// for the test and stops it after; it is skipped when there is no bash, or no server can start. The times it
// measured are printed; `tool/codelessly render ... --timings` says where a slow one went.
@Timeout(Duration(minutes: 15))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The longest a warm command may take, in milliseconds (CODELESSLY_SPEED_BOUND_MS sets another).
final int _bound = int.tryParse(Platform.environment['CODELESSLY_SPEED_BOUND_MS'] ?? '') ?? 2500;

final String _sdk = Directory.current.path.replaceAll(r'\', '/');

Future<ProcessResult> _bash(List<String> args, {Map<String, String>? environment}) =>
    Process.run('bash', args, workingDirectory: _sdk, environment: environment, stdoutEncoding: utf8, stderrEncoding: utf8);

/// The fastest of [runs] runs of a command, in milliseconds, and its last result.
Future<(int, ProcessResult)> _fastest(List<String> args, {int runs = 3}) async {
  var best = 1 << 30;
  late ProcessResult last;
  for (var i = 0; i < runs; i++) {
    final clock = Stopwatch()..start();
    last = await _bash(args);
    best = clock.elapsedMilliseconds < best ? clock.elapsedMilliseconds : best;
  }
  return (best, last);
}

void main() {
  late Directory root;
  var startedServer = false;
  String? skip;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('tool_speed_test');
    try {
      if ((await Process.run('bash', ['-c', 'true'])).exitCode != 0) skip = 'bash does not run here.';
    } on ProcessException {
      skip = 'No bash on the PATH.';
    }
    if (skip != null || !File('$_sdk/tool/codelessly').existsSync()) {
      skip ??= 'Not run from the SDK\'s folder.';
      return;
    }
    // A small site: one page in the notation, expanded to the document the render draws.
    File('${root.path}/site/site.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({'schema': 3, 'pages': ['home.json'], 'variables': {'count': 3}}));
    File('${root.path}/pages/home.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('Column\n  Text "Hello"\n  Text "{count} items"\n  Row\n    Button "Save"\n    Button "Cancel"\n');
    final status = await _bash(['tool/codelessly', 'serve', '--status']);
    if (status.exitCode != 0 || !'${status.stdout}'.startsWith('Render server up')) {
      final start = await _bash(['tool/codelessly', 'serve', '--idle', '600']);
      if (start.exitCode != 0) {
        skip = 'No render server could start here: ${'${start.stderr}'.trim().split('\n').last}';
        return;
      }
      startedServer = true;
    }
  });

  tearDownAll(() async {
    if (startedServer) await _bash(['tool/codelessly', 'serve', '--stop']);
    root.deleteSync(recursive: true);
  });

  test('a warm expand of a site takes its own work, not the seconds of compiling it', () async {
    if (skip != null) return markTestSkipped(skip!);
    final site = root.path.replaceAll(r'\', '/');
    // The first run compiles the notation's commands when they changed.
    final first = await _bash(['tool/notation/notation.sh', 'expand', site, '--open']);
    if ('${first.stderr}'.contains('The notation needs codelessly_api')) return markTestSkipped('No codelessly_api with the notation beside the SDK.');
    expect(first.exitCode, 0, reason: '${first.stderr}');
    expect(File('$site/site/home.json').existsSync(), isTrue);
    final (ms, r) = await _fastest(['tool/notation/notation.sh', 'expand', site, '--open', '--timings']);
    printOnFailure('${r.stderr}');
    // ignore: avoid_print
    print('warm expand: $ms ms (bound $_bound)');
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect('${r.stdout}', contains('pages/home.txt -> site/home.json'));
    expect('${r.stderr}', contains(RegExp(r'timings: expand start \d+ ms, run \d+ ms; total \d+ ms')));
    expect(ms, lessThan(_bound), reason: 'A warm expand took $ms ms. What it said:\n${r.stderr}');
  });

  test('a warm render of one page at one size takes its drawing, not seconds of starting processes', () async {
    if (skip != null) return markTestSkipped(skip!);
    final site = root.path.replaceAll(r'\', '/');
    if (!File('$site/site/home.json').existsSync()) return markTestSkipped('The site was not expanded.');
    final args = ['tool/codelessly', 'render', '$site/site', '--out', '$site/out', '--screen', 'home', '--sizes', '390x844', '--timings'];
    // The first run compiles the toolkit's commands when they changed, and warms the server's code.
    final first = await _bash(args);
    expect(first.exitCode, 0, reason: '${first.stdout}\n${first.stderr}');
    if (!'${first.stderr}'.contains(', the render server (pid ')) {
      return markTestSkipped('The render server did not take the run (it serves older code, or stopped): ${'${first.stderr}'.split('\n').first}');
    }
    final (ms, r) = await _fastest(args);
    // ignore: avoid_print
    print('warm render, one page at one size: $ms ms (bound $_bound)');
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    final said = '${r.stderr}'.split('\n');
    expect(said.first, allOf(startsWith('Rendering with codelessly_sdk '), contains(', the render server (pid ')));
    expect('${r.stdout}', contains('home@390x844.png'));
    expect(File('$site/out/home@390x844.png').existsSync(), isTrue);
    // Where the time went, for whoever reads a failure: the render's phases, then the command's.
    expect(said.where((l) => l.startsWith('timings: render ')).single, contains(RegExp(r'show \d+ ms.*; total \d+ ms')));
    expect(said.where((l) => l.startsWith('timings: command ')).single, contains(RegExp(r'start \d+ ms, checks \d+ ms, render \d+ ms; total \d+ ms')));
    expect(ms, lessThan(_bound), reason: 'A warm render took $ms ms. What it said:\n${r.stderr}');
  });
}
