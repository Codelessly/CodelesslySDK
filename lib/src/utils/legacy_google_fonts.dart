import 'dart:async';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'legacy_google_fonts.g.dart';

export 'legacy_google_fonts.g.dart';

/// Loads Google Fonts families that the google_fonts package no longer
/// carries, straight from their files on fonts.gstatic.com.
///
/// Google merged width and optical-size families ("Roboto Condensed",
/// "IBM Plex Sans Condensed", "Big Shoulders Stencil Display") into
/// variable fonts, and google_fonts dropped the old names. The editor still
/// offers them and projects use them, so text in these families would fall
/// back to the default font. [ensure] registers each weight a text style
/// asks for under the family's own name the first time it is needed; text
/// lays out again by itself once the font arrives.
abstract final class LegacyGoogleFonts {
  static final Map<String, Future<void>> _loading = {};

  /// Fetches font files (replaceable in tests).
  static Future<Uint8List> Function(String url) fetch = (url) async {
    final http.Response response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Font ${response.statusCode}: $url');
    }
    return response.bodyBytes;
  };

  /// Registers a font with the engine (replaceable in tests).
  static Future<void> Function(String family, Uint8List bytes) register =
      (family, bytes) => (FontLoader(
        family,
      )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();

  /// Whether [family] is one of these families.
  static bool has(String family) => legacyGoogleFontFiles.containsKey(family);

  /// The file key (`700`, `400italic`) closest to [weight] in [family]:
  /// the same style if it has one, then the nearest weight.
  static String? variantFor(String family, int weight, bool italic) {
    final Map<String, String>? files = legacyGoogleFontFiles[family];
    if (files == null || files.isEmpty) return null;
    String? best;
    int bestScore = 1 << 30;
    for (final String key in files.keys) {
      final bool keyItalic = key.endsWith('italic');
      final int keyWeight = int.tryParse(key.replaceAll('italic', '')) ?? 400;
      final int score =
          (keyItalic == italic ? 0 : 10000) + (keyWeight - weight).abs();
      if (score < bestScore) {
        bestScore = score;
        best = key;
      }
    }
    return best;
  }

  /// Starts loading [family] at [weight] and style unless it is loaded or
  /// loading; returns when it is ready (errors are swallowed: the text keeps
  /// its fallback font).
  static Future<void> ensure(
    String family, {
    int weight = 400,
    bool italic = false,
  }) {
    final String? key = variantFor(family, weight, italic);
    if (key == null) return Future.value();
    final String url = legacyGoogleFontFiles[family]![key]!;
    return _loading.putIfAbsent(url, () async {
      try {
        await register(family, await fetch(url));
      } catch (_) {
        // Leave it: the text stays in the fallback font.
      }
    });
  }

  /// Forgets what was loaded (tests).
  static void reset() => _loading.clear();
}
