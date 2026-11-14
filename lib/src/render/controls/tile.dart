// List tiles as render objects (`listTile`), and what the expansion tiles
// (render/controls/expansion.dart) share with them: the slot layout of a
// tile's header and SSUI's chevron. No Material widget in their path.
// Unstyled, a list tile is SSUI's ListRow (design_systems/ssui/components/
// ListRow.json):
//
// | Part | SSUI | Flutter prop over it |
// |---|---|---|
// | height | 36 (`sizes.tableRow`), dense 28 (`tableRowDense`) | `minTileHeight`, `visualDensity` |
// | padding | 12 × 6 | `contentPadding` (else the node's padding) |
// | gap | 10 between leading, text and trailing | `horizontalTitleGap` |
// | divider | none: a list draws the dividers between its rows (`listView` `separator`) | the list's `separator` props |
// | hover / press | `hoverOverlay` / `pressedOverlay` | `hoverColor` |
// | selected | `activeTint` | `selectedTileColor` |
//
// The slots (leading, title, subtitle, trailing) are nodes: the tree lays
// each out by its own fits, this box places them. The whole tile is the tap
// target; Enter and Space press it while focused.
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show ListTileProps, Node, TriggerType;
import 'package:flutter/foundation.dart' show immutable, listEquals, mapEquals;
import 'package:flutter/rendering.dart';

import '../convert.dart';
import '../node_tree.dart' show NodeBox, Slot, SlotKind, fireTrigger;
import '../recipe.dart';
import 'buttons.dart' show outlinedBorder;
import 'kit.dart';
import 'tokens.dart';

/// The slots of a tile, in the order its children are placed.
const tileSlots = ['leading', 'title', 'subtitle', 'trailing'];

/// The recipe of `listTile`: lib/src/widgets/controls.dart registers it.
void listTileRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  final l = n.layout;
  chain.add(b.fitBox('fit', l.width.fit, l.height.fit, Size(l.width.value, l.height.value)));
  final interactive = b.tree.animates;
  final states = b.tree.statesOf(b.id, instance: b.instance);
  final patched = n.behaviors.states.patches.keys.toSet();
  final spec = TileSpec.of(n, ControlTokens.of(b));
  final ids = <String, String>{
    for (final s in tileSlots)
      if (n.slots[s] case final String id when b.nodeOf(id) != null) id: s,
  };
  final box = b.obtain<RenderListTile>('tile', RenderListTile.new)
    ..interactive = interactive
    ..spec = spec
    ..slotOf = ids
    ..selected = spec.selected || states.contains(api.WidgetState.selected)
    ..onPressed = interactive ? () => fireTrigger(b, 'click') : null
    ..onStateChanged = interactive && patched.isNotEmpty
        ? (s, on) {
            if (patched.contains(s)) b.tree.setState(b.id, s, on, instance: b.instance);
          }
        : null;
  box.enabled = spec.enabled && !states.contains(api.WidgetState.disabled);
  box.focusNode.canRequestFocus = box.enabled && spec.pressable;
  box.autofocus = interactive && spec.autofocus;
  b.syncChildren(box, ids.keys.toList(), Slot(SlotKind.root, n));
  chain.add(box);
  touchTarget(b, box, interactive: interactive);
}

/// On a touch screen a tile shorter than 44 px takes taps in a 44 px band
/// around it (hit testing only: its box keeps its size), as a button does.
void touchTarget(NodeBuilder b, RenderControl control, {required bool interactive}) {
  if (!interactive || b is! NodeBox) return;
  final node = b;
  node.outsideHitTest = (result, position) {
    if (!control.hitTestTarget(result, node.localToGlobal(position))) return false;
    result.add(BoxHitTestEntry(node, position));
    return true;
  };
}

/// Whether [n] has reactions to a tap (its tile then takes focus and shows
/// the hand cursor).
bool hasClick(Node n) => n.actions.any((r) => r.trigger.type == TriggerType.click);

