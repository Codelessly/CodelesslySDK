import 'package:codelessly_api/codelessly_api.dart';

/// In the SDK we are not using GetIt, so this singleton should help making
/// the nodes available when they are needed.
class NodeRegistry {
  /// The registry of nodes.
  final Map<String, BaseNode> _registry;

  /// A private constructor.
  NodeRegistry([Map<String, BaseNode>? registry]) : _registry = registry ?? {};

  /// Takes a map of [nodes], clears the registry and adds these nodes to it.
  void setNodes(Map<String, BaseNode> nodes) => _registry
    ..clear()
    ..addAll(nodes);

  /// Returns the registry of nodes.
  Map<String, BaseNode> getNodes() => _registry;

  /// Returns the node with the given [id].
  BaseNode? getNodeByIdOrNull(String id) => _registry[id];

  T getNodeByID<T extends BaseNode>(String id) {
    final node = _registry[id];

    if (node == null) {
      throw Exception('Node with id $id not found');
    }
    return node as T;
  }

  bool hasNodeID(String id) => _registry.containsKey(id);

  void clear() => _registry.clear();
}
