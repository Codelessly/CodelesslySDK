import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Goldens differ by a fraction of a percent between machines (font hinting
/// and antialiasing), so they compare with a small tolerance: a moved or
/// resized widget still fails.
///
/// Icons are hosted SVGs (icons.codelessly.com, fonts.gstatic.com), and a
/// widget test answers every real HTTP request with 400, which reports an
/// exception and fails the test. Icons load from a stand-in client that
/// serves a square glyph instead; a test can still set its own.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SvgIcon.httpClient ??= MockClient(
    (request) async => http.Response(
      _iconSvg,
      200,
      headers: const {'content-type': 'image/svg+xml'},
    ),
  );
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

/// A square glyph, the stand-in for every hosted icon in tests.
const String _iconSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<path d="M4 4h16v16H4z"/></svg>';
