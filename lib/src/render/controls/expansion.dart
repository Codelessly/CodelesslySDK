// Accordions and expansion tiles as render objects (`accordion`,
// `expansionTile`): no Material `ExpansionTile`, no toggle button over the
// header. The whole header is the tap target; Enter and Space toggle it
// while focused; the content opens and closes on the tree's ticker over
// SSUI's `durations.control` (150 ms, ease in-out), clipped while it moves;
// screen readers hear a button that is expanded or collapsed.
//
// | Type | Header | Content |
// |---|---|---|
// | accordion | SSUI's Accordion: `tertiaryBackground`, a 1 px `primaryBorder`, radius `radii.panel` (8), 16 × 12 padding, its first child | its second child in a `primaryBackground` panel with the same border, 16 padding |
// | expansionTile | the `tile` slot's leading, title, subtitle and trailing laid out as a list tile (render/controls/tile.dart) | its children, in a column; `primaryBorder` hairlines above and below while open (`showDividers`) |
//
// The chevron is SSUI's (Lucide's chevron-right in `tertiaryText`), turning
// a quarter to point down as the content opens. Each accordion and tile
// opens on its own (several may be open at once, as before).
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show AccordionProps, ExpansionTileProps, Node;
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/foundation.dart' show immutable, listEquals, mapEquals;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../convert.dart';
import '../node_tree.dart' show NodeBox, Slot, SlotKind, fireTrigger;
import '../recipe.dart';
import 'kit.dart';
import 'tile.dart';
import 'tokens.dart';

/// The two looks of an expanding control.
enum ExpansionKind { accordion, tile }

/// The recipe of `accordion`: its first child is the header, its second the
/// content.
void accordionRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  String? at(int i) {
    final id = n.children.elementAtOrNull(i);
    return id != null && b.nodeOf(id) != null ? id : null;
  }

  final header = at(0), content = at(1);
  _expansion(
    b,
    n,
    chain,
    ExpansionSpec(
      kind: ExpansionKind.accordion,
      tokens: ControlTokens.of(b),
      header: null,
      crossAxis: crossAxisAlignment(n.prop(AccordionProps.crossAxisAlignment)),
    ),
    roles: {?header: 'title', ?content: 'body'},
    expanded: n.prop(AccordionProps.expanded),
  );
}

/// The recipe of `expansionTile`: the `tile` slot's slots make the header,
/// its children the content.
void expansionTileRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  final tokens = ControlTokens.of(b);
  final tile = b.nodeOf(n.slots['tile'] ?? '');
  final roles = <String, String>{
    if (tile != null)
      for (final s in tileSlots)
        if (tile.slots[s] case final String id when b.nodeOf(id) != null) id: s,
    for (final c in n.children)
      if (b.nodeOf(c) != null) c: 'body',
  };
  Color? c(api.Color? v) => v?.flutter;
  final density = n.prop(ExpansionTileProps.visualDensity);
  final radius = n.prop(ExpansionTileProps.radius).flutter;
  final align = n.prop(ExpansionTileProps.expandedAlignment);
  final cross = n.prop(ExpansionTileProps.expandedCrossAxisAlignment);
  final padding = n.layout.padding;
  _expansion(
    b,
    n,
    chain,
    ExpansionSpec(
      kind: ExpansionKind.tile,
      tokens: tokens,
      header: TileSpec.of(tile, tokens),
      maintainState: n.prop(ExpansionTileProps.maintainState),
      backgroundColor: c(n.prop(ExpansionTileProps.backgroundColor)),
      collapsedBackgroundColor: c(n.prop(ExpansionTileProps.collapsedBackgroundColor)),
      iconColor: c(n.prop(ExpansionTileProps.iconColor)),
      collapsedIconColor: c(n.prop(ExpansionTileProps.collapsedIconColor)),
      tilePadding: n.prop(ExpansionTileProps.tilePadding)?.flutter ?? (padding == api.EdgeInsets.zero ? null : padding.flutter),
      childrenPadding: n.prop(ExpansionTileProps.childrenPadding)?.flutter,
      expandedAlignment: align?.flutter,
      crossAxis: cross == null ? CrossAxisAlignment.center : crossAxisAlignment(cross),
      chevronLeading: n.prop(ExpansionTileProps.controlAffinity) == api.ListTileControlAffinity.leading,
      showChevron: n.prop(ExpansionTileProps.showTrailingIcon),
      showDividers: n.prop(ExpansionTileProps.showDividers),
      densityDy: density?.dy,
      shape: switch (n.prop(ExpansionTileProps.shape)) {
        final String s => _shape(s, radius),
        null => null,
      },
      collapsedShape: switch (n.prop(ExpansionTileProps.collapsedShape)) {
        final String s => _shape(s, radius),
        null => null,
      },
    ),
    roles: roles,
    expanded: n.prop(ExpansionTileProps.initiallyExpanded),
  );
}

