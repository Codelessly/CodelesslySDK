// The control kit: what every control the SDK draws itself is made of, as
// render objects (no widget, no Material). A control is a leaf render box
// that resolves its `WidgetState`s (hovered, focused, pressed, selected,
// disabled) from the pointer, the keyboard and the node's bound states, and
// paints itself from tokens (render/controls/tokens.dart):
//
// | Piece | Flutter counterpart |
// |---|---|
// | [RenderControl]: states, tap, hover and cursor, focus, activation, semantics, tap target | `ButtonStyleButton`'s `InkWell` + `FocusableActionDetector` + `Semantics` |
// | [paintStateLayer]: the overlay of the current state | `ButtonStyle.overlayColor` |
// | [paintFocusRing]: SSUI's focus ring | (none in Material) |
// | [ControlLabel]: one line, optically centred | `Text` in a `DefaultTextStyle` |
// | the control's one child: an icon glyph (render/paint/icon_glyph.dart) | `Icon` |
// | [RenderControl.stateValue]: each state eased in and out (SSUI: 150 ms, ease-out) on a `Ticker` | `AnimatedContainer` / `ButtonStyle.animationDuration` |
import 'dart:async' show scheduleMicrotask;
import 'dart:ui' show BoxHeightStyle;

import 'package:codelessly_api/core.dart' as api show WidgetState;
import 'package:flutter/animation.dart' show Curve, Curves;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import 'focus.dart';
import 'root.dart';

/// The base of a control: its states and their sources, its activation
/// (tap, Enter, Space, a screen reader's tap), its focus node and its
/// semantics. Subclasses lay out and paint; its [icon] is theirs to place.
abstract class RenderControl extends RenderBox implements MouseTrackerAnnotation {
  RenderControl() {
    focusNode = ControlFocusNode(this, onActivate: activate, onFocusChange: (on) {
      _notify(api.WidgetState.focused, on);
      _statesChanged();
      markNeedsPaint();
      markNeedsSemanticsUpdate();
    });
    _tap = TapGestureRecognizer(debugOwner: this)
      ..onTapDown = ((_) => _setPressed(true))
      ..onTapUp = ((_) => _setPressed(false))
      ..onTapCancel = (() => _setPressed(false))
      ..onTap = activate;
  }

  RenderBox? _icon;

  /// Its icon (a glyph render box), placed and painted by the subclass. Not
  /// `child`: the tree wires a node's chain through `child`, and a control
  /// is the chain's leaf.
  RenderBox? get icon => _icon;
  set icon(RenderBox? v) {
    if (identical(v, _icon)) return;
    if (_icon != null) dropChild(_icon!);
    _icon = v;
    if (v != null) adoptChild(v);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    if (_icon != null) visitor(_icon!);
  }

  @override
  void redepthChildren() {
    if (_icon != null) redepthChild(_icon!);
  }

  /// Its place in the root's focus order.
  late final ControlFocusNode focusNode;
  late final TapGestureRecognizer _tap;

  /// What a press does (null: nothing, but the control still draws its
  /// press).
  VoidCallback? onPressed;

  /// Told when a state the control tracks itself changes (hovered, pressed,
  /// focused): the node's `states` patches follow it.
  void Function(api.WidgetState state, bool on)? onStateChanged;

