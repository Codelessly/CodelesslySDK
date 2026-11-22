// The render server's parts that need no server to test: what its options and its status say, and the files
// the workers of one request share (tool/render/src/fan.dart). test/tool/render_parallel_test.dart tests the
// server itself.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/cli/src/common.dart' show UsageError;
import '../../tool/cli/src/memory.dart';
import '../../tool/cli/src/pool.dart';
import '../../tool/render/src/fan.dart';

void main() {
  test('--workers: a whole number is that many, auto (or nothing) follows the load', () {
    expect(workersOption(null), isNull);
    expect(workersOption('auto'), isNull);
    expect(workersOption('AUTO'), isNull);
    expect(workersOption('1'), 1);
    expect(workersOption('12'), 12);
    expect(() => workersOption('0'), throwsA(isA<UsageError>()));
    expect(() => workersOption('many'), throwsA(isA<UsageError>()));
  });

  test('how many requests at a time a client with many is told to send a server that follows its load', () {
    expect(parallelHint(processors: 32), 8);
    expect(parallelHint(processors: 8), 4);
    expect(parallelHint(processors: 1), 1);
    expect(parallelHint(processors: 32, most: 3), 3);
    expect(parallelHint(processors: 2, least: 4), 4);
  });

  test('the memory a raise must leave free: an eighth of the machine, half a gigabyte to two', () {
    expect(memoryReserveMb(128 * 1024), 2048);
    expect(memoryReserveMb(8 * 1024), 1024);
    expect(memoryReserveMb(2 * 1024), 512);
    expect(memoryReserveMb(null), 1024);
  });

  test('the machine\'s memory is read from the system, with no process started for it', () {
    final clock = Stopwatch()..start();
    final m = readMemory();
    final first = clock.elapsedMicroseconds;
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    expect(m, isNotNull);
    expect(m!.totalMb, greaterThan(256));
    expect(m.freeMb, inInclusiveRange(1, m.totalMb));
    // (A PowerShell start for the same number took a quarter of a second.)
    if (!Platform.isMacOS) expect(first, lessThan(50000), reason: 'Reading it took $first µs.');
    expect(memoryFromMeminfo('MemTotal:       16303428 kB\nMemFree:          812340 kB\nMemAvailable:    9234567 kB\n'), (totalMb: 15921, freeMb: 9018));
  });

  test('a request of one capture is told from its arguments', () {
    expect(asksOneCapture(['site', '--screen', 'home', '--sizes', '390x844', '--out', 'o']), isTrue);
    expect(asksOneCapture(['card.json', '--sizes', '390x844', '--out', 'o']), isTrue);
    expect(asksOneCapture(['site', '--screen', 'home', '--sizes', '390x844', '--dump-layout', '--out', 'o', '--tap', 'Save']), isTrue);
    // More than one capture, or not known to be one: shared as before.
    expect(asksOneCapture(['site', '--screen', 'home', '--sizes', '390x844,1440x900', '--out', 'o']), isFalse);
    expect(asksOneCapture(['site', '--screen', 'home', '--out', 'o']), isFalse, reason: 'No --sizes: the three default sizes.');
    expect(asksOneCapture(['site', '--sizes', '390x844', '--out', 'o']), isFalse, reason: 'Every page of the site.');
    expect(asksOneCapture(['site', '--screen', 'home', '--screen', 'settings', '--sizes', '390x844', '--out', 'o']), isFalse);
    expect(asksOneCapture(['a.json', 'b.json', '--sizes', '390x844', '--out', 'o']), isFalse);
    expect(asksOneCapture(['site', '--screen', 'home', '--sizes', '390x844', '--state', 'a', '--state', 'b']), isFalse);
    expect(asksOneCapture(['site', '--components-all', '--sizes', '390x844']), isFalse);
    expect(asksOneCapture(['--sheet', 'sheet.png', '--out', 'o', 'a.png']), isFalse);
  });

  test('what serve --status says of the number of workers', () {
    expect(scalingLine({'mode': 'fixed', 'limit': 4}), contains('4, fixed'));
    final said = scalingLine({
      'mode': 'auto', 'limit': 6, 'min': 1, 'max': null, 'learned': 6, 'ceiling': 8, 'ceilingUntil': '2026-01-01T12:02:00.000', 'retireAfterSeconds': 60,
      'freeMemoryMb': 9000, 'memoryReserveMb': 2048,
      'lastDecision': {'at': '2026-01-01T12:00:00.000', 'from': 8, 'to': 4, 'reason': 'more workers rendered no more at 8'},
    });
    expect(said, contains('limit 6 now (least 1, most not fixed)'));
    expect(said, contains('learned ceiling 8 (until 12:02:00)'));
    expect(said, contains('Last scaling decision: 12:00:00 8 -> 4: more workers rendered no more at 8.'));
    expect(scalingLine({'mode': 'auto', 'limit': 1, 'min': 1, 'retireAfterSeconds': 60}), contains('Last scaling decision: none yet.'));
  });

  group('the files the workers of a request share', () {
    late FanDir dir;
    setUp(() => dir = FanDir('${Directory.systemTemp.createTempSync('fan_test').path.replaceAll(r'\', '/')}/args.fan')..create());
    tearDown(() => Directory(dir.path).parent.deleteSync(recursive: true));

    test('a capture is one worker\'s: the first to claim it', () {
      expect(dir.claim(0, 0, 'w0'), isTrue);
      expect(dir.claim(0, 0, 'w1'), isFalse);
      expect(dir.claim(0, 1, 'w1'), isTrue);
      expect(dir.claim(1, 0, 'w1'), isTrue, reason: 'Another run\'s capture of the same number is another capture.');
      expect(dir.state(0).claimed, 2);
      expect(dir.state(1).claimed, 1);
    });

    test('where a run stands: who is on it, what is claimed and recorded, how many captures it has', () {
      expect(dir.state(0), (entered: 0, claimed: 0, recorded: 0, estimate: null, total: null, solo: false));
      dir
        ..enter(0, 'w0')
        ..enter(0, 'w1')
        ..writeEstimate(0, 6)
        ..claim(0, 0, 'w0')
        ..claim(0, 1, 'w1')
        ..writeRecord(0, 0, {'worker': 'w0', 'images': ['a.png']});
      expect(dir.state(0), (entered: 2, claimed: 2, recorded: 1, estimate: 6, total: null, solo: false));
      expect(dir.record(0, 0)!['images'], ['a.png']);
      expect(dir.record(0, 1), isNull);
      // The first estimate stands; a walk says the count for good.
      dir
        ..writeEstimate(0, 9)
        ..markSolo(0)
        ..writeWalk(0, {'total': 7, 'pre': <Object>[], 'heads': <String, Object>{}});
      expect(dir.state(0), (entered: 2, claimed: 2, recorded: 1, estimate: 6, total: 7, solo: true));
    });

    test('a worker that stopped gives back what it claimed and did not render, and nothing else', () {
      dir
        ..enter(0, 'w0')
        ..enter(0, 'w1')
        ..claim(0, 0, 'w0')
        ..writeRecord(0, 0, {'worker': 'w0'})
        ..claim(0, 1, 'w0')
        ..claim(0, 2, 'w1');
      expect(dir.release('w0'), 1);
      expect(dir.state(0), (entered: 1, claimed: 2, recorded: 1, estimate: null, total: null, solo: false));
      expect(dir.claim(0, 1, 'w2'), isTrue, reason: 'The capture given back is another worker\'s to take.');
      expect(dir.claim(0, 0, 'w2'), isFalse, reason: 'A rendered capture stays rendered.');
      expect(dir.claim(0, 2, 'w2'), isFalse, reason: 'Another worker\'s claim stands.');
    });

    test('the server asks a worker to make way, and takes it back', () {
      expect(dir.yieldAsked('w0'), isFalse);
      dir.askYield('w0');
      expect(dir.yieldAsked('w0'), isTrue);
      expect(dir.yieldAsked('w1'), isFalse);
      dir.clearYield('w0');
      expect(dir.yieldAsked('w0'), isFalse);
    });

    test('a request whose folder is gone (its client left) is nobody\'s work: nothing throws', () {
      Directory(dir.path).deleteSync(recursive: true);
      expect(dir.exists, isFalse);
      expect(dir.claim(0, 0, 'w0'), isFalse);
      dir
        ..enter(0, 'w0')
        ..writeRecord(0, 0, {})
        ..askYield('w0')
        ..clearYield('w0');
      expect(dir.release('w0'), 0);
      expect(dir.state(0).claimed, 0);
    });
  });
}