void _expansion(NodeBuilder b, Node n, List<RenderBox> chain, ExpansionSpec spec,
    {required Map<String, String> roles, required bool expanded}) {
  final l = n.layout;
  chain.add(b.fitBox('fit', l.width.fit, l.height.fit, Size(l.width.value, l.height.value)));
  final interactive = b.tree.animates;
  final states = b.tree.statesOf(b.id, instance: b.instance);
  final patched = n.behaviors.states.patches.keys.toSet();
  final box = b.obtain<RenderExpansion>('expansion', RenderExpansion.new)
    ..interactive = interactive
    ..spec = spec
    ..roles = roles
    ..expandedFrom(expanded)
    ..selected = states.contains(api.WidgetState.selected)
    ..onToggled = interactive
        ? (open) {
            fireTrigger(b, 'click');
            fireTrigger(b, 'changed', event: {'value': open});
          }
        : null
    ..onStateChanged = interactive && patched.isNotEmpty
        ? (s, on) {
            if (patched.contains(s)) b.tree.setState(b.id, s, on, instance: b.instance);
          }
        : null;
  box.enabled = (spec.header?.enabled ?? true) && !states.contains(api.WidgetState.disabled);
  box.autofocus = interactive && (spec.header?.autofocus ?? false);
  b.syncChildren(box, roles.keys.toList(), Slot(SlotKind.root, n));
  chain.add(box);
  touchTarget(b, box, interactive: interactive);
}

/// A shape by its stored name (`CShapeBorder`), rounded by [radius].
OutlinedBorder _shape(String name, BorderRadius radius) => switch (name) {
      'circle' => const CircleBorder(),
      'stadium' => const StadiumBorder(),
      'beveledRectangle' => BeveledRectangleBorder(borderRadius: radius),
      'continuousRectangle' => ContinuousRectangleBorder(borderRadius: radius),
      _ => RoundedRectangleBorder(borderRadius: radius),
    };

/// What an expanding control shows, resolved from its node and tokens:
/// everything but its states.
@immutable
class ExpansionSpec {
  const ExpansionSpec({
    required this.kind,
    required this.tokens,
    required this.header,
    this.maintainState = false,
    this.backgroundColor,
    this.collapsedBackgroundColor,
    this.iconColor,
    this.collapsedIconColor,
    this.tilePadding,
    this.childrenPadding,
    this.expandedAlignment,
    this.crossAxis = CrossAxisAlignment.center,
    this.chevronLeading = false,
    this.showChevron = true,
    this.showDividers = true,
    this.densityDy,
    this.shape,
    this.collapsedShape,
  });

  final ExpansionKind kind;
  final ControlTokens tokens;

  /// The header's tile (an expansion tile's `tile` slot); null for an
  /// accordion.
  final TileSpec? header;

  /// Paint the content while closed (it is always laid out).
  final bool maintainState;
  final Color? backgroundColor, collapsedBackgroundColor, iconColor, collapsedIconColor;
  final EdgeInsets? tilePadding, childrenPadding;
  final Alignment? expandedAlignment;
  final CrossAxisAlignment crossAxis;
  final bool chevronLeading, showChevron, showDividers;
  final double? densityDy;
  final OutlinedBorder? shape, collapsedShape;

  bool get isAccordion => kind == ExpansionKind.accordion;

  /// SSUI's Accordion: 16 × 12 inside a 1 px border.
  static const accordionPadding = EdgeInsets.symmetric(horizontal: 17, vertical: 13);

