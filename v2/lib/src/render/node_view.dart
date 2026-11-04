import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'node_tree.dart';

/// Hosts the render tree of one node of a [NodeTree] (a screen, or any
/// node): the widget tree stops here.
class NodeView extends LeafRenderObjectWidget {
  const NodeView({super.key, required this.tree, required this.rootId});

  final NodeTree tree;
  final String rootId;

  @override
  RenderNodeView createRenderObject(BuildContext context) => RenderNodeView(tree, rootId);

  @override
  void updateRenderObject(BuildContext context, RenderNodeView renderObject) {
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
    _tree = tree;
    _rootId = rootId;
    child = tree.obtain(rootId, const Slot.root());
  }
}
