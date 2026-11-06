import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../codelessly_sdk.dart';

/// A list item that can be swiped sideways to reveal [SwipeActionsModel]
/// actions behind it.
///
/// * A swipe past [SwipeActionsModel.threshold] of the item's width runs the
///   first action of that side (the start actions are revealed by a swipe
///   toward the end); an action that removes the item slides it away first.
/// * A shorter swipe that passes half the actions' width leaves them
///   revealed, to tap; any other swipe springs back.
class SwipeActionsBox extends StatefulWidget {
  /// The actions.
  final SwipeActionsModel model;

  /// Runs an action.
  final ValueChanged<SwipeActionModel> onAction;

  /// The item.
  final Widget child;

  /// The width of each revealed action button.
  final double actionWidth;

  /// Creates a [SwipeActionsBox].
  const SwipeActionsBox({
    super.key,
    required this.model,
    required this.onAction,
    required this.child,
    this.actionWidth = 80,
  });

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

  List<SwipeActionModel> _actionsFor(double offset) {
    // Swiping toward the end (right in LTR) reveals the start actions.
    final bool towardEnd = _rtl ? offset < 0 : offset > 0;
    return towardEnd ? widget.model.startActions : widget.model.endActions;
  }

  void _onUpdate(DragUpdateDetails details) {
    final double next = _offset + details.primaryDelta!;
    if (_actionsFor(next).isEmpty && next.abs() > _offset.abs()) {
      // Nothing to reveal on this side: resist.
      _animation.value = _offset + details.primaryDelta! * 0.15;
      return;
    }
    _animation.value = next.clamp(-_width, _width);
  }

  Future<void> _onEnd(DragEndDetails details) async {
    final double offset = _offset;
    final List<SwipeActionModel> actions = _actionsFor(offset);
    final double velocity = details.primaryVelocity ?? 0;
    final bool flung =
        velocity.abs() > 1200 && velocity.sign == offset.sign && offset != 0;
    if (actions.isNotEmpty &&
        (offset.abs() >= widget.model.threshold * _width || flung)) {
      await _run(actions.first, offset.sign);
      return;
    }
    final double reveal = actions.length * widget.actionWidth;
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

  Future<void> _run(SwipeActionModel action, double sign) async {
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

  Widget _background(double offset) {
    final List<SwipeActionModel> actions = _actionsFor(offset);
    if (actions.isEmpty || offset == 0) return const SizedBox.shrink();
    final bool full = offset.abs() >= widget.model.threshold * _width;
    final bool atStart = (offset > 0) != _rtl;
    final List<SwipeActionModel> shown = full ? [actions.first] : actions;
    return Row(
      mainAxisAlignment: atStart
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      children: [
        for (final SwipeActionModel action in shown)
          SizedBox(
            width: full
                ? offset.abs()
                : math.max(
                    widget.actionWidth,
                    offset.abs() / math.max(1, shown.length),
                  ),
            child: Material(
              color: action.background.toFlutterColor(),
              child: InkWell(
                onTap: () => _run(action, offset.sign),
                child: Semantics(
                  button: true,
                  label: action.label,
                  child: Center(
                    child: _ActionLabel(action: action),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.model.enabled) return widget.child;
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth.isFinite ? constraints.maxWidth : 400;
        return Semantics(
          customSemanticsActions: {
            for (final SwipeActionModel action in [
              ...widget.model.startActions,
              ...widget.model.endActions,
            ])
              CustomSemanticsAction(label: action.label): () =>
                  widget.onAction(action),
          },
          child: GestureDetector(
            onHorizontalDragUpdate: _onUpdate,
            onHorizontalDragEnd: _onEnd,
            child: AnimatedBuilder(
              animation: _animation,
              child: widget.child,
              builder: (context, child) => Stack(
                children: [
                  Positioned.fill(child: _background(_offset)),
                  Transform.translate(
                    offset: Offset(_offset, 0),
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActionLabel extends StatelessWidget {
  final SwipeActionModel action;

  const _ActionLabel({required this.action});

  @override
  Widget build(BuildContext context) {
    final Color color = action.foreground.toFlutterColor();
    final MultiSourceIconModel? icon = action.icon;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null && icon.show)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: retrieveIconWidget(icon, 22, color)!,
          ),
        if (action.label.isNotEmpty)
          Text(
            action.label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}
