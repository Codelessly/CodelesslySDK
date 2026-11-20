// A screen shown over everything as a banner (`openModal presentation=banner`,
// docs/design/26-shown-over-and-in-sequence.md): no barrier, the page behind
// stays usable; it comes in along the top (or bottom) edge inside the safe
// area and above the keyboard, as its route transition's enter side says
// (else it slides in from its edge), stays until it is closed, swiped away or
// its `closeAfterMs` runs out (a clock that holds while it is pressed), and
// goes out the way it came. Banners show one at a time, in the order they
// were opened: a toast is a banner whose screen is the toast.
import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show DragDirection, OpenModalAction, RouteTransition, TransitionSide;
import 'package:flutter/widgets.dart';

import 'route_transition.dart' show TransitionSideView, sideAmountAt;

/// The banners waiting their turn in an overlay, and the one shown.
class _BannerQueue {
  final Queue<void Function()> waiting = Queue();
  bool showing = false;

  void add(void Function() show) {
    waiting.add(show);
    pump();
  }

  void pump() {
    if (showing || waiting.isEmpty) return;
    showing = true;
    waiting.removeFirst()();
  }

  void done() {
    showing = false;
    pump();
  }
}

final Expando<_BannerQueue> _queues = Expando('banner queue');

/// How many banners wait for their turn in [overlay] (tests, tools).
int bannersWaiting(OverlayState overlay) => _queues[overlay]?.waiting.length ?? 0;

/// Shows [screen] over everything in [overlay] as [action] (a banner) says,
/// after the banners already shown or waiting there; completes with what
/// closed it: the result its screen's close gives, or null when it was
/// swiped away or its time ran out. [screen] gets the close it shows with.
Future<Object?> showBanner(
  OverlayState overlay,
  Widget Function(void Function(Object? result) close) screen, {
  required OpenModalAction action,
}) {
  final queue = _queues[overlay] ??= _BannerQueue();
  final done = Completer<Object?>();
  queue.add(() {
    if (!overlay.mounted) {
      done.complete(null);
      queue.done();
      return;
    }
    final key = GlobalKey<CodelesslyBannerState>();
    late final OverlayEntry entry;
    var finished = false;
    void finish(Object? result) {
      if (finished) return;
      finished = true;
      if (!done.isCompleted) done.complete(result);
      if (entry.mounted) entry.remove();
      entry.dispose();
      queue.done();
    }

    void close(Object? result) {
      final state = key.currentState;
      if (state == null) return finish(result);
      unawaited(state.hide().whenComplete(() => finish(result)));
    }

    entry = OverlayEntry(
      builder: (_) => CodelesslyBanner(
        key: key,
        bottom: action.alignment[1] > 0,
        dismissible: action.barrierDismissible,
        transition: action.routeTransition,
        closeAfterMs: action.closeAfterMs,
        onDismissed: () => finish(null),
        onTimeout: () => close(null),
        child: screen(close),
      ),
    );
    overlay.insert(entry);
  });
  return done.future;
}

/// A banner: slides in along the top (or bottom) edge, inside the safe area
/// and above the keyboard, or comes as [transition]'s enter side says; a
/// swipe away dismisses it when [dismissible] (along [transition]'s dismiss
/// direction when it names one); with [closeAfterMs] it closes itself that
/// long after it has come in, the clock held while it is pressed.
class CodelesslyBanner extends StatefulWidget {
  const CodelesslyBanner({
    super.key,
    required this.bottom,
    required this.dismissible,
    required this.onDismissed,
    required this.child,
    this.transition,
    this.closeAfterMs = 0,
    this.onTimeout,
  });

  final bool bottom, dismissible;
  final VoidCallback onDismissed;
  final Widget child;

  /// How it comes and goes, and the drag that dismisses it; null: a slide
  /// from its edge with a fade (280 ms in, 200 out), swiped toward its edge.
  final RouteTransition? transition;

  /// Closes itself ([onTimeout]) this many ms after it came in; 0: stays.
  final int closeAfterMs;
  final VoidCallback? onTimeout;

  @override
  State<CodelesslyBanner> createState() => CodelesslyBannerState();
}

