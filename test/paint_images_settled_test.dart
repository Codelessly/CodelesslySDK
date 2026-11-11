import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settled completes at once when nothing is loading', () async {
    expect(PaintImages.loading, isFalse);
    final watch = Stopwatch()..start();
    await PaintImages.settled(timeout: const Duration(seconds: 2));
    expect(watch.elapsedMilliseconds, lessThan(500));
  });
}
