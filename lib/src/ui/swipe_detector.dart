import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Reports swipes on [child] as [TriggerType.swipeLeft], [swipeRight],
/// [swipeUp] or [swipeDown]. A drag counts as a swipe when it travels
/// [minDistance] or is flung faster than [minVelocity]. A mouse wheel
/// scroll counts too: scrolling down swipes up, the way content moves.
class SwipeDetector extends StatefulWidget {
  /// Creates a [SwipeDetector].
  const SwipeDetector({
    super.key,
    required this.onSwipe,
    required this.child,
    this.minDistance = 40,
    this.minVelocity = 300,
  });

  /// Called with the swipe's direction.
  final ValueChanged<TriggerType> onSwipe;

  /// The swiped widget.
  final Widget child;

  /// How far a drag travels to count as a swipe, in logical pixels.
  final double minDistance;

  /// How fast a shorter drag is flung to count, in logical pixels a second.
  final double minVelocity;

  @override
  State<SwipeDetector> createState() => _SwipeDetectorState();
}

class _SwipeDetectorState extends State<SwipeDetector> {
  Offset _travel = Offset.zero;
  DateTime _lastWheel = DateTime(0);

  static TriggerType _direction(Offset delta) => delta.dx.abs() > delta.dy.abs()
      ? (delta.dx < 0 ? TriggerType.swipeLeft : TriggerType.swipeRight)
      : (delta.dy < 0 ? TriggerType.swipeUp : TriggerType.swipeDown);

  void _onEnd(DragEndDetails details) {
    final Offset velocity = details.velocity.pixelsPerSecond;
    if (_travel.distance >= widget.minDistance) {
      widget.onSwipe(_direction(_travel));
    } else if (velocity.distance >= widget.minVelocity) {
      widget.onSwipe(_direction(velocity));
    }
    _travel = Offset.zero;
  }

  void _onWheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final DateTime now = DateTime.now();
    // A wheel sends many small scrolls; one notch is one swipe.
    if (now.difference(_lastWheel).inMilliseconds < 150) return;
    _lastWheel = now;
    final Offset delta = event.scrollDelta;
    if (delta == Offset.zero) return;
    widget.onSwipe(_direction(-delta));
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onWheel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _travel = Offset.zero,
        onPanUpdate: (DragUpdateDetails d) => _travel += d.delta,
        onPanEnd: _onEnd,
        child: widget.child,
      ),
    );
  }
}
