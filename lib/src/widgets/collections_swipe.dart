// A list item swiped sideways to reveal its list's swipe actions.
import 'dart:math' as math;
import 'dart:async' show unawaited;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Json, SwipeAction, SwipeActions;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, LogicalKeyboardKey;

import '../render/convert.dart';
import '../render/controls/focus.dart';
import '../render/controls/root.dart';
import '../render/paint/icon_glyph.dart';
import '../runtime/http_image_loader.dart';

/// A list item that can be swiped sideways to reveal [SwipeActions] behind
/// it.
///
/// * A swipe past [SwipeActions.threshold] of the item's width (or a fling)
///   runs the first action of that side (the start actions are revealed by
///   a swipe toward the end); an action that removes the item slides it
///   away first.
/// * A shorter swipe that passes half the actions' width leaves them
///   revealed, to tap; any other swipe springs back.
class SwipeActionsBox extends StatefulWidget {
  const SwipeActionsBox({
    super.key,
    required this.model,
    required this.onAction,
    required this.child,
    required this.semanticLabel,
    this.offered,
    this.actionWidth = 80,
    this.textDefault,
  });

  final SwipeActions model;

  /// The default text style the list inherits, under the labels' styles.
  final api.TextStyle? textDefault;
  final ValueChanged<SwipeAction> onAction;

  /// Whether an action is offered for this item (its `when`); null offers
  /// every one.
  final bool Function(SwipeAction action)? offered;
  final Widget child;
  final String semanticLabel;

  /// The width of each revealed action button.
  final double actionWidth;

  @override
  State<SwipeActionsBox> createState() => _SwipeActionsBoxState();
}