class CodelesslyBannerState extends State<CodelesslyBanner> with SingleTickerProviderStateMixin {
  late final RouteTransition? _transition = widget.transition?.resolved;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _transition?.resolvedDurationMs ?? 280),
    reverseDuration: Duration(milliseconds: _transition?.resolvedReverseDurationMs ?? 200),
  )
    ..addStatusListener(_onStatus)
    ..forward();

  /// Its time on screen ([closeAfterMs]): counted while it has come in and
  /// is not pressed.
  late final HeldClock _clock = HeldClock(widget.closeAfterMs, () {
    if (mounted && !_hiding) widget.onTimeout?.call();
  });
  int _pressed = 0;
  bool _hiding = false;

  /// Whether its clock is running (it has come in and is not pressed).
  bool get clockRunning => _clock.running;

  /// How long it has been on screen and not pressed, in ms.
  int get shownMs => _clock.shownMs;

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_hiding) _resume();
  }

  void _resume() {
    if (widget.closeAfterMs <= 0 || _hiding || _pressed > 0 || !_controller.isCompleted) return;
    _clock.run();
  }

  void _hold() => _clock.hold();

  /// Goes out; completes when it is gone.
  Future<void> hide() {
    _hiding = true;
    _hold();
    return _controller.reverse();
  }

  @override
  void dispose() {
    _clock.hold();
    _controller.dispose();
    super.dispose();
  }

  DismissDirection get _direction {
    final d = _transition?.dismiss?.direction;
    if (d == null) return widget.bottom ? DismissDirection.down : DismissDirection.up;
    return switch (d) {
      DragDirection.up => DismissDirection.up,
      DragDirection.down => DismissDirection.down,
      DragDirection.left => DismissDirection.endToStart,
      DragDirection.right => DismissDirection.startToEnd,
    };
  }

  Widget _moved(Widget child) {
    final t = _transition;
    final total = t?.resolvedDurationMs ?? 280;
    if (t == null || t.enter == null || t.enter!.isStill) {
      final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return SlideTransition(
        position: Tween<Offset>(begin: Offset(0, widget.bottom ? 1 : -1), end: Offset.zero).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      child: child,
      builder: (context, child) {
        final going = _hiding && t.popExit != null;
        final TransitionSide side = going ? t.popExit! : t.enter!;
        final amount = going
            ? sideAmountAt(side, 1 - _controller.value, totalMs: t.resolvedReverseDurationMs, entering: false)
            : sideAmountAt(side, _controller.value, totalMs: total, entering: true);
        return TransitionSideView(side: side, amount: amount, child: child!);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    Widget banner = widget.child;
    if (widget.closeAfterMs > 0) {
      // Held while a finger or the pointer is on it (reading it, dragging it).
      banner = Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          _pressed++;
          _hold();
        },
        onPointerUp: (_) {
          _pressed = math.max(0, _pressed - 1);
          _resume();
        },
        onPointerCancel: (_) {
          _pressed = math.max(0, _pressed - 1);
          _resume();
        },
        child: banner,
      );
    }
    if (widget.dismissible) {
      final distance = _transition?.dismiss?.distance;
      banner = Dismissible(
        key: const ValueKey('Codelessly banner'),
        direction: _direction,
        dismissThresholds: distance == null ? const {} : {_direction: distance.clamp(0.05, 1.0)},
        onDismissed: (_) {
          _hiding = true;
          _hold();
          widget.onDismissed();
        },
        child: banner,
      );
    }
    banner = _moved(banner);
    return Positioned(
      left: 0,
      right: 0,
      top: widget.bottom ? null : 0,
      bottom: widget.bottom ? media.viewInsets.bottom : null,
      child: SafeArea(
        top: !widget.bottom,
        bottom: widget.bottom,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: math.max(0, media.size.height - media.viewInsets.bottom)),
          child: Semantics(container: true, liveRegion: true, child: banner),
        ),
      ),
    );
  }
}

/// Whether [a] is shown as a banner.
bool isBanner(OpenModalAction a) => a.presentation == api.ModalPresentation.banner;

/// A time on screen that runs and holds (`closeAfterMs`: held while
/// pressed), counted in steps of [step] ms of the app's timers, and calls
/// [onDone] once it reaches [ms].
class HeldClock {
  HeldClock(this.ms, this.onDone);

  final int ms;
  final VoidCallback onDone;
  static const int step = 50;

  Timer? _timer;
  int _shown = 0;
  bool _done = false;

  bool get running => _timer != null;
  int get shownMs => _shown;

  void run() {
    if (_timer != null || _done || ms <= 0) return;
    _timer = Timer.periodic(const Duration(milliseconds: step), (_) {
      _shown += step;
      if (_shown < ms) return;
      _done = true;
      hold();
      onDone();
    });
  }

  void hold() {
    _timer?.cancel();
    _timer = null;
  }
}

/// The content of a dialog or sheet that closes itself [ms] after its route
/// has come in (`closeAfterMs`), the clock held while it is pressed: it pops
/// its route, with no result, if that route is still the top one.
class ModalTimeout extends StatefulWidget {
  const ModalTimeout({super.key, required this.ms, required this.child});

  final int ms;
  final Widget child;

  @override
  State<ModalTimeout> createState() => _ModalTimeoutState();
}

class _ModalTimeoutState extends State<ModalTimeout> {
  late final HeldClock _clock = HeldClock(widget.ms, () {
    final route = _route;
    if (!mounted || route == null || !route.isCurrent) return;
    Navigator.of(context).pop();
  });
  int _pressed = 0;
  ModalRoute<Object?>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (identical(route, _route)) return;
    _route?.animation?.removeStatusListener(_onStatus);
    _route = route;
    final animation = route?.animation;
    animation?.addStatusListener(_onStatus);
    if (animation == null || animation.isCompleted) _resume();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _resume();
  }

  void _resume() {
    if (_pressed > 0 || !mounted) return;
    _clock.run();
  }

  void _hold() => _clock.hold();

  @override
  void dispose() {
    _route?.animation?.removeStatusListener(_onStatus);
    _clock.hold();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          _pressed++;
          _hold();
        },
        onPointerUp: (_) {
          _pressed = math.max(0, _pressed - 1);
          _resume();
        },
        onPointerCancel: (_) {
          _pressed = math.max(0, _pressed - 1);
          _resume();
        },
        child: widget.child,
      );
}
