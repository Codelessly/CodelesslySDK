// Fonts of published layouts, registered with the engine (FontLoader).
//
// Every font of one family registers under the family's name, so a text
// style naming the family and a weight (as v2 text styles do) picks the
// matching file. Uploaded fonts come from their URL; a font without one is
// a Google Font, fetched by family, weight and style.
import 'dart:async';

import 'package:codelessly_api_v2/codelessly_api.dart' show PublishFont;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Gets the file of a font.
abstract interface class FontFetcher {
  /// The font file's bytes (TTF/OTF), or null when it can't be had.
  Future<Uint8List?> fetch(PublishFont font);
}

/// Fetches nothing: fonts fall back to the platform's. For tests and apps
/// that bundle their fonts.
class NoFontFetcher implements FontFetcher {
  const NoFontFetcher();

  @override
  Future<Uint8List?> fetch(PublishFont font) async => null;
}

/// Fetches fonts over HTTP: an uploaded font from its URL, a Google Font
/// through the Google Fonts CSS API.
class HttpFontFetcher implements FontFetcher {
  HttpFontFetcher({http.Client? client, this.googleFontsApi = 'https://fonts.googleapis.com/css2'})
      : _client = client; // ignore: prefer_initializing_formals

  final http.Client? _client;
  final String googleFontsApi;

  /// The Google Fonts CSS URL of [font].
  Uri googleFontsUrl(PublishFont font) => Uri.parse(
      '$googleFontsApi?family=${Uri.encodeQueryComponent(font.family).replaceAll('%20', '+')}:ital,wght@${font.italic ? 1 : 0},${font.weight}');

  Future<http.Response> _get(Uri url) async {
    final client = _client ?? http.Client();
    try {
      return await client.get(url);
    } finally {
      if (_client == null) client.close();
    }
  }

  @override
  Future<Uint8List?> fetch(PublishFont font) async {
    try {
      var url = font.url == null ? null : Uri.tryParse(font.url!);
      if (url == null) {
        // Without a browser's user agent, the API serves TrueType files.
        final css = await _get(googleFontsUrl(font));
        if (css.statusCode != 200) return null;
        final file = fontFileIn(css.body);
        if (file == null) return null;
        url = Uri.tryParse(file);
        if (url == null) return null;
      }
      final res = await _get(url);
      return res.statusCode == 200 ? res.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }
}

/// The font file a Google Fonts stylesheet [css] names for Latin text.
///
/// Asked from a browser, the API answers with one `@font-face` per unicode
/// subset (cyrillic-ext, greek, vietnamese, latin-ext, latin...), each its
/// own woff2 file; the first is not Latin, so taking it registered a font
/// without the letters the text uses. This takes the block marked
/// `/* latin */`, else the one whose `unicode-range` starts at U+0000, else
/// the only (or last) one; null when [css] names no file.
String? fontFileIn(String css) {
  final blocks = RegExp(r'(/\*\s*([\w-]+)\s*\*/\s*)?@font-face\s*\{([^}]*)\}').allMatches(css).toList();
  String? urlOf(String block) {
    final m = RegExp(r'url\(([^)]+)\)').firstMatch(block);
    return m?.group(1)!.replaceAll(RegExp(r'''['"]'''), '');
  }

  if (blocks.isEmpty) {
    final m = RegExp(r'url\(([^)]+)\)').firstMatch(css);
    return m?.group(1)!.replaceAll(RegExp(r'''['"]'''), '');
  }
  for (final b in blocks) {
    if (b.group(2) == 'latin') return urlOf(b.group(3)!);
  }
  for (final b in blocks) {
    if (RegExp(r'unicode-range:\s*U\+0000-').hasMatch(b.group(3)!)) return urlOf(b.group(3)!);
  }
  return urlOf(blocks.last.group(3)!);
}

/// Registers the fonts of published layouts with the engine, each once.
class CodelesslyFonts {
  CodelesslyFonts({this.fetcher = const NoFontFetcher(), Future<void> Function(String family, List<Uint8List> files)? register})
      : _register = register ?? _registerWithEngine;

  final FontFetcher fetcher;
  final Future<void> Function(String family, List<Uint8List> files) _register;
  final Map<String, Future<bool>> _fonts = {};

  /// Fonts registered (by id).
  Set<String> get loaded => {..._fonts.keys};

  /// Fetches and registers [fonts] not registered yet; completes when they
  /// are (a font that can't be fetched is skipped).
  Future<void> load(Iterable<PublishFont> fonts) async {
    final byFamily = <String, List<PublishFont>>{};
    for (final f in fonts) {
      if (_fonts.containsKey(f.id)) continue;
      byFamily.putIfAbsent(f.family, () => []).add(f);
    }
    final pending = <Future<bool>>[];
    for (final e in byFamily.entries) {
      final files = Future.wait(e.value.map(fetcher.fetch));
      final done = files.then((bytes) async {
        final ok = [...bytes.nonNulls];
        if (ok.isEmpty) return false;
        await _register(e.key, ok);
        return true;
      }).catchError((Object _) => false);
      for (final f in e.value) {
        _fonts[f.id] = done;
      }
      pending.add(done);
    }
    await Future.wait(pending);
  }

  static Future<void> _registerWithEngine(String family, List<Uint8List> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(f)));
    }
    await loader.load();
  }
}
