// Interactive pages retain the design template and motion. Flutter's
// viewport supplies drag arbitration, accessibility and page snapping.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:flutter/widgets.dart';

import '../render/behaviours.dart' show motionMatrix;
import '../render/convert.dart' show clip;
import '../render/recipe.dart';
import '../runtime/expressions/bindings.dart';
import 'collections_layout.dart';
import 'collections_list_runtime.dart';

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
  }

  @override
  void didUpdateWidget(RuntimePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
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
          countChanged) {
        if (count == 0) return;
        // A shorter list can clamp the old viewport and emit changed during
        // layout. Capture this request before that feedback mutates the
        // bound node, rather than reading its new intermediate page later.
        final requested = _node.prop(api.PageViewProps.initialPage);
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
          // onPageChanged commonly writes this same bound variable. Its
          // intermediate page reports are feedback, not navigation requests:
          // retargeting to each report would cancel a multi-page animation.
          if (target == _page.round()) return;
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

  void _scrolled() {
    final page = _page;
    for (final instance in _provided) {
      final index = instance.key! as int;
      final data = _r.data;
      _r.binder
          ?.provideItem(
            _r.tree.source,
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
    _controller.dispose();
    for (final instance in _provided) {
      _r.binder?.forgetItem(instance);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _r.data;
    final vertical =
        _node.prop(api.CollectionScrollProps.scrollDirection) ==
        api.Axis.vertical;
    return PageView.builder(
      controller: _controller,
      scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
      reverse: _node.prop(api.CollectionScrollProps.reverse),
      physics: scrollPhysicsOf(_node),
      padEnds: _node.prop(api.PageViewProps.padEnds),
      pageSnapping: _node.prop(api.PageViewProps.pageSnapping),
      allowImplicitScrolling: _node.prop(
        api.PageViewProps.allowImplicitScrolling,
      ),
      clipBehavior: clip(_node.prop(api.CollectionScrollProps.clipBehavior)),
      itemCount: data?.length,
      onPageChanged: (index) =>
          _r.fire('changed', event: {'index': index, 'page': index}),
      itemBuilder: (context, index) {
        final instance = ProvidedItem('page', _r.b.instance, _node.id, index);
        _provided.add(instance);
        _r.binder
            ?.provideItem(
              _r.tree.source,
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
              );
              final size = constraints.biggest;
              final origin = Alignment(
                pose.originX,
                pose.originY,
              ).alongSize(size);
              final transform =
                  Matrix4.translationValues(
                      pose.shiftX * size.width + origin.dx,
                      pose.shiftY * size.height + origin.dy,
                      0,
                    )
                    ..multiply(motionMatrix(pose))
                    ..translateByDouble(-origin.dx, -origin.dy, 0, 1);
              return Opacity(
                opacity: pose.opacity.clamp(0, 1),
                child: Transform(transform: transform, child: child),
              );
            },
          ),
        );
      },
    );
  }
}
