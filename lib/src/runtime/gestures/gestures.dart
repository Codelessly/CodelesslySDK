// The runtime's gesture layers, as the render core takes them
// ([NodeGestures]): a node that follows the pointer (drag_motion.dart) and
// drag and drop (drag_and_drop.dart).
import 'package:codelessly_api/codelessly_api.dart' show Node;
import 'package:flutter/rendering.dart' show RenderBox;

import '../../render/contracts.dart';
import '../../render/node_tree.dart' show NodeBox;
import 'drag_and_drop.dart' show dragAndDropLayers;
import 'drag_motion.dart' show dragMotionLayers;

/// The SDK's gesture layers. Each adds its layers only in a running app's
/// tree (and drag and drop only where the tree reacts).
final class DragGestures implements NodeGestures {
  const DragGestures();

  @override
  void addMotionLayers(NodeBox box, Node n, List<RenderBox> chain) => dragMotionLayers(box, n, chain);

  @override
  void addDragAndDropLayers(NodeBox box, Node n, List<RenderBox> chain) => dragAndDropLayers(box, n, chain);
}
