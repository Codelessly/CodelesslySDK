import 'dart:math' as math;
import 'dart:ui' show FlutterView;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Whether [fraction] of a node being visible counts as in view for a
/// [threshold] (a [TriggerModel.visibleFraction] or
/// [MotionModel.revealFraction]): 0 asks for any visible pixel, anything
/// else at least that share.
bool meetsVisibleFraction(double fraction, double threshold) =>
    threshold <= 0 ? fraction > 0 : fraction >= math.min(threshold, 1) - 1e-6;

/// Reports how much of [child] is visible: inside the screen and inside
/// every [Scrollable] around it (a scrolling page, a scrollable frame, a
/// list or a page view).
///
/// The fraction is the share of the child's width that is visible times the
/// share of its height. A child longer than the view along a side counts as
/// wholly visible along that side when it covers the view, so a tall section
/// filling the screen reports 1.
///
/// It is measured after the first layout and again whenever a scrollable
/// around it scrolls, the window resizes, or the child is laid out or
/// painted again (it moved), and [onChanged] is called with every new
/// value, and with the first. Nothing is measured while [enabled] is false.
class ViewportVisibility extends StatefulWidget {
  /// Creates a [ViewportVisibility].
  const ViewportVisibility({
    super.key,
    required this.onChanged,
    required this.child,
    this.enabled = true,
  });

  /// Called with the visible fraction, from 0 to 1, when it changes.
  final ValueChanged<double> onChanged;

  /// Whether to measure at all.
  final bool enabled;

  /// The widget to watch.
  final Widget child;

  @override
  State<ViewportVisibility> createState() => _ViewportVisibilityState();
}

class _ViewportVisibilityState extends State<ViewportVisibility>
    with WidgetsBindingObserver {
  /// The scrollables around the child, nearest first.
  List<ScrollableState> _scrollables = const [];

  /// The scroll positions listened to.
  final List<ScrollPosition> _positions = [];

  double? _last;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Depending on the window size re-measures on resize.
    MediaQuery.maybeSizeOf(context);
    _scrollables = [
      for (
        ScrollableState? scrollable = Scrollable.maybeOf(context);
        scrollable != null;
        scrollable = Scrollable.maybeOf(scrollable.context)
      )
        scrollable,
    ];
    _listen();
    _schedule();
  }

  @override
  void didUpdateWidget(ViewportVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      _listen();
      if (widget.enabled) {
        _last = null;
        _schedule();
      }
    }
  }

  void _listen() {
    for (final ScrollPosition position in _positions) {
      position.removeListener(_schedule);
    }
    _positions.clear();
    if (!widget.enabled) return;
    for (final ScrollableState scrollable in _scrollables) {
      final ScrollPosition position = scrollable.position;
      position.addListener(_schedule);
      _positions.add(position);
    }
  }

  @override
  void didChangeMetrics() => _schedule();

  /// Measures after the current frame is laid out and painted.
  void _schedule() {
    if (_scheduled || !widget.enabled || !mounted) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted && widget.enabled) _measure();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _measure() {
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.attached || !object.hasSize) return;
    final double fraction = visibleFractionOf(object, _scrollables, context);
    if (fraction == _last) return;
    _last = fraction;
    widget.onChanged(fraction);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final ScrollPosition position in _positions) {
      position.removeListener(_schedule);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _LayoutProbe(onLayoutOrPaint: _schedule, child: widget.child);
}

/// The share of [box] that is visible on the screen [context] is shown on
/// and inside every one of [scrollables]; see [ViewportVisibility].
double visibleFractionOf(
  RenderBox box,
  List<ScrollableState> scrollables,
  BuildContext context,
) {
  final Rect rect = MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
  final Size screen =
      MediaQuery.maybeSizeOf(context) ??
      switch (View.maybeOf(context)) {
        final FlutterView view => view.physicalSize / view.devicePixelRatio,
        null => Size.infinite,
      };
  Rect view = Offset.zero & screen;
  for (final ScrollableState scrollable in scrollables) {
    final RenderObject? clip = scrollable.context.findRenderObject();
    if (clip is! RenderBox || !clip.attached || !clip.hasSize) continue;
    view = view.intersect(
      MatrixUtils.transformRect(
        clip.getTransformTo(null),
        Offset.zero & clip.size,
      ),
    );
  }
  if (view.width <= 0 || view.height <= 0) return 0;

  // A box with no width or height (a sentinel line) is visible when it
  // lies in the view.
  double share(double start, double end, double viewStart, double viewEnd) {
    final double length = end - start;
    if (length <= 0) {
      return start >= viewStart && start <= viewEnd ? 1 : 0;
    }
    final double visible = math.min(end, viewEnd) - math.max(start, viewStart);
    if (visible <= 0) return 0;
    return (visible / math.min(length, viewEnd - viewStart))
        .clamp(0, 1)
        .toDouble();
  }

  return share(rect.left, rect.right, view.left, view.right) *
      share(rect.top, rect.bottom, view.top, view.bottom);
}

/// Calls [onLayoutOrPaint] whenever its child is laid out or painted, which
/// is when it may have moved.
class _LayoutProbe extends SingleChildRenderObjectWidget {
  const _LayoutProbe({required this.onLayoutOrPaint, super.child});

  final VoidCallback onLayoutOrPaint;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLayoutProbe(onLayoutOrPaint);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLayoutProbe renderObject,
  ) => renderObject.onLayoutOrPaint = onLayoutOrPaint;
}

class _RenderLayoutProbe extends RenderProxyBox {
  _RenderLayoutProbe(this.onLayoutOrPaint);

  VoidCallback onLayoutOrPaint;

  @override
  void performLayout() {
    super.performLayout();
    onLayoutOrPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    onLayoutOrPaint();
  }
}

/// Runs a node's [TriggerType.enterViewport] and [TriggerType.exitViewport]
/// [reactions] as [child] scrolls into and out of view.
///
/// Each reaction's [TriggerModel.visibleFraction] is its own threshold:
/// entering fires when the visible fraction rises to it (or on the first
/// frame, when the node already shows that much), exiting when the
/// fraction falls below it after the node was in view.
class ViewportReactionsBox extends StatefulWidget {
  /// Creates a [ViewportReactionsBox].
  const ViewportReactionsBox({
    super.key,
    required this.reactions,
    required this.onTrigger,
    required this.child,
  });

  /// The node's viewport reactions.
  final List<Reaction> reactions;

  /// Runs [reactions] of the trigger [type].
  final void Function(TriggerType type, List<Reaction> reactions) onTrigger;

  /// The node's widget.
  final Widget child;

  @override
  State<ViewportReactionsBox> createState() => _ViewportReactionsBoxState();
}

class _ViewportReactionsBoxState extends State<ViewportReactionsBox> {
  /// Whether the node is in view, for each threshold seen so far.
  final Map<double, bool> _inView = {};

  void _onChanged(double fraction) {
    final Map<double, List<Reaction>> byThreshold = {};
    for (final Reaction reaction in widget.reactions) {
      (byThreshold[reaction.trigger.visibleFraction] ??= []).add(reaction);
    }
    for (final MapEntry(key: threshold, value: reactions)
        in byThreshold.entries) {
      final bool inView = meetsVisibleFraction(fraction, threshold);
      final bool? was = _inView[threshold];
      _inView[threshold] = inView;
      if (was == inView || (was == null && !inView)) continue;
      widget.onTrigger(
        inView ? TriggerType.enterViewport : TriggerType.exitViewport,
        reactions,
      );
    }
  }

  @override
  Widget build(BuildContext context) =>
      ViewportVisibility(onChanged: _onChanged, child: widget.child);
}
