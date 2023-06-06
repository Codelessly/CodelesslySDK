import 'dart:math';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';
import '../functions/functions_repository.dart';

/// A wrapper class for both [PassiveNodeTransformerManager] and
/// [ActiveNodeTransformerManager].
///
/// Helps separate the functions that are common between them into one place.
abstract class WidgetNodeTransformerManager extends NodeTransformerManager<
    Widget, BuildContext, WidgetBuildSettings, NodeWidgetTransformer> {
  WidgetNodeTransformerManager(super.getNode);

  /// Convenience method to handle widget opacity.
  Widget applyWidgetOpacity(BaseNode node, Widget widget) {
    if (node is! BlendMixin || node.opacity > 0.99) {
      return widget;
    }

    final double opacity = node.opacity < 0.99 ? node.opacity : 1;
    return Opacity(opacity: opacity, child: widget);
  }

  /// Convenience method to handle widget visibility.
  Widget applyWidgetVisibility(
      BuildContext context, BaseNode node, Widget widget) {
    final CodelesslyContext codelesslyContext =
        context.read<CodelesslyContext>();
    // Get variable for visibility property, if available.
    final VariableData? variable =
        codelesslyContext.variables[node.variables['visible']]?.value;
    // Parse variable's value.
    final bool? variableValue = bool.tryParse(variable?.value ?? '');
    // Get node's property values that are used in any actions.
    final List<ValueModel> nodeValues =
        codelesslyContext.nodeValues[node.id]?.value ?? [];
    // Get visibility value from node values.
    final bool? nodeValue =
        nodeValues.firstWhereOrNull((val) => val.name == 'visible')?.value;

    // Priority: variable > local node value > node property.
    final bool visible = variableValue ?? nodeValue ?? node.visible;

    if (visible) return widget;

    return Visibility(visible: visible, child: widget);
  }

  /// Convenience method to handle widget rotation.
  ///
  /// Takes into account margin and padding to figure out the origin of
  /// the rotation.
  Widget applyWidgetRotation(
      BuildContext context, BaseNode node, Widget widget) {
    final CodelesslyContext payload = context.read<CodelesslyContext>();
    // Get node's values.
    final List<ValueModel> nodeValues =
        payload.nodeValues[node.id]?.value ?? [];
    // Get local rotation value if it exists, else use node's rotation value.
    final int rotationDegrees = nodeValues
            .firstWhereOrNull((value) => value.name == 'rotationDegrees')
            ?.value ??
        node.rotationDegrees;
    if (rotationDegrees == 0) return widget;
    return widget = Transform.rotate(
      angle: rotationDegrees * pi / 180,
      origin: Offset(
        (node.outerBoxGlobal.edgeLeft / 2) -
            (node.outerBoxGlobal.edgeRight / 2),
        (node.outerBoxGlobal.edgeTop / 2) -
            (node.outerBoxGlobal.edgeBottom / 2),
      ),
      child: widget,
    );
  }

  /// Convenience method to handle widget margins.
  Widget applyWidgetMargins(BaseNode node, Widget widget) {
    if (node.margin == EdgeInsetsModel.zero) return widget;
    return Padding(
      padding: node.margin.flutterEdgeInsets,
      child: widget,
    );
  }

  /// Convenience method to handle widget constraints.
  Widget applyWidgetConstraints(BaseNode node, Widget widget) {
    if (node.constraints.isEmpty) return widget;
    return ConstrainedBox(
      constraints: node.constraints.flutterConstraints,
      child: widget,
    );
  }

  /// Convenience method to handle widget reactions.
  Widget wrapWithReaction(BuildContext context, BaseNode node, Widget widget) {
    if (node is! ReactionMixin || (node as ReactionMixin).reactions.isEmpty) {
      return widget;
    }

    final List<Reaction> onClickReactions = (node as ReactionMixin)
        .reactions
        .where((reaction) => reaction.trigger.type == TriggerType.click)
        .toList();

    final List<Reaction> onLongPressReactions = (node as ReactionMixin)
        .reactions
        .where((reaction) => reaction.trigger.type == TriggerType.longPress)
        .toList();

    final InkWellModel? inkWell = node is BlendMixin ? node.inkWell : null;

    if (inkWell != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: getBorderRadius(node),
        clipBehavior: getClipBehavior(node),
        child: InkWell(
          onTap: onClickReactions.isEmpty
              ? null
              : () {
                  for (final Reaction reaction in onClickReactions) {
                    final ActionModel action = reaction.action;
                    FunctionsRepository.performAction(context, action);
                  }
                },
          onLongPress: onLongPressReactions.isEmpty
              ? null
              : () {
                  for (final Reaction reaction in onLongPressReactions) {
                    final ActionModel action = reaction.action;
                    FunctionsRepository.performAction(context, action);
                  }
                },
          splashColor: inkWell.splashColor?.toFlutterColor(),
          highlightColor: inkWell.highlightColor?.toFlutterColor(),
          hoverColor: inkWell.hoverColor?.toFlutterColor(),
          focusColor: inkWell.focusColor?.toFlutterColor(),
          child: widget,
        ),
      );
    } else {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onClickReactions.isEmpty
              ? null
              : () {
                  for (final Reaction reaction in onClickReactions) {
                    final ActionModel action = reaction.action;
                    FunctionsRepository.performAction(context, action);
                  }
                },
          onLongPress: onLongPressReactions.isEmpty
              ? null
              : () {
                  for (final Reaction reaction in onLongPressReactions) {
                    final ActionModel action = reaction.action;
                    FunctionsRepository.performAction(context, action);
                  }
                },
          child: widget,
        ),
      );
    }
  }

  BorderRadius? getBorderRadius(BaseNode node) {
    if (node is CornerMixin) {
      if (node.cornerRadius.linked &&
          node.cornerRadius.type == RadiusType.elliptical) {
        return BorderRadius.all(Radius.elliptical(
            node.basicBoxLocal.width, node.basicBoxLocal.height));
      }
      return node.cornerRadius.borderRadius;
    } else {
      return null;
    }
  }

  Clip getClipBehavior(BaseNode node) {
    if (node is ClipMixin) {
      if (node.clipsContent) {
        return Clip.hardEdge;
      } else {
        return Clip.none;
      }
    }

    if (node is CornerMixin && node.cornerRadius != CornerRadius.zero) {
      return Clip.antiAlias;
    } else {
      return Clip.none;
    }
  }
}

