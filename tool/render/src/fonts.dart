// Fonts for the render command: font files found in directories (an npm
// `@fontsource/*` package, a site's fonts folder, the system's font
// directories), each read for its real family, weight and style (the
// OpenType `name` and `OS/2` tables, not the file name), served to the SDK
// through a FontFetcher. TrueType/OpenType files are read as they are; a
// WOFF web font is decoded to the TrueType/OpenType file it wraps (its
// tables are zlib streams). Families a document names that no file
// provides are recorded, so the report can say which text fell back and
// where the command looked.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:codelessly_api/codelessly_api.dart' show FontFamily, PublishFont;
import 'package:codelessly_sdk/codelessly_sdk.dart' show FontFetcher;
import 'package:codelessly_sdk/src/app/site_files.dart' show sfntOf;

import 'google_fonts.dart' show googleStandInOf;
import 'site.dart' show sitePath;

export 'package:codelessly_sdk/src/app/site_files.dart' show sfntOf;

/// One font file: its family, weight (100–900) and style.
typedef FontFace = ({String family, int weight, bool italic, String path});

/// The family, weight and italic flag of the TrueType/OpenType file [bytes],
/// or null when it can't be read.
///
/// [weights] is the range of a variable font's `wght` axis (its `fvar`
/// table): the weights it draws, by a font variation; null for a static font.
({String family, int weight, bool italic, (int, int)? weights})? readFontFace(Uint8List bytes) {
  try {
    final data = ByteData.sublistView(bytes);
    final numTables = data.getUint16(4);
    int? nameAt, os2At, fvarAt;
    for (var i = 0; i < numTables; i++) {
      final rec = 12 + i * 16;
      final tag = String.fromCharCodes(bytes.sublist(rec, rec + 4));
      final offset = data.getUint32(rec + 8);
      if (tag == 'name') nameAt = offset;
      if (tag == 'OS/2') os2At = offset;
      if (tag == 'fvar') fvarAt = offset;
    }
    (int, int)? weights;
    if (fvarAt != null) {
      final axesAt = fvarAt + data.getUint16(fvarAt + 4);
      final axisCount = data.getUint16(fvarAt + 8);
      final axisSize = data.getUint16(fvarAt + 10);
      for (var i = 0; i < axisCount; i++) {
        final a = axesAt + i * axisSize;
        if (String.fromCharCodes(bytes.sublist(a, a + 4)) != 'wght') continue;
        final min = data.getInt32(a + 4) / 65536, max = data.getInt32(a + 12) / 65536;
        weights = ((min / 100).ceil() * 100, (max / 100).floor() * 100);
      }
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
    var weight = 400;
    var italic = false;
    if (os2At != null) {
      weight = data.getUint16(os2At + 4);
      italic = (data.getUint16(os2At + 62) & 1) != 0;
    }
    weight = ((weight / 100).round() * 100).clamp(100, 900);
    final family = names[16] ?? (names[1] == null ? null : typographicFamily(names[1]!, weight));
    if (family == null || family.isEmpty) return null;
    return (family: family, weight: weight, italic: italic, weights: weights);
  } catch (_) {
    return null;
  }
}

/// The family a font file's legacy family name (`name` ID 1) belongs to when the file has no typographic family
/// (ID 16): a face outside regular, bold, italic and bold italic is named with its weight in ID 1 ("IBM Plex Mono
/// SemiBold", weight 600), which is the family "IBM Plex Mono" at 600, as browsers and fontconfig read it. The
/// weight word is dropped only when it names the file's own weight (OS/2), so a family called "... Black" at 400
/// keeps its name.
String typographicFamily(String legacy, int weight) {
  final m = RegExp(r'^(.+?)[ -]+(Thin|Hairline|ExtraLight|Extra Light|UltraLight|Ultra Light|Light|Book|Medium|SemiBold|'
          r'Semi Bold|DemiBold|Demi Bold|ExtraBold|Extra Bold|UltraBold|Ultra Bold|Black|Heavy)$', caseSensitive: false)
      .firstMatch(legacy.trim());
  if (m == null) return legacy;
  final word = m.group(2)!.toLowerCase().replaceAll(' ', '');
  final named = switch (word) {
    'thin' || 'hairline' => 100,
    'extralight' || 'ultralight' => 200,
    'light' => 300,
    'book' => 400,
    'medium' => 500,
    'semibold' || 'demibold' => 600,
    'extrabold' || 'ultrabold' => 800,
    _ => 900,
  };
  return named == weight ? m.group(1)! : legacy;
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
Directory get _decoded => _decodedDir ??= Directory.systemTemp.createTempSync('codelessly-render-fonts');
Directory? _decodedDir;

/// Removes the decoded font files of this run (they were loaded into the
/// engine; nothing reads the files again).
void disposeDecodedFonts() {
  final d = _decodedDir;
  _decodedDir = null;
  try {
    if (d != null && d.existsSync()) d.deleteSync(recursive: true);
  } catch (_) {
    // Left for the system's own cleanup.
  }
}

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
      for (final w in _weightsOf(face.weight, face.weights)) {
        out.add((family: face.family, weight: w, italic: face.italic, path: path));
      }
    }
  }
  return out;
}