  /// The header row's geometry.
  TileMetrics get headerMetrics {
    if (isAccordion) return const TileMetrics(padding: accordionPadding, gap: 8);
    final h = header ?? TileSpec(tokens: tokens);
    final m = h.metrics;
    return TileMetrics(
      padding: tilePadding ?? m.padding,
      gap: m.gap,
      minHeight: math.max(0, m.minHeight + (densityDy ?? 0) * 4),
      minVerticalPadding: m.minVerticalPadding,
      minLeadingWidth: m.minLeadingWidth,
      top: m.top,
      bottom: m.bottom,
    );
  }

  /// The chevron's square: SSUI's accordion draws it at 20, a tile row at 16.
  double get chevronSize => isAccordion ? 20 : 16;

  /// Around the content: an accordion's panel (16 inside a 1 px border), a
  /// tile's `childrenPadding`.
  EdgeInsets get contentInset => isAccordion ? const EdgeInsets.all(17) : (childrenPadding ?? EdgeInsets.zero);

  /// The panel corner radius (SSUI's `radii.panel`).
  double get panelRadius => tokens.radius('panel', 8);

  List<Object?> get _fields => [
        kind, tokens.theme, tokens.dark, tokens.backdrop, header, maintainState, backgroundColor, //
        collapsedBackgroundColor, iconColor, collapsedIconColor, tilePadding, childrenPadding, expandedAlignment, crossAxis,
        chevronLeading, showChevron, showDividers, densityDy, shape, collapsedShape,
      ];

  @override
  bool operator ==(Object other) => other is ExpansionSpec && listEquals(other._fields, _fields);

  @override
  int get hashCode => Object.hashAll(_fields);
}

