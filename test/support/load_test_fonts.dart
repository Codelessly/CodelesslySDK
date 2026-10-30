import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads actual Material icon and Roboto text glyphs for SDK widget goldens.
/// Call from `setUpAll(loadTestFonts)`; a local family handles SDK scene text.
Future<void> loadTestFonts() async {
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
  final bytes = await File('../material_icons/assets/Roboto-Regular.ttf')
      .readAsBytes();
  for (final family in ['Roboto', 'Roboto Regular', 'TabsFixture Regular', '']) {
    await (FontLoader(family)
          ..addFont(Future.value(bytes.buffer.asByteData())))
        .load();
  }
}