/// The weights a font file draws: its own, or every hundred of a variable
/// font's `wght` axis (drawn there by a font variation, as the SDK's text
/// styles set one).
Iterable<int> _weightsOf(int weight, (int, int)? axis) sync* {
  if (axis == null || axis.$1 > axis.$2) {
    yield weight;
    return;
  }
  for (var w = axis.$1.clamp(100, 900); w <= axis.$2.clamp(100, 900); w += 100) {
    yield w;
  }
}

/// A declared font file that could not be used: missing, or not read.
typedef DeclaredFontProblem = ({String family, int weight, bool italic, String asset, String path, String reason, bool missing});

/// The faces a site declares (`site.json`'s `fonts`, files relative to
/// [siteDir]), each under its declared family, weight and style (as a
/// pubspec's fonts are, whatever the file calls itself); a WOFF file is
/// decoded. Files that are missing or unreadable go to [problems].
List<FontFace> declaredFonts(List<FontFamily> families, String siteDir, List<DeclaredFontProblem> problems) {
  final out = <FontFace>[];
  for (final f in families) {
    for (final a in f.fonts) {
      final file = File(sitePath(siteDir, a.asset));
      if (!file.existsSync()) {
        problems.add((family: f.family, weight: a.weight, italic: a.italic, asset: a.asset, path: file.path, reason: 'no file ${file.path}', missing: true));
        continue;
      }
      if (a.asset.toLowerCase().endsWith('.woff2')) continue; // not a format this renderer reads
      final bytes = file.readAsBytesSync();
      String? reason;
      final sfnt = sfntOf(bytes, why: (r) => reason = r);
      if (sfnt == null) {
        problems.add((family: f.family, weight: a.weight, italic: a.italic, asset: a.asset, path: file.path, reason: reason ?? 'not read', missing: false));
        continue;
      }
      var path = file.path;
      if (!identical(sfnt, bytes)) {
        path = '${_decoded.path}/declared-${out.length}-${file.uri.pathSegments.last}.ttf';
        File(path).writeAsBytesSync(sfnt);
      }
      // A variable font declared once draws every weight of its axis.
      final axis = readFontFace(sfnt)?.weights;
      for (final w in axis == null ? [a.weight] : _weightsOf(a.weight, axis)) {
        out.add((family: f.family, weight: w, italic: a.italic, path: path));
      }
    }
  }
  return out;
}

/// The fonts the render command always has: Roboto (the default family of a
/// Flutter app on Android and on the web, used for text that names no
/// family), the MaterialIcons font and Roboto Mono (what `monospace` and
/// `Text.mono` draw in), all from the Flutter SDK.
List<FontFace> defaultFonts(String flutterRoot) => [
      ..._defaultFonts.putIfAbsent(
          flutterRoot,
          () => scanFonts([
                '$flutterRoot/bin/cache/artifacts/material_fonts',
                for (final dir in _robotoMonoDirs)
                  if (Directory('$flutterRoot/$dir').existsSync()) '$flutterRoot/$dir',
              ])),
    ];

/// Flutter's own font files do not change while a process runs: read once (a render server's every run asks).
final Map<String, List<FontFace>> _defaultFonts = {};

/// Where the Flutter SDK keeps Roboto Mono (DevTools' copy).
const _robotoMonoDirs = ['bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/Roboto_Mono'];

