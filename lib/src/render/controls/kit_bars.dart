// What the bars (render/controls/{tab_bar,navigation_bar,app_bar}.dart)
// share beyond the kit (kit.dart): a control of several items, one of them
// selected, that the pointer, the keyboard and a screen reader pick
// ([RenderItemBar]); the selection indicator's motion on the tree's ticker
// ([IndicatorMotion]); the glyphs a bar paints ([BarGlyphs]); the view's
// safe-area padding ([controlViewPadding]); label styles from the node.
//
// | Piece | Flutter counterpart |
// |---|---|
// | [RenderItemBar] | `TabBar`'s / `NavigationBar`'s `InkWell` per item, `FocusableActionDetector`, `Semantics(selected:)` per item |
// | [IndicatorMotion] | `TabController.animation` driving `TabBarIndicator` |
// | [controlViewPadding] | `MediaQuery.paddingOf` (`SafeArea`) |
import 'dart:async' show scheduleMicrotask;
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Json, SizeFit, readInt, readString;
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../convert.dart';
import '../paint/icon_glyph.dart';
import '../paint/icon_names.dart';
import 'kit.dart';
import 'root.dart';

// --- the view's safe area ------------------------------------------------------

/// The safe-area padding (logical pixels: a notch, a status bar, a home
/// indicator) of the view [object] is shown in.
///
/// A hook until the root exposes the view's metrics (WS-K: the root's
/// `metrics`): by default it is read from the [RenderView] above the root
/// (`FlutterView.padding` over its pixel ratio), never from `MediaQuery`.
/// A host that consumed the padding itself (a `SafeArea` around the
/// adapter) sets this to give none.
EdgeInsets Function(RenderObject object) controlViewPadding = viewPaddingAbove;

/// The padding of the [RenderView] above [object] (zero outside one).
EdgeInsets viewPaddingAbove(RenderObject object) {
  // Under a root: the root's view (the same walk, the root marks it).
  RenderObject? p = RenderControlRoot.of(object) ?? object;
  for (; p != null; p = p.parent) {
    if (p is RenderView) {
      final view = p.flutterView;
      final ratio = view.devicePixelRatio;
      if (ratio <= 0) return EdgeInsets.zero;
      final pad = view.padding;
      return EdgeInsets.fromLTRB(pad.left / ratio, pad.top / ratio, pad.right / ratio, pad.bottom / ratio);
    }
  }
  return EdgeInsets.zero;
}

// --- sizing -----------------------------------------------------------------------------

/// [s]'s fit for a control: a node with no size on this axis (fixed at 0,
/// what a node with no layout has) hugs, so a control is never 0 × 0.
SizeFit controlFit(api.AxisSize s) => s.fit == SizeFit.fixed && s.value == 0 ? SizeFit.hug : s.fit;

// --- label styles ----------------------------------------------------------------

/// The fields [own] sets over [inherited] (the node's default text style),
/// as Flutter's: what a bar's label takes over its SSUI style.
TextStyle barTextStyle(api.TextStyle own, [api.TextStyle? inherited]) {
  final s = inherited == null ? own : inherited.merge(own);
  final w = s.fontWeight;
  return TextStyle(
    fontFamily: s.fontFamily,
    fontSize: s.fontSize,
    fontWeight: w == null ? null : FontWeight.values[(w ~/ 100 - 1).clamp(0, 8)],
    fontStyle: s.fontStyle == null ? null : FontStyle.values.byName(s.fontStyle!.name),
    letterSpacing: s.letterSpacing,
    height: s.height,
    // The color is the node's own (not the default text style's): an
    // inherited ink would hide the selection.
    color: own.color?.flutter,
    decoration: switch (s.decoration) {
      api.TextDecoration.underline => TextDecoration.underline,
      api.TextDecoration.lineThrough => TextDecoration.lineThrough,
      api.TextDecoration.overline => TextDecoration.overline,
      _ => null,
    },
  );
}

/// [own] over the SSUI [base]: a label's style, in [color] unless [own]
/// has one, its line centered (even leading).
TextStyle overBase(TextStyle base, TextStyle own, Color color) => base
    .merge(own.copyWith(color: own.color ?? color))
    .copyWith(leadingDistribution: TextLeadingDistribution.even);