class _SwipeActionsBoxState extends State<SwipeActionsBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController.unbounded(
    vsync: this,
  );
  double _width = 0;

  /// The item's offset: positive when swiped toward the end.
  double get _offset => _animation.value;

  bool get _rtl => Directionality.maybeOf(context) == TextDirection.rtl;

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  List<SwipeAction> _actionsFor(double offset) {
    // Swiping toward the end (right in LTR) reveals the start actions.
    final towardEnd = _rtl ? offset < 0 : offset > 0;
    final all = towardEnd ? widget.model.startActions : widget.model.endActions;
    final offered = widget.offered;
    return offered == null
        ? all
        : [
            for (final a in all)
              if (offered(a)) a,
          ];
  }

  bool _armed = false;

  /// Notes when the swipe passes the threshold either way (haptics).
  void _trackArmed() {
    final armed =
        _width > 0 &&
        _offset.abs() >= widget.model.threshold * _width &&
        _actionsFor(_offset).isNotEmpty;
    if (armed != _armed) {
      _armed = armed;
      if (widget.model.armHaptic) HapticFeedback.selectionClick();
    }
  }

  void _onUpdate(DragUpdateDetails details) {
    final next = _offset + details.primaryDelta!;
    if (_actionsFor(next).isEmpty && next.abs() > _offset.abs()) {
      // Nothing to reveal on this side: resist.
      _animation.value = _offset + details.primaryDelta! * 0.15;
      return;
    }
    _animation.value = next.clamp(-_width, _width);
    _trackArmed();
  }

  Future<void> _onEnd(DragEndDetails details) async {
    _armed = false;
    final offset = _offset;
    final actions = _actionsFor(offset);
    final velocity = details.primaryVelocity ?? 0;
    final flung =
        velocity.abs() > 1200 && velocity.sign == offset.sign && offset != 0;
    if (actions.isNotEmpty &&
        (offset.abs() >= widget.model.threshold * _width || flung)) {
      await _run(actions.first, offset.sign);
      return;
    }
    final reveal = actions.length * widget.actionWidth;
    if (actions.isNotEmpty && offset.abs() >= reveal / 2) {
      await _settle(offset.sign * reveal);
    } else {
      await _settle(0);
    }
  }

  Future<void> _settle(double target) => _animation.animateTo(
    target,
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOutCubic,
  );

  Future<void> _run(SwipeAction action, double sign) async {
    if (action.removes) {
      await _animation.animateTo(
        sign * _width,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeIn,
      );
    } else {
      await _settle(0);
    }
    widget.onAction(action);
    // A removed item that is put back (undo) shows in place.
    if (mounted && action.removes) _animation.value = 0;
  }

  bool _key(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape && _offset != 0) {
      unawaited(_settle(0));
      return true;
    }
    if (key != LogicalKeyboardKey.arrowLeft &&
        key != LogicalKeyboardKey.arrowRight)
      return false;
    final sign = key == LogicalKeyboardKey.arrowLeft ? -1.0 : 1.0;
    final actions = _actionsFor(sign);
    if (actions.isEmpty) return false;
    unawaited(
      _settle(sign * math.min(_width, actions.length * widget.actionWidth)),
    );
    return true;
  }

  void _activate() {
    if (_offset != 0) {
      final actions = _actionsFor(_offset);
      if (actions.isNotEmpty) unawaited(_run(actions.first, _offset.sign));
      return;
    }
    final preferred = _rtl ? 1.0 : -1.0;
    final towardStart = _actionsFor(preferred).isNotEmpty ? preferred : -preferred;
    final actions = _actionsFor(towardStart);
    if (actions.isNotEmpty)
      unawaited(
        _settle(
          towardStart * math.min(_width, actions.length * widget.actionWidth),
        ),
      );
  }

  Widget _background(double offset) {
    final actions = _actionsFor(offset);
    if (actions.isEmpty || offset == 0) return const SizedBox.shrink();
    final full = offset.abs() >= widget.model.threshold * _width;
    final atStart = (offset > 0) != _rtl;
    final shown = full ? [actions.first] : actions;
    final scale = full ? widget.model.armedScale : 1.0;
    final row = Row(
      mainAxisAlignment: atStart
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      children: [
        for (final action in shown)
          SizedBox(
            // What a test or the render tool finds a revealed action by
            // (`--tap delete`): its id and its label.
            key: ValueKey(('Codelessly swipe action', action.id, action.label)),
            width: full
                ? offset.abs()
                : math.max(
                    widget.actionWidth,
                    offset.abs() / math.max(1, shown.length),
                  ),
            child: Material(
              color: action.background.flutter,
              child: _ActionTarget(
                onTap: () => _run(action, offset.sign),
                child: Semantics(
                  button: true,
                  label: action.label,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      // A label wider than a narrow slot shrinks to fit.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AnimatedScale(
                          scale: scale,
                          duration: const Duration(milliseconds: 120),
                          child: _ActionLabel(
                            action: action,
                            textDefault: widget.textDefault,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    final radius = widget.model.radius;
    if (radius == api.BorderRadius.zero) return row;
    return ClipRRect(borderRadius: radius.flutter, child: row);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.model.enabled) return widget.child;
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth.isFinite ? constraints.maxWidth : 400;
        return _SwipeFocus(
          enabled: _actionsFor(1).isNotEmpty || _actionsFor(-1).isNotEmpty,
          onKey: _key,
          onActivate: _activate,
          label: widget.semanticLabel,
          actions: {
            for (final action in [..._actionsFor(1), ..._actionsFor(-1)])
              CustomSemanticsAction(label: action.label): () =>
                  widget.onAction(action),
          },
          direction: Directionality.of(context),
          child: GestureDetector(
            onHorizontalDragUpdate: _onUpdate,
            onHorizontalDragEnd: _onEnd,
            child: AnimatedBuilder(
              animation: _animation,
              child: widget.child,
              builder: (context, child) => Stack(
                children: [
                  Positioned.fill(child: _background(_offset)),
                  Transform.translate(offset: Offset(_offset, 0), child: child),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A swipe row joins the same focus scope as the controls it contains. Its
/// keyboard ring and actions are not a separate Flutter focus system.
class _SwipeFocus extends SingleChildRenderObjectWidget {
  const _SwipeFocus({
    required this.enabled,
    required this.onKey,
    required this.onActivate,
    required this.label,
    required this.actions,
    required this.direction,
    required super.child,
  });

  final bool enabled;
  final bool Function(KeyEvent) onKey;
  final VoidCallback onActivate;
  final String label;
  final Map<CustomSemanticsAction, VoidCallback> actions;
  final TextDirection direction;

  @override
  _RenderSwipeFocus createRenderObject(BuildContext context) =>
      _RenderSwipeFocus()
        ..enabled = enabled
        ..key = onKey
        ..activate = onActivate
        ..label = label
        ..actions = actions
        ..direction = direction
        ..ringColor = Theme.of(context).colorScheme.primary;

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSwipeFocus renderObject,
  ) => renderObject
    ..enabled = enabled
    ..key = onKey
    ..activate = onActivate
    ..label = label
    ..actions = actions
    ..direction = direction
    ..ringColor = Theme.of(context).colorScheme.primary;
}

class _RenderSwipeFocus extends RenderProxyBox {
  _RenderSwipeFocus() {
    focusNode =
        ControlFocusNode(
            this,
            onKey: (event) => key(event),
            onActivate: () => activate(),
            onFocusChange: (_) {
              markNeedsPaint();
              markNeedsSemanticsUpdate();
            },
          )
          ..onHighlightChange = markNeedsPaint
          ..focusableWhen = (() => enabled)
          ..label = (() => label);
  }

  late final ControlFocusNode focusNode;
  bool get enabled => _enabled;
  bool _enabled = true;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    markNeedsSemanticsUpdate();
  }
  bool Function(KeyEvent) key = (_) => false;
  VoidCallback activate = () {};
  String get label => _label;
  String _label = 'Row actions';
  set label(String value) {
    if (_label == value) return;
    _label = value;
    markNeedsSemanticsUpdate();
  }
  Map<CustomSemanticsAction, VoidCallback> get actions => _actions;
  Map<CustomSemanticsAction, VoidCallback> _actions = const {};
  set actions(Map<CustomSemanticsAction, VoidCallback> value) {
    _actions = value;
    markNeedsSemanticsUpdate();
  }
  TextDirection get direction => _direction;
  TextDirection _direction = TextDirection.ltr;
  set direction(TextDirection value) {
    if (_direction == value) return;
    _direction = value;
    markNeedsSemanticsUpdate();
  }
  Color get ringColor => _ringColor;
  Color _ringColor = const Color(0xFF2563EB);
  set ringColor(Color value) {
    if (_ringColor == value) return;
    _ringColor = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    final root = RenderControlRoot.of(this);
    if (root != null) focusNode.join(root.focus);
  }

  @override
  void detach() {
    focusNode.leave();
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!focusNode.showsHighlight) return;
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(
        (offset & size).inflate(2),
        const Radius.circular(6),
      ),
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..explicitChildNodes = true
      ..isButton = true
      ..isEnabled = enabled
      ..isFocused = focusNode.hasFocus
      ..label = label
      ..textDirection = direction
      ..customSemanticsActions = actions;
    if (enabled) {
      config.onTap = activate;
      config.onFocus = () => focusNode.requestFocus();
    }
  }
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel({required this.action, this.textDefault});
  final SwipeAction action;
  final api.TextStyle? textDefault;

  @override
  Widget build(BuildContext context) {
    final color = action.foreground.flutter;
    final icon = action.icon;
    final own = action.labelStyle;
    final style = const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)
        .merge(own == api.TextStyle.empty ? null : textStyle(own, textDefault))
        .copyWith(color: color);
    final glyph = icon != null && icon['show'] != false
        ? SizedBox.square(
            dimension: action.iconSize,
            child: _Glyph(icon: icon, color: color),
          )
        : null;
    final label = action.label.isNotEmpty
        ? Text(action.label, style: style)
        : null;
    if (action.inline) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?glyph,
          if (glyph != null && label != null) const SizedBox(width: 8),
          ?label,
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (glyph != null)
          Padding(padding: const EdgeInsets.only(bottom: 4), child: glyph),
        ?label,
      ],
    );
  }
}

/// An icon glyph (icon JSON) in [color], filling its box.
class _Glyph extends LeafRenderObjectWidget {
  const _Glyph({required this.icon, required this.color});
  final Json icon;
  final Color color;

  @override
  RenderIconGlyph createRenderObject(BuildContext context) => RenderIconGlyph()
    // Outside a tree with a loader of its own, its SVG is fetched as the SDK does.
    ..imageLoader = const HttpImageLoader()
    ..icon = icon
    ..color = color;

  @override
  void updateRenderObject(BuildContext context, RenderIconGlyph renderObject) =>
      renderObject
        ..icon = icon
        ..color = color;
}

/// A revealed action's press target: a tap runs it, and a mouse over it
/// shows a faint layer of the theme's hover color and the click cursor.
class _ActionTarget extends StatefulWidget {
  const _ActionTarget({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_ActionTarget> createState() => _ActionTargetState();
}

class _ActionTargetState extends State<_ActionTarget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(color: _hovered ? Theme.of(context).hoverColor : null),
            child: widget.child,
          ),
        ),
      );
}