  bool _enabled = true;
  bool get enabled => _enabled;
  set enabled(bool v) {
    if (v == _enabled) return;
    _enabled = v;
    focusNode.canRequestFocus = v;
    if (!v) {
      focusNode.unfocus();
      _hovered = _pressed = false;
    }
    _statesChanged();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  bool _selected = false;
  bool get selected => _selected;

  /// A selected control (its node's bound `selected`: Flutter's
  /// `statesController`).
  set selected(bool v) {
    if (v == _selected) return;
    _selected = v;
    _statesChanged();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  set autofocus(bool v) => focusNode.autofocus = v;

  String? _semanticsLabel;

  /// What a screen reader says (else the control's label).
  set semanticsLabel(String? v) {
    if (v == _semanticsLabel) return;
    _semanticsLabel = v;
    markNeedsSemanticsUpdate();
  }

  String? get semanticsLabel => _semanticsLabel;

  bool _hovered = false, _pressed = false;
  bool get hovered => _hovered && _enabled;
  bool get pressed => _pressed && _enabled;

  /// Focused, by keyboard: the ring shows.
  bool get focusHighlight => focusNode.showsHighlight && _enabled;

  /// Its states now, as the model names them.
  Set<api.WidgetState> get states => {
        if (hovered) api.WidgetState.hovered,
        if (focusNode.hasFocus) api.WidgetState.focused,
        if (pressed) api.WidgetState.pressed,
        if (_selected) api.WidgetState.selected,
        if (!_enabled) api.WidgetState.disabled,
      };

  void _setHovered(bool v) {
    if (v == _hovered) return;
    _hovered = v;
    if (!v) _setPressed(false);
    _notify(api.WidgetState.hovered, v);
    _statesChanged();
    markNeedsPaint();
  }

  void _setPressed(bool v) {
    if (v == _pressed) return;
    _pressed = v;
    _notify(api.WidgetState.pressed, v);
    _statesChanged();
    markNeedsPaint();
  }

  // --- state transitions -------------------------------------------------------

  /// The states whose look eases in and out.
  static const transitionStates = [
    api.WidgetState.hovered,
    api.WidgetState.focused,
    api.WidgetState.pressed,
    api.WidgetState.selected,
    api.WidgetState.disabled,
  ];

  /// How long a state takes to come or go (SSUI's `durations.control`,
  /// 150 ms; a subclass sets it from its tokens). Zero: at once.
  Duration transitionDuration = const Duration(milliseconds: 150);

  /// The curve of a state's look (SSUI's buttons: ease-out).
  Curve transitionCurve = Curves.easeOut;

  /// Whether its states ease at all: a design canvas, or a platform that
  /// asks for no animation, shows each state at once.
  bool get animatesStates => true;

  /// Whether [s] is on now (what [stateValue] is heading for). The focused
  /// look is the keyboard's ring ([focusHighlight]).
  bool stateTarget(api.WidgetState s) => switch (s) {
        api.WidgetState.hovered => hovered,
        api.WidgetState.focused => focusHighlight,
        api.WidgetState.pressed => pressed,
        api.WidgetState.selected => _selected,
        api.WidgetState.disabled => !_enabled,
        _ => false,
      };

  // Linear progress of each state (0 off, 1 on), before the curve.
  final Map<api.WidgetState, double> _progress = {};
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;

  /// How far [s]'s look has come, eased: 0 off, 1 on, in between while it
  /// changes. Paint with it; read [stateTarget] (or [states]) for the state
  /// itself.
  double stateValue(api.WidgetState s) {
    final t = _progress[s] ?? (stateTarget(s) ? 1.0 : 0.0);
    if (t <= 0 || t >= 1) return t.clamp(0, 1).toDouble();
    return transitionCurve.transform(t);
  }

  /// Whether a state is still easing.
  bool get transitioning => _ticker?.isActive ?? false;

  bool get _snaps =>
      !animatesStates ||
      !attached ||
      !hasSize ||
      transitionDuration <= Duration.zero ||
      RendererBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  /// A state changed: ease towards it (or show it at once before the
  /// control is first laid out, on a design canvas and with animations off).
  void _statesChanged() {
    if (_snaps) {
      _settle();
      return;
    }
    var moving = false;
    for (final s in transitionStates) {
      final target = stateTarget(s) ? 1.0 : 0.0;
      if ((_progress[s] ?? target) != target) moving = true;
    }
    if (!moving) return;
    final ticker = _ticker ??= Ticker(_tick, debugLabel: 'control states');
    if (!ticker.isActive) {
      _lastTick = Duration.zero;
      ticker.start();
    }
  }

  /// Every state at its target, the ticker stopped.
  void _settle() {
    _ticker?.stop();
    for (final s in transitionStates) {
      _progress[s] = stateTarget(s) ? 1.0 : 0.0;
    }
  }

  void _tick(Duration elapsed) {
    final dt = elapsed - _lastTick;
    _lastTick = elapsed;
    final step = dt.inMicroseconds / transitionDuration.inMicroseconds;
    var moving = false;
    for (final s in transitionStates) {
      final target = stateTarget(s) ? 1.0 : 0.0;
      final from = _progress[s] ?? target;
      final next = target > from ? (from + step).clamp(0.0, target) : (from - step).clamp(target, 1.0);
      _progress[s] = next.toDouble();
      if (next != target) moving = true;
    }
    if (!moving) _ticker?.stop();
    if (attached) markNeedsPaint();
  }

  void _notify(api.WidgetState s, bool on) {
    final cb = onStateChanged;
    if (cb == null) return;
    // States change while the pointer router or the key handler runs; the
    // node's patches re-apply its box after that.
    scheduleMicrotask(() => cb(s, on));
  }

  /// Presses the control (a tap, Enter or Space, a screen reader).
  void activate() {
    if (!_enabled) return;
    onPressed?.call();
  }

  // --- pointer ---------------------------------------------------------------

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => false;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerDownEvent && _enabled) _tap.addPointer(event);
  }