/// A glyph prop as the icon render object draws it: a Material icon given
/// by name alone is looked up by name. Empty: no icon.
Json barGlyph(Object? glyph) {
  if (glyph is String) return glyph.isEmpty ? const {} : iconWithName(const {}, glyph);
  if (glyph is! Map) return const {};
  final g = glyph.cast<String, Object?>();
  if (g.isEmpty || g['show'] == false) return const {};
  final codepoint = readInt(g['codepoint']);
  if ((codepoint == null || codepoint <= 0) && readString(g['image']) == null) {
    if (readString(g['name']) case final String name when name.isNotEmpty) return iconWithName(g, name);
  }
  return g;
}

bool sameJson(Json a, Json b) => a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

// --- glyphs ---------------------------------------------------------------------------

/// The icon glyphs one bar paints (one render box each, children of the bar).
class BarGlyphs {
  BarGlyphs(this.owner);

  final RenderBox owner;
  final List<RenderIconGlyph> _glyphs = [];
  final List<Rect> _rects = [];

  List<RenderIconGlyph> get glyphs => _glyphs;

  /// Shows [icons] (an empty one is none, kept for its index).
  void sync(List<Json> icons, void Function(RenderObject child) adopt, void Function(RenderObject child) drop) {
    while (_glyphs.length > icons.length) {
      drop(_glyphs.removeLast());
      _rects.removeLast();
    }
    while (_glyphs.length < icons.length) {
      final g = RenderIconGlyph();
      _glyphs.add(g);
      _rects.add(Rect.zero);
      adopt(g);
    }
    for (var i = 0; i < icons.length; i++) {
      _glyphs[i].icon = icons[i];
    }
  }

  /// Lays glyph [i] out at [rect] (local to the owner).
  void place(int i, Rect rect) {
    _rects[i] = rect;
    _glyphs[i].layout(BoxConstraints.tight(rect.size));
  }

  Rect rectOf(int i) => _rects[i];

  void color(int i, Color c) => _glyphs[i].color = c;

  void paint(PaintingContext context, Offset offset, {bool Function(int i)? visible, Offset shift = Offset.zero}) {
    for (var i = 0; i < _glyphs.length; i++) {
      if (_glyphs[i].icon.isEmpty || !_glyphs[i].hasSize) continue;
      if (visible != null && !visible(i)) continue;
      context.paintChild(_glyphs[i], offset + shift + _rects[i].topLeft);
    }
  }

  void visit(RenderObjectVisitor visitor) => _glyphs.forEach(visitor);
}

// --- the indicator's motion -------------------------------------------------------

/// Moves a selection indicator from where it was to where it is now over
/// [duration] with SSUI's ease, on a [Ticker] of its own (the tree's frame
/// clock, as `render/behaviors.dart`'s motions use); repaints [owner] each
/// frame.
class IndicatorMotion {
  IndicatorMotion(this.owner);

  final RenderObject owner;
  Ticker? _ticker;
  Rect? _from;
  double _t = 1;
  Duration duration = const Duration(milliseconds: 150);

  /// Whether it is moving.
  bool get running => _t < 1;

  /// Starts from [from] (the indicator as drawn now) towards wherever the
  /// target is from now on.
  void start(Rect? from) {
    if (from == null || duration == Duration.zero || !owner.attached) {
      _t = 1;
      return;
    }
    _from = from;
    _t = 0;
    final t = _ticker ??= Ticker(_tick, debugLabel: 'indicator');
    if (t.isActive) t.stop();
    t.start();
    owner.markNeedsPaint();
  }

  void _tick(Duration elapsed) {
    _t = duration.inMicroseconds == 0 ? 1 : math.min(1, elapsed.inMicroseconds / duration.inMicroseconds);
    if (_t >= 1) _ticker?.stop();
    if (owner.attached) owner.markNeedsPaint();
  }

  /// Where the indicator is drawn this frame, going to [target].
  Rect at(Rect target) {
    final from = _from;
    if (_t >= 1 || from == null) return target;
    final e = Curves.ease.transform(_t);
    return Rect.fromLTRB(lerpDouble(from.left, target.left, e)!, lerpDouble(from.top, target.top, e)!,
        lerpDouble(from.right, target.right, e)!, lerpDouble(from.bottom, target.bottom, e)!);
  }

  /// The share of the way it has come (1: there).
  double get progress => _t >= 1 ? 1 : Curves.ease.transform(_t);

  void stop() {
    _ticker?.stop();
    _t = 1;
  }

  void dispose() {
    _ticker?.dispose();
    _ticker = null;
  }
}

