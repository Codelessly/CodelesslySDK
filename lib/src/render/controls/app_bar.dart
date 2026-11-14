// The app bar as a render object: `appBar` (Flutter's `AppBar`), with no
// Material widget and no Scaffold in its path. A canvas places it in its
// `appBar` slot (render/layout/scaffold_slots.dart: across the top at its
// own height, the body below); the bar lays out its own slots as
// Flutter's `NavigationToolbar` does: the leading icon at the start, the
// actions at the end, the title after the leading icon (or centred).
// Unstyled it is SSUI's top bar:
//
// | Part | SSUI | Prop over it |
// |---|---|---|
// | bar | 44 high when it hugs (`sizes.topBar`), `primaryBackground`, a 1 px `primaryBorder` hairline along the bottom | `backgroundColor`, `elevation` (a shadow for the hairline), `shadowColor` |
// | title | 14 px, weight 600, `primaryText` (SSUI's `sectionTitle`), 12 from the start or 8 after the leading icon | `title`, `titleTextStyle`, `foregroundColor`, `centerTitle`, `titleSpacing` |
// | leading, actions | ghost icon buttons: a 28 px square, a 16 px `secondaryText` glyph, actions 4 apart, 8 from the edges | `leading`, `leadingWidth`, `actions` (each `size`, `color`) |
//
// In a canvas's `appBar` slot the bar keeps the view's top safe area clear
// (read from the root's view, kit_bars.dart's `controlViewPadding`, never
// from `MediaQuery`): it grows by it and draws its fill behind it.
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show AppBarProps, Json, Node, SizeFit;
import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/rendering.dart';

import '../convert.dart';
import '../recipe.dart';
import 'kit.dart';
import 'kit_bars.dart';
import 'tokens.dart';

/// The recipe of `appBar`: lib/src/widgets/controls.dart registers it.
void appBarRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  final l = n.layout;
  // The canvas's app bar (Flutter's `AppBar.primary`): its toolbar is the
  // node's height, the safe area above it is added.
  final primary = b.slot.parent?.slots['appBar'] == b.id;
  final grows = primary && l.height.fit == SizeFit.fixed && l.height.value > 0;
  chain.add(b.fitBox('fit', controlFit(l.width), grows ? SizeFit.hug : controlFit(l.height), Size(l.width.value, l.height.value)));
  chain.add(b.obtain<RenderAppBar>('appBar', RenderAppBar.new)
    ..spec = AppBarSpec.of(n, ControlTokens.of(b), inherited: b.slot.textDefault ?? n.behaviors.defaultTextStyle)
    ..primary = primary
    ..toolbarHeight = grows ? l.height.value : null);
}

const _deep = DeepCollectionEquality();

/// An icon of the bar (the leading one or an action).
@immutable
class BarIcon {
  const BarIcon(this.icon, {this.size, this.color, this.tooltip});
  final Json icon;
  final double? size;
  final Color? color;
  final String? tooltip;

  static BarIcon of(api.IconAction a) => BarIcon(barGlyph(a.icon), size: a.size, color: a.color?.flutter, tooltip: a.tooltip);

  List<Object?> get _fields => [icon, size, color, tooltip];

  @override
  bool operator ==(Object other) => other is BarIcon && _deep.equals(other._fields, _fields);

  @override
  int get hashCode => Object.hash(size, color, tooltip);
}

/// An app bar resolved from its node and tokens.
@immutable
class AppBarSpec {
  const AppBarSpec({
    required this.tokens,
    this.title = '',
    this.titleStyle = const TextStyle(),
    this.centerTitle = false,
    this.titleSpacing,
    this.leading,
    this.leadingWidth,
    this.actions = const [],
    this.background,
    this.foreground,
    this.shadowColor,
    this.elevation,
  });

  final ControlTokens tokens;
  final String title;
  final TextStyle titleStyle;
  final bool centerTitle;
  final double? titleSpacing;
  final BarIcon? leading;
  final double? leadingWidth;
  final List<BarIcon> actions;
  final Color? background, foreground, shadowColor;
  final double? elevation;

  factory AppBarSpec.of(Node n, ControlTokens tokens, {api.TextStyle? inherited}) {
    final leading = n.prop(AppBarProps.leading);
    return AppBarSpec(
      tokens: tokens,
      title: n.prop(AppBarProps.title).trim(),
      titleStyle: barTextStyle(n.prop(AppBarProps.titleTextStyle), inherited),
      centerTitle: n.prop(AppBarProps.centerTitle) ?? false,
      titleSpacing: n.prop(AppBarProps.titleSpacing),
      leading: leading == null || barGlyph(leading.icon).isEmpty ? null : BarIcon.of(leading),
      leadingWidth: n.prop(AppBarProps.leadingWidth),
      actions: [for (final a in n.prop(AppBarProps.actions)) BarIcon.of(a)],
      background: n.prop(AppBarProps.backgroundColor)?.flutter,
      foreground: n.prop(AppBarProps.foregroundColor)?.flutter,
      shadowColor: n.prop(AppBarProps.shadowColor)?.flutter,
      elevation: n.prop(AppBarProps.elevation),
    );
  }

