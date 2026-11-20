// Interactive pages retain the design template and motion. Flutter's
// viewport supplies drag arbitration, accessibility and page snapping.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:flutter/gestures.dart' show DragStartBehavior, PointerDeviceKind;
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/widgets.dart';

import '../render/behaviors.dart' show motionMatrix;
import '../render/convert.dart' show clip;
import '../render/physics.dart' show springOf;
import '../render/recipe.dart';
import '../runtime/expressions/bindings.dart';
import '../runtime/expressions/engine.dart' show Expressions;
import '../runtime/expressions/scopes.dart' show watchName;
import 'collections_layout.dart';
import 'collections_list_runtime.dart';

final Object _pageReportZone = Object();

/// The perspective entry a page view's camera of `perspective` 1 has: a
/// motion's own (motionMatrix).
const double pageCameraDepth = 0.0012;

class RuntimePageView extends StatefulWidget {
  const RuntimePageView({
    super.key,
    required this.runtime,
    required this.itemId,
  });
  final ListRuntime runtime;
  final String itemId;

  @override
  State<RuntimePageView> createState() => _RuntimePageViewState();
}

class _RuntimePageViewState extends State<RuntimePageView> {
  late PageController _controller;
  int? _itemCount;
  Listenable? _pageWatch;
  Object? _pageScope;
  String _pageBinding = '';
  int? _feedbackPage, _externalPage;
  bool _externalRequestPending = false;
  final _provided = <ProvidedItem>{};
  ListRuntime get _r => widget.runtime;
  api.Node get _node => _r.node;
  double get _page =>
      _controller.hasClients && _controller.position.hasContentDimensions
      ? _controller.page ?? _controller.initialPage.toDouble()
      : _controller.initialPage.toDouble();

  PageController _create() {
    final count = _r.data?.length;
    final initial = _node.prop(api.PageViewProps.initialPage);
    return PageController(
      initialPage: count == null
          ? initial
          : count == 0
          ? 0
          : initial.clamp(0, count - 1),
      viewportFraction: _node.prop(api.PageViewProps.viewportFraction),
      keepPage: _node.prop(api.PageViewProps.keepPage),
    )..addListener(_scrolled);
  }

  @override
  void initState() {
    super.initState();
    _controller = _create();
    _itemCount = _r.data?.length;
    _observePageBinding();
  }