// --- a bar of items ---------------------------------------------------------------------

/// A control of [itemCount] items in a row, one of them [selectedIndex]: a
/// tab bar, a navigation bar. Taps pick the item under them, Left and
/// Right (Home, End) move the keyboard's item while focused (wrapping),
/// Enter and Space pick it; each item is its own node for a screen reader
/// (selected or not, a tap action), with [itemRole].
///
/// Subclasses lay out [itemRects] and paint; they call [select] through
/// the base, which tells [onSelected] and moves the indicator ([motion]).
abstract class RenderItemBar extends RenderControl {
  RenderItemBar() {
    focusNode
      ..onKey = _onKey
      ..onActivate = _activateFocused
      ..onFocusChange = (on) {
        if (on && (_cursor < 0 || _cursor >= itemCount)) _cursor = selectedIndex.clamp(0, math.max(0, itemCount - 1));
        if (on) revealItem(_cursor);
        final cb = onStateChanged;
        if (cb != null) scheduleMicrotask(() => cb(api.WidgetState.focused, on));
        markNeedsPaint();
        markNeedsSemanticsUpdate();
      };
  }

  late final IndicatorMotion motion = IndicatorMotion(this);

  /// The glyphs' colors follow the states: set whenever the bar is to be
  /// painted again (never while painting).
  @override
  void markNeedsPaint() {
    super.markNeedsPaint();
    updateGlyphColors();
  }

  /// Sets each glyph's color for the states now.
  @protected
  void updateGlyphColors() {}
  late final BarGlyphs glyphs = BarGlyphs(this);

  /// How many items it has.
  int get itemCount;

  /// What a screen reader calls item [i].
  String itemLabel(int i);

  /// The items' semantics role (null: plain buttons).
  SemanticsRole? get itemRole => null;

  /// Each item's box, in local coordinates (after layout; scrolled).
  List<Rect> get itemRects;

  bool interactive = false;

  int _selected = 0;

  /// The selected item (-1: none).
  int get selectedIndex => _selected;

  /// Sets the selection from the node (its prop or bound value): no
  /// [onSelected], the indicator moves to it.
  set selectedIndex(int v) {
    if (v == _selected) return;
    final from = hasSize && attached ? indicatorRectNow : null;
    _selected = v;
    if (from != null && interactive) motion.start(from);
    selectionChanged();
  }

  /// Called after the selection changed (a subclass that sizes items by
  /// their selected style lays out again).
  @protected
  void selectionChanged() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  /// Told when the user picks an item (a tap, Enter or Space, a screen
  /// reader): the recipe fires the node's `changed` with it.
  ValueChanged<int>? onSelected;

  /// The indicator as drawn now (null: none drawn), the motion's start.
  @protected
  Rect? get indicatorRectNow;

  /// Picks item [i] (as the user does).
  void select(int i) {
    if (!enabled || i < 0 || i >= itemCount) return;
    _cursor = i;
    final changed = i != _selected;
    selectedIndex = i;
    revealItem(i);
    if (changed) onSelected?.call(i);
  }

  /// Scrolls item [i] into view (a scrolling bar does).
  @protected
  void revealItem(int i) {}

  int _cursor = -1;

  /// The item the keyboard is on while focused (-1: none).
  int get focusedIndex => focusNode.hasFocus ? _cursor : -1;

  int _hoveredItem = -1;

  /// The item under a mouse (-1: none).
  int get hoveredIndex => hovered ? _hoveredItem : -1;

  int? _downItem;

  /// The item being pressed (-1: none).
  int get pressedIndex => pressed ? (_downItem ?? -1) : -1;