  List<Object?> get _fields => [
        tokens.theme, tokens.dark, tokens.backdrop, title, titleStyle, centerTitle, titleSpacing, leading, leadingWidth, //
        actions, background, foreground, shadowColor, elevation,
      ];

  @override
  bool operator ==(Object other) => other is AppBarSpec && _deep.equals(other._fields, _fields);

  @override
  int get hashCode => Object.hash(title, actions.length, background);
}

/// An app bar: its fill, its leading icon, title and actions.
class RenderAppBar extends RenderBox implements LabelledControl {
  RenderAppBar();

  final ControlLabel _title = ControlLabel();
  late final BarGlyphs _glyphs = BarGlyphs(this);

  AppBarSpec? _spec;
  AppBarSpec get spec => _spec!;
  set spec(AppBarSpec v) {
    if (v == _spec) return;
    _spec = v;
    _glyphs.sync([v.leading?.icon ?? const {}, for (final a in v.actions) a.icon], adoptChild, dropChild);
    if (v.leading case final BarIcon l) _glyphs.color(0, iconColorOf(l));
    for (var i = 0; i < v.actions.length; i++) {
      _glyphs.color(i + 1, iconColorOf(v.actions[i]));
    }
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  bool _primary = false;

  /// The canvas's app bar: it keeps the view's top safe area clear.
  set primary(bool v) {
    if (v == _primary) return;
    _primary = v;
    markNeedsLayout();
  }

  double? _toolbarHeight;

  /// The toolbar's own height (a fixed node in the canvas slot); null: the
  /// box's.
  set toolbarHeight(double? v) {
    if (v == _toolbarHeight) return;
    _toolbarHeight = v;
    markNeedsLayout();
  }

  ControlTokens get _t => spec.tokens;

  /// The safe area kept clear above the toolbar.
  double get safeInset => _primary && attached ? controlViewPadding(this).top : 0;

  static const _button = 28.0;
  static const _edge = 8.0;
  static const _actionGap = 4.0;

  double get _hugHeight => _t.theme.sizes['topBar'] ?? 44;
  double get _naturalHeight => (_toolbarHeight ?? _hugHeight) + safeInset;

  TextStyle _titleStyle(Color color) {
    final base = TextStyle(fontFamily: _t.fontFamily, fontSize: 14, fontWeight: FontWeight.w600, height: 1.4, letterSpacing: 0);
    return base.merge(spec.titleStyle).copyWith(color: color, leadingDistribution: TextLeadingDistribution.even);
  }

  /// The title's ink.
  Color get titleColor => spec.titleStyle.color ?? spec.foreground ?? _t.onSurface;

  /// An icon's ink.
  Color iconColorOf(BarIcon i) => i.color ?? spec.foreground ?? _t.secondaryText;

  /// The bar's fill.
  Color get backgroundColor => spec.background ?? _t.surface;

  double _iconSize(BarIcon i) => i.size ?? 16;

  double get _naturalWidth {
    _title.update(spec.title, _titleStyle(const Color(0xFF000000)));
    final leading = spec.leading == null ? 0.0 : (spec.leadingWidth ?? _button) + (spec.titleSpacing ?? 8);
    final actions = spec.actions.isEmpty ? 0.0 : spec.actions.length * _button + (spec.actions.length - 1) * _actionGap + _edge;
    return _edge + leading + (spec.leading == null ? (spec.titleSpacing ?? 12) - _edge : 0) + _title.intrinsicWidth + actions + _edge;
  }

  @override
  double computeMinIntrinsicWidth(double height) => _naturalWidth;
  @override
  double computeMaxIntrinsicWidth(double height) => _naturalWidth;
  @override
  double computeMinIntrinsicHeight(double width) => _naturalHeight;
  @override
  double computeMaxIntrinsicHeight(double width) => _naturalHeight;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => constraints.constrain(Size(_naturalWidth, _naturalHeight));

  Rect _toolbar = Rect.zero;
  Rect? _leadingBox;
  List<Rect> _actionBoxes = const [];
  double _titleLeft = 0;

  /// Where the toolbar's slots are (local): the leading button, the title's
  /// line, the action buttons.
  ({Rect? leading, Rect title, List<Rect> actions}) get slots => (
        leading: _leadingBox,
        title: Rect.fromLTWH(_titleLeft, _toolbar.center.dy - _title.size.height / 2, _title.size.width, _title.size.height),
        actions: _actionBoxes,
      );

  @override
  void performLayout() {
    final c = constraints;
    final width = c.hasTightWidth ? c.maxWidth : c.constrainWidth(_naturalWidth);
    final height = c.hasTightHeight ? c.maxHeight : c.constrainHeight(_naturalHeight);
    size = Size(width, height);
    final inset = math.min(safeInset, height);
    final bar = _toolbar = Rect.fromLTRB(0, inset, width, height);
    final cy = bar.center.dy;
    var start = _edge;
    Rect? leading;
    if (spec.leading case final BarIcon l) {
      final w = spec.leadingWidth ?? _button;
      leading = Rect.fromLTWH(start, cy - _button / 2, w, _button);
      final s = _iconSize(l);
      _glyphs.place(0, Rect.fromCenter(center: leading.center, width: s, height: s));
      start = leading.right + (spec.titleSpacing ?? 8);
    } else {
      start = spec.titleSpacing ?? 12;
    }
    _leadingBox = leading;
    final actions = <Rect>[];
    var end = width - _edge;
    for (var i = spec.actions.length - 1; i >= 0; i--) {
      final r = Rect.fromLTWH(end - _button, cy - _button / 2, _button, _button);
      actions.insert(0, r);
      final s = _iconSize(spec.actions[i]);
      _glyphs.place(i + 1, Rect.fromCenter(center: r.center, width: s, height: s));
      end = r.left - _actionGap;
    }
    _actionBoxes = actions;
    final titleEnd = actions.isEmpty ? width - (spec.titleSpacing ?? 12) : actions.first.left - _edge;
    _title.update(spec.title, _titleStyle(const Color(0xFF000000)));
    _title.layout(math.max(0, titleEnd - start));
    if (spec.centerTitle) {
      // Centred on the bar, kept between the leading icon and the actions.
      final w = _title.size.width;
      _titleLeft = (width / 2 - w / 2).clamp(start, math.max(start, titleEnd - w));
    } else {
      _titleLeft = start;
    }
  }

  @override
  List<({String text, String? fontFamily, List<Rect> glyphs})> get labels => !hasSize || spec.title.isEmpty
      ? const []
      : [(text: spec.title, fontFamily: _title.fontFamily, glyphs: _title.glyphBoxes(_titleLeft, _toolbar.center.dy))];

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final rect = offset & size;
    final e = spec.elevation;
    if (e != null && e > 0) {
      for (final sh in _t.shadows(e <= 1 ? 'level1' : e <= 3 ? 'level2' : e <= 6 ? 'level3' : 'level4')) {
        final paint = sh.toPaint();
        if (spec.shadowColor case final Color own) paint.color = own.withValues(alpha: own.a * sh.color.a);
        canvas.drawRect(rect.shift(sh.offset).inflate(sh.spreadRadius), paint);
      }
    }
    canvas.drawRect(rect, Paint()..color = backgroundColor);
    if (e == null || e <= 0) canvas.drawRect(Rect.fromLTWH(rect.left, rect.bottom - 1, rect.width, 1), Paint()..color = _t.primaryBorder);
    _glyphs.paint(context, offset);
    if (spec.title.isNotEmpty) {
      _title.update(spec.title, _titleStyle(titleColor));
      _title.paint(canvas, offset.dx + _titleLeft, offset.dy + _toolbar.center.dy);
    }
  }

  // --- children: the glyphs ---------------------------------------------------------

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    for (final g in _glyphs.glyphs) {
      g.attach(owner);
    }
  }

  @override
  void detach() {
    super.detach();
    for (final g in _glyphs.glyphs) {
      g.detach();
    }
  }

  @override
  void redepthChildren() => _glyphs.glyphs.forEach(redepthChild);

  @override
  void visitChildren(RenderObjectVisitor visitor) => _glyphs.visit(visitor);

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    final i = _glyphs.glyphs.indexWhere((g) => identical(g, child));
    if (i < 0) return;
    final o = _glyphs.rectOf(i).topLeft;
    transform.translateByDouble(o.dx, o.dy, 0, 1);
  }

  // --- semantics ------------------------------------------------------------------------

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    if (spec.title.isEmpty) return;
    config
      ..isSemanticBoundary = true
      ..label = spec.title
      ..isHeader = true
      ..textDirection = TextDirection.ltr;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {}

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }
}