  @override
  void didUpdateWidget(RuntimePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _observePageBinding();
    final count = _r.data?.length;
    final countChanged = count != _itemCount;
    _itemCount = count;
    if (oldWidget.runtime.node.prop(api.PageViewProps.viewportFraction) !=
            _node.prop(api.PageViewProps.viewportFraction) ||
        oldWidget.runtime.node.prop(api.PageViewProps.keepPage) !=
            _node.prop(api.PageViewProps.keepPage)) {
      _controller.dispose();
      _controller = _create();
    } else {
      final previous = oldWidget.runtime.node;
      if (previous.prop(api.PageViewProps.initialPage) !=
              _node.prop(api.PageViewProps.initialPage) ||
          countChanged ||
          _externalRequestPending) {
        if (count == 0) return;
        // A shorter list can clamp the old viewport and emit changed during
        // layout. Capture this request before that feedback mutates the
        // bound node, rather than reading its new intermediate page later.
        final boundRequest = _node.prop(api.PageViewProps.initialPage);
        final feedback = _feedbackPage == boundRequest;
        final externalPending = _externalRequestPending;
        _externalRequestPending = false;
        _feedbackPage = null;
        // A changed reaction may await speech, storage or a script before
        // writing its report. Its value can be several pages behind by
        // the time this widget rebuilds, so proximity is not provenance.
        if (feedback && !countChanged && !externalPending) return;
        // The island may coalesce an external request and a later echoed
        // report into one rebuild. Preserve the genuine request even when
        // the report became the bound node's last value before this frame.
        final requested = feedback || externalPending
            ? _externalPage ?? boundRequest
            : boundRequest;
        final target = count == null
            ? requested
            : requested.clamp(0, count - 1);
        final duration = _node.prop(api.PageViewProps.animationDuration);
        final curve = switch (_node.prop(api.PageViewProps.animationCurve)) {
          'linear' => Curves.linear,
          'easeIn' => Curves.easeIn,
          'easeOut' => Curves.easeOut,
          'easeInOut' => Curves.easeInOut,
          _ => Curves.easeOutCubic,
        };
        final controller = _controller;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              !identical(controller, _controller) ||
              !controller.hasClients) {
            return;
          }
          // A genuine target near the currently rounded page must still
          // replace an in-flight animation to a different destination.
          if ((target - _page).abs() < 0.000001) return;
          if (duration == 0) {
            _controller.jumpToPage(target);
          } else {
            _controller.animateToPage(
              target,
              duration: Duration(milliseconds: duration),
              curve: curve,
            );
          }
        });
      }
    }
  }

  int? _boundPage() {
    final scope = _r.scope;
    if (scope == null || _pageBinding.isEmpty) return null;
    final value = _r.engine.evaluate(_pageBinding, scope);
    return value is num ? value.toInt() : int.tryParse('$value');
  }

  void _pageValueChanged() {
    final value = _boundPage();
    if (value != null && Zone.current[_pageReportZone] == (this, value)) {
      _feedbackPage = value;
    } else {
      _feedbackPage = null;
      _externalPage = value;
      _externalRequestPending = value != null;
    }
  }

  void _observePageBinding() {
    final binding = _node.bind['props.initialPage'] ?? '';
    final scope = _r.scope;
    if (binding == _pageBinding && identical(scope, _pageScope)) return;
    _pageWatch?.removeListener(_pageValueChanged);
    _pageScope = scope;
    _pageBinding = binding;
    _feedbackPage = null;
    _externalRequestPending = false;
    _externalPage = _boundPage();
    final roots = {
      for (final path in Expressions.readsOf(binding))
        if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*').stringMatch(path)
            case final String root)
          root,
    };
    _pageWatch = scope == null
        ? null
        : Listenable.merge([for (final root in roots) ?watchName(scope, root)]);
    _pageWatch?.addListener(_pageValueChanged);
  }

  void _reportPage(int index) {
    // Zone values follow asynchronous action chains. The variable listener
    // can therefore distinguish this pager's echoed report from a genuine
    // button/API request, even after the reaction awaited another action.
    unawaited(
      runZoned(
        // `${result.index}` / `${result.page}`, as documented: the runner
        // reads a `value` as the whole result, so the map is given as
        // `result`. `value` too: what SDK 8.x's page view reported (an
        // action that reads `lanePage = \${value}`).
        () => _r.fire('changed', event: {
          'result': {'index': index, 'page': index},
          'value': index,
        }),
        zoneValues: {_pageReportZone: (this, index)},
      ),
    );
  }

  void _scrolled() {
    final page = _page;
    for (final instance in _provided) {
      final index = instance.key! as int;
      final data = _r.data;
      _r.binder
          ?.provideItem(
            _r.b.source,
            instance,
            index: index,
            item: data != null && index < data.length ? data[index] : index,
          )
          ?.setPageOffset(index - page);
    }
    _r.fire('scroll', event: {'page': page, 'offset': _controller.offset});
  }

  @override
  void dispose() {
    _pageWatch?.removeListener(_pageValueChanged);
    _controller.dispose();
    for (final instance in _provided) {
      _r.binder?.forgetItem(instance);
    }
    super.dispose();
  }


  /// Page [index]: the item template with its page offset, posed by the
  /// page motion (the before-pose for pages before the current one; a page
  /// whose back faces the viewer isn't drawn or tapped).
  Widget _item(BuildContext context, int index, bool vertical) {
    final data = _r.data;
      final instance = ProvidedItem('page', _r.b.instance, _node.id, index);
      _provided.add(instance);
      _r.binder
          ?.provideItem(
            _r.b.source,
            instance,
            index: index,
            item: data != null ? data[index] : index,
          )
          ?.setPageOffset(index - _page);
      final child = NodeChild(
        tree: _r.tree,
        id: widget.itemId,
        instance: instance,
      );
      return _camera(_posed(child, index, vertical), index, vertical);
  }

  /// [page] seen through the view's camera (`perspective`): a perspective
  /// about the view's middle, so every page's 3D turn (its motion's rotateX
  /// or rotateY) is seen from one point. No camera: [page] as it is.
  Widget _camera(Widget page, int index, bool vertical) {
    final perspective = _node.prop(api.PageViewProps.perspective);
    if (perspective <= 0) return page;
    return AnimatedBuilder(
      animation: _controller,
      child: page,
      builder: (context, child) => LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final d = index - _page;
          // The view's middle, from the page's top left: the page sits d
          // pages from it along the axis.
          final o = Offset(size.width / 2 - (vertical ? 0 : d * size.width), size.height / 2 - (vertical ? d * size.height : 0));
          final transform = Matrix4.translationValues(o.dx, o.dy, 0)
            ..multiply(Matrix4.identity()..setEntry(3, 2, pageCameraDepth * perspective))
            ..translateByDouble(-o.dx, -o.dy, 0, 1);
          return Transform(transform: transform, child: child);
        },
      ),
    );
  }

  /// A page posed by the view's page motion.
  Widget _posed(Widget child, int index, bool vertical) {
      final motion = _node.prop(api.PageViewProps.pageMotion);
      if (motion == null) return child;
      return AnimatedBuilder(
        animation: _controller,
        child: child,
        builder: (context, child) => LayoutBuilder(
          builder: (context, constraints) {
            final pose = RenderPageItems.pageMotionAt(
              motion,
              index - _page,
              vertical: vertical,
              before: _node.prop(api.PageViewProps.pageMotionBefore),
            );
            if (RenderPageItems.facesAway(pose) || pose.opacity <= 0) {
              // Turned away (or faded out): kept, but neither drawn nor hit.
              return IgnorePointer(child: Opacity(opacity: 0, child: child));
            }
            final size = constraints.biggest;
            final m = pose.motion;
            final origin = Alignment(m.alignment.x, m.alignment.y).alongSize(size);
            final transform =
                Matrix4.translationValues(
                    m.shiftX * size.width + origin.dx,
                    m.shiftY * size.height + origin.dy,
                    0,
                  )
                  ..multiply(motionMatrix(m))
                  ..translateByDouble(-origin.dx, -origin.dy, 0, 1);
            return Opacity(
              opacity: pose.opacity.clamp(0, 1),
              child: Transform(transform: transform, child: child),
            );
          },
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final data = _r.data;
    final vertical =
        _node.prop(api.CollectionScrollProps.scrollDirection) ==
        api.Axis.vertical;
    final scrollBehavior = ScrollConfiguration.of(context).copyWith(
      scrollbars: false,
      dragDevices: {
        ...ScrollConfiguration.of(context).dragDevices,
        PointerDeviceKind.mouse,
      },
    );
    // A fling that carries over many pages (snapPhysics), resting on the
    // page nearest where it would stop, in place of one page a fling.
    final snap = _node.prop(api.PageViewProps.pageSnapping) ? _node.prop(api.CollectionScrollProps.snapPhysics) : null;
    // The page extent the controller places pages by.
    final physics = snap == null
        ? scrollPhysicsOf(_node)
        : FlingSnapPhysics(
            physics: snap,
            nearest: (pixels, p) {
              final extent = p.viewportDimension * _controller.viewportFraction;
              return extent <= 0 ? pixels : (pixels / extent).roundToDouble() * extent;
            },
            parent: scrollPhysicsOf(_node),
          );
    final pageSnapping = snap == null && _node.prop(api.PageViewProps.pageSnapping);
    if (_node.prop(api.PageViewProps.paintOrder) == api.PagePaintOrder.reverse) {
      return _ReversePager(
        controller: _controller,
        scrollBehavior: scrollBehavior,
        vertical: vertical,
        reverse: _node.prop(api.CollectionScrollProps.reverse),
        physics: physics,
        padEnds: _node.prop(api.PageViewProps.padEnds),
        pageSnapping: pageSnapping,
        allowImplicitScrolling: _node.prop(api.PageViewProps.allowImplicitScrolling),
        viewportFraction: _node.prop(api.PageViewProps.viewportFraction),
        clipBehavior: clip(_node.prop(api.CollectionScrollProps.clipBehavior)),
        itemCount: data?.length,
        onPageChanged: _reportPage,
        itemBuilder: (context, index) => _item(context, index, vertical),
      );
    }
    final Widget pages = PageView.builder(
      controller: _controller,
      // Page turning is also a desktop interaction. Keep the host's input
      // devices while opting this pager into mouse dragging.
      scrollBehavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: false,
        dragDevices: {
          ...ScrollConfiguration.of(context).dragDevices,
          PointerDeviceKind.mouse,
        },
      ),
      scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
      reverse: _node.prop(api.CollectionScrollProps.reverse),
      physics: physics,
      padEnds: _node.prop(api.PageViewProps.padEnds),
      pageSnapping: pageSnapping,
      allowImplicitScrolling: _node.prop(
        api.PageViewProps.allowImplicitScrolling,
      ),
      clipBehavior: clip(_node.prop(api.CollectionScrollProps.clipBehavior)),
      itemCount: data?.length,
      onPageChanged: _reportPage,
      itemBuilder: (context, index) => _item(context, index, vertical),
    );    // The next page showing at the edge fades out, in place of a hard cut.
    final fade = _node.prop(api.PageViewProps.edgeFade);
    if (fade <= 0) return pages;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final extent = vertical ? bounds.height : bounds.width;
        final stop = extent <= 0 ? 1.0 : (1 - fade / extent).clamp(0.0, 1.0);
        return LinearGradient(
          begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
          end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
          colors: const [Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
          stops: [0, stop, 1],
        ).createShader(bounds);
      },
      child: pages,
    );

  }
}


