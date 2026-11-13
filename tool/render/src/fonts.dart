// Fonts for the render command: font files found in directories, each
// read for its real family, weight and style (the OpenType `name` and
// `OS/2` tables, not the file name), served to the SDK through a
// FontFetcher. Families a document names that no file provides are
// recorded, so the report can say which text fell back.
import 'dart:io';
import 'dart:typed_data';

import 'package:codelessly_api/codelessly_api.dart' show PublishFont;
import 'package:codelessly_sdk/codelessly_sdk.dart' show FontFetcher;

/// One font file: its family, weight (100–900) and style.
typedef FontFace = ({String family, int weight, bool italic, String path});

/// The family, weight and italic flag of the TrueType/OpenType file [bytes],
/// or null when it can't be read.
({String family, int weight, bool italic})? readFontFace(Uint8List bytes) {
  try {
    final data = ByteData.sublistView(bytes);
    final numTables = data.getUint16(4);
    int? nameAt, os2At;
    for (var i = 0; i < numTables; i++) {
      final rec = 12 + i * 16;
      final tag = String.fromCharCodes(bytes.sublist(rec, rec + 4));
      final offset = data.getUint32(rec + 8);
      if (tag == 'name') nameAt = offset;
      if (tag == 'OS/2') os2At = offset;
    }
    if (nameAt == null) return null;
    final count = data.getUint16(nameAt + 2);
    final strings = data.getUint16(nameAt + 4);
    final names = <int, String>{};
    for (var i = 0; i < count; i++) {
      final rec = nameAt + 6 + i * 12;
      final platform = data.getUint16(rec);
      final nameId = data.getUint16(rec + 6);
      final length = data.getUint16(rec + 8);
      final offset = data.getUint16(rec + 10);
      if (nameId != 1 && nameId != 16) continue;
      final start = nameAt + strings + offset;
      final raw = bytes.sublist(start, start + length);
      final String text;
      if (platform == 3 || platform == 0) {
        final units = [for (var j = 0; j + 1 < raw.length; j += 2) (raw[j] << 8) | raw[j + 1]];
        text = String.fromCharCodes(units);
      } else {
        text = String.fromCharCodes(raw);
      }
      // Prefer Windows/Unicode names over Mac Roman ones.
      if (!names.containsKey(nameId) || platform == 3) names[nameId] = text;
    }
    final family = names[16] ?? names[1];
    if (family == null || family.isEmpty) return null;
    var weight = 400;
    var italic = false;
    if (os2At != null) {
      weight = data.getUint16(os2At + 4);
      italic = (data.getUint16(os2At + 62) & 1) != 0;
    }
    return (family: family, weight: ((weight / 100).round() * 100).clamp(100, 900), italic: italic);
  } catch (_) {
    return null;
  }
}

/// The font files in [dirs] (searched recursively): `.ttf` and `.otf`.
List<FontFace> scanFonts(Iterable<String> dirs) {
  final out = <FontFace>[];
  for (final dir in dirs) {
    final d = Directory(dir);
    if (!d.existsSync()) continue;
    for (final f in d.listSync(recursive: true, followLinks: true).whereType<File>()) {
      final lower = f.path.toLowerCase();
      if (!lower.endsWith('.ttf') && !lower.endsWith('.otf')) continue;
      final face = readFontFace(f.readAsBytesSync());
      if (face != null) out.add((family: face.family, weight: face.weight, italic: face.italic, path: f.path));
    }
  }
  return out;
}

/// The fonts the render command always has: Roboto (the default family of a
/// Flutter app on Android and on the web, used for text that names no
/// family) and the MaterialIcons font, both from the Flutter SDK.
List<FontFace> defaultFonts(String flutterRoot) => scanFonts(['$flutterRoot/bin/cache/artifacts/material_fonts']);

/// A request for a font no file provides (or only in another weight or
/// style).
typedef FontMiss = ({String family, int weight, bool italic, String? substitute});

/// Serves [faces] to the SDK, recording what it asked for and didn't get.
class DirectoryFontFetcher implements FontFetcher {
  DirectoryFontFetcher(this.faces);

  final List<FontFace> faces;
  final List<FontMiss> misses = [];