/// The family names that mean "a monospace face" (CSS's generic family and
/// the notation's words): drawn in Roboto Mono when nothing else provides
/// them, with no fallback warning.
const monospaceFamilies = {'monospace', 'mono', 'ui-monospace'};

/// The kind of face a family is, read from its name: what a family no file
/// provides falls back to (a serif to a serif, a slab to a slab, a script to
/// a script) rather than to Roboto (round 11: Georgia, Roboto Slab and a
/// script drew as the sans).
enum FontClass { sans, serif, slab, mono, script }

/// The class of [family], from the words of its name.
FontClass fontClassOf(String family) {
  final f = family.toLowerCase();
  if (monospaceFamilies.contains(f) || RegExp(r'mono|code|courier|consol|menlo|monaco|typewriter').hasMatch(f)) return FontClass.mono;
  if (RegExp(r'slab|rockwell|arvo|zilla|bitter|museo slab|courier prime').hasMatch(f)) return FontClass.slab;
  if (RegExp(r'script|brush|hand|pacifico|dancing|caveat|vibes|satisfy|lobster|cursive|signature|allura|sacramento|kaushan|calligraph').hasMatch(f)) return FontClass.script;
  if (RegExp(r'sans').hasMatch(f)) return FontClass.sans;
  if (RegExp(r'serif|georgia|times|garamond|baskerville|bodoni|didot|playfair|merriweather|lora|cormorant|crimson|fraunces|spectral|libre caslon|caslon|cambria|palatino|book antiqua|minion|charter|newsreader|literata|source serif|pt serif|noto serif|dm serif|instrument serif|abril|prata|cardo|alegreya(?! sans)|vollkorn|gelasio|tiempos|domine|eb garamond|old standard|century|bookman|sitka|iowan|athelas|hoefler|recoleta|gt sectra').hasMatch(f)) return FontClass.serif;
  return FontClass.sans;
}

/// The system's faces of each class, in the order taken (the first family
/// with a file): Windows, macOS, then Linux. Read only when a family no file
/// provides asks for one.
Map<FontClass, List<String>> classFontFiles() {
  final win = '${Platform.environment['WINDIR'] ?? 'C:/Windows'}/Fonts';
  const mac = '/System/Library/Fonts/Supplemental';
  return {
    FontClass.serif: [
      for (final f in const ['georgia.ttf', 'georgiab.ttf', 'georgiai.ttf', 'times.ttf', 'timesbd.ttf', 'timesi.ttf', 'GARA.TTF', 'GARABD.TTF', 'GARAIT.TTF', 'BKANT.TTF', 'ANTQUAB.TTF', 'ANTQUAI.TTF']) '$win/$f',
      for (final f in const ['Georgia.ttf', 'Georgia Bold.ttf', 'Georgia Italic.ttf', 'Times New Roman.ttf', 'Times New Roman Bold.ttf']) '$mac/$f',
      for (final f in const ['DejaVuSerif.ttf', 'DejaVuSerif-Bold.ttf', 'DejaVuSerif-Italic.ttf']) '/usr/share/fonts/truetype/dejavu/$f',
      for (final f in const ['LiberationSerif-Regular.ttf', 'LiberationSerif-Bold.ttf', 'LiberationSerif-Italic.ttf']) '/usr/share/fonts/truetype/liberation/$f',
    ],
    FontClass.slab: [
      for (final f in const ['ROCK.TTF', 'ROCKB.TTF', 'ROCKI.TTF', 'ROCKEB.TTF']) '$win/$f',
      for (final f in const ['Rockwell.ttc']) '$mac/$f',
    ],
    FontClass.script: [
      for (final f in const ['BRUSHSCI.TTF', 'FREESCPT.TTF', 'MTCORSVA.TTF']) '$win/$f',
      for (final f in const ['Brush Script.ttf', 'Apple Chancery.ttf']) '$mac/$f',
    ],
  };
}

/// The family a text's symbols the default fonts lack (arrows ← → ↑ ↓, ↵,
/// ⌘, ✓) fall back to: a symbol font of the system's, registered under
/// this name. On a device the system's fallback fonts draw them.
const symbolFamily = 'Codelessly Symbols';

