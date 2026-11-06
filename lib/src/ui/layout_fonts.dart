import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/extensions.dart';

/// Loads one font variant: its family in one weight and style.
///
/// Completes when the font can be drawn and throws when it could not be
/// loaded.
typedef FontVariantLoader = Future<void> Function(FontName font);

/// Loads the fonts a layout draws its text in before the layout is shown.
///
/// A Google Font is fetched the first time a text style asks for it, so a
/// screen used to lay its text out in the fallback font first and fetch its
/// fonts only then, one weight and style at a time as each text was built.
/// On the published web app a screenshot or a slow connection caught the
/// fallback (Roboto) in small caps labels, italic notes and an error
/// panel's title, and a font whose fetch failed stayed missing until
/// something rebuilt the text. [CodelesslyLayoutBuilder] now asks for every
/// variant its nodes use as soon as it has the layout, keeps the layout
/// hidden until they load (for at most [firstPaintTimeout]), and retries a
/// variant that failed. A font that arrives after the layout is shown
/// changes the system fonts, which lays the text out again.
abstract final class LayoutFonts {
  /// Whether layouts load their fonts before their first paint.
  ///
  /// On by default on the web, where every Google Font is fetched over the
  /// network on each fresh load. Elsewhere google_fonts keeps the files on
  /// the device after the first fetch.
  static bool enabled = kIsWeb;

  /// How long a layout stays hidden waiting for its fonts. It is shown when
  /// this runs out with the fonts that have loaded, and the rest replace the
  /// fallback as they arrive.
  static Duration firstPaintTimeout = const Duration(seconds: 3);

  /// How many more times a variant whose load failed is tried, [retryDelay]
  /// apart.
  static int retries = 2;

  /// The wait before a failed variant is tried again.
  static Duration retryDelay = const Duration(seconds: 2);

  /// Loads one variant. Defaults to [loadGoogleFont].
  static FontVariantLoader loader = loadGoogleFont;

  static final Set<String> _loaded = <String>{};
  static final Map<String, Future<bool>> _loading = <String, Future<bool>>{};

  /// Forgets loaded fonts and restores the defaults.
  @visibleForTesting
  static void reset() {
    _loaded.clear();
    _loading.clear();
    enabled = kIsWeb;
    firstPaintTimeout = const Duration(seconds: 3);
    retries = 2;
    retryDelay = const Duration(seconds: 2);
    loader = loadGoogleFont;
  }

  /// Reads the app's asset manifest ahead of the first layout.
  ///
  /// google_fonts reads it (to look for a bundled copy) before it fetches a
  /// font. Read when a screen first asks for its fonts, its response waited
  /// behind the screen's first, slow frames, and the fetches started only
  /// seconds later. The bundle keeps the parsed manifest, so google_fonts
  /// finds it at once.
  static void warmUp() {
    if (!enabled) return;
    AssetManifest.loadFromAssetBundle(rootBundle).then<void>((_) {}).ignore();
  }

  /// [font] as the variant text draws it in: its family, its weight (read
  /// from the style for a weightless font), and italic or normal.
  static FontName variantOf(FontName font) => FontName(
    family: font.family,
    weight: FontWeightNumeric.values[font.flutterFontWeight.value ~/ 100 - 1],
    style: font.isItalic ? 'Italic' : 'Normal',
  );

  static String _key(FontName variant) =>
      '${variant.family}|${variant.weight!.name}|${variant.style}';

  /// Every font variant the text of [nodes] is drawn in: each `fontName` in
  /// their properties, such as a text's spans or a button's label style.
  ///
  /// Default Roboto is left out: it isn't stored with the nodes, and it is
  /// the font text falls back to.
  static Set<FontName> fontsIn(Iterable<BaseNode> nodes) {
    final Set<FontName> fonts = <FontName>{};
    void visit(Object? json) {
      if (json is Map) {
        for (final MapEntry entry in json.entries) {
          final Object? value = entry.value;
          if (entry.key == 'fontName' && value is Map) {
            final Object? family = value['family'];
            if (family is String && family.trim().isNotEmpty) {
              try {
                fonts.add(variantOf(FontName.fromJson(value)));
              } catch (_) {
                // Not a font name after all.
              }
            }
          } else {
            visit(value);
          }
        }
      } else if (json is List) {
        json.forEach(visit);
      }
    }

    for (final BaseNode node in nodes) {
      try {
        visit(node.toJson());
      } catch (_) {
        // A node that doesn't serialize draws in fonts loaded as it builds.
      }
    }
    return fonts;
  }

  /// Whether [font]'s variant has loaded.
  static bool isLoaded(FontName font) =>
      _loaded.contains(_key(variantOf(font)));

  /// Loads the variants of [fonts] that haven't loaded, together.
  ///
  /// Completes when each has loaded or failed its last try; it never throws.
  static Future<void> load(Iterable<FontName> fonts) => Future.wait<bool>([
    for (final FontName font in fonts.map(variantOf).toSet())
      if (!_loaded.contains(_key(font)))
        _loading.putIfAbsent(_key(font), () => _loadVariant(font)),
  ]);

  static Future<bool> _loadVariant(FontName variant) async {
    final String key = _key(variant);
    try {
      for (int attempt = 0; ; attempt++) {
        try {
          await loader(variant);
          _loaded.add(key);
          return true;
        } catch (error) {
          if (attempt >= retries) {
            debugPrint('Font ${variant.family} $key failed to load: $error');
            return false;
          }
          await Future<void>.delayed(retryDelay);
        }
      }
    } finally {
      _loading.remove(key);
    }
  }

  /// Loads [font] with google_fonts, the way a text style that uses it
  /// would, when its family is a Google Font. Other families are fonts the
  /// project uploaded, which the SDK loads with the publish model.
  static Future<void> loadGoogleFont(FontName font) async {
    if (!GoogleFonts.asMap().containsKey(font.family)) return;
    // Starts the load, or finds it started, for the variant a text style
    // with this weight and style matches.
    GoogleFonts.getFont(
      font.family,
      fontWeight: font.flutterFontWeight,
      fontStyle: font.isItalic ? FontStyle.italic : FontStyle.normal,
    );
    // google_fonts only exposes all of its pending loads. One that fails
    // fails this wait too, and this variant is asked for again, which
    // returns at once if it has loaded.
    await GoogleFonts.pendingFonts();
  }
}

/// Shows [child] once [fonts] completes or [timeout] runs out, whichever is
/// first, keeping it built (and its load actions running) meanwhile.
class FontsGate extends StatefulWidget {
  const FontsGate({
    super.key,
    required this.fonts,
    required this.timeout,
    required this.child,
  });

  /// The fonts' load; null when they have loaded.
  final Future<void>? fonts;
  final Duration timeout;
  final Widget child;

  @override
  State<FontsGate> createState() => _FontsGateState();
}

class _FontsGateState extends State<FontsGate> {
  late bool _shown = widget.fonts == null;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final Future<void>? fonts = widget.fonts;
    if (fonts == null) return;
    _timer = Timer(widget.timeout, _show);
    fonts.whenComplete(_show).ignore();
  }

  void _show() {
    _timer?.cancel();
    _timer = null;
    if (!_shown && mounted) setState(() => _shown = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Visibility(
    visible: _shown,
    maintainState: true,
    maintainAnimation: true,
    maintainSize: true,
    child: widget.child,
  );
}
