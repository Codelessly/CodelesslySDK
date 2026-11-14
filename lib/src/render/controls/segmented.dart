// The segmented button as a render object (`segmentedButton`), with no
// Material widget in its path. Unstyled it is SSUI's segmented control
// (design_systems/ssui: SoftSaaSSegmentedControl / SoftSaaSSegmentedTrack):
// a well (`subtleFill`; `secondaryBackground` with a `primaryBorder` hairline
// in dark), radius 7, its segments inset 2 px with radius 5, the selected
// one raised (`primaryBackground` with a `primaryBorder` hairline in light,
// `tertiaryBackground` in dark) in `onSurface`, the others in
// `secondaryText`. A hugging one is a control of the scale (28 high; its
// segments the scale's padding and font); a sized one takes its box, the
// metrics of the nearest step and its width shared between the segments.
//
// Each label is measured and centred in its segment, across and down (the
// glyphs, not the line: render/controls/kit.dart's ControlLabel). Tap a
// segment to choose it (multi-select toggles it, as Flutter's
// `SegmentedButton`); the arrow keys move the choice (multi-select: a
// cursor that Enter or Space toggles). `variant: track` keeps its
// `trackPadding`, `selectedShadows` and `slidingThumb`; every colour, side,
// radius, padding and text style prop applies over SSUI's.
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Json, Node, SegmentedButtonProps, SegmentedVariant, SizeFit;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../convert.dart';
import '../node_tree.dart' show NodeBox, fireTrigger;
import '../paint/icon_glyph.dart';
import '../recipe.dart';
import 'kit.dart';
import 'kit_toggles.dart';
import 'tokens.dart';

/// The recipe of `segmentedButton` (lib/src/widgets/controls.dart
/// registers it).
void segmentedRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  final l = n.layout;
  chain.add(b.fitBox('fit', l.width.fit, l.height.fit, Size(l.width.value, l.height.value)));
  final interactive = b.tree.animates;
  final states = b.tree.statesOf(b.id, instance: b.instance);
  final patched = n.behaviors.states.patches.keys.toSet();
  final box = b.obtain<RenderSegmentedButton>('segmented', RenderSegmentedButton.new)
    ..interactive = interactive
    ..configure(n, ControlTokens.of(b), inherited: b.slot.textDefault)
    ..onChanged = interactive ? (v) => fireTrigger(b, 'changed', event: {'value': v}) : null
    ..onStateChanged = interactive && patched.isNotEmpty
        ? (s, on) {
            if (patched.contains(s)) b.tree.setState(b.id, s, on, instance: b.instance);
          }
        : null;
  box.enabled = n.prop(SegmentedButtonProps.enabled) && !states.contains(api.WidgetState.disabled);
  chain.add(box);
  if (interactive && b is NodeBox) {
    final node = b;
    node.outsideHitTest = (result, position) {
      if (!box.hitTestTarget(result, node.localToGlobal(position))) return false;
      result.add(BoxHitTestEntry(node, position));
      return true;
    };
  }
}

/// One segment as drawn.
class _Segment {
  _Segment(this.value, this.label, this.icon, this.enabled, this.tooltip);
  final String value, label;
  final Json? icon;
  final bool enabled;
  final String? tooltip;
  final ControlLabel text = ControlLabel();
  RenderIconGlyph? glyph;
  Rect rect = Rect.zero;
  double labelLeft = 0;
  Rect iconRect = Rect.zero;
}

/// The font size of a segment at a step of the scale (SSUI's control
/// sizes: 11.5, 12, 12.5, 13, 15).
double _fontSize(ControlScale s) => switch (s.name) {
      'xs' => 11.5,
      'compact' => 12,
      'small' => 12.5,
      'medium' => 13,
      _ => 15,
    };

/// A segmented button: its well, its segments and the selection.
class RenderSegmentedButton extends RenderControl implements LabelledControl {
  RenderSegmentedButton() {
    onPressed = _pressed;
    focusNode.onKey = _key;
  }

  bool _interactive = false;

  /// Whether it takes pointers and focus (a running app).
  set interactive(bool v) {
    if (v == _interactive) return;
    _interactive = v;
    if (!v) focusNode.leave();
    markNeedsPaint();
  }

  Node? _node;
  late ControlTokens _tokens;
  TextStyle _own = const TextStyle();
  bool _configured = false;
  List<_Segment> _segments = [];

  Node get node => _node!;
  ControlTokens get tokens => _tokens;

