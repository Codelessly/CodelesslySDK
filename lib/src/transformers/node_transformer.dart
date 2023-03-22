import 'package:codelessly_api/api.dart';
import 'package:flutter/widgets.dart';

import '../../codelessly_sdk.dart';

/// A class that holds information about how to build a node.
abstract class BuildSettings {
  /// Whether to internally handle the node's opacity.
  final bool withOpacity;

  /// Whether to internally handle the node's visibility.
  final bool withVisibility;

  /// Whether to internally handle the node's rotation.
  final bool withRotation;

  /// Whether to internally handle the node's margins.
  final bool withMargins;

  /// Whether to internally handle the node's constraints.
  final bool withConstraints;

  /// Whether to internally handle the node's reactions.
  final bool withReactions;

  /// Whether to internally handle the node's alignment.
  final bool withAlignment;

  /// Creates a [BuildSettings] instance.
  const BuildSettings({
    this.withOpacity = true,
    this.withVisibility = true,
    this.withRotation = true,
    this.withMargins = true,
    this.withConstraints = true,
    this.withReactions = true,
    this.withAlignment = true,
  });
}

/// A class that holds information about how to build a node that is to be
/// output as a Flutter widget.
class WidgetBuildSettings extends BuildSettings {
  /// Creates a [WidgetBuildSettings] instance.
  const WidgetBuildSettings({
    super.withOpacity,
    super.withVisibility,
    super.withRotation,
    super.withMargins,
    super.withConstraints,
    super.withReactions,
    super.withAlignment,
  });

  /// Creates a copy of this [WidgetBuildSettings] instance.
  WidgetBuildSettings copyWith({
    bool? withOpacity,
    bool? withVisibility,
    bool? withRotation,
    bool? withMargins,
    bool? withConstraints,
    bool? withReactions,
    bool? withAlignment,
  }) {
    return WidgetBuildSettings(
      withOpacity: withOpacity ?? this.withOpacity,
      withVisibility: withVisibility ?? this.withVisibility,
      withRotation: withRotation ?? this.withRotation,
      withMargins: withMargins ?? this.withMargins,
      withConstraints: withConstraints ?? this.withConstraints,
      withReactions: withReactions ?? this.withReactions,
      withAlignment: withAlignment ?? this.withAlignment,
    );
  }
}

/// This is the base class for all transformers.
///
/// If you wish to create your own transformer, you need to create a
/// passive version, then an active version that uses the passive version.
///
/// `N` is the node type.
/// `O` is the output type, probably a [Widget].
/// `BX` is the context type, probably a [BuildContext].
/// `BS` is the build settings type, probably a [WidgetBuildSettings].
/// `NTM` is the node transformer manager, probably a
/// [WidgetNodeTransformerManager].
///
/// Codegen uses different `O`, `BX`, and `BS` types.
abstract class NodeTypeTransformer<N extends BaseNode, O, BX,
    BS extends BuildSettings> {
  /// Creates a new instance of the transformer.
  ///
  /// [getNode] is a function that returns a node by its id.
  ///
  /// [manager] is the node transformer manager that this transformer
  ///           is registered to.
  NodeTypeTransformer(this.getNode, this.manager);

  /// The function that returns a node by its id.
  final GetNode getNode;

  /// The node transformer manager that this transformer is registered to.
  final NodeTransformerManager manager;

  /// Transforms a node into some output.
  O buildWidget(
    N node,
    BX context,
    BS settings,
  );
}

/// This is the base class for all widget transformers, transforming
/// [BaseNode]s into Flutter [Widget]s.
abstract class NodeWidgetTransformer<N extends BaseNode>
    extends NodeTypeTransformer<N, Widget, BuildContext, WidgetBuildSettings> {
  @override
  final WidgetNodeTransformerManager manager;

  /// Creates a new instance of the transformer.
  NodeWidgetTransformer(GetNode getNode, this.manager)
      : super(getNode, manager);
}
