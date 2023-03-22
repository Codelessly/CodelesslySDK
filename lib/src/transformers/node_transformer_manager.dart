import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../codelessly_sdk.dart';

/// The base class for all node transformers. It holds a registry that maps
/// node types to their relevant transformers.
///
/// There are two types of transformers: active and passive.
///
/// Passive transformers are transformers that transform their passed nodes into
/// direct widgets and do nothing else.
///
/// Conversely, active transformers are transformers that transform their passed
/// nodes into widgets that handle events, different rendering states, and
/// several other mechanics that are not handled by passive transformers and
/// make interfacing with them in the Codelessly editor a much more
/// user-friendly and dynamic experience.
///
/// To register your own transformers, use either [globalPassiveManager]
/// or [globalActiveManager] depending on the type of transformer you want to
/// register. Then call [registerTransformer] or [registerAllTransformers] to
/// register your transformers in each.
///
/// This class is extended by [ActiveNodeTransformerManager] and
/// [PassiveNodeTransformerManager]. Please refer to each for an in-depth
/// explanation of how they work.
///
/// `O` is the output type, probably a [Widget].
/// `BC` is the context type, probably a [BuildContext].
/// `BS` is the build settings type, probably a [WidgetBuildSettings].
/// `NT` is the node transformer type, probably a [NodeWidgetTransformer].
///
/// Codegen uses different O, BC, BS, and NT types for its transformers.
abstract class NodeTransformerManager<O, BC, BS extends BuildSettings,
    NT extends NodeTypeTransformer> {
  final GetNode getNode;

  NodeTransformerManager(this.getNode);

  /// The registry that maps node types to their relevant transformers.
  final Map<String, NT> _registry = {};

  /// Registers a transformer in the registry.
  /// The key must match the node [BaseNode.type].
  /// NT is an instance of the [NodeTypeTransformer] to register.
  void registerTransformer(
    String key,
    NT transformer,
  ) {
    _registry[key] = transformer;
  }

  /// Registers a map of transformers in the registry.
  void registerAllTransformers(Map<String, NT> transformers) {
    _registry.addAll(transformers);
  }

  /// A convenience method that pulls the relevant transformer by its `type`.
  ///
  /// ```
  /// final PassiveIconTransformer iconTransformer =
  ///     getTransformer<PassiveIconTransformer>;
  /// ```
  L getTransformer<L>() =>
      _registry.values.firstWhere((transformer) => transformer is L) as L;

  /// Get a transformer from a given [node]'s type.
  NT getTransformerByNode(BaseNode node) => _registry[node.type]!;

  /// Get a transformer from a given node type key.
  NT getTransformerByID(String id) => _registry[id]!;

  /// Will convert a [BaseNode] to an `O` (probably [Widget]).
  ///
  /// Managers can do whatever they want here. This is where they normally
  /// wrap the widget with specific behavior, like listening to events from
  /// the Codelessly editor and responding with widget rebuilds.
  ///
  /// The [context] is the context of the widget that is being built (probably
  /// a [BuildContext]).
  ///
  /// The [settings] are the build settings for the widget that is being built.
  /// (probably a [WidgetBuildSettings].
  ///
  /// [returns] A Flutter widget.
  O buildWidgetFromNode(
    BaseNode node,
    BC context, {
    required BS settings,
  });

  /// Will convert a `T` (probably [BaseNode]) to a `K` (probably [Widget]).
  /// Managers can do whatever they want here. This is where they normally
  /// wrap the widget with interaction for example.
  ///
  /// The `context` is the context of the widget that is being built (probably
  /// a [BuildContext]).
  O buildWidgetByID(
    String id,
    BC context, {
    required BS settings,
  }) {
    final BaseNode node = getNode(id);
    return buildWidgetFromNode(node, context, settings: settings);
  }
}
