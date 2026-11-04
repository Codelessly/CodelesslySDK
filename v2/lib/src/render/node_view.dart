import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'islands.dart';
import 'node_tree.dart';

/// Hosts the render tree of one node of a [NodeTree] (a screen, or any
/// node). No widget or element exists per node below it; its element owns
/// the islands (widget-built nodes) of the boxes it shows, so they live
/// under the app's element tree (see islands.dart).
class NodeView extends RenderObjectWidget {
  const NodeView({super.key, required this.tree, required this.rootId, this.interactive = false});

  final NodeTree tree;
  final String rootId;

  /// Islands (inputs, embeds) take pointer input and focus: a running app.
  /// False on a design canvas.
  final bool interactive;

  @override
  IslandOwnerElement createElement() => IslandOwnerElement(this);

  void _configure() {
    final env = tree.islands.environment;
    if (env.interactive != interactive) {
      tree.islands.environment = IslandEnvironment(interactive: interactive, wrap: env.wrap);
    }
  }

  @override
  RenderNodeView createRenderObject(BuildContext context) {
    _configure();
    return RenderNodeView(tree, rootId);
  }

  @override
  void updateRenderObject(BuildContext context, RenderNodeView renderObject) {
    _configure();
    renderObject.setRoot(tree, rootId);
  }
}

class RenderNodeView extends RenderProxyBox with RenderObjectWithLayoutCallbackMixin, IslandParent {
  RenderNodeView(NodeTree tree, String rootId) {
    setRoot(tree, rootId);
  }

  NodeTree? _tree;
  String? _rootId;

  void setRoot(NodeTree tree, String rootId) {
    if (identical(tree, _tree) && rootId == _rootId) return;
    final old = child;
    if (old is NodeBox) {
      child = null;
      old.tree.release(old);
    }
    _tree = tree;
    _rootId = rootId;
    final box = tree.obtain(rootId, const Slot.root());
    // Another view showed it (a view rebuilt elsewhere in the app): it's
    // this one's now.
    if (box.parent != null) box.detachFromParent();
    child = box;
  }

  /// The root box belongs to the tree, not to this view: let go of it.
  @override
  void dispose() {
    child = null;
    super.dispose();
  }
}