/// A tile's header geometry and look, from a `listTile` node (or the `tile`
/// slot of an `expansionTile`) and tokens.
@immutable
class TileSpec {
  const TileSpec({
    required this.tokens,
    this.dense = false,
    this.isThreeLine = false,
    this.densityDy = 0,
    this.shape,
    this.selected = false,
    this.enabled = true,
    this.autofocus = false,
    this.pressable = false,
    this.tileColor,
    this.selectedTileColor,
    this.hoverColor,
    this.focusColor,
    this.padding,
    this.titleGap,
    this.minVerticalPadding,
    this.minLeadingWidth,
    this.minTileHeight,
    this.titleAlignment,
  });

  final ControlTokens tokens;
  final bool dense, isThreeLine;

  /// `visualDensity.vertical`: 4 px of height a step, as Flutter's.
  final double densityDy;
  final OutlinedBorder? shape;
  final bool selected, enabled, autofocus;

  /// It has a tap reaction: it takes focus and the hand cursor.
  final bool pressable;
  final Color? tileColor, selectedTileColor, hoverColor, focusColor;
  final EdgeInsets? padding;
  final double? titleGap, minVerticalPadding, minLeadingWidth, minTileHeight;
  final api.ListTileTitleAlignment? titleAlignment;

  /// A plain tile: SSUI's look and nothing else ([n] null).
  factory TileSpec.of(Node? n, ControlTokens tokens) {
    if (n == null) return TileSpec(tokens: tokens);
    Color? c(api.Color? v) => v?.flutter;
    final shape = n.prop(ListTileProps.shape);
    final own = n.layout.padding;
    return TileSpec(
      tokens: tokens,
      dense: n.prop(ListTileProps.dense),
      isThreeLine: n.prop(ListTileProps.isThreeLine),
      densityDy: n.prop(ListTileProps.visualDensity)?.vertical ?? 0,
      shape: shape == null ? null : outlinedBorder(shape),
      selected: n.prop(ListTileProps.selected),
      enabled: n.prop(ListTileProps.enabled),
      autofocus: n.prop(ListTileProps.autofocus),
      pressable: hasClick(n),
      tileColor: c(n.prop(ListTileProps.tileColor)),
      selectedTileColor: c(n.prop(ListTileProps.selectedTileColor)),
      hoverColor: c(n.prop(ListTileProps.hoverColor)),
      focusColor: c(n.prop(ListTileProps.focusColor)),
      padding: n.prop(ListTileProps.contentPadding)?.flutter ?? (own == api.EdgeInsets.zero ? null : own.flutter),
      titleGap: n.prop(ListTileProps.horizontalTitleGap),
      minVerticalPadding: n.prop(ListTileProps.minVerticalPadding),
      minLeadingWidth: n.prop(ListTileProps.minLeadingWidth),
      minTileHeight: n.prop(ListTileProps.minTileHeight),
      titleAlignment: n.prop(ListTileProps.titleAlignment),
    );
  }

  /// SSUI's ListRow padding (12 × 6), or the node's.
  EdgeInsets get effectivePadding => padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6);

  /// SSUI's row heights: 36, 28 dense, or `minTileHeight`; visual density
  /// moves it 4 px a step.
  double get minHeight =>
      math.max(0, (minTileHeight ?? (dense ? tokens.size('tableRowDense', 28) : tokens.size('tableRow', 36))) + densityDy * 4);

  /// Between leading, the text and trailing (SSUI's 10).
  double get gap => titleGap ?? 10;

  TileMetrics get metrics => TileMetrics(
        padding: effectivePadding,
        gap: gap,
        minHeight: minHeight,
        minVerticalPadding: minVerticalPadding ?? 0,
        minLeadingWidth: minLeadingWidth ?? 0,
        top: switch (titleAlignment) {
          api.ListTileTitleAlignment.top || api.ListTileTitleAlignment.titleHeight => true,
          api.ListTileTitleAlignment.threeLine || null => isThreeLine,
          _ => false,
        },
        bottom: titleAlignment == api.ListTileTitleAlignment.bottom,
      );

  List<Object?> get _fields => [
        tokens.theme, tokens.dark, tokens.backdrop, dense, isThreeLine, densityDy, shape, selected, enabled, autofocus, //
        pressable, tileColor, selectedTileColor, hoverColor, focusColor, padding, titleGap, minVerticalPadding,
        minLeadingWidth, minTileHeight, titleAlignment,
      ];

  @override
  bool operator ==(Object other) => other is TileSpec && listEquals(other._fields, _fields);

  @override
  int get hashCode => Object.hashAll(_fields);
}

