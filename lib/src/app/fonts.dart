// Fonts of published layouts, registered with the engine (FontLoader).
//
// Every font of one family registers under the family's name, so a text
// style naming the family and a weight (as text styles do) picks the
// matching file. Uploaded fonts come from their URL; a font without one is
// a Google Font, fetched by family, weight and style.
import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart' show PublishFont;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:http/http.dart' as http;

import '../render/convert.dart' show FontDemand;

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
  HttpFontFetcher({
    http.Client? client,
    this.googleFontsApi = 'https://fonts.googleapis.com/css2',
  }) : _client = client; // ignore: prefer_initializing_formals

  final http.Client? _client;
  final String googleFontsApi;

  /// The Google Fonts CSS URL of [font].
  Uri googleFontsUrl(PublishFont font) => Uri.parse(
    '$googleFontsApi?family=${Uri.encodeQueryComponent(font.family).replaceAll('%20', '+')}:ital,wght@${font.italic ? 1 : 0},${font.weight}',
  );

  /// The Google Fonts CSS URL of [font]'s family alone (its default file).
  Uri googleFontsFamilyUrl(PublishFont font) => Uri.parse(
    '$googleFontsApi?family=${Uri.encodeQueryComponent(font.family).replaceAll('%20', '+')}',
  );

  /// The font file of Google Fonts [css]. Without a browser's user agent it
  /// names one TrueType file; in a browser it names one file per Unicode
  /// subset (`/* cyrillic */`, ..., `/* latin */`), each holding only that
  /// subset's glyphs: the `latin` one, else the last (the base subset comes
  /// last), else the only one. Taking the first drew Latin text in the
  /// platform's font. Null when the CSS names no file.
  static String? fontFileOf(String css) {
    String? clean(String? u) => u?.replaceAll(RegExp(r'''['"]'''), '').trim();
    final blocks = RegExp(
      r'(?:/\*\s*([\w-]+)\s*\*/\s*)?@font-face\s*\{([^}]*)\}',
    ).allMatches(css).toList();
    String? urlIn(String body) =>
        clean(RegExp(r'url\(([^)]+)\)').firstMatch(body)?.group(1));
    for (final b in blocks) {
      if (b.group(1) == 'latin') return urlIn(b.group(2)!);
    }
    for (final b in blocks.reversed) {
      if (urlIn(b.group(2)!) case final String u) return u;
    }
    return clean(RegExp(r'url\(([^)]+)\)').firstMatch(css)?.group(1));
  }

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
      // Platform fallback families are not Google Fonts. An uploaded file
      // with the same family still loads from its explicit URL.
      const platformFamilies = {'arial', 'helvetica', 'sans-serif', 'serif', 'monospace',
        'system-ui', 'times new roman', 'courier new'};
      if (font.url == null && platformFamilies.contains(font.family.toLowerCase())) return null;
      var url = font.url == null ? null : Uri.tryParse(font.url!);
      if (url == null) {
        // Without a browser's user agent, the API serves TrueType files.
        var css = await _get(googleFontsUrl(font));
        // A weight or style the family doesn't have (Anton asked for at
        // 700) is a 400: take the family's default file, which the engine
        // then draws bolder or slanted, rather than the platform's font.
        if (css.statusCode == 400) css = await _get(googleFontsFamilyUrl(font));
        if (css.statusCode != 200) return null;
        final file = fontFileOf(css.body);
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

/// Registers the fonts of published layouts with the engine, each once.
class CodelesslyFonts {
  CodelesslyFonts({
    this.fetcher = const NoFontFetcher(),
    Future<void> Function(String family, List<Uint8List> files)? register,
  }) : _register = register ?? _registerWithEngine {
    // Families only bindings reach are fetched when first drawn (Google
    // Fonts by name; a project's uploaded fonts are in the publish).
    if (fetcher is! NoFontFetcher) {
      FontDemand.handler ??= (family, weight, italic) => load([
            PublishFont(id: 'demand:$family/$weight/$italic', family: family, weight: weight, italic: italic),
          ]);
    }
  }

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
      final done = files
          .then((bytes) async {
            final ok = [...bytes.nonNulls];
            if (ok.isEmpty) return false;
            await _register(e.key, ok);
            return true;
          })
          .catchError((Object _) => false);
      for (final f in e.value) {
        _fonts[f.id] = done;
      }
      pending.add(done);
    }
    await Future.wait(pending);
  }

  // Engine registrations outlive an individual app/preview. Re-registering
  // identical files sends global font notifications to unrelated live trees.
  static final _engine = FontRegistrationCache(register: _loadEngineFonts);

  static Future<void> _registerWithEngine(
    String family,
    List<Uint8List> files,
  ) => _engine.load(family, files);

  static Future<void> _loadEngineFonts(
    String family,
    List<Uint8List> files,
  ) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(f)));
    }
    await loader.load();
  }
}

/// Deduplicates engine registrations by family and actual file bytes, including
/// concurrent loads and overlapping style sets. Failed loads remain retryable.
class FontRegistrationCache {
  FontRegistrationCache({required this.register});
  final Future<void> Function(String family, List<Uint8List> files) register;
  final Map<String, List<_RegisteredFont>> _families = {};

  Future<void> load(String family, List<Uint8List> files) async {
    final known = _families.putIfAbsent(family, () => []);
    final pending = <Future<void>>[];
    final fresh = <Uint8List>[];
    for (final bytes in files) {
      final existing = known
          .where((entry) => listEquals(entry.bytes, bytes))
          .firstOrNull;
      if (existing != null) {
        pending.add(existing.loaded);
      } else if (!fresh.any((other) => listEquals(other, bytes))) {
        fresh.add(bytes);
      }
    }
    if (fresh.isNotEmpty) {
      late final Future<void> done;
      done = Future<void>.sync(() => register(family, fresh)).catchError((
        Object error,
        StackTrace stack,
      ) {
        known.removeWhere((entry) => identical(entry.loaded, done));
        Error.throwWithStackTrace(error, stack);
      });
      known.addAll([
        for (final bytes in fresh)
          _RegisteredFont(Uint8List.fromList(bytes), done),
      ]);
      pending.add(done);
    }
    await Future.wait(pending);
  }
}

class _RegisteredFont {
  const _RegisteredFont(this.bytes, this.loaded);
  final Uint8List bytes;
  final Future<void> loaded;
}
