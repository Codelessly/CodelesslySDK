import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads Roboto (from the Flutter SDK) as the test font, under the names
/// the goldens use, so screenshots show real text; and compares goldens
/// with a small tolerance, as the SDK's own tests do.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final String fonts =
      '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}'
      '/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final String file in files) {
      final f = File('$fonts/$file');
      if (f.existsSync()) {
        loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      }
    }
    await loader.load();
  }

  const all = ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf'];
  await load('Roboto', all);
  await load('GenUiTestSans', all);
  // The SDK names a weight's family "<family> <weight name>".
  await load('GenUiTestSans Regular', ['Roboto-Regular.ttf']);
  await load('GenUiTestSans Medium', ['Roboto-Medium.ttf']);
  await load('GenUiTestSans Semi Bold', ['Roboto-Medium.ttf']);
  await load('GenUiTestSans SemiBold', ['Roboto-Medium.ttf']);
  await load('GenUiTestSans Bold', ['Roboto-Bold.ttf']);
  final icons = File('$fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
  final GoldenFileComparator current = goldenFileComparator;
  if (current is LocalFileComparator) {
    goldenFileComparator = _TolerantComparator(
      current.basedir.resolve('flutter_test_config.dart'),
    );
  }
  await testMain();
}

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= 0.01) {
      result.dispose();
      return true;
    }
    final String error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
