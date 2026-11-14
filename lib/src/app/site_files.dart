// The files a site ships beside its documents: the fonts it declares
// (`site.json`'s `fonts`, published with their path relative to the site)
// and its local images (an image paint's `url` written as `images/hero.jpg`).
// Both are read through the loader that loaded the site
// ([PublishAssetSource]), as a Flutter app reads its assets.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show ZLibDecoder;
import 'package:codelessly_api/codelessly_api.dart' show Json, PublishFont, isRelativeAssetPath, readMap;

import '../render/contracts.dart';
import 'fonts.dart';
import 'loader.dart';

/// The image files a document may name by a relative path, by extension,
/// with their media types.
const Map<String, String> siteImageTypes = {
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.gif': 'image/gif', '.webp': 'image/webp', //
  '.svg': 'image/svg+xml', '.bmp': 'image/bmp',
};

/// The media type of image file [path], or null when it is not one.
String? siteImageType(String path) {
  final lower = path.toLowerCase().split('?').first;
  for (final e in siteImageTypes.entries) {
    if (lower.endsWith(e.key)) return e.value;
  }
  return null;
}

/// Whether [value] names an image file beside the site (`images/hero.jpg`).
bool isSiteImage(String value) => isRelativeAssetPath(value) && siteImageType(value) != null;

/// Every site image [json] (a document's or layout's JSON) names, each once.
Set<String> siteImagesIn(Object? json) {
  final out = <String>{};
  void walk(Object? v) {
    if (v is String) {
      if (isSiteImage(v)) out.add(v.trim());
    } else if (v is Map) {
      v.values.forEach(walk);
    } else if (v is List) {
      v.forEach(walk);
    }
  }

  walk(json);
  return out;
}

/// [json] with each site image it names replaced by where it is read from:
/// the file's URL when [source] serves one, else a `data:` URL of its
/// bytes. A file [source] does not have stays as written (it draws nothing)
/// and is passed to [onMissing].
Future<Json> resolveSiteImages(Json json, PublishAssetSource source, {void Function(String path, Object error)? onMissing}) async {
  final paths = siteImagesIn(json);
  if (paths.isEmpty) return json;
  final resolved = <String, String>{};
  await Future.wait([
    for (final p in paths)
      () async {
        final url = source.assetUrl(p);
        if (url != null) {
          resolved[p] = '$url';
          return;
        }
        try {
          final bytes = await source.loadAsset(p);
          resolved[p] = 'data:${siteImageType(p)};base64,${base64Encode(bytes)}';
        } catch (e) {
          onMissing?.call(p, e);
        }
      }(),
  ]);
  Object? swap(Object? v) => switch (v) {
        final String s => resolved[s.trim()] ?? s,
        final Map<Object?, Object?> m => {for (final e in m.entries) e.key: swap(e.value)},
        final List<Object?> l => [for (final x in l) swap(x)],
        _ => v,
      };
  return readMap(swap(json)) ?? json;
}

/// An [ImageBytesLoader] that reads a site image ([isSiteImage]: a path
/// relative to the site, `images/7.jpg`) through the site's [files] (its
/// URL when they serve one, else its bytes), and every other URL through
/// [fallback]. What a site's literal paths get when the layout loads
/// ([resolveSiteImages]), for a path that only exists at run time: one a
/// binding builds (`images/${id}.jpg`).
final class SiteImageLoader implements ImageBytesLoader {
  const SiteImageLoader(this.fallback, this.files);

  final ImageBytesLoader fallback;
  final PublishAssetSource files;

  @override
  Future<Uint8List> load(String url) async {
    if (!isSiteImage(url)) return fallback.load(url);
    final path = url.trim();
    final served = files.assetUrl(path);
    if (served != null) return fallback.load('$served');
    return files.loadAsset(path);
  }
}

/// A [FontFetcher] that reads a site's declared fonts ([PublishFont.isSiteFile])
/// through the loader's files ([source]), and every other font through
/// [fallback]. WOFF files are unwrapped to the TrueType/OpenType file the
/// engine registers. A [GlyphFontFetcher] when [fallback] is one.
SiteFontFetcher siteFontFetcher(FontFetcher fallback, {PublishAssetSource? files}) =>
    fallback is GlyphFontFetcher ? _SiteGlyphFonts(fallback, files: files) : SiteFontFetcher(fallback, files: files);

/// See [siteFontFetcher].
class SiteFontFetcher implements FontFetcher {
  SiteFontFetcher(this.fallback, {this.files});

  final FontFetcher fallback;

