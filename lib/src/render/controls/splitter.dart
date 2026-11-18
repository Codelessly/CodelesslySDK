// A splitter changes a numeric width; its neighboring panes bind their
// layout to that value. The control itself owns pointer, keyboard, focus,
// semantics and the grip, independent of any one design system.
import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Node, SplitterProps;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../node_tree.dart' show fireTrigger;
import '../recipe.dart';
import 'kit.dart';
import 'tokens.dart';

void splitterRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  final l = n.layout;
  chain.add(
    b.fitBox(
      'fit',
      l.width.fit,
      l.height.fit,
      Size(l.width.value, l.height.value),
    ),
  );
  final interactive = b.tree.animates;
  final box = b.obtain<RenderSplitter>('splitter', RenderSplitter.new)
    ..configure(n, ControlTokens.of(b), Size(l.width.value, l.height.value))
    ..interactive = interactive
    ..onChanged = interactive
        ? (v) => fireTrigger(b, 'changed', event: {'value': v})
        : null
    ..onChangeEnd = interactive
        ? (v) => fireTrigger(b, 'changeEnd', event: {'value': v})
        : null;
  box.enabled = !b.tree
      .statesOf(b.id, instance: b.instance)
      .contains(api.WidgetState.disabled);
  chain.add(box);
}

class RenderSplitter extends RenderControl {
  RenderSplitter() {
    focusNode.onKey = _key;
    onPressed = _toggleCollapse;
    _installDrag(false);
  }

  void _installDrag(bool vertical) {
    _drag =
        (vertical
              ? VerticalDragGestureRecognizer(debugOwner: this)
              : HorizontalDragGestureRecognizer(debugOwner: this))
          ..onStart = (_) {
            _dragging = true;
            _dragStart = value;
            _raw = value;
            focusNode.requestFocus(highlight: false);
          }
          ..onUpdate = (d) {
            if (!_dragging) return;
            _raw +=
                (vertical
                    ? 1
                    : rtl
                    ? -1
                    : 1) *
                (d.primaryDelta ?? 0);
            _set(_raw);
          }
          ..onEnd = (_) {
            _finishDrag();
          }
          ..onCancel = _finishDrag;
  }

  late DragGestureRecognizer _drag;
  bool _verticalDrag = false;
  Node? _node;
  ControlTokens? _tokens;
  Size _design = Size.zero;
  bool _interactive = false;
  bool _dragging = false;
  double _dragStart = 0, _raw = 0, _value = 0, _remembered = 240;
  double? _bound;

  void Function(double)? onChanged, onChangeEnd;

  bool get interactive => _interactive;
  set interactive(bool v) {
    if (v == _interactive) return;
    _interactive = v;
    if (!v) focusNode.leave();
  }

  void configure(Node node, ControlTokens tokens, Size design) {
    final vertical = node.prop(SplitterProps.orientation) == api.Axis.vertical;
    if (vertical != _verticalDrag) {
      _drag.dispose();
      _verticalDrag = vertical;
      _installDrag(vertical);
    }
    final changed =
        node != _node ||
        tokens.theme != _tokens?.theme ||
        tokens.dark != _tokens?.dark ||
        design != _design;
    _node = node;
    _tokens = tokens;
    _design = design;
    semanticsLabel = node.prop(SplitterProps.label);
    final bound = node.prop(SplitterProps.value);
    if (_bound == null || bound != _bound) {
      _bound = bound;
      _value = bound;
      if (!_dragging && bound > min && bound < max) _remembered = bound;
    }
    if (changed) {
      markNeedsLayout();
      markNeedsPaint();
      markNeedsSemanticsUpdate();
    }
  }

  Node get node => _node!;
  ControlTokens get tokens => _tokens!;
  bool get rtl => node.behaviors.textDirection == api.TextDirection.rtl;
  bool get vertical =>
      node.prop(SplitterProps.orientation) == api.Axis.vertical;
  double get min => node.prop(SplitterProps.min);
  double get max =>
      node.prop(SplitterProps.max) < min ? min : node.prop(SplitterProps.max);
  double get step => node.prop(SplitterProps.step);
  double get value => _value.clamp(min, max).toDouble();

  void _set(double next, {bool end = false}) {
    final kept = next.clamp(min, max).toDouble();
    if (kept != _value) {
      _value = kept;
      if (!_dragging && kept > min && kept < max) _remembered = kept;
      markNeedsPaint();
      markNeedsSemanticsUpdate();
      onChanged?.call(kept);
    }
    if (end) onChangeEnd?.call(value);
  }

  void _finishDrag() {
    if (!_dragging) return;
    _dragging = false;
    final threshold = node
        .prop(SplitterProps.collapseAt)
        .clamp(0, (max - min) / 2);
    final collapsed = value - min <= threshold || max - value <= threshold;
    if (collapsed && _dragStart > min && _dragStart < max) {
      _remembered = _dragStart;
    }
    if (value - min <= threshold) _set(min);
    if (max - value <= threshold) _set(max);
    if (!collapsed && value > min && value < max) _remembered = value;
    onChangeEnd?.call(value);
  }