  /// The item at [local] (-1: none).
  int indexAt(Offset local) {
    final rects = itemRects;
    for (var i = 0; i < rects.length; i++) {
      if (rects[i].contains(local)) return i;
    }
    return -1;
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyUpEvent || itemCount == 0) return false;
    final k = event.logicalKey;
    int? to;
    if (k == LogicalKeyboardKey.arrowRight) to = (_cursor + 1) % itemCount;
    if (k == LogicalKeyboardKey.arrowLeft) to = (_cursor - 1 + itemCount) % itemCount;
    if (k == LogicalKeyboardKey.home) to = 0;
    if (k == LogicalKeyboardKey.end) to = itemCount - 1;
    if (to == null) return false;
    _cursor = to;
    revealItem(to);
    markNeedsPaint();
    markNeedsSemanticsUpdate();
    return true;
  }

  void _activateFocused() {
    if (_cursor >= 0) select(_cursor);
  }

  /// A tap picks the item it went down on.
  @override
  void activate() {
    final i = _downItem;
    _downItem = null;
    if (i != null && i >= 0) select(i);
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (!interactive) return;
    if (event is PointerDownEvent) {
      _downItem = indexAt(entry.localPosition);
      markNeedsPaint();
    }
    if (event is PointerHoverEvent || event is PointerMoveEvent && event.kind == PointerDeviceKind.mouse) {
      final i = indexAt(entry.localPosition);
      if (i != _hoveredItem) {
        _hoveredItem = i;
        markNeedsPaint();
      }
    }
    super.handleEvent(event, entry);
  }

  @override
  PointerExitEventListener? get onExit => (e) {
        _hoveredItem = -1;
        super.onExit?.call(e);
      };

  @override
  MouseCursor get cursor => interactive && enabled ? SystemMouseCursors.click : MouseCursor.defer;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    for (final g in glyphs.glyphs) {
      g.attach(owner);
    }
    if (!interactive) focusNode.leave();
  }

  @override
  void detach() {
    motion.stop();
    super.detach();
    for (final g in glyphs.glyphs) {
      g.detach();
    }
  }

  @override
  void redepthChildren() {
    super.redepthChildren();
    glyphs.glyphs.forEach(redepthChild);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    super.visitChildren(visitor);
    glyphs.visit(visitor);
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  /// Shows [icons], one per item.
  @protected
  void syncGlyphs(List<Json> icons) {
    glyphs.sync(icons, adoptChild, dropChild);
    updateGlyphColors();
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    final i = glyphs.glyphs.indexWhere((g) => identical(g, child));
    if (i < 0) return;
    final o = glyphs.rectOf(i).topLeft + glyphPaintShift;
    transform.translateByDouble(o.dx, o.dy, 0, 1);
  }

  /// Where the glyphs are painted from, relative to their laid-out place (a
  /// scroll).
  @protected
  Offset get glyphPaintShift => Offset.zero;

  // --- semantics ---------------------------------------------------------------

  @override
  String get semanticsName => '';

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.explicitChildNodes = true;
    final role = itemRole;
    if (role == SemanticsRole.tab && itemCount > 0) config.role = SemanticsRole.tabBar;
    describeScrollSemantics(config);
  }

  /// A scrolling bar adds its scroll actions.
  @protected
  void describeScrollSemantics(SemanticsConfiguration config) {}

  final Map<int, SemanticsNode> _itemNodes = {};

  @override
  void assembleSemanticsNode(SemanticsNode node, SemanticsConfiguration config, Iterable<SemanticsNode> children) {
    final rects = itemRects;
    final out = <SemanticsNode>[];
    for (var i = 0; i < itemCount && i < rects.length; i++) {
      // A tab scrolled out of view is reached by scrolling (the bar's
      // scroll actions), not shown.
      final visible = rects[i].intersect(Offset.zero & size);
      if (visible.width <= 0 || visible.height <= 0) continue;
      final n = _itemNodes[i] ??= SemanticsNode(key: ValueKey<int>(i));
      final c = SemanticsConfiguration()
        ..isSemanticBoundary = true
        ..label = itemLabel(i)
        ..textDirection = TextDirection.ltr
        ..isSelected = i == _selected
        ..isEnabled = enabled
        ..isFocused = focusedIndex == i;
      final role = itemRole;
      if (role != null) {
        c.role = role;
      } else {
        c.isButton = true;
      }
      if (enabled) {
        c.onTap = () => select(i);
        c.onFocus = () {
          _cursor = i;
          focusNode.requestFocus();
          markNeedsPaint();
        };
      }
      n
        ..updateWith(config: c)
        ..rect = visible;
      out.add(n);
    }
    _itemNodes.removeWhere((k, _) => k >= itemCount);
    node.updateWith(config: config, childrenInInversePaintOrder: out);
  }

  @override
  void clearSemantics() {
    super.clearSemantics();
    _itemNodes.clear();
  }

  /// SSUI's focus ring around [rect] (an item's box).
  void paintItemFocusRing(Canvas canvas, Rect rect, Color color, double radius) =>
      paintFocusRing(canvas, RRect.fromRectAndRadius(rect, Radius.circular(radius)), color);

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }
}
