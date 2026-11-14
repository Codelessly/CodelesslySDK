// What the date and time pickers (render/controls/pickers.dart) need beyond
// the kit and the overlay layer, with no widget: the popup layer (a barrier
// over the root holding the picker's panel, anchored under its field on a
// wide view and a bottom sheet on a narrow one), the colours a picker's
// panel draws with (SSUI's, or the node's `pickerTheme`), the locale's
// month and day names and first weekday (no Material
// localizations: a [PickerLocale] the widgets layer gives from intl's data),
// dates as the model writes them, and SSUI's small line icons (calendar,
// clock, chevrons) drawn as paths.
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api show Color, Json, TextStyle;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

import '../convert.dart';
import 'overlay.dart';
import 'root.dart';
import 'tokens.dart';

// --- the popup layer ------------------------------------------------------------

/// Below this root width a picker opens as a bottom sheet (Material's
/// compact window class), else as a popover under its field.
const double kPickerSheetBreakpoint = 600;

/// A picker's popup in the root's overlay layer: a barrier the size of the
/// root (a tap on it, or Escape, dismisses) with the panel ([child]) placed
/// under [anchorRect] (above when there is no room below, kept 8 px inside
/// the root), or, as a [sheet], along the root's bottom over a scrim.
class RenderPickerPopup extends RenderOverlayEntry with RenderObjectWithChildMixin<RenderBox> {
  RenderPickerPopup({
    required RenderBox panel,
    required this.anchorRect,
    required this.sheet,
    required this.scrim,
    required this.onDismiss,
    this.semanticsLabel = '',
  }) {
    child = panel;
  }

  /// The field it opened from, in the root's coordinates.
  Rect anchorRect;

  /// A bottom sheet (a narrow root) rather than a popover.
  final bool sheet;

  /// The sheet's scrim (SSUI's `scrim`); a popover draws none.
  final Color scrim;

  /// A tap outside the panel, a screen reader's dismiss.
  final VoidCallback onDismiss;

  /// What a screen reader names the popup.
  final String semanticsLabel;

  /// Between the field and a popover.
  static const gap = 4.0;

  /// The panel's place in the popup.
  Offset panelOffset = Offset.zero;

  @override
  bool get hitTestable => true;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    final panel = child;
    if (panel == null) return;
    if (sheet) {
      panel.layout(BoxConstraints(minWidth: size.width, maxWidth: size.width, maxHeight: size.height * .9), parentUsesSize: true);
      panelOffset = Offset(0, size.height - panel.size.height);
    } else {
      panel.layout(BoxConstraints.loose(Size(math.max(0, size.width - 16), math.max(0, size.height - 16))), parentUsesSize: true);
      final p = panel.size;
      final a = anchorRect;
      var top = a.bottom + gap;
      if (top + p.height > size.height - 8 && a.top - gap - p.height >= 8) top = a.top - gap - p.height;
      top = top.clamp(8.0, math.max(8.0, size.height - p.height - 8)).toDouble();
      final left = a.left.clamp(8.0, math.max(8.0, size.width - p.width - 8)).toDouble();
      panelOffset = Offset(left, top);
    }
    (panel.parentData! as BoxParentData).offset = panelOffset;
  }

  @override
  Offset placeIn(RenderControlRoot root, Size rootSize) => Offset.zero;

  /// The panel's rect in the popup.
  Rect get panelRect => child == null ? Rect.zero : panelOffset & child!.size;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (sheet && scrim.a > 0) context.canvas.drawRect(offset & size, Paint()..color = scrim);
    final panel = child;
    if (panel != null) context.paintChild(panel, offset + panelOffset);
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final panel = child;
    if (panel == null) return false;
    return result.addWithPaintOffset(offset: panelOffset, position: position, hitTest: (r, p) => panel.hitTest(r, position: p));
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    // The barrier: a press outside the panel closes the popup (and goes no
    // further: what is under it is not pressed).
    if (event is PointerDownEvent && !panelRect.contains(entry.localPosition)) onDismiss();
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) => transform.translateByDouble(panelOffset.dx, panelOffset.dy, 0, 1);

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..explicitChildNodes = true
      ..scopesRoute = true
      ..namesRoute = true
      ..label = semanticsLabel
      ..textDirection = TextDirection.ltr
      ..onDismiss = onDismiss;
  }
}