  void _toggleCollapse() => _set(
    value == min || value == max ? _remembered.clamp(min, max).toDouble() : min,
    end: true,
  );

  bool _key(KeyEvent event) {
    if (!_interactive ||
        !enabled ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return false;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape && _dragging) {
      _dragging = false;
      _set(_dragStart, end: true);
      return true;
    }
    final delta = switch (key) {
      LogicalKeyboardKey.arrowRight =>
        vertical
            ? null
            : rtl
            ? -step
            : step,
      LogicalKeyboardKey.arrowLeft =>
        vertical
            ? null
            : rtl
            ? step
            : -step,
      LogicalKeyboardKey.arrowUp => vertical ? -step : null,
      LogicalKeyboardKey.arrowDown => vertical ? step : null,
      LogicalKeyboardKey.pageUp => step * 10,
      LogicalKeyboardKey.pageDown => -step * 10,
      _ => null,
    };
    if (delta != null) {
      _set(value + delta, end: true);
      return true;
    }
    if (key == LogicalKeyboardKey.home) {
      _set(min, end: true);
      return true;
    }
    if (key == LogicalKeyboardKey.end) {
      _set(max, end: true);
      return true;
    }
    return false;
  }

  void increase() => _set(value + step, end: true);
  void decrease() => _set(value - step, end: true);

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerDownEvent && interactive && enabled) {
      _drag.addPointer(event);
    }
  }

  @override
  MouseCursor get cursor => interactive && enabled
      ? vertical
            ? SystemMouseCursors.resizeUpDown
            : SystemMouseCursors.resizeLeftRight
      : MouseCursor.defer;

  Size get _natural => Size(
    _design.width > 0 ? _design.width : 44,
    _design.height > 0 ? _design.height : 44,
  );
  @override
  double computeMinIntrinsicWidth(double height) => _natural.width;
  @override
  double computeMaxIntrinsicWidth(double height) => _natural.width;
  @override
  double computeMinIntrinsicHeight(double width) => _natural.height;
  @override
  double computeMaxIntrinsicHeight(double width) => _natural.height;
  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.constrain(_natural);
  @override
  void performLayout() => size = constraints.constrain(_natural);

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final area = offset & size;
    if (hovered || pressed) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(area.deflate(4), const Radius.circular(8)),
        Paint()..color = tokens.hoverOverlay,
      );
    }
    final center = area.center;
    // In a window a pointer works (a desktop's, 700 wide and up) the
    // splitter at rest is the hairline between its panes, as a desktop app's
    // is: the grip shows while the pointer is on it, it is held or it has
    // the keyboard's focus. On a phone, where nothing hovers, the grip
    // always shows (the line is 2 px, a thumb's mark).
    final grip = gripShown;
    final desk = _windowWidth >= 700;
    final line = desk && !grip ? 1.0 : 2.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: vertical ? size.width : line,
          height: vertical ? line : size.height,
        ),
        Radius.circular(line / 2),
      ),
      Paint()..color = tokens.primaryBorder,
    );
    for (final y in grip ? const [-8.0, 0.0, 8.0] : const <double>[]) {
      canvas.drawCircle(
        vertical ? center.translate(y, 0) : center.translate(0, y),
        1.5,
        Paint()..color = tokens.secondaryText,
      );
    }
    if (focusHighlight) {
      paintFocusRing(
        canvas,
        RRect.fromRectAndRadius(area.deflate(3), const Radius.circular(8)),
        tokens.focusBorder,
        width: 2,
      );
    }
  }

  /// Whether its grip (three dots) is drawn now: on a phone always; in a
  /// desktop window while it is hovered, held, dragged or focused.
  bool get gripShown => _windowWidth < 700 || hovered || pressed || _dragging || focusHighlight;

  /// The width of the window it is drawn in (its root's when there is no
  /// view above it).
  double get _windowWidth {
    RenderObject? at = this;
    RenderObject? last;
    while (at != null) {
      if (at is RenderView) return at.size.width;
      last = at;
      at = at.parent;
    }
    return last is RenderBox && last.hasSize ? last.size.width : 0;
  }

  @override
  String get semanticsName => node.prop(SplitterProps.label);

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSlider = true
      ..value =
          '${value.round()} pixels${value == min
              ? ', leading pane collapsed'
              : value == max
              ? ', trailing pane collapsed'
              : ''}'
      ..increasedValue = '${(value + step).clamp(min, max).round()} pixels'
      ..decreasedValue = '${(value - step).clamp(min, max).round()} pixels'
      ..textDirection = rtl ? TextDirection.rtl : TextDirection.ltr;
    if (interactive && enabled) {
      config
        ..onIncrease = increase
        ..onDecrease = decrease;
    }
  }

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }
}
