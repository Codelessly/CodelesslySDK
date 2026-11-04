import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'islands.dart';
import 'node_tree.dart';

/// Hosts the render tree of one node of a [NodeTree] (a screen, or any
/// node): the widget tree stops here.
class NodeView extends LeafRenderObjectWidget {
  const NodeView({super.key, required this.tree, required this.rootId, this.interactive = false});

  final NodeTree tree;
  final String rootId;

  /// Islands (inputs, embeds) take pointer input and focus: a running app.
  /// False on a design canvas.
  final bool interactive;

  @override
  RenderNodeView createRenderObject(BuildContext context) {
    tree.islands.environment = IslandEnvironment.capture(context, interactive: interactive);
    return RenderNodeView(tree, rootId);
  }

  @override
  void updateRenderObject(BuildContext context, RenderNodeView renderObject) {
    tree.islands.environment = IslandEnvironment.capture(context, interactive: interactive);
    tree.islands.rebuildAll();
    renderObject.setRoot(tree, rootId);
  }
}

class RenderNodeView extends RenderProxyBox {
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
    _tree?.islands.onNeedsFlush = null;
    _tree = tree;
    _rootId = rootId;
    tree.islands.onNeedsFlush = markNeedsLayout;
    child = tree.obtain(rootId, const Slot.root());
  }

  /// The root box belongs to the tree, not to this view: let go of it.
  @override
  void dispose() {
    _tree?.islands.onNeedsFlush = null;
    child = null;
    super.dispose();
  }

  @override
  void performLayout() {
    // Build islands first, where mutating the subtree is allowed.
    final tree = _tree;
    if (tree != null) invokeLayoutCallback<BoxConstraints>((_) => tree.islands.flush());
    super.performLayout();
  }
}