  /// The smallest box a touch may land in (SSUI: 44 × 44 on touch
  /// platforms, as `MaterialTapTargetSize.padded` is 48), grown around the
  /// control by hit testing only: its layout keeps its own size.
  Size get minTapTarget => switch (defaultTargetPlatform) {
        TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => const Size(44, 44),
        _ => Size.zero,
      };

  /// Where a touch counts as on the control, in its own coordinates.
  Rect get tapTarget {
    final min = minTapTarget;
    final r = Offset.zero & size;
    final dx = (min.width - r.width).clamp(0.0, double.infinity) / 2;
    final dy = (min.height - r.height).clamp(0.0, double.infinity) / 2;
    return r.inflate(0).inflateSides(dx, dy);
  }

  /// Hit tests a position outside its box but in its [tapTarget] (the
  /// node's box asks: `NodeBox.outsideHitTest`); [global] is in global
  /// coordinates.
  bool hitTestTarget(BoxHitTestResult result, Offset global) {
    if (!attached || !hasSize) return false;
    final local = globalToLocal(global);
    if (!tapTarget.contains(local)) return false;
    result.add(BoxHitTestEntry(this, local));
    return true;
  }

  // --- hover -------------------------------------------------------------------

  @override
  MouseCursor get cursor => _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic;

  @override
  PointerEnterEventListener? get onEnter => (_) => _setHovered(true);

  @override
  PointerExitEventListener? get onExit => (_) => _setHovered(false);

  @override
  bool get validForMouseTracker => attached;

  // --- lifecycle ---------------------------------------------------------------

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _icon?.attach(owner);
    final root = RenderControlRoot.of(this);
    if (root != null) focusNode.join(root.focus);
    _settle();
  }

  @override
  void detach() {
    focusNode.leave();
    _hovered = _pressed = false;
    _settle();
    super.detach();
    _icon?.detach();
  }

  @override
  void dispose() {
    _tap.dispose();
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }

  // --- semantics ---------------------------------------------------------------

  /// What a screen reader announces it as; [describeSemanticsConfiguration]
  /// sets the rest.
  String get semanticsName;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..label = _semanticsLabel ?? semanticsName
      ..isEnabled = _enabled
      ..isFocused = focusNode.hasFocus
      ..textDirection = TextDirection.ltr;
    if (_selected) config.isSelected = true;
    if (_enabled) {
      config.onTap = activate;
      config.onFocus = () => focusNode.requestFocus();
    }
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {}
}