  /// The face for [family] nearest [weight] and [italic]; null when the
  /// family has no file at all.
  FontFace? match(String family, int weight, bool italic) {
    final same = [for (final f in faces) if (f.family.toLowerCase() == family.toLowerCase()) f];
    if (same.isEmpty) return null;
    same.sort((a, b) {
      int score(FontFace f) => (f.weight - weight).abs() + (f.italic == italic ? 0 : 1000);
      return score(a).compareTo(score(b));
    });
    return same.first;
  }

  @override
  Future<Uint8List?> fetch(PublishFont font) async {
    // A family with no file at all is drawn in Roboto (the test
    // environment's own fallback draws boxes, which nobody can review).
    final face = match(font.family, font.weight, font.italic) ?? match('Roboto', font.weight, font.italic);
    if (face == null || face.family.toLowerCase() != font.family.toLowerCase() ||
        face.weight != font.weight || face.italic != font.italic) {
      final miss = (
        family: font.family,
        weight: font.weight,
        italic: font.italic,
        substitute: face == null ? null : '${face.family} ${face.weight}${face.italic ? ' italic' : ''}',
      );
      if (!misses.contains(miss)) misses.add(miss);
    }
    if (face == null) return null;
    return File(face.path).readAsBytesSync();
  }
}

/// Material icon names → their MaterialIcons font codepoints (Flutter's
/// `codepoints` file).
Map<String, int> materialCodepoints(String flutterRoot) {
  final f = File('$flutterRoot/bin/cache/artifacts/material_fonts/codepoints');
  if (!f.existsSync()) return const {};
  final out = <String, int>{};
  for (final line in f.readAsLinesSync()) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length == 2) out[parts[0]] = int.parse(parts[1], radix: 16);
  }
  return out;
}

/// The code points font file [path] has glyphs for (its `cmap` table,
/// formats 4 and 12), or null when it can't be read.
Set<int>? fontCoverage(String path) {
  try {
    final b = ByteData.sublistView(File(path).readAsBytesSync());
    final numTables = b.getUint16(4);
    int? cmapAt;
    for (var i = 0; i < numTables; i++) {
      final rec = 12 + 16 * i;
      final tag = String.fromCharCodes([for (var k = 0; k < 4; k++) b.getUint8(rec + k)]);
      if (tag == 'cmap') cmapAt = b.getUint32(rec + 8);
    }
    if (cmapAt == null) return null;
    final out = <int>{};
    final count = b.getUint16(cmapAt + 2);
    for (var i = 0; i < count; i++) {
      final rec = cmapAt + 4 + 8 * i;
      final platform = b.getUint16(rec), encoding = b.getUint16(rec + 2);
      if (!(platform == 3 && (encoding == 1 || encoding == 10)) && platform != 0) continue;
      final sub = cmapAt + b.getUint32(rec + 4);
      final format = b.getUint16(sub);
      if (format == 4) {
        final segs = b.getUint16(sub + 6) ~/ 2;
        final ends = sub + 14, starts = ends + 2 * segs + 2, deltas = starts + 2 * segs, offsets = deltas + 2 * segs;
        for (var s = 0; s < segs; s++) {
          final end = b.getUint16(ends + 2 * s), start = b.getUint16(starts + 2 * s);
          final delta = b.getInt16(deltas + 2 * s), ro = b.getUint16(offsets + 2 * s);
          for (var c = start; c <= end && c != 0xFFFF; c++) {
            int glyph;
            if (ro == 0) {
              glyph = (c + delta) & 0xFFFF;
            } else {
              final at = offsets + 2 * s + ro + 2 * (c - start);
              glyph = b.getUint16(at);
              if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
            }
            if (glyph != 0) out.add(c);
          }
        }
      } else if (format == 12) {
        final groups = b.getUint32(sub + 12);
        for (var g = 0; g < groups; g++) {
          final at = sub + 16 + 12 * g;
          final start = b.getUint32(at), end = b.getUint32(at + 4), glyph = b.getUint32(at + 8);
          for (var c = start; c <= end; c++) {
            if (glyph + (c - start) != 0) out.add(c);
          }
        }
      }
    }
    return out;
  } catch (_) {
    return null;
  }
}
