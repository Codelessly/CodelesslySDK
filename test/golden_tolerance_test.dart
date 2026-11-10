import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flutter_test_config.dart';

/// The tolerant golden comparator passes a sub-percent difference (font
/// antialiasing between machines) and still fails a real change.
void main() {
  Future<Uint8List> png(int changed) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 100, 100),
      Paint()..color = Colors.white,
    );
    // [changed] pixels out of 10,000 in black.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, changed / 10, 10),
      Paint()..color = Colors.black,
    );
    final ui.Image image = await recorder.endRecording().toImage(100, 100);
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return bytes!.buffer.asUint8List();
  }

  testWidgets('a small difference passes, a large one fails', (tester) async {
    await tester.runAsync(() async {
      final Directory dir = await Directory.systemTemp.createTemp('golden');
      final File golden = File('${dir.path}/g.png')
        ..writeAsBytesSync(await png(0));
      final TolerantGoldenComparator comparator = TolerantGoldenComparator(
        Uri.file('${dir.path}/test.dart'),
      );
      expect(await comparator.compare(await png(50), golden.uri), isTrue);
      await expectLater(
        comparator.compare(await png(500), golden.uri),
        throwsA(isA<FlutterError>()),
      );
    });
  });
}