// --- colours --------------------------------------------------------------------

/// What a picker's panel draws with: SSUI's tokens, then the node's
/// `pickerTheme` (`backgroundColor`, `accentColor`, `onAccentColor`,
/// `textColor`, `mutedColor`, `dividerColor`, `radius`, `dayRadius`,
/// `fontFamily`, `headlineStyle`).
@immutable
class PickerColors {
  const PickerColors({
    required this.background,
    required this.accent,
    required this.onAccent,
    required this.text,
    required this.muted,
    required this.divider,
    required this.hover,
    required this.focus,
    required this.radius,
    required this.dayRadius,
    required this.fontFamily,
    required this.shadows,
    required this.scrim,
    this.headline,
  });

  /// The panel's surface.
  final Color background;

  /// The selected day and time, today's ring, the primary action.
  final Color accent;

  /// Text on [accent].
  final Color onAccent;

  /// Days, times, the month's title.
  final Color text;

  /// Weekday names, hints, icons.
  final Color muted;

  /// The panel's hairline.
  final Color divider;

  /// A hovered day (SSUI's `hoverOverlay`).
  final Color hover;

  /// The keyboard's ring (SSUI's `focusBorder`).
  final Color focus;

  /// The panel's corners (SSUI's control radius, 7).
  final double radius;

  /// A day's corners (SSUI's inner radius, 5).
  final double dayRadius;
  final String? fontFamily;
  final List<BoxShadow> shadows;
  final Color scrim;

  /// The node's `headlineStyle` (the month's title), over SSUI's.
  final TextStyle? headline;

  /// [tokens], then [theme] (a node's `pickerTheme`, may be null).
  factory PickerColors.of(ControlTokens tokens, api.Json? theme) {
    Color named(String name, Color fallback) => tokens.theme.color(name)?.flutter ?? fallback;
    final j = theme ?? const {};
    Color? c(String key) => api.Color.fromJson(j[key])?.flutter;
    double? d(String key) => j[key] is num ? (j[key] as num).toDouble() : double.tryParse('${j[key] ?? ''}');
    final text = c('textColor') ?? tokens.onSurface;
    final headline = j['headlineStyle'] == null ? null : textStyle(api.TextStyle.fromJson(j['headlineStyle']));
    return PickerColors(
      background: c('backgroundColor') ?? tokens.surface,
      accent: c('accentColor') ?? tokens.primary,
      onAccent: c('onAccentColor') ?? tokens.readableOn(c('accentColor') ?? tokens.primary, tokens.onPrimary),
      text: text,
      muted: c('mutedColor') ?? named('tertiaryText', text.withValues(alpha: .45)),
      divider: c('dividerColor') ?? tokens.primaryBorder,
      hover: tokens.hoverOverlay,
      focus: tokens.focusBorder,
      radius: d('radius') ?? tokens.radius('control', 7),
      dayRadius: d('dayRadius') ?? tokens.radius('inner', 5),
      fontFamily: j['fontFamily'] is String ? j['fontFamily'] as String : tokens.fontFamily,
      shadows: tokens.shadows('level3'),
      scrim: named('scrim', tokens.dark ? const Color(0x99000000) : const Color(0x66000000)),
      headline: headline,
    );
  }

