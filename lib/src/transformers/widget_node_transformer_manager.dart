import 'dart:developer';
import 'dart:math' hide log;
import 'dart:typed_data';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg_plus/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';

typedef LayoutRetrieverBuilder = Widget Function(
  BuildContext context,
  SizeC bounds,
  String pageID,
  String layoutID,
  String canvasID,
);

/// A wrapper class for both [PassiveNodeTransformerManager] and
/// [ActiveNodeTransformerManager].
///
/// Helps separate the functions that are common between them into one place.
abstract class WidgetNodeTransformerManager extends NodeTransformerManager<
    Widget, BuildContext, WidgetBuildSettings, NodeWidgetTransformer> {
  /// Returns a widget that decides how to load nested layouts of a rendered
  /// node.
  final LayoutRetrieverBuilder layoutRetrievalBuilder;

  WidgetNodeTransformerManager(super.getNode, this.layoutRetrievalBuilder);

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
    BuildContext context,
    BaseNode node,
    Widget widget, {
    required bool maintainState,
  }) {
    final bool visible = PropertyValueDelegate.getPropertyValue<bool>(
          node,
          'visible',
          scopedValues: ScopedValues.of(context),
        ) ??
        node.visible;

    if (visible) return widget;

    return Visibility(
      visible: visible,
      maintainState: maintainState,
      maintainAnimation: maintainState,
      maintainSize: maintainState,
      maintainSemantics: maintainState,
      maintainInteractivity: maintainState,
      child: widget,
    );
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
            ?.value
            .typedValue<int>() ??
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
    if (node is! ReactionMixin) return widget;
    if (node case CanvasNode() || SpacerNode()) return widget;
    if (node is CustomPropertiesMixin &&
        node.handlesDefaultReactionsInternally) {
      // Node is a custom properties mixin and intends to handle reactions
      // internally, even default ones. So, we don't need to wrap it with
      // reactions.
      return widget;
    }
    final InkWellModel? inkWell = node is BlendMixin ? node.inkWell : null;

    // Due to the way inkwell works internally, it is handled by
    // the individual node transformers internally if it is default shape mixin
    // because then it has fills that obscure the inkwell effect.
    if (node is DefaultShapeNode && inkWell != null) return widget;

    final List<Reaction> onClickReactions = (node as ReactionMixin)
        .reactions
        .where((reaction) =>
            reaction.trigger.type == TriggerType.click &&
            reaction.action.enabled)
        .toList();

    final List<Reaction> onLongPressReactions = (node as ReactionMixin)
        .reactions
        .where((reaction) =>
            reaction.trigger.type == TriggerType.longPress &&
            reaction.action.enabled)
        .toList();

    if (inkWell != null) {
      return Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => FunctionsRepository.triggerAction(
            context,
            TriggerType.click,
            reactions: onClickReactions,
          ),
          onLongPress: () => FunctionsRepository.triggerAction(
            context,
            TriggerType.longPress,
            reactions: onLongPressReactions,
          ),
          borderRadius: getBorderRadius(node),
          overlayColor: inkWell.overlayColor != null
              ? WidgetStatePropertyAll<Color>(
                  inkWell.overlayColor!.toFlutterColor())
              : null,
          splashColor: inkWell.splashColor?.toFlutterColor(),
          highlightColor: inkWell.highlightColor?.toFlutterColor(),
          hoverColor: inkWell.hoverColor?.toFlutterColor(),
          focusColor: inkWell.focusColor?.toFlutterColor(),
          child: widget,
        ),
      );
    } else {
      if (onClickReactions.isEmpty && onLongPressReactions.isEmpty) {
        return widget;
      }
      // TODO: should handle TriggerType.hover and TriggerType.unhover too.
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        hitTestBehavior: HitTestBehavior.opaque,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FunctionsRepository.triggerAction(
            context,
            TriggerType.click,
            reactions: onClickReactions,
          ),
          onLongPress: () => FunctionsRepository.triggerAction(
            context,
            TriggerType.longPress,
            reactions: onLongPressReactions,
          ),
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
  const AdaptiveNodeBox({super.key, required this.node, this.child});

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

/// A [Widget] that will fit its child to the size of the [BaseNode], it will
/// not take into account the node's [BaseNode.horizontalFit] and
/// [BaseNode.verticalFit]. It will strictly use the
/// [BaseNode.middleBoxLocal] as the size of the node.
class StrictNodeBox extends StatelessWidget {
  /// The [BaseNode] that will be used to determine the size of the box and
  /// its accompanying [SizeFit] values.
  final BaseNode node;

  /// The child [Widget] that will be fitted to the size of the [BaseNode].
  final Widget? child;

  /// Creates a [StrictNodeBox] that will fit its [child] to the size of the
  /// [node], taking into account the node's [BaseNode.horizontalFit] and
  /// [BaseNode.verticalFit].
  const StrictNodeBox({super.key, required this.node, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: node.basicBoxLocal.width,
      height: node.basicBoxLocal.height,
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
  const AdaptiveSizeFitBox({
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

class SvgIcon extends StatelessWidget {
  final IconModel icon;
  final Color? color;
  final double? size;
  final BoxFit fit;

  const SvgIcon({
    super.key,
    required this.icon,
    this.color,
    this.size,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    // In material apps, if there is a [Theme] without any [IconTheme]s
    // specified, icon colors default to white if [ThemeData.brightness] is dark
    // and black if [ThemeData.brightness] is light.
    //
    // Otherwise, falls back to black.
    // Apparently, Theme.of(context).iconTheme is not same as IconTheme.of(context)
    // Theme.of(context).iconTheme doesn't work properly inheriting theme when
    // in app bar, nav bar, tabs!
    final iconTheme = IconTheme.of(context);
    final Color iconColor = switch (icon) {
      _ when color != null => color!,
      _ when iconTheme.color != null => iconTheme.color!,
      _ => Theme.of(context).brightness == Brightness.light
          ? Colors.black
          : Colors.white,
    };
    final url = icon.toSvgUrl();

    if (url != null) {
      // log('SVG ICON URL: $url');
    } else {
      log('SVG ICON URL: 404 | name: ${icon.name} | type: ${icon.type} | '
          'codepoint: ${icon.codepoint} | fontFamily: ${icon.fontFamily} | '
          'fontPackage: ${icon.fontPackage}${icon is MaterialIcon ? ' | '
              'style: ${(icon as MaterialIcon).style}' : ''}');
    }

    return SizedBox.square(
      dimension: size ?? Theme.of(context).iconTheme.size ?? 24,
      child: SvgPicture.network(
        url ?? '',
        fit: fit,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      ),
    );
  }
}

class SvgIconImage extends StatelessWidget {
  final String? url;
  final Color? color;
  final double? size;
  final BoxFit fit;
  final Uint8List? bytes;

  const SvgIconImage({
    super.key,
    this.url,
    this.bytes,
    this.color,
    this.size,
    this.fit = BoxFit.contain,
  }) : assert(url != null || bytes != null,
            'Either url or bytes must be provided');

  @override
  Widget build(BuildContext context) {
    // In material apps, if there is a [Theme] without any [IconTheme]s
    // specified, icon colors default to white if [ThemeData.brightness] is dark
    // and black if [ThemeData.brightness] is light.
    //
    // Otherwise, falls back to black.
    // Apparently, Theme.of(context).iconTheme is not same as IconTheme.of(context)
    // Theme.of(context).iconTheme doesn't work properly inheriting theme when
    // in app bar, nav bar, tabs!
    final iconTheme = IconTheme.of(context);
    final Color iconColor = switch (url) {
      _ when color != null => color!,
      _ when iconTheme.color != null => iconTheme.color!,
      _ => Theme.of(context).brightness == Brightness.light
          ? Colors.black
          : Colors.white,
    };

    return SizedBox.square(
      dimension: size ?? Theme.of(context).iconTheme.size ?? 24,
      child: bytes != null
          ? SvgPicture.memory(
              bytes!,
              fit: fit,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            )
          : SvgPicture.network(
              url!,
              fit: fit,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
    );
  }
}
