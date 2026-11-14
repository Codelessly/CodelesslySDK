// render.sh, the render command's launcher: which Flutter it runs, when it
// resolves dependencies, where codelessly_api comes from, and that runs
// started together take turns. Run against a copy of the script in a
// scratch SDK layout with a stand-in `flutter` that records its calls.
@TestOn('linux || mac-os')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A scratch layout: `<root>/sdk/tool/render/render.sh` (this checkout's
/// script), `<root>/sdk/pubspec.yaml`, and a stand-in flutter at
/// `<root>/flutter/bin/flutter`.
class Layout {
  Layout() : root = Directory.systemTemp.createTempSync('render_script_test').path {
    Directory('$sdk/tool/render').createSync(recursive: true);
    File('tool/render/render.sh').copySync('$sdk/tool/render/render.sh');
    File('$sdk/pubspec.yaml').writeAsStringSync('name: codelessly_sdk\n');
    Directory('$root/flutter/bin').createSync(recursive: true);
    // Records each call; `pub get` writes the package config; `test` writes
    // the harness's report and status (after [delay] seconds) and the times.
    File(flutter).writeAsStringSync(r'''#!/usr/bin/env bash
echo "$0 $*" >> "$CALLS"
case "$1" in
  pub) mkdir -p .dart_tool && echo '{}' > .dart_tool/package_config.json ;;
  test)
    echo "start $(date +%s.%N)" >> "$CALLS.times"
    sleep "${DELAY:-0}"
    echo "end $(date +%s.%N)" >> "$CALLS.times"
    echo "0 error(s), 0 warning(s)." > "$CODELESSLY_RENDER_ARGS.report"
    echo 0 > "$CODELESSLY_RENDER_ARGS.status" ;;
esac
''');
    Process.runSync('chmod', ['+x', flutter]);
  }

  final String root;
  String get sdk => '$root/sdk';
  String get flutter => '$root/flutter/bin/flutter';
  String get calls => '$root/calls';
  List<String> get callLines => File(calls).existsSync() ? File(calls).readAsLinesSync() : const [];

  Future<ProcessResult> run(Map<String, String> env, {String out = 'out'}) => Process.run(
        'bash',
        ['$sdk/tool/render/render.sh', 'site', '--out', '$root/$out'],
        workingDirectory: root,
        environment: {'PATH': '/usr/bin:/bin', 'HOME': root, 'CALLS': calls, ...env},
        includeParentEnvironment: false,
      );

  void dispose() => Directory(root).deleteSync(recursive: true);
}

void main() {
  late Layout l;
  setUp(() => l = Layout());
  tearDown(() => l.dispose());

  test('Flutter is found from FLUTTER_ROOT when FLUTTER is unset and the PATH has none', () async {
    final r = await l.run({'FLUTTER_ROOT': '${l.root}/flutter'});
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect(l.callLines.last, startsWith('${l.flutter} test --no-pub'));
  });

  test('Flutter is found on the PATH, and FLUTTER wins over both', () async {
    var r = await l.run({'PATH': '${l.root}/flutter/bin:/usr/bin:/bin'});
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect(l.callLines.last, contains('test --no-pub'));
    File('${l.root}/other').writeAsStringSync('#!/usr/bin/env bash\necho "other \$*" >> "\$CALLS"\nexec ${l.flutter} "\$@"\n');
    Process.runSync('chmod', ['+x', '${l.root}/other']);
    r = await l.run({'FLUTTER': '${l.root}/other', 'FLUTTER_ROOT': '${l.root}/flutter'});
    expect(l.callLines.where((c) => c.startsWith('other test')), hasLength(1));
  });

  test('no Flutter anywhere says exactly what to set, that master is needed, and exits 2', () async {
    // The usual install places are searched last; none of them here.
    final r = await l.run({'CODELESSLY_FLUTTER_PLACES': '${l.root}/nowhere/bin/flutter'});
    expect(r.exitCode, 2);
    expect('${r.stderr}', contains('FLUTTER=/path/to/flutter/bin/flutter tool/render/render.sh'));
    expect('${r.stderr}', contains('FLUTTER_ROOT'));
    expect('${r.stderr}', contains('master'));
  });

  test('Flutter in a usual install place outside the PATH is found', () async {
    final r = await l.run({'CODELESSLY_FLUTTER_PLACES': '${l.root}/nowhere/bin/flutter ${l.flutter}'});
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect(l.callLines.last, startsWith('${l.flutter} test --no-pub'));
  });

  test('every run first prints the SDK and API versions it uses', () async {
    File('${l.sdk}/pubspec.yaml').writeAsStringSync('name: codelessly_sdk\nversion: 30.1.0\n');
    Directory('${l.root}/CodelesslyAPI').createSync();
    File('${l.root}/CodelesslyAPI/pubspec.yaml').writeAsStringSync('name: codelessly_api\nversion: 30.1.0\n');
    final r = await l.run({'FLUTTER_ROOT': '${l.root}/flutter'});
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final first = '${r.stderr}'.split('\n').first;
    expect(first, allOf(contains('codelessly_sdk 30.1.0'), contains('codelessly_api 30.1.0'), contains('${l.root}/CodelesslyAPI')));
  });

  test('dependencies are resolved when they never were, and not again while they are current', () async {
    await l.run({'FLUTTER_ROOT': '${l.root}/flutter'});
    expect(l.callLines.where((c) => c.contains(' pub get')), hasLength(1));
    await l.run({'FLUTTER_ROOT': '${l.root}/flutter'});
    expect(l.callLines.where((c) => c.contains(' pub get')), hasLength(1));
    // A changed pubspec resolves again.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    File('${l.sdk}/pubspec.yaml').writeAsStringSync('name: codelessly_sdk\n# changed\n');
    await l.run({'FLUTTER_ROOT': '${l.root}/flutter'});
    expect(l.callLines.where((c) => c.contains(' pub get')), hasLength(2));
  });

  test('a sibling codelessly_api checkout is used through an override the script writes, and only then', () async {
    await l.run({'FLUTTER_ROOT': '${l.root}/flutter'});
    expect(File('${l.sdk}/pubspec_overrides.yaml').existsSync(), isFalse);
    Directory('${l.root}/CodelesslyAPI').createSync();
    File('${l.root}/CodelesslyAPI/pubspec.yaml').writeAsStringSync('name: codelessly_api\n');
    final r = await l.run({'FLUTTER_ROOT': '${l.root}/flutter'});
    final overrides = File('${l.sdk}/pubspec_overrides.yaml').readAsStringSync();
    expect(overrides, contains('path: ${l.root}/CodelesslyAPI'));
    expect('${r.stderr}', contains('Using codelessly_api from'));
    // The override is new: dependencies resolve again.
    expect(l.callLines.where((c) => c.contains(' pub get')), hasLength(2));
    // The sibling gone, the script's override goes with it.
    Directory('${l.root}/CodelesslyAPI').deleteSync(recursive: true);
    await l.run({'FLUTTER_ROOT': '${l.root}/flutter'});
    expect(File('${l.sdk}/pubspec_overrides.yaml').existsSync(), isFalse);
  });

  test('an override the checkout has of its own is left as it is', () async {
    Directory('${l.root}/CodelesslyAPI').createSync();
    File('${l.root}/CodelesslyAPI/pubspec.yaml').writeAsStringSync('name: codelessly_api\n');
    const mine = 'dependency_overrides:\n  codelessly_api:\n    path: ../elsewhere\n';
    File('${l.sdk}/pubspec_overrides.yaml').writeAsStringSync(mine);
    await l.run({'FLUTTER_ROOT': '${l.root}/flutter'});
    expect(File('${l.sdk}/pubspec_overrides.yaml').readAsStringSync(), mine);
  });

  test('runs started together on one checkout take turns: their flutter test runs never overlap', () async {
    await l.run({'FLUTTER_ROOT': '${l.root}/flutter'}); // resolve first
    File('${l.calls}.times').deleteSync();
    final runs = await Future.wait([
      for (var i = 0; i < 3; i++) l.run({'FLUTTER_ROOT': '${l.root}/flutter', 'DELAY': '1'}, out: 'out$i'),
    ]);
    for (final r in runs) {
      expect(r.exitCode, 0, reason: '${r.stderr}');
    }
    final times = [for (final line in File('${l.calls}.times').readAsLinesSync()) line.split(' ')];
    // start, end, start, end...: no start before the previous run's end.
    expect([for (final t in times) t[0]], ['start', 'end', 'start', 'end', 'start', 'end']);
    expect(runs.where((r) => '${r.stderr}'.contains('waiting')), isNotEmpty);
  });
}