  /// SSUI's text at [size] and [weight] in [color] (else [text]).
  TextStyle style(double size, {FontWeight weight = FontWeight.w400, Color? color, double height = 1.3}) => TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        height: height,
        leadingDistribution: TextLeadingDistribution.even,
        color: color ?? text,
      );

  @override
  bool operator ==(Object other) =>
      other is PickerColors &&
      other.background == background &&
      other.accent == accent &&
      other.onAccent == onAccent &&
      other.text == text &&
      other.muted == muted &&
      other.divider == divider &&
      other.radius == radius &&
      other.dayRadius == dayRadius &&
      other.fontFamily == fontFamily &&
      other.headline == headline;

  @override
  int get hashCode => Object.hash(background, accent, text, muted, radius, fontFamily);
}

/// Paints a panel's surface: [colors]' background, its shadows, a hairline;
/// [rrect] is its outline.
void paintPickerSurface(Canvas canvas, RRect rrect, PickerColors colors) {
  for (final s in colors.shadows) {
    canvas.drawRRect(rrect.shift(s.offset).inflate(s.spreadRadius), s.toPaint());
  }
  canvas.drawRRect(rrect, Paint()..color = colors.background);
  canvas.drawRRect(
      rrect.deflate(.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = colors.divider);
}

// --- the locale -----------------------------------------------------------------

/// What a picker reads from outside the render layer: the locale's month
/// and day names and first weekday, what day it is, and an intl pattern's
/// text. The widgets layer gives intl's data and the runtime's clock
/// (widgets/picker_locale.dart: the render tool's `--now` pins it);
/// [PickerLocale.english] is the fallback.
abstract interface class PickerLocale {
  /// Month names, January first, as written alone (`November`).
  List<String> get months;

  /// Short month names (`Nov`).
  List<String> get shortMonths;

  /// Day names, Sunday first (`Thursday`).
  List<String> get weekdays;

  /// Short day names, Sunday first (`Thu`).
  List<String> get shortWeekdays;

  /// One-letter day names, Sunday first, as written alone (`T`).
  List<String> get narrowWeekdays;

  /// `AM` and `PM`.
  List<String> get ampm;

  /// The weekday a week starts on, as `DateTime.weekday` (1 Monday ... 7
  /// Sunday).
  int get firstWeekday;

  /// Now (a pinned clock when the host pins one).
  DateTime now();

  /// [at] in the intl [pattern], or null when it can't be read.
  String? format(String pattern, DateTime at);

  /// US English with the device's clock and no patterns.
  static const PickerLocale english = _English();
}

class _English implements PickerLocale {
  const _English();
  @override
  List<String> get months => const [
        'January', 'February', 'March', 'April', 'May', 'June', //
        'July', 'August', 'September', 'October', 'November', 'December',
      ];
  @override
  List<String> get shortMonths => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  @override
  List<String> get weekdays => const ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  @override
  List<String> get shortWeekdays => const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  @override
  List<String> get narrowWeekdays => const ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  @override
  List<String> get ampm => const ['AM', 'PM'];
  @override
  int get firstWeekday => DateTime.sunday;
  @override
  DateTime now() => DateTime.now();
  @override
  String? format(String pattern, DateTime at) => null;
}

/// [weekday] (`DateTime.weekday`) as an index of the Sunday-first lists.
int sundayIndex(int weekday) => weekday % 7;

// --- dates as the model writes them ---------------------------------------------

/// [value] as a day (`yyyy-MM-dd...`), or null.
DateTime? parseDay(String? value) {
  if (value == null || value.length < 10) return null;
  return DateTime.tryParse('${value.substring(0, 10)}T00:00:00');
}

/// [value] as a time of day (`HH:mm...`): minutes since midnight, or null.
int? parseClock(String? value) {
  if (value == null) return null;
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value.trim());
  if (m == null) return null;
  final h = int.parse(m[1]!), min = int.parse(m[2]!);
  return h < 24 && min < 60 ? h * 60 + min : null;
}

