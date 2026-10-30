import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'codelessly_context.dart';

/// Where each node is shown: its id mapped to the build contexts of the
/// widgets that show it, in the order they appeared, so an action can find
/// a node on screen (see [ScrollToAction]).
///
/// Every node built by the SDK registers itself while it is mounted. A node
/// shown more than once (the item of a list) has a context per copy.
class NodeContextRegistry {
  const NodeContextRegistry._();

  static final Map<String, List<BuildContext>> _contexts = {};

  /// Records that [context] shows the node [nodeId].
  static void register(String nodeId, BuildContext context) =>
      (_contexts[nodeId] ??= []).add(context);

  /// Forgets that [context] shows the node [nodeId].
  static void unregister(String nodeId, BuildContext context) {
    final List<BuildContext>? contexts = _contexts[nodeId];
    if (contexts == null) return;
    contexts.remove(context);
    if (contexts.isEmpty) _contexts.remove(nodeId);
  }

  /// The mounted contexts showing the node [nodeId], first shown first.
  static List<BuildContext> contextsOf(String nodeId) => [
    for (final BuildContext context in _contexts[nodeId] ?? const [])
      if (context.mounted) context,
  ];

  /// The context that shows the node [nodeId], preferring one under the
  /// same [CodelesslyContext] as [from] (the same layout, when several
  /// show nodes with the same ids). Null when the node isn't shown.
  static BuildContext? find(String nodeId, {BuildContext? from}) {
    final List<BuildContext> contexts = contextsOf(nodeId);
    if (contexts.isEmpty) return null;
    final CodelesslyContext? own = from == null ? null : _codelessly(from);
    if (own != null) {
      for (final BuildContext context in contexts) {
        if (identical(_codelessly(context), own)) return context;
      }
    }
    return contexts.first;
  }

  static CodelesslyContext? _codelessly(BuildContext context) {
    try {
      return Provider.of<CodelesslyContext>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }
}