extension on Rect {
  Rect inflateSides(double dx, double dy) => Rect.fromLTRB(left - dx, top - dy, right + dx, bottom + dy);
}

/// A control that draws text itself (no RenderParagraph): what the label
/// guard (test/app/no_material_look_test.dart) and tools measure.
abstract interface class LabelledControl implements RenderBox {
  /// Each label: its text, font family, and glyph boxes in local
  /// coordinates.
  List<({String text, String? fontFamily, List<Rect> glyphs})> get labels;
}

/// Paints [overlay] over [shape] (the state layer: hover, press).
void paintStateLayer(Canvas canvas, RRect shape, Color? overlay) {
  if (overlay == null || overlay.a == 0) return;
  canvas.drawRRect(shape, Paint()..color = overlay);
}

/// Paints SSUI's focus ring: a [width] band of [color] just outside
/// [shape].
void paintFocusRing(Canvas canvas, RRect shape, Color color, {double width = 1.5}) {
  canvas.drawRRect(
    shape.inflate(width / 2),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color,
  );
}

/// One line of text, ellipsised to its width, placed so the glyphs (ascent
/// to descent: what the eye sees, not the line's leading) sit centred on a
/// line: what the guard test measures.
class ControlLabel {
  final TextPainter _painter = TextPainter(textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…');

  String _text = '';
  TextStyle? _style;
  TextAlign _align = TextAlign.center;

  String get text => _text;

  /// Sets what it shows; true when its layout changed.
  bool update(String text, TextStyle style, {TextAlign align = TextAlign.center}) {
    if (text == _text && style == _style && align == _align) return false;
    _text = text;
    _style = style;
    _align = align;
    _painter
      ..text = TextSpan(text: text, style: style)
      ..textAlign = align;
    _laidOutFor = null;
    return true;
  }

  double? _laidOutFor;
  double _glyphCentre = 0;

  /// Lays it out at most [maxWidth] wide.
  void layout(double maxWidth) {
    if (_laidOutFor == maxWidth) return;
    _laidOutFor = maxWidth;
    _painter.layout(maxWidth: maxWidth.isFinite ? maxWidth : double.infinity);
    if (_text.isEmpty) {
      _glyphCentre = _painter.height / 2;
      return;
    }
    final boxes = _painter.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: _painter.plainText.length),
        boxHeightStyle: BoxHeightStyle.tight);
    if (boxes.isEmpty) {
      _glyphCentre = _painter.height / 2;
      return;
    }
    var top = double.infinity, bottom = -double.infinity;
    for (final b in boxes) {
      if (b.top < top) top = b.top;
      if (b.bottom > bottom) bottom = b.bottom;
    }
    _glyphCentre = (top + bottom) / 2;
  }

  /// Its width on one line, uncut.
  double get intrinsicWidth {
    final p = TextPainter(text: _painter.text, textDirection: TextDirection.ltr, maxLines: 1)..layout();
    final w = p.width;
    p.dispose();
    return w;
  }

  Size get size => _painter.size;

  /// Where its glyphs are (ascent to descent of each line's text) when it
  /// is painted from [left] centred on [centreY].
  List<Rect> glyphBoxes(double left, double centreY) {
    if (_text.isEmpty) return const [];
    final top = centreY - _glyphCentre;
    return [
      for (final b in _painter.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: _painter.plainText.length),
          boxHeightStyle: BoxHeightStyle.tight))
        b.toRect().shift(Offset(left, top)),
    ];
  }

  /// The family it is set in (null: the platform's).
  String? get fontFamily => _style?.fontFamily;

  /// Paints it with its glyphs centred on [centreY], from [left].
  void paint(Canvas canvas, double left, double centreY) {
    if (_text.isEmpty) return;
    _painter.paint(canvas, Offset(left, centreY - _glyphCentre));
  }

  void dispose() => _painter.dispose();
}
