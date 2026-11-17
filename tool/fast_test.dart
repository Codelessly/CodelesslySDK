// The whole test suite in one fast run: `dart run tool/fast_test.dart`.
//
// `flutter test` compiles and starts every test file on its own, one after
// another: with 200+ files that is most of a run. This writes a few shard
// files (build/test_shards/shard_NN_test.dart), each calling the `main` of
// many test files inside a group named by the file, and runs those: a few
// compiles and processes instead of hundreds, the same tests.
//
//   dart run tool/fast_test.dart                 every test
//   dart run tool/fast_test.dart test/tool       the tests under a path
//   dart run tool/fast_test.dart --shards 24     how many shard files (default 24)
//   dart run tool/fast_test.dart -- --name foo   arguments after -- go to flutter test
//
// Tests in a shard share one process, so statics set by one file are seen by
// the next. A file that needs a process of its own runs as `flutter test`
// runs it: one with a file annotation (@TestOn, @Tags, @Timeout, @Skip), one
// under a folder with a flutter_test_config.dart, one comparing golden files
// (their paths are relative to the test file), and the files in [_alone].
import 'dart:io';

/// Files that pass alone and fail in a shard, with what they share.
const _alone = {
  // FontDemand's set of families asked for so far (a static).
  'test/app/fonts_test.dart',
  // The Firestore platform mock is installed once per process.
  'test/services/firebase_test.dart',
  // Compares pixels drawn with fonts another file may have registered.
  'test/migration/special_fields_test.dart',
};

const _out = 'build/test_shards';

Future<void> main(List<String> args) async {
  var shards = 24;
  final paths = <String>[];
  var passed = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--') {
      passed = args.sublist(i + 1);
      break;
    } else if (args[i] == '--shards' && i + 1 < args.length) {
      shards = int.parse(args[++i]);
    } else if (args[i] == '--help' || args[i] == '-h') {
      stdout.writeln('dart run tool/fast_test.dart [paths...] [--shards N] [-- flutter test arguments]');
      return;
    } else {
      paths.add(args[i].replaceAll(r'\', '/'));
    }
  }
  if (!File('pubspec.yaml').existsSync() || !Directory('test').existsSync()) {
    stderr.writeln('Run from the SDK\'s root (where pubspec.yaml and test/ are).');
    exit(2);
  }

  final files = [
    for (final f in Directory('test').listSync(recursive: true))
      if (f is File && f.path.endsWith('_test.dart')) f.path.replaceAll(r'\', '/'),
  ]..sort();
  bool wanted(String f) => paths.isEmpty || paths.any((p) => f == p || f.startsWith(p.endsWith('/') ? p : '$p/'));
  final alone = <String>[];
  final shared = <(String, int)>[];
  for (final f in files.where(wanted)) {
    final text = File(f).readAsStringSync();
    if (_alone.contains(f) || _ownProcess(f, text)) {
      alone.add(f);
    } else {
      shared.add((f, text.length));
    }
  }
  if (alone.isEmpty && shared.isEmpty) {
    stderr.writeln('No test files under ${paths.join(', ')}.');
    exit(2);
  }

  // The largest file first, each to the lightest shard so far.
  shared.sort((a, b) => b.$2.compareTo(a.$2));
  final count = shards.clamp(1, shared.isEmpty ? 1 : shared.length);
  final bins = [for (var i = 0; i < count; i++) <String>[]];
  final weights = List.filled(count, 0);
  for (final (f, size) in shared) {
    var least = 0;
    for (var i = 1; i < count; i++) {
      if (weights[i] < weights[least]) least = i;
    }
    bins[least].add(f);
    weights[least] += size;
  }

  final out = Directory(_out);
  if (out.existsSync()) out.deleteSync(recursive: true);
  out.createSync(recursive: true);
  final written = <String>[];
  for (var i = 0; i < count; i++) {
    final list = bins[i]..sort();
    if (list.isEmpty) continue;
    final name = '$_out/shard_${i.toString().padLeft(2, '0')}_test.dart';
    File(name).writeAsStringSync([
      '// Written by tool/fast_test.dart: the test files below in one process.',
      "import 'package:flutter_test/flutter_test.dart';",
      '',
      for (var j = 0; j < list.length; j++) "import '../../${list[j]}' as t$j;",
      '',
      'void main() {',
      for (var j = 0; j < list.length; j++) "  group('${list[j]}', t$j.main);",
      '}',
      '',
    ].join('\n'));
    written.add(name);
  }

  stdout.writeln('${shared.length} test files in ${written.length} shards, ${alone.length} on their own.');
  final watch = Stopwatch()..start();
  final process = await Process.start(
    'flutter',
    ['test', '--no-pub', ...passed, ...written, ...alone],
    mode: ProcessStartMode.inheritStdio,
    runInShell: true,
  );
  final code = await process.exitCode;
  stdout.writeln('Ran in ${(watch.elapsedMilliseconds / 1000).toStringAsFixed(1)} s.');
  exit(code);
}

/// Whether [file] has to run as its own `flutter test` file.
bool _ownProcess(String file, String text) {
  if (RegExp(r'^@(TestOn|Tags|Timeout|Skip|Retry)\(', multiLine: true).hasMatch(text)) return true;
  if (text.contains('matchesGoldenFile')) return true;
  for (var dir = File(file).parent; dir.path.replaceAll(r'\', '/') != 'test' && dir.path != dir.parent.path; dir = dir.parent) {
    if (File('${dir.path}/flutter_test_config.dart').existsSync()) return true;
  }
  return false;
}
