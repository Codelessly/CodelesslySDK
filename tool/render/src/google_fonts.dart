// Google Fonts for the render command, as an app has them: a family that is
// neither among the command's own faces, the --fonts directories nor the
// site's declared files is fetched by family, weight and style through the
// SDK's own HttpFontFetcher (the Google Fonts CSS API's TrueType file), kept
// in a cache directory (a second run, and a run with no network, read it
// there) and drawn. A family Google Fonts does not have (a system or a
// commercial face: Georgia, Times New Roman, Helvetica, Brush Script) is
// drawn in the open face named for it or for its class ([googleStandIns],
// [googleClassFamilies]), fetched the same way, so a picture is the same on
// every machine; the machine's own face is the fallback only when fetching
// is off (--no-google-fonts, CODELESSLY_NO_GOOGLE_FONTS=1) or fails.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:codelessly_api/codelessly_api.dart' show PublishFont;
import 'package:codelessly_sdk/codelessly_sdk.dart' show HttpFontFetcher;

import 'fonts.dart';

/// What a family's text is drawn in when it is fetched neither from a file
/// nor from Google Fonts: the open face of the same metrics for the system
/// and commercial faces sites name most, by family (lower case).
const googleStandIns = {
  'georgia': 'Gelasio',
  'times new roman': 'Tinos',
  'times': 'Tinos',
  'arial': 'Arimo',
  'helvetica': 'Arimo',
  'helvetica neue': 'Arimo',
  'courier new': 'Cousine',
  'courier': 'Cousine',
};

/// The open face (a Google Fonts family) a family of each class is drawn in
/// when it has no file and no stand-in of its own ([googleStandIns]): a
/// serif in Gelasio (Georgia's metrics), a slab in Roboto Slab, a script in
/// Dancing Script, a monospace face in Roboto Mono. A sans is drawn in
/// Roboto, the command's own.
const googleClassFamilies = {
  FontClass.serif: 'Gelasio',
  FontClass.slab: 'Roboto Slab',
  FontClass.script: 'Dancing Script',
  FontClass.mono: 'Roboto Mono',
};

/// The open face [family] is drawn in when it has no file of its own and
/// Google Fonts has none of it, or null (a sans: Roboto).
String? googleStandInOf(String family) => googleStandIns[family.toLowerCase()] ?? googleClassFamilies[fontClassOf(family)];

/// Whether a render uses Google Fonts at all: set by the render command
/// (render_harness.dart). Off where the render code runs in a test of its
/// own, so no test reaches the network or reads a cache that differs
/// between machines; a test gives [GoogleFontCache] its own fetch instead.
bool renderUsesGoogleFonts = false;

/// Faces fetched from Google Fonts, kept in [dir] by family, weight and style.
class GoogleFontCache {
  GoogleFontCache({required this.dir, this.enabled = true, Future<Uint8List?> Function(PublishFont font)? fetch}) : _fetch = fetch ?? _network;

  /// Where the files are kept: `CODELESSLY_FONT_CACHE`, else
  /// `<sdk>/.dart_tool/codelessly_google_fonts`.
  final String dir;

  /// Whether a face not in [dir] is fetched (off: the cache is still read).
  final bool enabled;
  final Future<Uint8List?> Function(PublishFont font) _fetch;

  /// Families a fetch was tried for and gave no file (not a Google Fonts
  /// family, or no network).
  final Set<String> failed = {};

  /// How many files this cache fetched (not read from [dir]).
  int fetched = 0;

  /// The cache directory of the SDK at [sdk].
  static String defaultDir(String sdk) => Platform.environment['CODELESSLY_FONT_CACHE'] ?? '$sdk/.dart_tool/codelessly_google_fonts';

  /// Whether the environment turns fetching off (`CODELESSLY_NO_GOOGLE_FONTS=1`, for CI).
  static bool get offByEnvironment => const {'1', 'true', 'yes'}.contains((Platform.environment['CODELESSLY_NO_GOOGLE_FONTS'] ?? '').trim().toLowerCase());

  String fileOf(String family, int weight, bool italic) =>
      '$dir/${family.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-$weight${italic ? '-italic' : ''}.ttf';

  /// [family]'s face nearest [weight] and [italic], from [dir] or fetched
  /// (then kept there); null when neither has it. A weight the family does
  /// not have is its default file, which the engine draws bolder.
  Future<FontFace?> face(String family, int weight, bool italic) async {
    final file = File(fileOf(family, weight, italic));
    if (!file.existsSync()) {
      if (!enabled) return null;
      Uint8List? bytes;
      try {
        bytes = await _fetch(PublishFont(id: PublishFont.idOf(family, weight, italic), family: family, weight: weight, italic: italic))
            .timeout(const Duration(seconds: 20));
      } catch (_) {}
      final sfnt = bytes == null ? null : sfntOf(bytes);
      if (sfnt == null || readFontFace(sfnt) == null) {
        failed.add(family);
        return null;
      }
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(sfnt);
      fetched++;
    }
    final read = readFontFace(file.readAsBytesSync());
    if (read == null) return null;
    final w = read.weights;
    return (family: family, weight: w == null ? read.weight : weight.clamp(w.$1, w.$2), italic: read.italic, path: file.path);
  }

  /// The network, as an app reaches it (a render runs under flutter_test,
  /// whose own HTTP client answers every request with 400).
  static Future<Uint8List?> _network(PublishFont font) =>
      HttpOverrides.runWithHttpOverrides(() => HttpFontFetcher().fetch(font), _Network());
}

class _Network extends HttpOverrides {}

/// Adds to [faces] what Google Fonts has for each of [wanted] that no face
/// of [faces] provides: the family itself, else its stand-in
/// ([googleStandInOf]). A family [faces] has (a declared file, a --fonts
/// directory, Roboto) is not fetched.
Future<void> addGoogleFonts(List<FontFace> faces, Iterable<({String family, int weight, bool italic})> wanted, GoogleFontCache cache) async {
  // A family a file here provides (declared, --fonts, built in) is that
  // file's; one fetched before is fetched again only for a weight or a
  // style it does not have yet.
  bool has(String family, int weight, bool italic) => faces.any((f) =>
      f.family.toLowerCase() == family.toLowerCase() &&
      (!f.path.startsWith(cache.dir) || (f.weight == weight && f.italic == italic)));
  void add(FontFace f) {
    if (!faces.any((g) => g.path == f.path && g.family == f.family)) faces.add(f);
  }

  // Every weight from 300 to 900 of each family asked for (once, then
  // cached): a text drawn at a weight no page listed (a binding's, a
  // control's) finds its face too.
  final all = <({String family, int weight, bool italic})>{
    for (final w in wanted) ...[w, for (var weight = 300; weight <= 900; weight += 100) (family: w.family, weight: weight, italic: w.italic)],
  };
  for (final w in all) {
    final low = w.family.toLowerCase();
    if (low.isEmpty || has(w.family, w.weight, w.italic) || monospaceFamilies.contains(low) || const {'sans-serif', 'system-ui', 'material icons', 'materialicons'}.contains(low)) continue;
    final own = googleStandIns.containsKey(low) || const {'serif', 'cursive'}.contains(low) ? null : await cache.face(w.family, w.weight, w.italic);
    if (own != null) {
      add(own);
      continue;
    }
    final alt = googleStandInOf(w.family);
    if (alt == null) continue;
    if (has(alt, w.weight, w.italic)) continue;
    if (await cache.face(alt, w.weight, w.italic) case final FontFace f) add(f);
  }
}