/// A [Widget] that will fit its child to the size of the [BaseNode], taking
/// into account the node's [BaseNode.horizontalFit] and [BaseNode.verticalFit].
class AdaptiveNodeBox extends StatelessWidget {
  /// The [BaseNode] that will be used to determine the size of the box and
  /// its accompanying [SizeFit] values.
  final BaseNode node;

  /// The child [Widget] that will be fitted to the size of the [BaseNode].
  final Widget? child;

  /// Creates a [AdaptiveNodeBox] that will fit its [child] to the size of the
  /// [node], taking into account the node's [BaseNode.horizontalFit] and
  /// [BaseNode.verticalFit].
  AdaptiveNodeBox({super.key, required this.node, required this.child});

  @override
  Widget build(BuildContext context) {
    return AdaptiveSizeFitBox(
      horizontalFit: node.horizontalFit,
      verticalFit: node.verticalFit,
      size: node.basicBoxLocal.size,
      child: child,
    );
  }
}

/// A [Widget] that will fit its child to the size of the [SizeC], taking
/// into account the [SizeFit] values.
///
/// If the [SizeFit] of an axis is [SizeFit.shrinkwrap], the size on that
/// axis will be set to `null`.
///
/// If the [SizeFit] of an axis is [SizeFit.expanded], the size on that axis
/// will be set to `double.infinity`.
///
/// If the [SizeFit] of an axis is [SizeFit.fixed] or [SizeFit.flexible], the
/// size on that axis will be set to the value of the [SizeC] on that axis.
class AdaptiveSizeFitBox extends StatelessWidget {
  /// The child [Widget] that will be fitted to the size of the [SizeC].
  final Widget? child;

  /// The [SizeFit] value that will be used to determine the width of the box.
  final SizeFit? horizontalFit;

  /// The [SizeFit] value that will be used to determine the height of the box.
  final SizeFit? verticalFit;

  /// The [SizeC] that will be used to determine the size of the box, if the
  /// [horizontalFit] and [verticalFit] values are not [SizeFit.fixed] or
  /// [SizeFit.flexible].
  final SizeC size;

  /// Creates a [AdaptiveSizeFitBox] that will fit its [child] to the size of
  /// the [SizeC], taking into account the [horizontalFit] and [verticalFit]
  /// values.
  AdaptiveSizeFitBox({
    super.key,
    required this.horizontalFit,
    required this.verticalFit,
    required this.size,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (horizontalFit == SizeFit.shrinkWrap)
          ? null
          : (horizontalFit == SizeFit.expanded)
              ? double.infinity
              : size.width,
      height: (verticalFit == SizeFit.shrinkWrap)
          ? null
          : (verticalFit == SizeFit.expanded)
              ? double.infinity
              : size.height,
      child: child,
    );
  }
}
