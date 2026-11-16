// The overlay layer's entries (render/controls/root.dart shows them above
// the screen): what Flutter's `Overlay` and `OverlayEntry` are for widgets.
// The first entry is the tooltip: SSUI's dark pill, shown after
// `durations.tooltipDelay` of hovering, keyboard focus or a touch hold.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind, TextDirection;

import 'package:codelessly_api/core.dart' as api show ThemeTokens;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'focus.dart';
import 'root.dart';
import 'tokens.dart';

/// A box shown in a root's overlay layer: laid out with loose constraints of
/// the root's size and placed by [placeIn].
abstract class RenderOverlayEntry extends RenderBox {
  /// Where its top left goes in [root] (of [rootSize]), after its layout.
  Offset placeIn(RenderControlRoot root, Size rootSize);

  /// Whether it takes pointers (a menu does; a tooltip doesn't).
  bool get hitTestable => false;
}

/// A tooltip's bubble: [message] in a pill above [anchor] (below when there
/// is no room), centered on it and kept 8 px inside the root.
class RenderTooltipBubble extends RenderOverlayEntry {
  RenderTooltipBubble({required this.anchor, required String message, required ControlTokens tokens, required this._direction})
      : _message = message, // ignore: prefer_initializing_formals
        _tokens = tokens; // ignore: prefer_initializing_formals

  /// What it points at.
  RenderBox anchor;

  String _message;
  String get message => _message;
  set message(String v) {
    if (v == _message) return;
    _message = v;
    markNeedsLayout();
  }

  ControlTokens _tokens;
  set tokens(ControlTokens v) {
    _tokens = v;
    markNeedsLayout();
  }

  TextDirection _direction;
  TextDirection get direction => _direction;
  set direction(TextDirection v) {
    if (v == _direction) return;
    _direction = v;
    _text.textDirection = v;
    markNeedsLayout();
  }

  static const _padding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
  static const _gap = 6.0;
  static const _maxWidth = 250.0;

  final TextPainter _text = TextPainter(textDirection: TextDirection.ltr);

  @override
  void performLayout() {
    _text.textDirection = _direction;
    _text.text = TextSpan(
      text: _message,
      style: TextStyle(
        fontFamily: _tokens.fontFamily,
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        height: 1.2,
        leadingDistribution: TextLeadingDistribution.even,
        color: _tokens.tooltipText,
      ),
    );
    _text.layout(maxWidth: math.min(_maxWidth, constraints.maxWidth) - _padding.horizontal);
    size = constraints.constrain(Size(_text.width + _padding.horizontal, _text.height + _padding.vertical));
  }

  /// Where [anchor] is in the root, measured when the bubble is shown (a
  /// root may not read another box's size while it lays out).
  Rect anchorRect = Rect.zero;

  /// Measures [anchor] in [root] (outside layout).
  void measureAnchor(RenderControlRoot root) {
    anchorRect = anchor.attached && anchor.hasSize
        ? MatrixUtils.transformRect(anchor.getTransformTo(root), Offset.zero & anchor.size)
        : Rect.zero;
  }

  @override
  Offset placeIn(RenderControlRoot root, Size rootSize) {
    final a = anchorRect;
    var top = a.top - _gap - size.height;
    if (top < 8) top = a.bottom + _gap;
    final left = (a.center.dx - size.width / 2).clamp(8.0, math.max(8.0, rootSize.width - size.width - 8)).toDouble();
    return Offset(left, top);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final rect = offset & size;
    context.canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(_tokens.radius('inner', 5))), Paint()..color = _tokens.tooltipBackground);
    _text.paint(context.canvas, offset + _padding.topLeft);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
    config.liveRegion = true;
    config.label = _message;
    config.textDirection = _direction;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }
}

/// A node's `tooltip` (Flutter's `Tooltip`): shows the bubble in the root's
/// overlay after the theme's tooltip delay of hovering, keyboard focus or
/// a touch hold. Screen readers read [message] as the node's tooltip.
class RenderTooltipRegion extends RenderMouseRegion {
  RenderTooltipRegion() : super(opaque: false) {
    onEnter = (_) { _hovered = true; _schedule(); };
    onExit = (_) { _hovered = false; if (!_focused) { hide(); _dismissed = false; } };
  }

  String _message = '';
  String get message => _message;
  set message(String v) {
    if (v == _message) return;
    _message = v;
    _bubble?.message = v;
    markNeedsSemanticsUpdate();
  }

  ControlTokens? _tokens;
  set tokens(ControlTokens v) {
    _tokens = v;
    _bubble?.tokens = v;
  }

  TextDirection _direction = TextDirection.ltr;
  set direction(TextDirection v) {
    _direction = v;
    _bubble?.direction = v;
    markNeedsSemanticsUpdate();
  }

  Timer? _timer;
  Timer? _touchExpiry;
  RenderTooltipBubble? _bubble;
  RenderControlRoot? _root;
  bool _hovered = false;
  bool _focused = false;
  bool _touchHeld = false;
  bool _dismissed = false;
  int? _touchPointer;
  Offset? _touchStart;
  final Map<ControlFocusNode, ({ControlKeyResult Function(KeyEvent)? result, ControlKeyResult Function(KeyEvent) wrapper})> _focusKeys = {};