/// A page view whose earlier pages draw over later ones (`paintOrder:
/// reverse`): Flutter's `PageView` with its fill-viewport sliver painting
/// and hit testing last-to-first. A page turning away then stays over the
/// page it reveals, as a book's page does.
class _ReversePager extends StatefulWidget {
  const _ReversePager({
    required this.controller,
    required this.scrollBehavior,
    required this.vertical,
    required this.reverse,
    required this.physics,
    required this.padEnds,
    required this.pageSnapping,
    required this.allowImplicitScrolling,
    required this.viewportFraction,
    required this.clipBehavior,
    required this.itemCount,
    required this.onPageChanged,
    required this.itemBuilder,
  });

  final PageController controller;
  final ScrollBehavior scrollBehavior;
  final bool vertical, reverse, padEnds, pageSnapping, allowImplicitScrolling;
  final ScrollPhysics? physics;
  final double viewportFraction;
  final Clip clipBehavior;
  final int? itemCount;
  final ValueChanged<int> onPageChanged;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<_ReversePager> createState() => _ReversePagerState();
}

class _ReversePagerState extends State<_ReversePager> {
  int _lastReported = -1;

  @override
  void initState() {
    super.initState();
    _lastReported = widget.controller.initialPage;
  }

  AxisDirection get _axisDirection => widget.vertical
      ? (widget.reverse ? AxisDirection.up : AxisDirection.down)
      : (widget.reverse ? AxisDirection.left : AxisDirection.right);

