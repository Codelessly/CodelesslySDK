import 'package:flutter/widgets.dart';

/// The colors and type of GenUI surfaces. A surface's `createSurface.theme`
/// may set `primaryColor`; the rest comes from the host.
@immutable
class GenUiTheme {
  const GenUiTheme({
    this.primary = 0xFF3D5AFE,
    this.primarySoft = 0xFFE8ECFF,
    this.text = 0xFF14161A,
    this.mutedText = 0xFF5F6673,
    this.surface = 0xFFFFFFFF,
    this.surfaceAlt = 0xFFF5F6F8,
    this.border = 0xFFE3E6EB,
    this.track = 0xFFE6E8EE,
    this.inputFill = 0xFFF7F8FA,
    this.positive = 0xFF1E8E5A,
    this.negative = 0xFFC8372D,
    this.fontFamily = 'Inter',
    this.series = const [
      0xFF3D5AFE,
      0xFFFF7043,
      0xFF26A69A,
      0xFFAB47BC,
      0xFFFFB300,
      0xFF78909C,
    ],
  });

  final int primary;
  final int primarySoft;
  final int text;
  final int mutedText;
  final int surface;
  final int surfaceAlt;
  final int border;
  final int track;
  final int inputFill;
  final int positive;
  final int negative;
  final String fontFamily;

  /// Default series colors, in order.
  final List<int> series;

  Color c(int argb) => Color(argb);

  /// This theme with a surface's `primaryColor` (`#RRGGBB`) applied.
  GenUiTheme withPrimaryHex(String? hex) {
    final int? argb = parseHexColor(hex);
    if (argb == null) return this;
    final Color base = Color(argb);
    final Color soft = Color.lerp(base, const Color(0xFFFFFFFF), 0.86)!;
    return GenUiTheme(
      primary: argb,
      primarySoft: soft.toARGB32(),
      text: text,
      mutedText: mutedText,
      surface: surface,
      surfaceAlt: surfaceAlt,
      border: border,
      track: track,
      inputFill: inputFill,
      positive: positive,
      negative: negative,
      fontFamily: fontFamily,
      series: [argb, ...series.skip(1)],
    );
  }

  static int? parseHexColor(String? hex) {
    if (hex == null) return null;
    final String h = hex.startsWith('#') ? hex.substring(1) : hex;
    if (h.length == 6) return int.tryParse('FF$h', radix: 16);
    if (h.length == 8) return int.tryParse(h, radix: 16);
    return null;
  }
}

/// Provides the [GenUiTheme] to the components of a surface.
class GenUiThemeScope extends InheritedWidget {
  const GenUiThemeScope({super.key, required this.theme, required super.child});

  final GenUiTheme theme;

  static GenUiTheme of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GenUiThemeScope>()?.theme ??
      const GenUiTheme();

  @override
  bool updateShouldNotify(GenUiThemeScope oldWidget) =>
      oldWidget.theme != theme;
}