/// The system's symbol font, when it has one: Segoe UI Symbol (Windows),
/// Apple Symbols (macOS), DejaVu Sans or Noto Sans Symbols (Linux).
String? systemSymbolFont() {
  const candidates = [
    'C:/Windows/Fonts/seguisym.ttf',
    '/System/Library/Fonts/Apple Symbols.ttf',
    '/System/Library/Fonts/Supplemental/Apple Symbols.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/TTF/DejaVuSans.ttf',
    '/usr/share/fonts/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/truetype/noto/NotoSansSymbols2-Regular.ttf',
    '/usr/share/fonts/noto/NotoSansSymbols2-Regular.ttf',
  ];
  final windir = Platform.environment['WINDIR'];
  for (final c in [if (windir != null) '$windir/Fonts/seguisym.ttf', ...candidates]) {
    if (File(c).existsSync()) return c;
  }
  return null;
}

/// A request for a font no file provides (or only in another weight or
/// style).
typedef FontMiss = ({String family, int weight, bool italic, String? substitute});

/// Serves [faces] to the SDK, recording what it asked for and didn't get.
class DirectoryFontFetcher implements FontFetcher {
  DirectoryFontFetcher(this.faces, {Map<FontClass, List<String>>? classFiles}) : _classFiles = classFiles ?? classFontFiles();

  final List<FontFace> faces;

  /// The system's faces of each class, read when first needed ([classFontFiles]).
  final Map<FontClass, List<String>> _classFiles;
  final Map<FontClass, List<FontFace>> _classFaces = {};

  /// The face of [family]'s class nearest [weight] and [italic]: a serif's
  /// for a serif no file provides; null for a sans (Roboto is its class)
  /// and where the system has none (a slab or a script then takes a serif).
  FontFace? classFace(String family, int weight, bool italic) {
    final cls = fontClassOf(family);
    for (final c in [cls, if (cls == FontClass.slab || cls == FontClass.script) FontClass.serif]) {
      if (c == FontClass.sans || c == FontClass.mono) return null;
      final faces = _classFaces.putIfAbsent(c, () => scanFonts([for (final p in _classFiles[c] ?? const <String>[]) if (File(p).existsSync()) p]));
      if (faces.isEmpty) continue;
      // The first family of the list that has a file, nearest the weight.
      final first = faces.first.family;
      final same = [for (final f in faces) if (f.family == first) f];
      int score(FontFace f) => (f.weight - weight).abs() + (f.italic == italic ? 0 : 1000);
      same.sort((a, b) => score(a).compareTo(score(b)));
      return same.first;
    }
    return null;
  }
  /// The open face [family] is drawn in when it has no file and Google
  /// Fonts none of it ([googleStandInOf]), when that face is among [faces]
  /// (fetched, or in the cache): the same on every machine.
  FontFace? openStandIn(String family, int weight, bool italic) {
    final alt = googleStandInOf(family);
    return alt == null ? null : match(alt, weight, italic);
  }

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

  /// `monospace` (and its other generic names): Roboto Mono.
  FontFace? _generic(String family, int weight, bool italic) =>
      monospaceFamilies.contains(family.toLowerCase()) ? match('Roboto Mono', weight, italic) : null;

  /// The face a text in [family] at [weight] and [italic] is drawn in: its
  /// own file, else what stands in for it (Roboto Mono for a monospace
  /// family, an open stand-in, a face of its class, Roboto); null when not
  /// even Roboto is here.
  FontFace? faceFor(String family, int weight, bool italic) {
    // A family with no file at all is drawn in Roboto (the test
    // environment's own fallback draws boxes, which nobody can review).
    final generic = _generic(family, weight, italic);
    // A named monospace face no file provides (IBM Plex Mono) is drawn in
    // Roboto Mono, as `monospace` is, and said.
    final mono = generic == null && fontClassOf(family) == FontClass.mono ? match('Roboto Mono', weight, italic) : null;
    return match(family, weight, italic) ?? generic ?? openStandIn(family, weight, italic) ?? mono ?? classFace(family, weight, italic) ?? match('Roboto', weight, italic);
  }

  /// How long each fetch takes at least: a slow font source (a large file,
  /// a network), for tests of what is measured before it arrives.
  static Duration debugLatency = Duration.zero;

  final Set<Future<void>> _inFlight = {};

  /// Whether a fetch is in flight.
  bool get fetching => _inFlight.isNotEmpty;