/// `yyyy-MM-dd`.
String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// `HH:mm` of [minutes] since midnight.
String isoClock(int minutes) => '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// [minutes] since midnight as the locale reads it: `9:05 AM`, or `09:05`
/// in 24-hour time.
String readableClock(int minutes, PickerLocale s, {required bool use24h}) {
  final h = minutes ~/ 60, m = (minutes % 60).toString().padLeft(2, '0');
  if (use24h) return '${h.toString().padLeft(2, '0')}:$m';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$m ${s.ampm[h < 12 ? 0 : 1]}';
}

/// [d] as `Thu, Nov 12` (what Material's `formatMediumDate` read).
String mediumDay(DateTime d, PickerLocale s) => '${s.shortWeekdays[sundayIndex(d.weekday)]}, ${s.shortMonths[d.month - 1]} ${d.day}';

/// [d] as `Thursday, November 12, 2026`: what a screen reader says of a day.
String fullDay(DateTime d, PickerLocale s) =>
    '${s.weekdays[sundayIndex(d.weekday)]}, ${s.months[d.month - 1]} ${d.day}, ${d.year}';

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime? a, DateTime? b) => a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day;

// --- icons ----------------------------------------------------------------------

/// SSUI's line icons (lucide's) a picker draws.
enum PickerGlyph { calendar, clock, chevronDown, chevronLeft, chevronRight }

/// Paints [glyph] filling [rect] (a square) in [color], as lucide's 24-unit
/// strokes of 2 scaled to the square.
void paintPickerGlyph(Canvas canvas, PickerGlyph glyph, Rect rect, Color color) {
  final k = rect.width / 24;
  Offset p(double x, double y) => rect.topLeft + Offset(x * k, y * k);
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1, 2 * k)
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  switch (glyph) {
    case PickerGlyph.calendar:
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromPoints(p(3, 4), p(21, 22)), Radius.circular(2 * k)), paint);
      canvas.drawLine(p(16, 2), p(16, 6), paint);
      canvas.drawLine(p(8, 2), p(8, 6), paint);
      canvas.drawLine(p(3, 10), p(21, 10), paint);
    case PickerGlyph.clock:
      canvas.drawCircle(p(12, 12), 10 * k, paint);
      canvas.drawPath(Path()..moveTo(p(12, 6).dx, p(12, 6).dy)..lineTo(p(12, 12).dx, p(12, 12).dy)..lineTo(p(16, 14).dx, p(16, 14).dy), paint);
    case PickerGlyph.chevronDown:
      canvas.drawPath(Path()..moveTo(p(6, 9).dx, p(6, 9).dy)..lineTo(p(12, 15).dx, p(12, 15).dy)..lineTo(p(18, 9).dx, p(18, 9).dy), paint);
    case PickerGlyph.chevronLeft:
      canvas.drawPath(Path()..moveTo(p(15, 18).dx, p(15, 18).dy)..lineTo(p(9, 12).dx, p(9, 12).dy)..lineTo(p(15, 6).dx, p(15, 6).dy), paint);
    case PickerGlyph.chevronRight:
      canvas.drawPath(Path()..moveTo(p(9, 18).dx, p(9, 18).dy)..lineTo(p(15, 12).dx, p(15, 12).dy)..lineTo(p(9, 6).dx, p(9, 6).dy), paint);
  }
}

/// One line of text laid out for painting in a picker's panel.
TextPainter pickerText(String text, TextStyle style, {double maxWidth = double.infinity, TextAlign align = TextAlign.center}) =>
    TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…', textAlign: align)
      ..layout(maxWidth: maxWidth);

/// Paints [painter] centred in [rect].
void paintCentred(Canvas canvas, TextPainter painter, Rect rect) =>
    painter.paint(canvas, rect.center - Offset(painter.width / 2, painter.height / 2));

/// A tap handled by a box itself: the up's position (local) goes to [onTap].
TapGestureRecognizer pickerTap(Object owner, void Function(Offset local) onTap) =>
    TapGestureRecognizer(debugOwner: owner)..onTapUp = (d) => onTap(d.localPosition);
