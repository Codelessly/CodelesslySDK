import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'node_motion.dart';

/// The nodes Scroll To actions scroll to, and where each is built.
///
/// Only nodes some [ScrollToAction] targets are tracked: a layout adds its
/// targets with [addTargetsIn] when it loads, and the transformer manager
/// wraps those nodes (see [wrap]) in a [ScrollTarget] that records where
/// the node is built.
abstract final class ScrollTargets {
  static final Set<String> _targets = {};
  static final Map<String, List<BuildContext>> _built = {};

  /// Whether a Scroll To action targets node [nodeId].
  static bool isTarget(String nodeId) => _targets.contains(nodeId);

  /// Tracks the nodes the Scroll To actions of [nodes] (on the nodes and
  /// their reactive children) target.
  static void addTargetsIn(Iterable<BaseNode> nodes) {
    for (final BaseNode node in nodes) {
      if (node is ReactionMixin) {
        addTargetsOf([
          for (final Reaction reaction in (node as ReactionMixin).reactions)
            reaction.action,
        ]);
      }
      if (node is ParentReactionMixin) {
        for (final ReactionMixin child
            in (node as ParentReactionMixin).reactiveChildren) {
          addTargetsOf([
            for (final Reaction reaction in child.reactions) reaction.action,
          ]);
        }
      }
    }
  }

  /// Tracks the nodes the Scroll To actions in [actions] (and the actions
  /// nested in them) target.
  static void addTargetsOf(Iterable<ActionModel> actions) {
    for (final ActionModel action in actions) {
      for (final ActionModel nested in action.selfAndNestedActions) {
        if (nested is ScrollToAction && nested.nodeId.isNotEmpty) {
          _targets.add(nested.nodeId);
        }
      }
    }
  }

  /// [child], the build of [node], wrapped to record where it is built
  /// when a Scroll To action targets it.
  static Widget wrap(BaseNode node, Widget child) => isTarget(node.id)
      ? ScrollTarget(nodeId: node.id, child: child)
      : child;

  /// Where node [nodeId] is built, or null when it isn't. The latest built
  /// instance wins when it is built more than once.
  static BuildContext? of(String nodeId) {
    final List<BuildContext>? built = _built[nodeId];
    if (built == null) return null;
    for (final BuildContext context in built.reversed) {
      if (context.mounted) return context;
    }
    return null;
  }

  /// Scrolls every scroll view around node [ScrollToAction.nodeId] so it
  /// comes into view, as [action] says. Returns false when the node isn't
  /// built, e.g. an item of a lazy list far off screen.
  static Future<bool> scrollTo(ScrollToAction action) async {
    if (_scrollTo(action) case final Future<void> scrolled) {
      await scrolled;
      return true;
    }
    // The screen may not have been laid out yet, e.g. right as it opens.
    await SchedulerBinding.instance.endOfFrame;
    if (_scrollTo(action) case final Future<void> scrolled) {
      await scrolled;
      return true;
    }
    return false;
  }

  /// Starts the scrolls of [action], or returns null when its node isn't
  /// built and laid out.
  static Future<void>? _scrollTo(ScrollToAction action) {
    final BuildContext? context = of(action.nodeId);
    if (context == null || !_laidOut(context)) return null;
    final Duration duration = Duration(
      milliseconds: action.durationMs < 0 ? 0 : action.durationMs,
    );
    final Curve curve = flutterCurveOf(action.curve);
    final RenderObject target = context.findRenderObject()!;

    final List<Future<void>> scrolls = [];
    // What to reveal in the next scroll view out: the target itself, then
    // the scroll view it is in, with the target's rect in it.
    RenderObject object = target;
    Rect? rect;
    bool innermost = true;
    ScrollableState? scrollable = Scrollable.maybeOf(context);
    while (scrollable != null) {
      final ScrollPosition position = scrollable.position;
      final RenderAbstractViewport? viewport = RenderAbstractViewport.maybeOf(
        object,
      );
      if (viewport == null) break;
      double to = viewport
          .getOffsetToReveal(
            object,
            action.alignment,
            rect: rect,
            axis: position.axis,
          )
          .offset;
      if (innermost) to += action.offset;
      if (position.hasContentDimensions) {
        to = to.clamp(position.minScrollExtent, position.maxScrollExtent);
      }
      final double delta = to - position.pixels;

      // Where the target will be in this scroll view once it has scrolled,
      // for the next scroll view out to reveal. Measured before scrolling.
      final RenderObject? outer = scrollable.context.findRenderObject();
      final double moved = axisDirectionIsReversed(position.axisDirection)
          ? delta
          : -delta;
      final Offset shift = switch (position.axis) {
        Axis.vertical => Offset(0, moved),
        Axis.horizontal => Offset(moved, 0),
      };
      final Rect? outerRect = outer == null || !outer.attached
          ? null
          : MatrixUtils.transformRect(
              target.getTransformTo(outer),
              target.paintBounds,
            ).shift(shift);

      if (delta.abs() > precisionErrorTolerance) {
        if (duration == Duration.zero) {
          position.jumpTo(to);
        } else {
          scrolls.add(
            position.animateTo(to, duration: duration, curve: curve),
          );
        }
      }

      if (outer == null || outerRect == null) break;
      rect = outerRect;
      object = outer;
      innermost = false;
      scrollable = Scrollable.maybeOf(scrollable.context);
    }
    return Future.wait(scrolls);
  }

  static bool _laidOut(BuildContext context) {
    final RenderObject? object = context.findRenderObject();
    return object is RenderBox && object.attached && object.hasSize;
  }
}

/// Records where node [nodeId] is built for Scroll To actions (see
/// [ScrollTargets]).
class ScrollTarget extends StatefulWidget {
  /// Creates a [ScrollTarget].
  const ScrollTarget({super.key, required this.nodeId, required this.child});

  /// The id of the node [child] builds.
  final String nodeId;

  /// The node's build.
  final Widget child;

  @override
  State<ScrollTarget> createState() => _ScrollTargetState();
}

class _ScrollTargetState extends State<ScrollTarget> {
  @override
  void initState() {
    super.initState();
    _register(widget.nodeId);
  }

  @override
  void didUpdateWidget(covariant ScrollTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodeId != widget.nodeId) {
      _unregister(oldWidget.nodeId);
      _register(widget.nodeId);
    }
  }

  @override
  void dispose() {
    _unregister(widget.nodeId);
    super.dispose();
  }

  void _register(String nodeId) =>
      (ScrollTargets._built[nodeId] ??= []).add(context);

  void _unregister(String nodeId) {
    final List<BuildContext>? built = ScrollTargets._built[nodeId];
    if (built == null) return;
    built.remove(context);
    if (built.isEmpty) ScrollTargets._built.remove(nodeId);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