/// An accordion or expansion tile: a header that toggles, its content
/// opening below it.
class RenderExpansion extends RenderControl
    with
        ContainerRenderObjectMixin<RenderBox, TileParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, TileParentData> {
  RenderExpansion() {
    onPressed = toggle;
  }

  bool _interactive = false;

  /// Whether it takes pointers and focus (a running app); a design canvas
  /// draws it at rest, open or closed as its node says.
  set interactive(bool v) {
    if (v == _interactive) return;
    _interactive = v;
    if (!v) {
      focusNode.leave();
      _ticker?.stop();
      _t = _expanded ? 1 : 0;
    }
    markNeedsLayout();
  }

  ExpansionSpec? _spec;
  ExpansionSpec get spec => _spec!;
  set spec(ExpansionSpec v) {
    if (v == _spec) return;
    _spec = v;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  Map<String, String> _roles = const {};

  /// Each child node's part, by node id: a header slot (leading, title,
  /// subtitle, trailing) or `body`.
  set roles(Map<String, String> v) {
    if (mapEquals(v, _roles)) return;
    _roles = v;
    markNeedsLayout();
  }

  /// Told after a tap, a key or a screen reader opened ([open]) or closed it.
  void Function(bool open)? onToggled;

  bool _expanded = false;
  bool? _fromNode;

  /// Whether it is open (or opening).
  bool get expanded => _expanded;

  /// How far open it is drawn now (0 closed, 1 open), eased.
  double get progress => _t;
  double _t = 0;

  /// The node's `expanded` (`initiallyExpanded`): when it changes, the
  /// control follows; a tap in between keeps its own.
  void expandedFrom(bool v) {
    if (v == _fromNode) return;
    final first = _fromNode == null;
    _fromNode = v;
    if (first) {
      _expanded = v;
      _t = v ? 1 : 0;
      markNeedsLayout();
      return;
    }
    _setExpanded(v);
  }

  /// Opens it when closed, closes it when open (a tap on the header, Enter,
  /// Space).
  void toggle() {
    if (!enabled) return;
    _setExpanded(!_expanded);
    onToggled?.call(_expanded);
  }

  void _setExpanded(bool v) {
    if (v == _expanded) return;
    _expanded = v;
    markNeedsSemanticsUpdate();
    _animateTo(v ? 1 : 0);
  }

  // --- the animation, on the tree's ticker -------------------------------------

  Ticker? _ticker;
  double _from = 0, _to = 0;
  Duration? _start;

  int get _ms => _spec?.tokens.controlMs ?? 150;

  void _animateTo(double to) {
    if (!_interactive || !attached || _ms <= 0) {
      _ticker?.stop();
      _t = to;
      markNeedsLayout();
      return;
    }
    _from = _t;
    _to = to;
    _start = null;
    final ticker = _ticker ??= Ticker(_tick, debugLabel: 'expansion');
    ticker.stop();
    ticker.start();
  }

  void _tick(Duration elapsed) {
    final start = _start ??= elapsed;
    final f = ((elapsed - start).inMicroseconds / 1000 / _ms).clamp(0.0, 1.0);
    _t = _from + (_to - _from) * Curves.easeInOut.transform(f);
    if (f >= 1) {
      _t = _to;
      _ticker?.stop();
    }
    markNeedsLayout();
  }

  /// Whether the content is moving.
  bool get animating => _ticker?.isActive ?? false;

  // --- children ------------------------------------------------------------------

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! TileParentData) child.parentData = TileParentData();
  }

  String _roleOf(RenderBox c, int i) =>
      (c is NodeBox ? _roles[c.id] : null) ?? (i < _roles.length ? _roles.values.elementAt(i) : 'body');

  Map<String, RenderBox> get _header {
    final out = <String, RenderBox>{};
    var i = 0;
    for (var c = firstChild; c != null; c = childAfter(c), i++) {
      final r = _roleOf(c, i);
      if (r != 'body') out[r] ??= c;
    }
    return out;
  }

  List<RenderBox> get _body {
    final out = <RenderBox>[];
    var i = 0;
    for (var c = firstChild; c != null; c = childAfter(c), i++) {
      if (_roleOf(c, i) == 'body') out.add(c);
    }
    return out;
  }

  /// The chevron's square, when the header shows one: a tile's slot on the
  /// chevron's side takes its place (as Flutter's `ExpansionTile`).
  double _chevron(Map<String, RenderBox> header) {
    final s = spec;
    if (s.isAccordion) return s.chevronSize;
    if (!s.showChevron) return 0;
    return header[s.chevronLeading ? 'leading' : 'trailing'] == null ? s.chevronSize : 0;
  }

  @override
  String get semanticsName => paragraphText([
        for (final e in _header.entries)
          if (e.key == 'title' || e.key == 'subtitle') e.value,
      ]);

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (_interactive) super.handleEvent(event, entry);
  }

  @override
  MouseCursor get cursor => _interactive ? super.cursor : MouseCursor.defer;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (!_interactive) focusNode.leave();
  }

  @override
  void detach() {
    // Off screen it lands where it was going.
    if (_ticker?.isActive ?? false) {
      _ticker!.stop();
      _t = _to;
    }
    super.detach();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    _clip.layer = null;
    _opacity.layer = null;
    super.dispose();
  }

  // --- layout ----------------------------------------------------------------------

  Rect _headerRect = Rect.zero;
  Rect? _chevronRect;
  double _bodyHeight = 0;

  /// The header's box (the tap target), in local coordinates.
  Rect get headerRect => _headerRect;

  /// The content's full height (open), inset included.
  double get contentHeight => _bodyHeight;

  @override
  double computeMinIntrinsicWidth(double height) {
    final header = _header, s = spec;
    final h = tileHeaderWidth(header, s.headerMetrics, chevron: _chevron(header));
    final body = _body.fold(0.0, (w, c) => math.max(w, c.getMaxIntrinsicWidth(double.infinity)));
    return math.max(h, _body.isEmpty ? 0 : body + s.contentInset.horizontal);
  }

  @override
  double computeMaxIntrinsicWidth(double height) => computeMinIntrinsicWidth(height);

  double _intrinsicHeight(double width) {
    final header = _header, s = spec, m = s.headerMetrics;
    double h(String n) => header[n]?.getMaxIntrinsicHeight(double.infinity) ?? 0;
    final text = h('title') + (header['subtitle'] == null ? 0 : h('subtitle') + m.subtitleGap);
    final row = [h('leading'), text, h('trailing'), _chevron(header)].reduce(math.max);
    final head = math.max(m.minHeight, row + math.max(m.padding.top, m.minVerticalPadding) + math.max(m.padding.bottom, m.minVerticalPadding));
    final body = _body;
    final content = body.isEmpty ? 0.0 : body.fold(0.0, (a, c) => a + c.getMaxIntrinsicHeight(double.infinity)) + s.contentInset.vertical;
    return head + content * _t;
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
    final c = constraints, s = spec;
    final header = _header, body = _body;
    final m = s.headerMetrics;
    final chevron = _chevron(header);
    final headerConstraints = BoxConstraints(minWidth: c.minWidth, maxWidth: c.maxWidth);
    var head = layoutTileHeader(header, headerConstraints, m, chevron: chevron, chevronLeading: s.chevronLeading);

    // The content: a column inside the inset, as wide as the control.
    final inset = s.contentInset;
    final innerMax = c.maxWidth.isFinite ? math.max(0.0, c.maxWidth - inset.horizontal) : double.infinity;
    final stretch = s.crossAxis == CrossAxisAlignment.stretch && innerMax.isFinite;
    var bodyW = 0.0, bodyH = 0.0;
    for (final child in body) {
      child.layout(stretch ? BoxConstraints.tightFor(width: innerMax) : BoxConstraints(maxWidth: innerMax), parentUsesSize: true);
      bodyW = math.max(bodyW, child.size.width);
      bodyH += child.size.height;
    }
    _bodyHeight = body.isEmpty ? 0 : bodyH + inset.vertical;
    final width = c.constrainWidth(math.max(head.size.width, body.isEmpty ? 0 : bodyW + inset.horizontal));
    if (width != head.size.width) {
      head = layoutTileHeader(header, BoxConstraints.tightFor(width: width), m, chevron: chevron, chevronLeading: s.chevronLeading);
    }
    _headerRect = Offset.zero & head.size;
    _chevronRect = head.chevron;
    size = c.constrain(Size(width, head.size.height + _bodyHeight * _t));

    // Each child at its place in the column (Flutter's ExpansionTile: the
    // column aligned by expandedAlignment, its children by the cross axis).
    final avail = math.max(0.0, width - inset.horizontal);
    final columnX = inset.left + (s.expandedAlignment == null ? (avail - bodyW) / 2 : (avail - bodyW) * (s.expandedAlignment!.x + 1) / 2);
    var y = head.size.height + inset.top;
    for (final child in body) {
      final x = switch (s.crossAxis) {
        CrossAxisAlignment.start => s.expandedAlignment == null ? inset.left : columnX,
        CrossAxisAlignment.end => s.expandedAlignment == null ? width - inset.right - child.size.width : columnX + bodyW - child.size.width,
        CrossAxisAlignment.stretch => inset.left,
        _ => s.expandedAlignment == null ? inset.left + (avail - child.size.width) / 2 : columnX + (bodyW - child.size.width) / 2,
      };
      (child.parentData! as BoxParentData).offset = Offset(x, y);
      y += child.size.height;
    }
  }

  // --- paint -------------------------------------------------------------------------

  /// The overlay of its state now (hover, press), if any.
  Color? get stateOverlay {
    if (!_interactive) return null;
    final t = spec.tokens;
    if (pressed) return t.pressedOverlay;
    if (hovered) return spec.header?.hoverColor ?? t.hoverOverlay;
    if (focusNode.hasFocus && spec.header?.focusColor != null) return spec.header!.focusColor;
    return null;
  }

  /// The chevron's color now.
  Color get chevronColor {
    final s = spec, t = s.tokens;
    final closed = s.collapsedIconColor ?? t.tertiaryText, open = s.iconColor ?? t.tertiaryText;
    return Color.lerp(closed, open, _t)!;
  }

  /// The header's fill now (null: none).
  Color? get headerFill {
    final s = spec;
    if (s.isAccordion) return s.tokens.tertiaryBackground;
    final closed = s.collapsedBackgroundColor, open = s.backgroundColor;
    if (closed == null && open == null) return selected ? s.tokens.activeTint : null;
    return Color.lerp(closed ?? const Color(0x00000000), open ?? const Color(0x00000000), _t);
  }

  /// The hairlines above and below an open tile (null: none now).
  Color? get dividerColor {
    final s = spec;
    if (s.isAccordion || !s.showDividers || _t <= 0) return null;
    final c = s.tokens.primaryBorder;
    return c.withValues(alpha: c.a * _t);
  }

  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();
  final LayerHandle<OpacityLayer> _opacity = LayerHandle<OpacityLayer>();

  /// Whether the content is cut at the bottom (opening, closing, or a box
  /// too short for it).
  bool get clipsContent => size.height < _headerRect.height + _bodyHeight - .01;

  /// The alpha it was last painted at (255: opaque; disabled 128).
  int get paintedAlpha => _opacity.layer?.alpha ?? 255;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!enabled) {
      _opacity.layer = context.pushOpacity(offset, 128, _paintClipped, oldLayer: _opacity.layer);
      return;
    }
    _opacity.layer = null;
    _paintClipped(context, offset);
  }

  void _paintClipped(PaintingContext context, Offset offset) {
    if (clipsContent) {
      _clip.layer = context.pushClipRect(needsCompositing, offset, Offset.zero & size, _paint, oldLayer: _clip.layer);
    } else {
      _clip.layer = null;
      _paint(context, offset);
    }
  }

  void _paint(PaintingContext context, Offset offset) {
    final s = spec, t = s.tokens;
    final canvas = context.canvas;
    final head = _headerRect.shift(offset);
    final showBody = _t > 0 || s.maintainState;
    if (s.isAccordion) {
      final r = Radius.circular(s.panelRadius);
      final open = _t > 0 && _bodyHeight > 0;
      final shape = open ? RRect.fromRectAndCorners(head, topLeft: r, topRight: r) : RRect.fromRectAndRadius(head, r);
      canvas.drawRRect(shape, Paint()..color = headerFill!);
      paintStateLayer(canvas, shape, stateOverlay);
      _hairline(canvas, shape, t.primaryBorder);
      if (open) {
        final panel = RRect.fromRectAndCorners(
            Rect.fromLTWH(head.left, head.bottom, head.width, _bodyHeight), bottomLeft: r, bottomRight: r);
        canvas.drawRRect(panel, Paint()..color = t.primaryBackground);
        _hairline(canvas, panel, t.primaryBorder);
      }
      if (focusHighlight) paintFocusRing(canvas, shape, t.focusBorder);
    } else {
      final whole = offset & size;
      final shape = _t >= .5 ? s.shape : s.collapsedShape;
      final fill = headerFill;
      if (fill != null && fill.a > 0) {
        if (shape != null) {
          canvas.drawPath(shape.getOuterPath(whole), Paint()..color = fill);
        } else {
          canvas.drawRect(whole, Paint()..color = fill);
        }
      }
      if (stateOverlay case final Color o when o.a > 0) canvas.drawRect(head, Paint()..color = o);
      if (dividerColor case final Color d) {
        final p = Paint()..color = d;
        canvas.drawRect(Rect.fromLTWH(whole.left, whole.top, whole.width, 1), p);
        canvas.drawRect(Rect.fromLTWH(whole.left, whole.bottom - 1, whole.width, 1), p);
      }
      if (focusHighlight) paintInsetFocusRing(canvas, head, null, t.focusBorder);
    }
    if (_chevronRect case final Rect r) paintChevron(canvas, r.shift(offset), chevronColor, turns: .25 * _t);
    var i = 0;
    for (var c = firstChild; c != null; c = childAfter(c), i++) {
      if (_roleOf(c, i) == 'body' && !showBody) continue;
      context.paintChild(c, offset + (c.parentData! as BoxParentData).offset);
    }
  }

  /// A 1 px border just inside [shape].
  static void _hairline(Canvas canvas, RRect shape, Color color) => canvas.drawRRect(
        shape.deflate(.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color,
      );

  // --- hit testing and semantics ----------------------------------------------

  /// Only the header takes the toggle: a tap in the content goes to the
  /// content (and through to the node's own reactions), never closes it.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    final child = hitTestChildren(result, position: position);
    if (_headerRect.contains(position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return child;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var i = childCount - 1;
    for (var c = lastChild; c != null; c = childBefore(c), i--) {
      if (_roleOf(c, i) == 'body' && _t <= 0) continue;
      final at = (c.parentData! as BoxParentData).offset;
      final hit = result.addWithPaintOffset(offset: at, position: position, hitTest: (r, p) => c!.hitTest(r, position: p));
      if (hit) return true;
    }
    return false;
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isButton = true
      ..isExpanded = _expanded
      // The content's nodes stay its own, not part of the header's label.
      ..explicitChildNodes = true;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    // The header's title and subtitle are its label; its leading and
    // trailing, and the content while open, speak for themselves.
    var i = 0;
    for (var c = firstChild; c != null; c = childAfter(c), i++) {
      final r = _roleOf(c, i);
      if (r == 'leading' || r == 'trailing' || (r == 'body' && _t > 0)) visitor(c);
    }
  }
}