/// The tokens tiles draw with beyond the kit's (SSUI's names).
extension TileTokens on ControlTokens {
  Color _named(String name, Color fallback) => theme.color(name)?.flutter ?? fallback;

  /// A panel's fill (SSUI's `primaryBackground`): the surface.
  Color get primaryBackground => _named('primaryBackground', surface);

  /// Muted marks: a chevron (SSUI's `tertiaryText`).
  Color get tertiaryText => _named('tertiaryText', onSurface.withValues(alpha: .4));

  /// A theme size (`sizes.tableRow`...), else [fallback].
  double size(String name, double fallback) => theme.sizes[name] ?? fallback;
}

/// The geometry of a tile's header row.
@immutable
class TileMetrics {
  const TileMetrics({
    required this.padding,
    this.gap = 10,
    this.minHeight = 0,
    this.minVerticalPadding = 0,
    this.minLeadingWidth = 0,
    this.subtitleGap = 1,
    this.top = false,
    this.bottom = false,
  });

  final EdgeInsets padding;
  final double gap, minHeight, minVerticalPadding, minLeadingWidth, subtitleGap;

  /// The slots sit at the top (bottom) of a taller row, not centered.
  final bool top, bottom;
}

/// Where a header's parts went: its size, and the chevron's square (when it
/// has one).
typedef TileHeader = ({Size size, Rect? chevron});

/// Lays out a tile's [slots] (by name: leading, title, subtitle, trailing)
/// as Flutter's `ListTile` places them, in SSUI's metrics: leading, then the
/// title over the subtitle taking what is left, then trailing; each centered
/// on the row (or at its top or bottom). A [chevron] square of that side
/// goes first ([chevronLeading]) or last, [m]'s gap from the slots. The
/// children's offsets are set relative to [origin]; the width is
/// [constraints]' (or, loose, the content's).
TileHeader layoutTileHeader(
  Map<String, RenderBox> slots,
  BoxConstraints constraints,
  TileMetrics m, {
  double chevron = 0,
  bool chevronLeading = false,
  Offset origin = Offset.zero,
}) {
  final pad = m.padding;
  final reserve = chevron > 0 ? chevron + m.gap : 0.0;
  final maxW = constraints.maxWidth;
  final inner = maxW.isFinite ? math.max(0.0, maxW - pad.horizontal - reserve) : double.infinity;
  final lead = slots['leading'], trail = slots['trailing'], title = slots['title'], sub = slots['subtitle'];
  lead?.layout(BoxConstraints(maxWidth: inner), parentUsesSize: true);
  trail?.layout(BoxConstraints(maxWidth: inner), parentUsesSize: true);
  final leadW = lead == null ? 0.0 : math.max(lead.size.width, m.minLeadingWidth) + m.gap;
  final trailW = trail == null ? 0.0 : trail.size.width + m.gap;
  final textMax = inner.isFinite ? math.max(0.0, inner - leadW - trailW) : double.infinity;
  title?.layout(BoxConstraints(maxWidth: textMax), parentUsesSize: true);
  sub?.layout(BoxConstraints(maxWidth: textMax), parentUsesSize: true);
  final textW = math.max(title?.size.width ?? 0, sub?.size.width ?? 0);
  final textH = (title?.size.height ?? 0) + (sub == null ? 0 : sub.size.height + (title == null ? 0 : m.subtitleGap));
  final width = constraints.constrainWidth(pad.horizontal + reserve + leadW + textW + trailW);
  final contentH = [lead?.size.height ?? 0, textH, trail?.size.height ?? 0, chevron].reduce(math.max);
  final top = math.max(pad.top, m.minVerticalPadding), bottom = math.max(pad.bottom, m.minVerticalPadding);
  final height = constraints.constrainHeight(math.max(m.minHeight, top + contentH + bottom));
  double y(double h) => m.top ? top : m.bottom ? height - bottom - h : (height - h) / 2;
  void place(RenderBox? c, double x, double dy) {
    if (c != null) (c.parentData! as BoxParentData).offset = origin + Offset(x, dy);
  }

  final start = pad.left + (chevronLeading ? reserve : 0);
  final end = width - pad.right - (chevronLeading ? 0 : reserve);
  place(lead, start, y(lead?.size.height ?? 0));
  final textTop = y(textH);
  place(title, start + leadW, textTop);
  place(sub, start + leadW, textTop + (title == null ? 0 : title.size.height + m.subtitleGap));
  place(trail, end - (trail?.size.width ?? 0), y(trail?.size.height ?? 0));
  final chevronRect = chevron <= 0
      ? null
      : Rect.fromLTWH(chevronLeading ? pad.left : width - pad.right - chevron, y(chevron), chevron, chevron).shift(origin);
  return (size: Size(width, height), chevron: chevronRect);
}