  /// The node it draws and its tokens; [inherited] is the default text
  /// style it is under.
  void configure(Node n, ControlTokens tokens, {api.TextStyle? inherited}) {
    final changed = !_configured || n != _node || tokens.theme != _tokens.theme || tokens.dark != _tokens.dark || tokens.backdrop != _tokens.backdrop;
    _node = n;
    _tokens = tokens;
    _own = labelStyleOf(n.prop(SegmentedButtonProps.textStyle), inherited);
    if (changed) {
      _syncSegments();
      markNeedsLayout();
      markNeedsSemanticsUpdate();
    }
    _slide.duration = Duration(milliseconds: tokens.controlMs);
    final bound = n.prop(SegmentedButtonProps.selected);
    if (!_configured || !_sameList(bound, _bound)) {
      _bound = bound;
      _setSelection(bound.toSet(), fire: false, animate: _configured);
    }
    _configured = true;
  }

  static bool _sameList(List<String> a, List<String>? b) {
    if (b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _syncSegments() {
    final old = _segments;
    for (final s in old) {
      s.text.dispose();
      if (s.glyph != null) dropChild(s.glyph!);
    }
    _segments = [
      for (final s in node.prop(SegmentedButtonProps.segments))
        () {
          final icon = s.icon == null ? null : glyphOf(s.icon!.icon);
          // A segment needs a label or an icon.
          final label = s.label.isNotEmpty ? s.label : (icon == null ? s.value : '');
          return _Segment(s.value, label, icon, s.enabled, s.tooltip);
        }(),
    ];
    final selectedIcon = _selectedIcon;
    for (final s in _segments) {
      final g = s.icon ?? selectedIcon;
      if (g == null) continue;
      final glyph = RenderIconGlyph()..icon = g;
      s.glyph = glyph;
      adoptChild(glyph);
    }
  }

  /// The node's `selectedIcon` (Material's check is not drawn: SSUI has
  /// none).
  Json? get _selectedIcon {
    final i = node.prop(SegmentedButtonProps.selectedIcon);
    return i == null || !node.prop(SegmentedButtonProps.showSelectedIcon) ? null : glyphOf(i.icon);
  }

  /// Reports the new selection (`changed`, a list of values).
  void Function(List<String> value)? onChanged;

  List<String>? _bound;
  Set<String> _selected = {};

  /// The values chosen now, in segment order.
  List<String> get selection => [for (final s in _segments) if (_selected.contains(s.value)) s.value];

  bool get multi => node.prop(SegmentedButtonProps.multiSelectionEnabled);

  void _setSelection(Set<String> next, {required bool fire, bool animate = true}) {
    final values = {for (final s in _segments) s.value};
    var kept = next.where(values.contains).toSet();
    if (!multi && kept.length > 1) kept = {_segments.firstWhere((s) => kept.contains(s.value)).value};
    _selected = kept;
    final i = _segments.indexWhere((s) => kept.contains(s.value));
    if (i >= 0) {
      _cursor = i;
      _slide.animateTo(i.toDouble(), animate: animate && _interactive);
    }
    markNeedsPaint();
    markNeedsSemanticsUpdate();
    if (fire) onChanged?.call(selection);
  }

  /// Chooses segment [i], as a tap does.
  void choose(int i) {
    if (!enabled || !_interactive || i < 0 || i >= _segments.length) return;
    final s = _segments[i];
    if (!s.enabled) return;
    _cursor = i;
    final Set<String> next;
    if (multi) {
      next = _selected.contains(s.value) ? ({..._selected}..remove(s.value)) : {..._selected, s.value};
    } else {
      if (_selected.length == 1 && _selected.contains(s.value)) return;
      next = {s.value};
    }
    if (next.isEmpty && !node.prop(SegmentedButtonProps.emptySelectionAllowed)) return;
    _setSelection(next, fire: true);
  }

  // --- pointer -------------------------------------------------------------------------

  int? _downIndex;
  int? _hoverIndex;

  /// The segment under the pointer (null: none).
  int? get hoveredSegment => hovered ? _hoverIndex : null;

  int? _indexAt(Offset local) {
    for (var i = 0; i < _segments.length; i++) {
      if (_segments[i].rect.inflate(_inset).contains(local)) return i;
    }
    return null;
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (!_interactive) return;
    if (event is PointerHoverEvent || event is PointerDownEvent) {
      final i = _indexAt(event.localPosition);
      if (i != _hoverIndex) {
        _hoverIndex = i;
        markNeedsPaint();
      }
      if (event is PointerDownEvent) _downIndex = i;
    }
    super.handleEvent(event, entry);
  }

  void _pressed() {
    final i = _downIndex;
    _downIndex = null;
    if (i != null) choose(i);
  }

  @override
  MouseCursor get cursor => _interactive ? super.cursor : MouseCursor.defer;

  // --- keyboard -------------------------------------------------------------------------

  int _cursor = 0;

  /// The segment the keyboard is on.
  int get cursorSegment => _cursor;

  bool _key(KeyEvent event) {
    if (!_interactive || !enabled || _segments.isEmpty) return false;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final k = event.logicalKey;
    final forward = k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.arrowDown
        ? 1
        : k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowUp
            ? -1
            : 0;
    if (forward != 0) {
      // The next enabled segment, wrapping (SSUI's track).
      var i = _cursor;
      for (var tries = 0; tries < _segments.length; tries++) {
        i = (i + forward) % _segments.length;
        if (_segments[i].enabled) break;
      }
      if (!_segments[i].enabled) return true;
      if (multi) {
        _cursor = i;
        markNeedsPaint();
      } else {
        choose(i);
      }
      return true;
    }
    if (event is KeyDownEvent &&
        (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.space)) {
      choose(_cursor);
      return true;
    }
    return false;
  }

  // --- geometry ---------------------------------------------------------------------------

  bool get _vertical => node.prop(SegmentedButtonProps.direction) == api.Axis.vertical;
  bool get _track => node.prop(SegmentedButtonProps.variant) == SegmentedVariant.track;

  /// The gap between the well and its segments.
  double get _inset => _track ? math.max(0.0, node.prop(SegmentedButtonProps.trackPadding)) : 2;

  /// The height of one segment's row when nothing sets it.
  double get _naturalHeight {
    final own = node.prop(SegmentedButtonProps.segmentHeight);
    if (own != null && own > 0) return own + 2 * _inset;
    final pad = node.prop(SegmentedButtonProps.padding);
    final step = _tokens.defaultHeight;
    if (pad != null && pad.vertical > 0) return math.max(step, _lineHeight(_scale(step)) + pad.vertical + 2 * _inset);
    return step;
  }

  ControlScale _scale(double height) => _tokens.scaleFor(height);

  double _lineHeight(ControlScale s) => (_own.fontSize ?? _fontSize(s)) * (_own.height ?? 1.2);

  TextStyle _style(ControlScale s, Color color) => TextStyle(
        fontFamily: _own.fontFamily ?? _tokens.fontFamily,
        fontSize: _own.fontSize ?? _fontSize(s),
        fontWeight: _own.fontWeight ?? FontWeight.w500,
        fontStyle: _own.fontStyle,
        letterSpacing: _own.letterSpacing ?? 0,
        height: _own.height ?? 1.2,
        leadingDistribution: TextLeadingDistribution.even,
        color: color,
      );

  /// A segment's side padding: SSUI's `paddingX` and its 1 px hairline.
  double _padX(ControlScale s) {
    final pad = node.prop(SegmentedButtonProps.padding);
    return pad?.left ?? s.paddingX - 1;
  }

  /// One segment's natural width at [s], in a row [segH] high.
  double _segmentWidth(_Segment seg, ControlScale s, double segH) {
    seg.text.update(seg.label, _style(s, const Color(0xFF000000)));
    final hasIcon = seg.glyph != null;
    final iconOnly = seg.label.isEmpty;
    final content = (hasIcon ? s.iconSize : 0) + (hasIcon && !iconOnly ? s.gap : 0) + (iconOnly ? 0 : seg.text.intrinsicWidth);
    final pad = node.prop(SegmentedButtonProps.padding);
    final padding = iconOnly ? (pad?.horizontal ?? 0) : (pad?.horizontal ?? 2 * _padX(s));
    return math.max(segH, content + padding);
  }

  Size _naturalSize(double height) {
    final s = _scale(_vertical ? _naturalHeight : height);
    if (_vertical) {
      final segH = _naturalHeight - 2 * _inset;
      final w = _segments.fold<double>(0, (m, seg) => math.max(m, _segmentWidth(seg, s, segH)));
      return Size(w + 2 * _inset, _segments.length * segH + 2 * _inset);
    }
    final segH = height - 2 * _inset;
    final w = _segments.fold<double>(0, (sum, seg) => sum + _segmentWidth(seg, s, segH));
    return Size(w + 2 * _inset, height);
  }

  @override
  double computeMinIntrinsicWidth(double height) => _naturalSize(height.isFinite && height > 0 ? height : _naturalHeight).width;
  @override
  double computeMaxIntrinsicWidth(double height) => computeMinIntrinsicWidth(height);
  @override
  double computeMinIntrinsicHeight(double width) => _naturalSize(_naturalHeight).height;
  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  double _heightFor(BoxConstraints c) {
    if (c.hasTightHeight) return c.maxHeight;
    return c.constrainHeight(_naturalSize(_naturalHeight).height);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final h = _heightFor(constraints);
    return constraints.constrain(Size(_naturalSize(_vertical ? _naturalHeight : h).width, h));
  }

  late ControlScale _laidScale;

  @override
  void performLayout() {
    final h = _heightFor(constraints);
    final natural = _naturalSize(_vertical ? _naturalHeight : h);
    size = constraints.constrain(Size(natural.width, h));
    final inset = _inset;
    final n = _segments.length;
    if (n == 0) return;
    if (_vertical) {
      final segH = (size.height - 2 * inset) / n;
      final s = _laidScale = _scale(_naturalHeight);
      for (var i = 0; i < n; i++) {
        _placeSegment(_segments[i], Rect.fromLTWH(inset, inset + i * segH, math.max(0, size.width - 2 * inset), segH), s);
      }
      return;
    }
    final segH = math.max(0.0, size.height - 2 * inset);
    final s = _laidScale = _scale(size.height);
    final inner = math.max(0.0, size.width - 2 * inset);
    final widths = [for (final seg in _segments) _segmentWidth(seg, s, segH)];
    final total = widths.fold<double>(0, (a, b) => a + b);
    // Expanded (or a well wider than its segments): the room shared out
    // equally, so each label stays centred in its own segment.
    final equal = node.prop(SegmentedButtonProps.expanded) || _track && node.layout.width.fit != SizeFit.hug;
    final extra = (inner - total) / n;
    var x = inset;
    for (var i = 0; i < n; i++) {
      final w = equal ? inner / n : math.max(0.0, widths[i] + extra);
      _placeSegment(_segments[i], Rect.fromLTWH(x, inset, w, segH), s);
      x += w;
    }
  }

  void _placeSegment(_Segment seg, Rect rect, ControlScale s) {
    seg.rect = rect;
    final hasIcon = seg.glyph != null;
    final iconOnly = seg.label.isEmpty;
    final pad = node.prop(SegmentedButtonProps.padding);
    final padL = iconOnly ? (pad?.left ?? 0) : (pad?.left ?? _padX(s));
    final padR = iconOnly ? (pad?.right ?? 0) : (pad?.right ?? _padX(s));
    final iconW = hasIcon ? s.iconSize + (iconOnly ? 0 : s.gap) : 0.0;
    seg.text.update(seg.label, _style(s, const Color(0xFF000000)));
    seg.text.layout(math.max(0, rect.width - padL - padR - iconW));
    final content = iconW + (iconOnly ? 0 : seg.text.size.width);
    // The icon and label together, centred in the segment.
    final start = rect.left + padL + math.max(0.0, (rect.width - padL - padR - content) / 2);
    seg.iconRect = Rect.fromLTWH(start, rect.center.dy - s.iconSize / 2, hasIcon ? s.iconSize : 0, hasIcon ? s.iconSize : 0);
    seg.labelLeft = start + iconW;
    seg.glyph?.layout(BoxConstraints.tight(seg.iconRect.size));
    (seg.glyph?.parentData as BoxParentData?)?.offset = seg.iconRect.topLeft;
  }

  /// Each segment's box, in order.
  List<Rect> get segmentRects => [for (final s in _segments) s.rect];

  /// Whether segment [i]'s label is laid out whole (not ellipsised).
  bool labelFits(int i) {
    final t = _segments[i].text;
    return _segments[i].label.isEmpty || t.size.width >= t.intrinsicWidth - .5;
  }

  /// The segments drawn raised (with the selected fill and shadows).
  List<String> get raised => selection;

  /// The shadows under a raised segment.
  List<BoxShadow> get selectedShadows => _shadows;

  // --- look ------------------------------------------------------------------------------

  Color? _c(api.Color? c) => c?.flutter;

  /// The well's fill.
  Color get trackColor => _c(node.prop(SegmentedButtonProps.backgroundColor)) ?? (_tokens.dark ? _tokens.secondaryBackground : _tokens.subtleFill);

  /// The well's outline (null: none).
  BorderSide? get trackSide {
    final own = node.prop(SegmentedButtonProps.side);
    if (own != null) return borderSideOf(own);
    return _tokens.dark ? BorderSide(color: _tokens.primaryBorder) : null;
  }

  /// The selected segment's fill.
  Color get selectedColor =>
      _c(node.prop(SegmentedButtonProps.selectedBackgroundColor)) ??
      (_tokens.dark ? _tokens.tertiaryBackground : _tokens.primaryBackground);

  /// The selected segment's hairline (light only, as SSUI's).
  BorderSide? get _selectedSide =>
      _tokens.dark || node.prop(SegmentedButtonProps.selectedBackgroundColor) != null ? null : BorderSide(color: _tokens.primaryBorder);

  /// The label colour of segment [i] now.
  Color labelColorOf(int i) {
    final on = _selected.contains(_segments[i].value);
    if (on) return _c(node.prop(SegmentedButtonProps.selectedForegroundColor)) ?? _tokens.onSurface;
    if (hoveredSegment == i && _segments[i].enabled && enabled) return _c(node.prop(SegmentedButtonProps.selectedForegroundColor)) ?? _tokens.onSurface;
    return _c(node.prop(SegmentedButtonProps.foregroundColor)) ?? _tokens.secondaryText;
  }

  double get _radius {
    final r = node.prop(SegmentedButtonProps.borderRadius);
    return r?.topLeft ?? _tokens.radius('control', 7);
  }

  double get _segmentRadius => math.max(0, _radius - _inset);

  List<BoxShadow> get _shadows => [
        for (final e in node.prop(SegmentedButtonProps.selectedShadows))
          if (e.type == api.EffectType.dropShadow && e.visible) boxShadow(e),
      ];

  /// One thumb slides between the segments (single selection, a row).
  bool get _sliding => node.prop(SegmentedButtonProps.slidingThumb) && !multi && !_vertical;

  late final ControlEase _slide = ControlEase(this);

  final LayerHandle<OpacityLayer> _opacity = LayerHandle<OpacityLayer>();

  /// The alpha it was last painted at (255; disabled 128).
  int get paintedAlpha => _opacity.layer?.alpha ?? 255;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!enabled) {
      _opacity.layer = context.pushOpacity(offset, 128, _paintSegments, oldLayer: _opacity.layer);
      return;
    }
    _opacity.layer = null;
    _paintSegments(context, offset);
  }

