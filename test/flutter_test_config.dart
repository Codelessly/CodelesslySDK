import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Goldens differ by a fraction of a percent between machines (font hinting
/// and antialiasing), so they compare with a small tolerance: a moved or
/// resized widget still fails.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final GoldenFileComparator current = goldenFileComparator;
  if (current is LocalFileComparator) {
    goldenFileComparator = TolerantGoldenComparator(
      current.basedir.resolve('flutter_test_config.dart'),
    );
  }
  await testMain();
}

/// A [LocalFileComparator] that passes images differing by at most
/// [tolerance] (a share of the pixels).
class TolerantGoldenComparator extends LocalFileComparator {
  TolerantGoldenComparator(super.testFile, {this.tolerance = 0.01});

  /// The largest share of pixels that may differ.
  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }
    final String error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