/// The widest a header's content is on one line (its intrinsic width).
double tileHeaderWidth(Map<String, RenderBox> slots, TileMetrics m, {double chevron = 0}) {
  double w(String s) => slots[s]?.getMaxIntrinsicWidth(double.infinity) ?? 0;
  final lead = slots['leading'] == null ? 0.0 : math.max(w('leading'), m.minLeadingWidth) + m.gap;
  final trail = slots['trailing'] == null ? 0.0 : w('trailing') + m.gap;
  return m.padding.horizontal + (chevron > 0 ? chevron + m.gap : 0) + lead + math.max(w('title'), w('subtitle')) + trail;
}

/// Paints SSUI's chevron (Lucide's `chevron-right`, a 2 px stroke on a 24
/// grid) in [rect], turned [turns] of a full turn (a quarter: pointing
/// down).
void paintChevron(Canvas canvas, Rect rect, Color color, {double turns = 0}) {
  final s = rect.width / 24;
  canvas.save();
  canvas.translate(rect.center.dx, rect.center.dy);
  if (turns != 0) canvas.rotate(turns * 2 * math.pi);
  canvas.scale(s);
  final path = Path()
    ..moveTo(-3, 6)
    ..lineTo(3, 0)
    ..lineTo(-3, -6);
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = color,
  );
  canvas.restore();
}

/// The text of the paragraphs under [boxes] (what a screen reader reads
/// for a header whose slots are nodes), one line each.
String paragraphText(Iterable<RenderBox> boxes) {
  final out = <String>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph) {
      final t = o.text.toPlainText().trim();
      if (t.isNotEmpty) out.add(t);
      return;
    }
    o.visitChildren(visit);
  }

  for (final b in boxes) {
    visit(b);
  }
  return out.join('\n');
}

/// A child of a tile: its offset.
class TileParentData extends ContainerBoxParentData<RenderBox> {}