  /// The site's files: the loader, when it has them.
  PublishAssetSource? files;

  @override
  Future<Uint8List?> fetch(PublishFont font) async {
    final files = this.files;
    if (!font.isSiteFile || files == null) return fallback.fetch(font);
    try {
      final sfnt = sfntOf(await files.loadAsset(font.url!));
      if (sfnt != null) return sfnt;
    } catch (_) {}
    // Not among the site's files: whatever the app's fetcher has of the family.
    return fallback.fetch(PublishFont(id: font.id, family: font.family, weight: font.weight, italic: font.italic));
  }
}

class _SiteGlyphFonts extends SiteFontFetcher implements GlyphFontFetcher {
  _SiteGlyphFonts(GlyphFontFetcher super.fallback, {super.files});

  @override
  Future<Uint8List?> fetchGlyphs(PublishFont font, String text) async =>
      font.isSiteFile ? null : (fallback as GlyphFontFetcher).fetchGlyphs(font, text);
}

/// The TrueType/OpenType bytes of font file [bytes]: as they are, or
/// unwrapped from WOFF 1.0 (zlib-compressed tables). Null for anything else:
/// WOFF2 (Brotli, not read), a collection (`.ttc`), not a font. [why] is
/// told the reason.
Uint8List? sfntOf(Uint8List bytes, {void Function(String reason)? why}) {
  if (bytes.length < 12) {
    why?.call('not a font file');
    return null;
  }
  final sig = String.fromCharCodes(bytes.sublist(0, 4));
  if (sig == 'wOFF') {
    try {
      return _woff(bytes);
    } catch (e) {
      why?.call('not a readable WOFF file ($e)');
      return null;
    }
  }
  if (sig == 'wOF2') {
    why?.call('WOFF2 (Brotli-compressed): not read. Use the .woff or .ttf of the same face '
        '(an npm @fontsource package ships a .woff beside each .woff2)');
    return null;
  }
  if (sig == 'ttcf') {
    why?.call('a font collection (.ttc): not read');
    return null;
  }
  final tag = ByteData.sublistView(bytes).getUint32(0);
  if (tag == 0x00010000 || sig == 'OTTO' || sig == 'true') return bytes;
  why?.call('not a font file');
  return null;
}

/// A WOFF file's TrueType/OpenType file (W3C WOFF 1.0): its tables
/// inflated, under an sfnt header and table directory.
Uint8List _woff(Uint8List bytes) {
  final b = ByteData.sublistView(bytes);
  final flavor = b.getUint32(4);
  final numTables = b.getUint16(12);
  final tables = <(String, int, Uint8List)>[];
  for (var i = 0; i < numTables; i++) {
    final rec = 44 + 20 * i;
    final tag = String.fromCharCodes(bytes.sublist(rec, rec + 4));
    final offset = b.getUint32(rec + 4), compLength = b.getUint32(rec + 8), origLength = b.getUint32(rec + 12);
    final checksum = b.getUint32(rec + 16);
    final raw = Uint8List.sublistView(bytes, offset, offset + compLength);
    tables.add((tag, checksum, compLength < origLength ? Uint8List.fromList(const ZLibDecoder().decodeBytes(raw)) : Uint8List.fromList(raw)));
  }
  tables.sort((a, c) => a.$1.compareTo(c.$1));
  final n = tables.length;
  var entrySelector = 0;
  while ((1 << (entrySelector + 1)) <= n) {
    entrySelector++;
  }
  final searchRange = (1 << entrySelector) * 16;
  final head = ByteData(12 + 16 * n)
    ..setUint32(0, flavor)
    ..setUint16(4, n)
    ..setUint16(6, searchRange)
    ..setUint16(8, entrySelector)
    ..setUint16(10, n * 16 - searchRange);
  var offset = 12 + 16 * n;
  for (var i = 0; i < n; i++) {
    final (tag, checksum, data) = tables[i];
    final rec = 12 + 16 * i;
    for (var k = 0; k < 4; k++) {
      head.setUint8(rec + k, tag.codeUnitAt(k));
    }
    head
      ..setUint32(rec + 4, checksum)
      ..setUint32(rec + 8, offset)
      ..setUint32(rec + 12, data.length);
    offset += (data.length + 3) & ~3;
  }
  final out = BytesBuilder(copy: false)..add(head.buffer.asUint8List());
  for (final (_, _, data) in tables) {
    out.add(data);
    final pad = ((data.length + 3) & ~3) - data.length;
    if (pad > 0) out.add(Uint8List(pad));
  }
  return out.takeBytes();
}
