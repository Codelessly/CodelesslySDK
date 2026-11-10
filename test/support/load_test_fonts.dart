import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads actual Material icon and Roboto text glyphs for SDK widget goldens.
/// Call from `setUpAll(loadTestFonts)`; a local family handles SDK scene text.
Future<void> loadTestFonts() async {
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
  // Kept with the tests (Roboto, Apache License 2.0), so they run from a
  // checkout of this repository alone, as CI has.
  final bytes = await File('test/support/fonts/Roboto-Regular.ttf')
      .readAsBytes();
  for (final family in [
    'Roboto',
    'Roboto Regular',
    'TabsFixture Regular',
    '',
  ]) {
    await (FontLoader(
      family,
    )..addFont(Future.value(bytes.buffer.asByteData()))).load();
  }
}