/// A list tile: its slots placed as a row, SSUI's row look, its states.
class RenderListTile extends RenderControl
    with
        ContainerRenderObjectMixin<RenderBox, TileParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, TileParentData> {
  RenderListTile();

  bool _interactive = false;

  /// Whether it takes pointers and focus (a running app); a design canvas
  /// draws it at rest.
  set interactive(bool v) {
    if (v == _interactive) return;
    _interactive = v;
    if (!v) focusNode.leave();
    markNeedsPaint();
  }

  TileSpec? _spec;
  TileSpec get spec => _spec!;
  set spec(TileSpec v) {
    if (v == _spec) return;
    _spec = v;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  Map<String, String> _slotOf = const {};

  /// Each child node's slot, by node id.
  set slotOf(Map<String, String> v) {
    if (mapEquals(v, _slotOf)) return;
    _slotOf = v;
    markNeedsLayout();
  }

  /// The children by slot.
  Map<String, RenderBox> get slots {
    final out = <String, RenderBox>{};
    var i = 0;
    for (var c = firstChild; c != null; c = childAfter(c), i++) {
      final s = c is NodeBox ? _slotOf[c.id] : null;
      out[s ?? (i < _slotOf.length ? _slotOf.values.elementAt(i) : 'title')] ??= c;
    }
    return out;
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! TileParentData) child.parentData = TileParentData();
  }

  @override
  String get semanticsName => paragraphText([?slots['title'], ?slots['subtitle']]);

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (_interactive) super.handleEvent(event, entry);
  }

  @override
  MouseCursor get cursor => _interactive && enabled && spec.pressable ? SystemMouseCursors.click : MouseCursor.defer;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (!_interactive) focusNode.leave();
  }

  // --- layout -----------------------------------------------------------------

  @override
  double computeMinIntrinsicWidth(double height) => tileHeaderWidth(slots, spec.metrics);

  @override
  double computeMaxIntrinsicWidth(double height) => computeMinIntrinsicWidth(height);

  double _intrinsicHeight(double width) {
    final s = slots, m = spec.metrics;
    double h(String n) => s[n]?.getMaxIntrinsicHeight(double.infinity) ?? 0;
    final text = h('title') + (s['subtitle'] == null ? 0 : h('subtitle') + m.subtitleGap);
    final content = [h('leading'), text, h('trailing')].reduce(math.max);
    return math.max(m.minHeight, content + math.max(m.padding.top, m.minVerticalPadding) + math.max(m.padding.bottom, m.minVerticalPadding));
  }

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.constrain(Size(computeMaxIntrinsicWidth(double.infinity), _intrinsicHeight(double.infinity)));

  @override
  void performLayout() {
    size = layoutTileHeader(slots, constraints, spec.metrics).size;
  }

  // --- paint ------------------------------------------------------------------

  /// The fill now (null: none), before the state layer.
  Color? get fillColor {
    final s = spec;
    var fill = s.tileColor;
    if (selected) {
      fill = s.selectedTileColor ?? Color.alphaBlend(s.tokens.activeTint, fill ?? const Color(0x00000000));
    }
    return fill;
  }

  /// The overlay of its state now (hover, press, a focus color), if any.
  Color? get stateOverlay {
    if (!_interactive) return null;
    final s = spec, t = s.tokens;
    if (pressed && s.pressable) return t.pressedOverlay;
    if (hovered) return s.hoverColor ?? t.hoverOverlay;
    if (focusNode.hasFocus && s.focusColor != null) return s.focusColor;
    return null;
  }


  final LayerHandle<OpacityLayer> _opacity = LayerHandle<OpacityLayer>();

  /// The alpha it was last painted at (255: opaque; a disabled tile 128).
  int get paintedAlpha => _opacity.layer?.alpha ?? 255;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!enabled) {
      _opacity.layer = context.pushOpacity(offset, 128, _paintTile, oldLayer: _opacity.layer);
      return;
    }
    _opacity.layer = null;
    _paintTile(context, offset);
  }

  void _paintTile(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final rect = offset & size;
    final shape = spec.shape;
    final path = shape?.getOuterPath(rect);
    void fill(Color c) => path == null ? canvas.drawRect(rect, Paint()..color = c) : canvas.drawPath(path, Paint()..color = c);
    if (fillColor case final Color c when c.a > 0) fill(c);
    if (stateOverlay case final Color c when c.a > 0) fill(c);
    if (shape != null) shape.paint(canvas, rect);
    defaultPaint(context, offset);
    if (focusHighlight) paintInsetFocusRing(canvas, rect, shape, spec.tokens.focusBorder);
  }

  // --- hit testing and semantics ----------------------------------------------

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isButton = spec.pressable
      ..isSelected = selected
      // Its slots' own nodes stay theirs (a trailing switch).
      ..explicitChildNodes = true;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    // The title and subtitle are its label; leading and trailing (a switch,
    // an avatar) speak for themselves.
    final s = slots;
    for (final name in const ['leading', 'trailing']) {
      if (s[name] case final RenderBox c) visitor(c);
    }
  }

  @override
  void dispose() {
    _opacity.layer = null;
    super.dispose();
  }
}

/// SSUI's focus ring drawn just inside [rect] (or [shape]): a tile spans its
/// list, so a ring outside it would be cut by what is next to it.
void paintInsetFocusRing(Canvas canvas, Rect rect, OutlinedBorder? shape, Color color, {double width = 1.5}) {
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..color = color;
  final inner = rect.deflate(width / 2);
  if (shape == null) {
    canvas.drawRect(inner, paint);
  } else {
    canvas.drawPath(shape.getOuterPath(inner), paint);
  }
}