  @override
  Future<Uint8List?> fetch(PublishFont font) {
    final f = _fetch(font);
    final done = f.then<void>((_) {}, onError: (Object _) {});
    _inFlight.add(done);
    done.whenComplete(() => _inFlight.remove(done));
    return f;
  }

  Future<Uint8List?> _fetch(PublishFont font) async {
    if (debugLatency > Duration.zero) {
      // Real time, as a slow file or network is (not a test's fake clock).
      final waited = Completer<void>();
      Zone.root.createTimer(debugLatency, waited.complete);
      await waited.future;
    }
    final generic = _generic(font.family, font.weight, font.italic);
    final face = faceFor(font.family, font.weight, font.italic);
    if (face == null || (generic == null || !identical(face, generic)) && (face.family.toLowerCase() != font.family.toLowerCase() ||
        face.weight != font.weight || face.italic != font.italic)) {
      final miss = (
        family: font.family,
        weight: font.weight,
        italic: font.italic,
        substitute: face == null ? null : '${face.family} ${face.weight}${face.italic ? ' italic' : ''}',
      );
      if (!misses.contains(miss)) misses.add(miss);
    }
    if (face == null) return null;
    // The engine keeps the first file registered for a face for the process's life: a later run (the render
    // server's) giving that face another file would still be drawn with the first one.
    final key = '${font.family.toLowerCase()}|${font.weight}|${font.italic}';
    final bytes = File(face.path).readAsBytesSync();
    // The same file at another place (each agent's own copy of a site, with its own copy of the fonts) is the
    // same face: told by what the file holds, not by where it is.
    final stamp = fontFileStamp(bytes);
    final before = engineFiles[key];
    if (before == null) {
      engineFiles[key] = (path: face.path, stamp: stamp);
    } else if (before.path != face.path && before.stamp != stamp) {
      engineConflicts.add('${font.family} ${font.weight}${font.italic ? ' italic' : ''}: ${face.path} after ${before.path}');
    }
    return bytes;
  }

  /// Process-wide: the file the engine was given for each face (`family|weight|italic`), across runs, and what
  /// tells its content ([fontFileStamp]).
  static final Map<String, ({String path, String stamp})> engineFiles = {};

  /// Faces this process was asked to draw with a file other than the one the engine already has for them (a
  /// family first drawn in Roboto, missing, then given its own file): the drawing is the first file's. The render
  /// server stops and hands such a run back (tool/render/render_harness.dart).
  static final List<String> engineConflicts = [];
}

/// What tells one font file's content from another's without reading it all again: its length and a hash of
/// its first and last 4096 bytes and of every 251st byte between.
String fontFileStamp(Uint8List bytes) {
  var h = 0x811c9dc5;
  void add(int b) => h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF;
  final n = bytes.length, edge = n < 4096 ? n : 4096;
  for (var i = 0; i < edge; i++) {
    add(bytes[i]);
  }
  for (var i = edge; i < n - edge; i += 251) {
    add(bytes[i]);
  }
  for (var i = n - edge < edge ? edge : n - edge; i < n; i++) {
    add(bytes[i]);
  }
  return '$n:${h.toRadixString(16)}';
}

/// A font file as these tables know it: its path, and its size and time (a file written again at the same path,
/// by another run of a render server, is another file).
String fontFileKey(String path) => _fileKeys.putIfAbsent(path, () {
      final stat = FileStat.statSync(path);
      return '$path|${stat.size}|${stat.modified.microsecondsSinceEpoch}';
    });

/// Asked once per run ([forgetFontFiles] at its start): a check asks for every text it reads.
final Map<String, String> _fileKeys = {};

/// A run starts: the font files are looked at again.
void forgetFontFiles() => _fileKeys.clear();

final Map<String, int> _latinScores = {};

/// How much of Latin text font file [path] covers: each printable ASCII
/// character counts 100, each other character up to U+024F (Latin-1 and
/// Latin Extended) 1.
int latinScore(String path) => _latinScores.putIfAbsent(fontFileKey(path), () {
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
Map<String, int> materialCodepoints(String flutterRoot) => _codepoints.putIfAbsent(flutterRoot, () => Map.unmodifiable(_readCodepoints(flutterRoot)));

final Map<String, Map<String, int>> _codepoints = {};

Map<String, int> _readCodepoints(String flutterRoot) {
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
