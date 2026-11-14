// Fonts for the render command: font files found in directories (an npm
// `@fontsource/*` package, a site's fonts folder, the system's font
// directories), each read for its real family, weight and style (the
// OpenType `name` and `OS/2` tables, not the file name), served to the SDK
// through a FontFetcher. TrueType/OpenType files are read as they are; a
// WOFF web font is decoded to the TrueType/OpenType file it wraps (its
// tables are zlib streams). Families a document names that no file
// provides are recorded, so the report can say which text fell back and
// where the command looked.
import 'dart:io';
import 'dart:typed_data';

import 'package:codelessly_api/codelessly_api.dart' show FontFamily, PublishFont;
import 'package:codelessly_sdk/codelessly_sdk.dart' show FontFetcher;
import 'package:codelessly_sdk/src/app/site_files.dart' show sfntOf;

export 'package:codelessly_sdk/src/app/site_files.dart' show sfntOf;

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

/// The system's font directories (Linux, macOS, Windows): what
/// `--fonts system` searches.
List<String> systemFontDirs() {
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
  return [
    '/usr/share/fonts', '/usr/local/share/fonts', '$home/.fonts', '$home/.local/share/fonts', //
    '/System/Library/Fonts', '/Library/Fonts', '$home/Library/Fonts',
    '${Platform.environment['WINDIR'] ?? r'C:\Windows'}\\Fonts',
  ];
}

/// [dirs] with `system` replaced by the system's font directories.
List<String> fontDirsOf(Iterable<String> dirs) => [
      for (final d in dirs)
        if (d == 'system') ...systemFontDirs() else d,
    ];

/// A font file the command found but cannot read, and why.
typedef UnreadFont = ({String path, String reason});

/// What [scanFonts] found: the faces, and the font files it could not use.
final List<UnreadFont> unreadFonts = [];

/// Where decoded web fonts are written (a TrueType/OpenType file each).
final Directory _decoded = Directory.systemTemp.createTempSync('codelessly-render-fonts');

/// The font files in [dirs] (searched recursively; `system`: the system's
/// font directories): `.ttf` and `.otf`, and `.woff` decoded. A font file
/// it cannot read is listed in [unreadFonts].
List<FontFace> scanFonts(Iterable<String> dirs) {
  final out = <FontFace>[];
  for (final dir in fontDirsOf(dirs)) {
    final type = FileSystemEntity.typeSync(dir);
    final files = type == FileSystemEntityType.file
        ? [File(dir)]
        : type == FileSystemEntityType.directory
            ? Directory(dir).listSync(recursive: true, followLinks: true).whereType<File>()
            : const <File>[];
    for (final f in files) {
      final lower = f.path.toLowerCase();
      if (!const ['.ttf', '.otf', '.woff', '.woff2', '.ttc'].any(lower.endsWith)) continue;
      final Uint8List bytes;
      try {
        bytes = f.readAsBytesSync();
      } catch (_) {
        continue;
      }
      String? reason;
      final sfnt = sfntOf(bytes, why: (r) => reason = r);
      if (sfnt == null) {
        unreadFonts.add((path: f.path, reason: reason ?? 'not read'));
        continue;
      }
      final face = readFontFace(sfnt);
      if (face == null) {
        unreadFonts.add((path: f.path, reason: 'its family name could not be read'));
        continue;
      }
      var path = f.path;
      if (!identical(sfnt, bytes)) {
        path = '${_decoded.path}/${out.length}-${f.uri.pathSegments.last}.ttf';
        File(path).writeAsBytesSync(sfnt);
      }
      out.add((family: face.family, weight: face.weight, italic: face.italic, path: path));
    }
  }
  return out;
}

/// A declared font file that could not be used: missing, or not read.
typedef DeclaredFontProblem = ({String family, String asset, String reason, bool missing});

/// The faces a site declares (`site.json`'s `fonts`, files relative to
/// [siteDir]), each under its declared family, weight and style (as a
/// pubspec's fonts are, whatever the file calls itself); a WOFF file is
/// decoded. Files that are missing or unreadable go to [problems].
List<FontFace> declaredFonts(List<FontFamily> families, String siteDir, List<DeclaredFontProblem> problems) {
  final out = <FontFace>[];
  for (final f in families) {
    for (final a in f.fonts) {
      final file = File('$siteDir/${a.asset}');
      if (!file.existsSync()) {
        problems.add((family: f.family, asset: a.asset, reason: 'no file ${file.path}', missing: true));
        continue;
      }
      if (a.asset.toLowerCase().endsWith('.woff2')) continue; // validation reports it (font_format)
      final bytes = file.readAsBytesSync();
      String? reason;
      final sfnt = sfntOf(bytes, why: (r) => reason = r);
      if (sfnt == null) {
        problems.add((family: f.family, asset: a.asset, reason: reason ?? 'not read', missing: false));
        continue;
      }
      var path = file.path;
      if (!identical(sfnt, bytes)) {
        path = '${_decoded.path}/declared-${out.length}-${file.uri.pathSegments.last}.ttf';
        File(path).writeAsBytesSync(sfnt);
      }
      out.add((family: f.family, weight: a.weight, italic: a.italic, path: path));
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
  ///
  /// A font package splits a face into subset files of the same family,
  /// weight and style (`latin`, `latin-ext`, `cyrillic`, `vietnamese`...):
  /// the one with the most of Latin text's characters is taken (ASCII
  /// first), so Latin text is not drawn from a Cyrillic subset as boxes.
  FontFace? match(String family, int weight, bool italic) {
    final same = [for (final f in faces) if (f.family.toLowerCase() == family.toLowerCase()) f];
    if (same.isEmpty) return null;
    int score(FontFace f) => (f.weight - weight).abs() + (f.italic == italic ? 0 : 1000);
    same.sort((a, b) {
      final s = score(a).compareTo(score(b));
      return s != 0 ? s : latinScore(b.path).compareTo(latinScore(a.path));
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

final Map<String, int> _latinScores = {};

/// How much of Latin text font file [path] covers: each printable ASCII
/// character counts 100, each other character up to U+024F (Latin-1 and
/// Latin Extended) 1.
int latinScore(String path) => _latinScores.putIfAbsent(path, () {
      final cov = fontCoverage(path);
      if (cov == null) return 0;
      var n = 0;
      for (var c = 0x20; c <= 0x24F; c++) {
        if (cov.contains(c)) n += c < 0x7F ? 100 : 1;
      }
      return n;
    });

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
