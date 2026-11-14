// The overlay layer's entries (render/controls/root.dart shows them above
// the screen): what Flutter's `Overlay` and `OverlayEntry` are for widgets.
// The first entry is the tooltip: SSUI's dark pill, shown after
// `durations.tooltipDelay` of hovering a node with a `tooltip`.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api show ThemeTokens;
import 'package:flutter/rendering.dart';

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
/// is no room), centred on it and kept 8 px inside the root.
class RenderTooltipBubble extends RenderOverlayEntry {
  RenderTooltipBubble({required this.anchor, required String message, required ControlTokens tokens})
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

  static const _padding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
  static const _gap = 6.0;
  static const _maxWidth = 250.0;

  final TextPainter _text = TextPainter(textDirection: TextDirection.ltr);

  @override
  void performLayout() {
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

  @override
  Offset placeIn(RenderControlRoot root, Size rootSize) {
    final a = anchor.attached && anchor.hasSize
        ? MatrixUtils.transformRect(anchor.getTransformTo(root), Offset.zero & anchor.size)
        : Rect.zero;
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
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }
}

/// A node's `tooltip` (Flutter's `Tooltip`): shows the bubble in the root's
/// overlay after the theme's tooltip delay of hovering, hides it when the
/// pointer leaves or presses. Screen readers read [message] as the node's
/// tooltip.
class RenderTooltipRegion extends RenderMouseRegion {
  RenderTooltipRegion() : super(opaque: false) {
    onEnter = (_) => _schedule();
    onExit = (_) => hide();
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

  Timer? _timer;
  RenderTooltipBubble? _bubble;
  RenderControlRoot? _root;

  /// Whether the bubble is showing.
  bool get showing => _bubble != null;

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: _tokens?.tooltipDelayMs ?? 400), show);
  }

  /// Shows the bubble now (a long press, a test).
  void show() {
    _timer?.cancel();
    if (_bubble != null || _message.isEmpty || !attached) return;
    final root = RenderControlRoot.of(this);
    if (root == null) return;
    final bubble = RenderTooltipBubble(anchor: this, message: _message, tokens: _tokens ?? ControlTokens.resolve(api.ThemeTokens.none, dark: false));
    _root = root..showOverlay(bubble);
    _bubble = bubble;
  }

  /// Hides the bubble (and a pending one).
  void hide() {
    _timer?.cancel();
    _timer = null;
    final b = _bubble;
    if (b == null) return;
    _root?.hideOverlay(b);
    _bubble = null;
    _root = null;
    b.dispose();
  }

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is PointerDownEvent) hide();
    super.handleEvent(event, entry);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    if (_message.isNotEmpty) config.tooltip = _message;
  }

  @override
  void detach() {
    hide();
    super.detach();
  }
}