  void _paintSegments(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final well = RRect.fromRectAndRadius(offset & size, Radius.circular(_radius));
    canvas.drawRRect(well, Paint()..color = trackColor);
    final segRadius = Radius.circular(_segmentRadius);
    final shadows = _shadows;
    void raised(Rect r) {
      final rr = RRect.fromRectAndRadius(r.shift(offset), segRadius);
      for (final sh in shadows) {
        canvas.drawRRect(rr.shift(sh.offset).inflate(sh.spreadRadius), sh.toPaint());
      }
      canvas.drawRRect(rr, Paint()..color = selectedColor);
      if (_selectedSide case final BorderSide side) {
        canvas.drawRRect(
            rr.deflate(side.width / 2),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = side.width
              ..color = side.color);
      }
    }

    if (_sliding && _segments.isNotEmpty && _selected.isNotEmpty) {
      // One thumb, between the segments it slides from and to.
      final at = _slide.value.clamp(0.0, _segments.length - 1.0);
      final i = at.floor(), j = math.min(i + 1, _segments.length - 1);
      raised(Rect.lerp(_segments[i].rect, _segments[j].rect, at - i)!);
    }
    for (var i = 0; i < _segments.length; i++) {
      final seg = _segments[i];
      final on = _selected.contains(seg.value);
      if (on && !_sliding) raised(seg.rect);
      if (!on && hoveredSegment == i && seg.enabled && enabled) {
        canvas.drawRRect(RRect.fromRectAndRadius(seg.rect.shift(offset), segRadius), Paint()..color = _tokens.hoverOverlay);
      }
      var color = labelColorOf(i);
      if (!seg.enabled) color = color.withValues(alpha: color.a * .5);
      if (seg.label.isNotEmpty) {
        seg.text.update(seg.label, _style(_laidScale, color));
        seg.text.layout(_labelWidth(seg));
        seg.text.paint(canvas, offset.dx + seg.labelLeft, offset.dy + seg.rect.center.dy);
      }
      final g = seg.glyph;
      if (g != null && (seg.icon != null || on)) context.paintChild(g, offset + seg.iconRect.topLeft);
    }
    if (trackSide case final BorderSide side when side.width > 0 && side.color.a > 0) {
      canvas.drawRRect(
          well.deflate(side.width / 2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = side.width
            ..color = side.color);
    }
    if (focusHighlight) {
      // SSUI: the well's edge in the focus colour; multi-select also rings
      // the segment the keyboard is on.
      canvas.drawRRect(
          well.deflate(.75),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = _tokens.focusBorder);
      if (multi && _cursor < _segments.length) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(_segments[_cursor].rect.shift(offset), segRadius).deflate(.75),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = _tokens.focusBorder);
      }
    }
  }

  /// The icons' colours follow the states: set whenever it is to be
  /// painted again (never while painting).
  @override
  void markNeedsPaint() {
    super.markNeedsPaint();
    if (_node == null) return;
    for (var i = 0; i < _segments.length; i++) {
      final seg = _segments[i];
      final g = seg.glyph;
      if (g == null) continue;
      final own = node.prop(SegmentedButtonProps.segments)[i].icon?.color?.flutter;
      var color = own ?? labelColorOf(i);
      if (!seg.enabled) color = color.withValues(alpha: color.a * .5);
      g.color = color;
    }
  }

  double _labelWidth(_Segment seg) {
    final s = _laidScale;
    final iconOnly = seg.label.isEmpty;
    final pad = node.prop(SegmentedButtonProps.padding);
    final padL = iconOnly ? (pad?.left ?? 0) : (pad?.left ?? _padX(s));
    final padR = iconOnly ? (pad?.right ?? 0) : (pad?.right ?? _padX(s));
    final iconW = seg.glyph != null ? s.iconSize + (iconOnly ? 0 : s.gap) : 0.0;
    return math.max(0, seg.rect.width - padL - padR - iconW);
  }

  @override
  List<({String text, String? fontFamily, List<Rect> glyphs})> get labels => !hasSize
      ? const []
      : [
          for (final seg in _segments)
            if (seg.label.isNotEmpty)
              (text: seg.label, fontFamily: seg.text.fontFamily, glyphs: seg.text.glyphBoxes(seg.labelLeft, seg.rect.center.dy)),
        ];

  // --- children (the segments' icons) ------------------------------------------------------

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    super.visitChildren(visitor);
    for (final s in _segments) {
      if (s.glyph != null) visitor(s.glyph!);
    }
  }

  @override
  void redepthChildren() {
    super.redepthChildren();
    for (final s in _segments) {
      if (s.glyph != null) redepthChild(s.glyph!);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    for (final s in _segments) {
      s.glyph?.attach(owner);
    }
    if (!_interactive) focusNode.leave();
  }

  @override
  void detach() {
    _slide.detach();
    _hoverIndex = null;
    super.detach();
    for (final s in _segments) {
      s.glyph?.detach();
    }
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    final o = (child.parentData as BoxParentData?)?.offset ?? Offset.zero;
    transform.translateByDouble(o.dx, o.dy, 0, 1);
  }

  // --- semantics ---------------------------------------------------------------------------

  @override
  String get semanticsName => '';

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.explicitChildNodes = true;
  }

  final List<SemanticsNode> _semantics = [];

  @override
  void assembleSemanticsNode(SemanticsNode node, SemanticsConfiguration config, Iterable<SemanticsNode> children) {
    while (_semantics.length < _segments.length) {
      _semantics.add(SemanticsNode());
    }
    final out = <SemanticsNode>[];
    for (var i = 0; i < _segments.length; i++) {
      final seg = _segments[i];
      final on = enabled && seg.enabled;
      final c = SemanticsConfiguration()
        ..isSemanticBoundary = true
        ..isButton = true
        ..isSelected = _selected.contains(seg.value)
        ..isEnabled = on
        ..label = seg.label.isNotEmpty ? seg.label : seg.tooltip ?? seg.value
        ..textDirection = TextDirection.ltr;
      if (on && _interactive) c.onTap = () => choose(i);
      out.add(_semantics[i]
        ..rect = seg.rect
        ..updateWith(config: c));
    }
    node.updateWith(config: config, childrenInInversePaintOrder: out);
  }

  @override
  void clearSemantics() {
    super.clearSemantics();
    _semantics.clear();
  }

  @override
  void dispose() {
    for (final s in _segments) {
      s.text.dispose();
    }
    _slide.dispose();
    _opacity.layer = null;
    super.dispose();
  }
}
