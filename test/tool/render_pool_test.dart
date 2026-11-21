// The render server's parts that need no server to test: how many workers it starts by default, and the files
// the workers of one request share (tool/render/src/fan.dart). test/tool/render_parallel_test.dart tests the
// server itself.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/cli/src/pool.dart';
import '../../tool/render/src/fan.dart';

void main() {
  test('the default number of workers: half the processors, what half the memory holds at a gigabyte each, 16 at most', () {
    expect(defaultWorkers(processors: 32, memoryMb: 128 * 1024), 16);
    expect(defaultWorkers(processors: 64, memoryMb: 512 * 1024), 16);
    expect(defaultWorkers(processors: 16, memoryMb: 16 * 1024), 8);
    expect(defaultWorkers(processors: 16, memoryMb: 8 * 1024), 4);
    expect(defaultWorkers(processors: 8, memoryMb: 16 * 1024), 4);
    expect(defaultWorkers(processors: 4, memoryMb: 2 * 1024), 1);
    expect(defaultWorkers(processors: 1, memoryMb: 64 * 1024), 1);
    // What the default leaves a 16 GB machine when every worker has grown to where it is replaced.
    expect(defaultWorkers(processors: 32, memoryMb: 16 * 1024) * defaultRecycleMb, lessThanOrEqualTo(8 * 1024));
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
