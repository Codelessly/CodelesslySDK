// A running page view: Flutter's PageView over the view's items, which the
// user swipes between. The page shown follows `initialPage` when it is
// bound (a variable the app changes: a tab bar, a link), animated by
// `animationDuration` and `animationCurve`; a swipe fires `changed` with the
// new page, so the variable follows the view back.
import 'package:codelessly_api_v2/codelessly_api.dart' as api;
import 'package:codelessly_api_v2/codelessly_api.dart' show CollectionScrollProps, Node, PageViewProps;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../render/recipe.dart';
import '../runtime/expressions/bindings.dart';
import 'collections_list_runtime.dart';

/// Adds a running page view of [n] (pages: [itemId] per item) to [chain].
void pageViewRuntimeRecipe(NodeBuilder b, Node n, List<RenderBox> chain, String itemId) {
  final runtime = ListRuntime(b, n);
  chain.add(b.island(
    'pageView',
    (context) => PageViewIsland(
      runtime: runtime,
      itemId: itemId,
      data: runtime.data,
      page: n.prop(PageViewProps.initialPage),
    ),
  ));
}

/// The widget of a running page view (see [pageViewRuntimeRecipe]).
class PageViewIsland extends StatefulWidget {
  const PageViewIsland({super.key, required this.runtime, required this.itemId, required this.data, required this.page});

  final ListRuntime runtime;
  final String itemId;

  /// The pages' items; null: as many as the item count (else one).
  final List<Object?>? data;

  /// The page the view shows: its `initialPage`, bound or not.
  final int page;

  @override
  State<PageViewIsland> createState() => PageViewIslandState();
}

class PageViewIslandState extends State<PageViewIsland> {
  late PageController _controller;
  final Set<ProvidedItem> _provided = {};

  /// The page shown, or being moved to by a binding.
  late int _page;

  Node get _node => widget.runtime.node;

  int get _count => widget.data?.length ?? (_node.prop(CollectionScrollProps.itemCount) ?? 1);

  int _clamp(int page) => page.clamp(0, (_count - 1).clamp(0, 1 << 30));

  @override
  void initState() {
    super.initState();
    _page = _clamp(widget.page);
    _controller = PageController(
      initialPage: _page,
      viewportFraction: _node.prop(PageViewProps.viewportFraction),
      keepPage: _node.prop(PageViewProps.keepPage),
    );
  }

  @override
  void didUpdateWidget(PageViewIsland old) {
    super.didUpdateWidget(old);
    final fraction = _node.prop(PageViewProps.viewportFraction);
    if (fraction != _controller.viewportFraction) {
      final c = _controller;
      _controller = PageController(initialPage: _page, viewportFraction: fraction, keepPage: _node.prop(PageViewProps.keepPage));
      SchedulerBinding.instance.addPostFrameCallback((_) => c.dispose());
    }
    // Only a change of the bound page moves the view: a rebuild after a
    // swipe (the variable not yet following) must not move it back.
    final target = _clamp(widget.page);
    if (widget.page != old.page && target != _page) {
      _page = target;
      // After this frame: the view may only now have the page's item.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients || _page != target) return;
        final ms = _node.prop(PageViewProps.animationDuration);
        if (ms <= 0) {
          _controller.jumpToPage(target);
        } else {
          _controller.animateToPage(target, duration: Duration(milliseconds: ms), curve: curveNamed(_node.prop(PageViewProps.animationCurve)));
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    final binder = widget.runtime.binder;
    if (binder != null) {
      for (final p in _provided) {
        binder.forgetItem(p);
      }
    }
    super.dispose();
  }

  void _changed(int page) {
    if (page == _page) return;
    _page = page;
    widget.runtime.fire('changed', event: {'value': page});
  }

  Object? _keyOf(int index) {
    final item = widget.data == null || index >= widget.data!.length ? null : widget.data![index];
    if (item is Map && item['id'] != null) return item['id'];
    return index;
  }

  Widget _pageAt(BuildContext context, int index) {
    final r = widget.runtime;
    final item = widget.data == null || index >= widget.data!.length ? index : widget.data![index];
    final instance = ProvidedItem('page', r.b.instance, _node.id, _keyOf(index));
    _provided.add(instance);
    r.binder?.provideItem(r.tree.source, instance, index: index, item: item);
    // Node boxes aren't hit themselves: the page is, so a swipe on its blank
    // parts still moves the view.
    return MetaData(
      key: ValueKey(('page', instance.key)),
      behavior: HitTestBehavior.opaque,
      child: NodeChild(tree: r.tree, id: widget.itemId, instance: instance),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = _node;
    final vertical = n.prop(CollectionScrollProps.scrollDirection) == api.Axis.vertical;
    return PageView.builder(
      controller: _controller,
      scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
      reverse: n.prop(CollectionScrollProps.reverse),
      pageSnapping: n.prop(PageViewProps.pageSnapping),
      padEnds: n.prop(PageViewProps.padEnds),
      allowImplicitScrolling: n.prop(PageViewProps.allowImplicitScrolling),
      physics: scrollPhysicsOf(n),
      clipBehavior: Clip.hardEdge,
      onPageChanged: _changed,
      itemCount: _count,
      itemBuilder: _pageAt,
    );
  }
}

/// The Flutter curve named [name] (`Curves.<name>`); ease out cubic for an
/// unknown name.
Curve curveNamed(String name) => switch (name) {
      'linear' => Curves.linear,
      'ease' => Curves.ease,
      'easeIn' => Curves.easeIn,
      'easeOut' => Curves.easeOut,
      'easeInOut' => Curves.easeInOut,
      'easeInCubic' => Curves.easeInCubic,
      'easeInOutCubic' => Curves.easeInOutCubic,
      'fastOutSlowIn' => Curves.fastOutSlowIn,
      'decelerate' => Curves.decelerate,
      'bounceOut' => Curves.bounceOut,
      'elasticOut' => Curves.elasticOut,
      _ => Curves.easeOutCubic,
    };
