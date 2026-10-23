import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Shares how far a [HoldToConfirm] has been held, 0 to 1, with the nodes
/// inside it, which read it as the `hold` variable.
class HoldProgressProvider extends InheritedWidget {
  /// How far the hold has progressed, from 0 to 1.
  final double progress;

  /// Creates a [HoldProgressProvider].
  const HoldProgressProvider({
    super.key,
    required this.progress,
    required super.child,
  });

  /// The progress of the nearest [HoldToConfirm] above [context], if any.
  static double? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<HoldProgressProvider>()
      ?.progress;

  @override
  bool updateShouldNotify(HoldProgressProvider oldWidget) =>
      progress != oldWidget.progress;
}

/// Calls [onConfirmed] once [child] has been pressed for [duration].
///
/// The progress fills from 0 to 1 while the pointer is down and drains back
/// in [drainDuration] when it is released early or moves away (a scroll, for
/// example). Assistive technologies confirm with a long press.
class HoldToConfirm extends StatefulWidget {
  /// How long the hold must last.
  final Duration duration;

  /// How long an unfinished hold takes to drain back to 0.
  final Duration drainDuration;

  /// Called when a hold completes.
  final VoidCallback onConfirmed;

  /// The widget being held.
  final Widget child;

  /// Creates a [HoldToConfirm].
  const HoldToConfirm({
    super.key,
    required this.duration,
    required this.onConfirmed,
    required this.child,
    this.drainDuration = const Duration(milliseconds: 250),
  });

  @override
  State<HoldToConfirm> createState() => _HoldToConfirmState();
}

class _HoldToConfirmState extends State<HoldToConfirm>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..addStatusListener(_onStatus);

  int? _pointer;
  Offset _downAt = Offset.zero;

  @override
  void didUpdateWidget(HoldToConfirm oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _pointer = null;
    _controller.value = 0;
    widget.onConfirmed();
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null) return;
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons != kPrimaryMouseButton) {
      return;
    }
    _pointer = event.pointer;
    _downAt = event.position;
    _controller.forward();
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    final double slop = event.kind == PointerDeviceKind.touch
        ? kTouchSlop
        : kPrecisePointerHitSlop * 4;
    if ((event.position - _downAt).distance > slop) _release();
  }

  void _up(PointerEvent event) {
    if (event.pointer == _pointer) _release();
  }

  void _release() {
    _pointer = null;
    if (_controller.isCompleted || _controller.value == 0) return;
    _controller.animateBack(
      0,
      duration: widget.drainDuration * _controller.value,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      onLongPress: widget.onConfirmed,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: AnimatedBuilder(
          animation: _controller,
          child: widget.child,
          builder: (context, child) =>
              HoldProgressProvider(progress: _controller.value, child: child!),
        ),
      ),
    );
  }
}