  @override
  Widget build(BuildContext context) {
    final base = widget.physics ?? widget.scrollBehavior.getScrollPhysics(context);
    final physics = widget.pageSnapping ? const PageScrollPhysics().applyTo(base) : base;
    final pad = widget.padEnds ? ((1 - widget.viewportFraction).clamp(0.0, 1.0)) / 2 : 0.0;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.depth == 0 && n is ScrollUpdateNotification && n.metrics is PageMetrics) {
          final page = (n.metrics as PageMetrics).page?.round();
          if (page != null && page != _lastReported) {
            _lastReported = page;
            widget.onPageChanged(page);
          }
        }
        return false;
      },
      child: Scrollable(
        dragStartBehavior: DragStartBehavior.start,
        axisDirection: _axisDirection,
        controller: widget.controller,
        physics: physics,
        scrollBehavior: widget.scrollBehavior,
        viewportBuilder: (context, position) => Viewport(
          scrollCacheExtent: ScrollCacheExtent.viewport(widget.allowImplicitScrolling ? 1.0 : 0.0),
          axisDirection: _axisDirection,
          offset: position,
          clipBehavior: widget.clipBehavior,
          slivers: [
            SliverLayoutBuilder(
              builder: (context, constraints) => SliverPadding(
                padding: widget.vertical
                    ? EdgeInsets.symmetric(vertical: constraints.viewportMainAxisExtent * pad)
                    : EdgeInsets.symmetric(horizontal: constraints.viewportMainAxisExtent * pad),
                sliver: _ReversePaintFillViewport(
                  viewportFraction: widget.viewportFraction,
                  delegate: SliverChildBuilderDelegate(widget.itemBuilder, childCount: widget.itemCount),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReversePaintFillViewport extends SliverMultiBoxAdaptorWidget {
  const _ReversePaintFillViewport({required super.delegate, required this.viewportFraction});
  final double viewportFraction;

  @override
  RenderSliverFillViewport createRenderObject(BuildContext context) => RenderReversePaintFillViewport(
    childManager: context as SliverMultiBoxAdaptorElement,
    viewportFraction: viewportFraction,
  );

  @override
  void updateRenderObject(BuildContext context, RenderSliverFillViewport renderObject) {
    renderObject.viewportFraction = viewportFraction;
  }
}

/// [RenderSliverFillViewport] painting its pages last to first (earlier
/// pages on top) and hit testing them first to last.
class RenderReversePaintFillViewport extends RenderSliverFillViewport {
  RenderReversePaintFillViewport({required super.childManager, super.viewportFraction});

  @override
  void paint(PaintingContext context, Offset offset) {
    if (firstChild == null) return;
    final Offset mainAxisUnit, crossAxisUnit, originOffset;
    final bool addExtent;
    switch (applyGrowthDirectionToAxisDirection(constraints.axisDirection, constraints.growthDirection)) {
      case AxisDirection.up:
        mainAxisUnit = const Offset(0, -1);
        crossAxisUnit = const Offset(1, 0);
        originOffset = offset + Offset(0, geometry!.paintExtent);
        addExtent = true;
      case AxisDirection.right:
        mainAxisUnit = const Offset(1, 0);
        crossAxisUnit = const Offset(0, 1);
        originOffset = offset;
        addExtent = false;
      case AxisDirection.down:
        mainAxisUnit = const Offset(0, 1);
        crossAxisUnit = const Offset(1, 0);
        originOffset = offset;
        addExtent = false;
      case AxisDirection.left:
        mainAxisUnit = const Offset(-1, 0);
        crossAxisUnit = const Offset(0, 1);
        originOffset = offset + Offset(geometry!.paintExtent, 0);
        addExtent = true;
    }
    RenderBox? child = lastChild;
    while (child != null) {
      final main = childMainAxisPosition(child);
      final cross = childCrossAxisPosition(child);
      var childOffset = Offset(
        originOffset.dx + mainAxisUnit.dx * main + crossAxisUnit.dx * cross,
        originOffset.dy + mainAxisUnit.dy * main + crossAxisUnit.dy * cross,
      );
      if (addExtent) childOffset += mainAxisUnit * paintExtentOf(child);
      // Unlike a flat list, a posed page can be drawn outside its slot (a
      // page turning away stays over the viewport), so every built page paints.
      context.paintChild(child, childOffset);
      child = childBefore(child);
    }
  }

  @override
  bool hitTestChildren(SliverHitTestResult result, {required double mainAxisPosition, required double crossAxisPosition}) {
    final boxResult = BoxHitTestResult.wrap(result);
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      if (hitTestBoxChild(boxResult, child, mainAxisPosition: mainAxisPosition, crossAxisPosition: crossAxisPosition)) {
        return true;
      }
    }
    return false;
  }
}

// A snapping scroll's fling that carries (CollectionScrollProps.snapPhysics,
// codelessly_api docs/design/26): the scroll coasts by the release's speed,
// slowing by the GesturePhysics' friction, over as many items as it
// carries, and comes to rest exactly on the item nearest where it would
// stop; a slow release settles on the nearest item on the physics' spring.
// With reduced motion it settles on the same item on the spring, with no
// coast.

/// Scroll physics of a scroll that snaps to items: a fling coasts by
/// [physics] and rests on the stop [nearest] gives for where it would stop.
class FlingSnapPhysics extends ScrollPhysics {
  const FlingSnapPhysics({required this.physics, required this.nearest, super.parent});

  /// The release's physics (friction, spring, the fling's speeds).
  final api.GesturePhysics physics;

  /// The stop (an item's offset) nearest [pixels] in [position].
  final double Function(double pixels, ScrollMetrics position) nearest;

  /// The stop the scroll comes to rest on, released at [velocity] from
  /// [position]: the one nearest the fling's projected end.
  double targetFor(ScrollMetrics position, double velocity) {
    final projected = physics.projectFling(position.pixels, velocity);
    return nearest(projected, position).clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();
  }

  static bool get _reducedMotion => SchedulerBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  @override
  FlingSnapPhysics applyTo(ScrollPhysics? ancestor) =>
      FlingSnapPhysics(physics: physics, nearest: nearest, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if (position.outOfRange ||
        (velocity <= 0 && position.pixels <= position.minScrollExtent && velocity < 0) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent && velocity > 0)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    final target = targetFor(position, velocity);
    final distance = target - position.pixels;
    if (distance.abs() < tolerance.distance && velocity.abs() < tolerance.velocity) return null;
    final spring = springOf(physics);
    // Reduced motion: no coast; the same item, on the spring from rest.
    if (_reducedMotion) return ScrollSpringSimulation(spring, position.pixels, target, 0, tolerance: tolerance);
    final v = velocity.clamp(-physics.maxFlingVelocity, physics.maxFlingVelocity).toDouble();
    if (!physics.fling || v.abs() < physics.minFlingVelocity || distance.abs() < tolerance.distance || distance.sign != v.sign) {
      return ScrollSpringSimulation(spring, position.pixels, target, v, tolerance: tolerance);
    }
    // A friction coast whose end is the item: the drag that stops a fling
    // of speed v after `distance` (FrictionSimulation ends at x0 - v / ln drag).
    final drag = math.exp(-v / distance).clamp(1e-9, 0.9999).toDouble();
    return _LandingSimulation(FrictionSimulation(drag, position.pixels, v), target, spring, tolerance);
  }

  @override
  bool get allowImplicitScrolling => false;
}

/// A friction coast aimed at [target], handed to a spring for its last
/// stretch once it is slower than [_handOff] pixels a second (a coast
/// reaches its end only in the limit): it ends exactly on [target].
class _LandingSimulation extends Simulation {
  _LandingSimulation(this.coast, this.target, SpringDescription spring, Tolerance tolerance) : super(tolerance: tolerance) {
    final v0 = coast.dx(0).abs();
    final k = coast.dx(1).abs() / math.max(v0, 1e-9);
    _at = v0 <= _handOff || k <= 0 || k >= 1 ? 0 : math.log(_handOff / v0) / math.log(k);
    _settle = ScrollSpringSimulation(spring, coast.x(_at), target, coast.dx(_at), tolerance: tolerance);
  }

  static const double _handOff = 60;

  final FrictionSimulation coast;
  final double target;
  late final double _at;
  late final ScrollSpringSimulation _settle;

  @override
  double x(double time) => time < _at ? coast.x(time) : (_settle.isDone(time - _at) ? target : _settle.x(time - _at));

  @override
  double dx(double time) => time < _at ? coast.dx(time) : _settle.dx(time - _at);

  @override
  bool isDone(double time) => time >= _at && _settle.isDone(time - _at);
}