  /// Whether the bubble is showing.
  bool get showing => _bubble != null;

  void _schedule() {
    if (_dismissed || _bubble != null || _timer != null) return;
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: _tokens?.tooltipDelayMs ?? 400), show);
  }

  /// Observes an existing press target or kit control; it adds no Tab stop.
  void focusChanged(ControlFocusNode node, bool focused) {
    if (focused && node.showsHighlight) {
      if (!_focusKeys.containsKey(node)) {
        final previous = node.onKeyResult;
        final previousKey = node.onKey;
        ControlKeyResult keys(KeyEvent event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape && (_bubble != null || _timer != null)) {
            _dismissed = true;
            hide();
            return ControlKeyResult.handled;
          }
          return previous?.call(event) ?? ((previousKey?.call(event) ?? false) ? ControlKeyResult.handled : ControlKeyResult.ignored);
        }
        _focusKeys[node] = (result: previous, wrapper: keys);
        node.onKeyResult = keys;
      }
      if (!_focused) {
        _focused = true;
        _dismissed = false;
        _schedule();
      }
    } else {
      final saved = _focusKeys.remove(node);
      if (saved != null && identical(node.onKeyResult, saved.wrapper)) node.onKeyResult = saved.result;
      if (_focusKeys.isEmpty) {
        _focused = false;
        _dismissed = false;
        if (!_hovered && !_touchHeld) hide();
      }
    }
  }

  /// Shows the bubble now (a long press, a test).
  void show() {
    _timer?.cancel();
    _timer = null;
    if (_bubble != null || _message.isEmpty || !attached) return;
    final root = RenderControlRoot.of(this);
    if (root == null) return;
    final bubble = RenderTooltipBubble(anchor: this, message: _message,
        tokens: _tokens ?? ControlTokens.resolve(api.ThemeTokens.none, dark: false), direction: _direction);
    bubble.measureAnchor(root);
    _root = root..showOverlay(bubble);
    _bubble = bubble;
  }

  /// Hides the bubble (and a pending one).
  void hide() {
    _timer?.cancel();
    _timer = null;
    _touchExpiry?.cancel();
    _touchExpiry = null;
    final b = _bubble;
    if (b == null) return;
    _root?.hideOverlay(b);
    _bubble = null;
    _root = null;
    b.dispose();
  }

  /// The pointer is over it wherever it is inside (so it hovers), and it is
  /// hit exactly where what it wraps is: a tap goes on to the button under
  /// it and to the reactions around it. (A mouse region that is not opaque
  /// answers "not hit" even when its child was, which hid the node from
  /// every layer above.)
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    final hit = hitTestChildren(result, position: position);
    result.add(BoxHitTestEntry(this, position));
    return hit;
  }

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is PointerDownEvent) {
      hide();
      if (event.kind == PointerDeviceKind.touch || event.kind == PointerDeviceKind.stylus) {
        _touchPointer = event.pointer;
        _touchStart = event.position;
        _touchHeld = true;
        _dismissed = false;
        _schedule();
      }
    } else if (event is PointerMoveEvent && event.pointer == _touchPointer &&
        _touchStart != null && (event.position - _touchStart!).distance > 12) {
      _touchHeld = false;
      _touchPointer = null;
      if (!_focused && !_hovered) hide();
    } else if ((event is PointerUpEvent || event is PointerCancelEvent) && event.pointer == _touchPointer) {
      _touchHeld = false;
      _touchPointer = null;
      if (_bubble == null) {
        if (!_focused && !_hovered) hide();
      } else {
        _touchExpiry?.cancel();
        _touchExpiry = Timer(const Duration(seconds: 2), () { if (!_focused && !_hovered) hide(); });
      }
    }
    super.handleEvent(event, entry);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    if (_message.isNotEmpty) {
      config.tooltip = _message;
      config.textDirection = _direction;
    }
  }

  @override
  void detach() {
    _touchExpiry?.cancel();
    for (final entry in _focusKeys.entries) {
      if (identical(entry.key.onKeyResult, entry.value.wrapper)) entry.key.onKeyResult = entry.value.result;
    }
    _focusKeys.clear();
    _focused = false;
    hide();
    super.detach();
  }
}

/// The focusable child of a tooltip reports its keyboard highlight here.
void tooltipFocusChanged(ControlFocusNode node) {
  for (RenderObject? p = node.owner.parent; p != null; p = p.parent) {
    if (p is RenderTooltipRegion) {
      p.focusChanged(node, node.showsHighlight);
      return;
    }
  }
  // A plain node's press target wraps its visual behavior layers, so its
  // tooltip is its direct child rather than an ancestor of the focus node.
  RenderTooltipRegion? found;
  void find(RenderObject parent, int depth) {
    if (found != null || depth > 8) return;
    parent.visitChildren((child) {
      if (found != null) return;
      if (child is RenderTooltipRegion) {
        found = child;
      } else {
        find(child, depth + 1);
      }
    });
  }
  find(node.owner, 0);
  found?.focusChanged(node, node.showsHighlight);
}
