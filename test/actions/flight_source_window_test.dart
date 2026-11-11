import 'package:codelessly_sdk/src/render/play.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    timeDilation = 1;
    FlightRegistry.reset();
  });

  test('a let-go source is kept for two seconds of animation time', () async {
    const rect = Rect.fromLTWH(10, 20, 30, 30);
    FlightRegistry.recordDrop('react', rect);
    expect(FlightRegistry.sourceOf('react'), rect);

    // Slowed 20 times, a second of wall time is 50 ms of animation: still
    // there, so the node that shows the key next flies from it.
    timeDilation = 20;
    FlightRegistry.recordDrop('slow', rect);
    await Future<void>.delayed(const Duration(milliseconds: 2100));
    expect(FlightRegistry.sourceOf('slow'), rect);

    // At normal speed it's gone after two seconds.
    timeDilation = 1;
    expect(FlightRegistry.sourceOf('slow'), isNull);
  });
}
