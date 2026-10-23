import 'dart:developer';
import 'dart:math' hide log;
import 'dart:typed_data';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
abstract class WidgetNodeTransformerManager
    extends
        NodeTransformerManager<
          Widget,
          BuildContext,
          WidgetBuildSettings,
          NodeWidgetTransformer
        > {
  /// Returns a widget that decides how to load nested layouts of a rendered
  /// node.
  final LayoutRetrieverBuilder layoutRetrievalBuilder;

  WidgetNodeTransformerManager(super.getNode, this.layoutRetrievalBuilder);

  /// Wraps every node this manager builds, when set. See
  /// [NodeBuildDecorator].
  NodeBuildDecorator? decorator;

  /// Returns [widget] wrapped by [decorator] at [layer], or [widget] when no
  /// decorator is set.
  Widget decorate(
    BuildContext context,
    BaseNode node,
    Widget widget,
    NodeBuildLayer layer,
  ) => decorator?.decorate(context, node, widget, layer) ?? widget;

  /// Convenience method to handle widget opacity.
  Widget applyWidgetOpacity(BaseNode node, Widget widget) {
    if (node is! BlendMixin || node.opacity > 0.99) {
      return widget;
    }

    final double opacity = node.opacity < 0.99 ? node.opacity : 1;
    return Opacity(opacity: opacity, child: widget);
  }

  /// Returns the visibility a condition or variable gives [node] at runtime,
  /// or null when nothing overrides the node's own visibility.
  ///
  /// [scopedValues] are the values the condition or variable reads; a design
  /// canvas passes its variables' default values. They default to the values
  /// of [context].
  bool? runtimeVisibility(
    BuildContext context,
    BaseNode node, {
    ScopedValues? scopedValues,
  }) => PropertyValueDelegate.getPropertyValue<bool>(
    node,
    'visible',
    scopedValues: scopedValues ?? ScopedValues.of(context),
  );

  /// Convenience method to handle widget visibility.
  ///
  /// [scopedValues] are passed to [runtimeVisibility].
  Widget applyWidgetVisibility(
    BuildContext context,
    BaseNode node,
    Widget widget, {
    required bool maintainState,
    ScopedValues? scopedValues,
  }) {
    final bool? runtimeVisible = runtimeVisibility(
      context,
      node,
      scopedValues: scopedValues,
    );
    final bool visible = runtimeVisible ?? node.visible;

    if (visible) return widget;

    // A node hidden by a condition or variable at runtime gives up its space,
    // so alternative content (a sign-in or sign-up title, an error line) can
    // share a spot in a row or column. A node hidden in the editor keeps its
    // space, matching the canvas.
    final bool keepSize = maintainState && runtimeVisible == null;
    return Visibility(
      visible: visible,
      maintainState: maintainState,
      maintainAnimation: maintainState,
      maintainSize: keepSize,
      maintainSemantics: keepSize,
      maintainInteractivity: keepSize,
      child: widget,
    );
  }

  /// Convenience method to handle widget rotation.
  ///
  /// Takes into account margin and padding to figure out the origin of
  /// the rotation.
  Widget applyWidgetRotation(
    BuildContext context,
    BaseNode node,
    Widget widget,
  ) {
    final CodelesslyContext payload = context.read<CodelesslyContext>();
    // Get node's values.
    final List<ValueModel> nodeValues =
        payload.nodeValues[node.id]?.value ?? [];
    // Get local rotation value if it exists, else use node's rotation value.
    final int rotationDegrees =
        nodeValues
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
    return Padding(padding: node.margin.flutterEdgeInsets, child: widget);
  }

  /// Convenience method to handle widget constraints.
  Widget applyWidgetConstraints(BaseNode node, Widget widget) {
    if (node.constraints.isEmpty) return widget;
    return ConstrainedBox(
      constraints: node.constraints.flutterConstraints,
      child: widget,
    );
  }

  static final RegExp _defaultNodeName = RegExp(
    r'^(frame|rectangle|row|column|stack|group|icon|container|ellipse|image|'
    r'auto layout|layout|node)\s*\d*$',
    caseSensitive: false,
  );

  /// Tells screen readers that a tappable node is a button. A node with text
  /// inside reads as that text; one without (an icon button) reads as its
  /// node name, or its icon's name when the node still has a default name.
  Widget wrapWithSemantics(BaseNode node, Widget widget) {
    final String? customLabel = node.variables['semanticLabel'];
    final String? customSelected = node.variables['semanticSelected'];
    if ((customLabel?.trim().isNotEmpty ?? false) || customSelected != null) {
      return _wrapWithCustomSemantics(
        node,
        widget,
        label: customLabel,
        selected: customSelected,
      );
    }
    if (node is! ReactionMixin) return widget;
    if (node case CanvasNode() || SpacerNode()) return widget;
    if (node is CustomPropertiesMixin &&
        node.handlesDefaultReactionsInternally) {
      return widget;
    }
    final bool tappable = (node as ReactionMixin).reactions.any(
      (reaction) =>
          reaction.trigger.type == TriggerType.click && reaction.action.enabled,
    );
    if (!tappable) return widget;

    final List<BaseNode> descendants = [];
    void collect(BaseNode parent) {
      for (final String id in parent.childrenOrEmpty) {
        final BaseNode? child = _tryGetNode(id);
        if (child == null) continue;
        descendants.add(child);
        collect(child);
      }
    }

    collect(node);

    final bool hasText = descendants.any((child) => child is TextNode);
    final String label = hasText ? '' : semanticLabelFor(node, descendants);
    return MergeSemantics(
      child: Semantics(
        button: true,
        label: label.isEmpty ? null : label,
        child: widget,
      ),
    );
  }

  /// Semantics a node's `semanticLabel` variable gives it (a text with paths
  /// or formulas): one node with that label, replacing what the children
  /// read. A button (a node that reacts to taps) keeps its tap and long press
  /// on that node; a widget (a field, a dropdown) keeps its own semantics,
  /// read after the label. A `semanticSelected` formula marks it selected,
  /// e.g. the chosen tab or chip.
  Widget _wrapWithCustomSemantics(
    BaseNode node,
    Widget widget, {
    String? label,
    String? selected,
  }) {
    List<Reaction> reactionsOf(TriggerType type) => [
      if (node is ReactionMixin)
        for (final Reaction reaction in (node as ReactionMixin).reactions)
          if (reaction.trigger.type == type && reaction.action.enabled)
            reaction,
    ];
    final List<Reaction> taps = reactionsOf(TriggerType.click);
    final List<Reaction> longPresses = reactionsOf(TriggerType.longPress);
    final bool tappable = taps.isNotEmpty;
    final bool widgetHandlesInput =
        node is CustomPropertiesMixin && node.handlesDefaultReactionsInternally;
    return Builder(
      builder: (context) {
        final ScopedValues scopedValues = ScopedValues.of(context);
        final String? text = label == null || label.trim().isEmpty
            ? null
            : PropertyValueDelegate.substituteVariables(
                label,
                scopedValues: scopedValues,
                nullSubstitutionMode: NullSubstitutionMode.emptyString,
              );
        final bool? isSelected = selected == null
            ? null
            : PropertyValueDelegate.getVariableValueFromPath<bool>(
                selected,
                scopedValues: scopedValues,
              );
        if (widgetHandlesInput) {
          // A field or dropdown's state and actions live on its own
          // semantics, which merge in after the label.
          return MergeSemantics(
            child: Semantics(
              container: true,
              selected: isSelected,
              label: text,
              child: widget,
            ),
          );
        }
        return Semantics(
          container: true,
          button: tappable ? true : null,
          selected: isSelected,
          label: text,
          // The children's text and the tap handler below are left out, so
          // the node's own tap and long press are given here.
          excludeSemantics: text != null,
          onTap: text != null && tappable
              ? () => FunctionsRepository.triggerAction(
                  context,
                  TriggerType.click,
                  reactions: taps,
                )
              : null,
          onLongPress: text != null && longPresses.isNotEmpty
              ? () => FunctionsRepository.triggerAction(
                  context,
                  TriggerType.longPress,
                  reactions: longPresses,
                )
              : null,
          child: widget,
        );
      },
    );
  }

  /// The name a screen reader announces for [node] when it has no text.
  static String semanticLabelFor(BaseNode node, List<BaseNode> descendants) {
    final String name = node.name.trim();
    if (name.isNotEmpty && !_defaultNodeName.hasMatch(name)) return name;
    for (final BaseNode child in descendants) {
      if (child is! IconNode) continue;
      final String? iconName = child.properties.icon.icon?.name;
      if (iconName != null && iconName.isNotEmpty) {
        return iconName.replaceAll('_', ' ');
      }
    }
    return '';
  }

  BaseNode? _tryGetNode(String id) {
    try {
      return getNode(id);
    } catch (_) {
      return null;
    }
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

    final List<Reaction> onClickReactions = (node as ReactionMixin).reactions
        .where(
          (reaction) =>
              reaction.trigger.type == TriggerType.click &&
              reaction.action.enabled,
        )
        .toList();

    final List<Reaction> onLongPressReactions = (node as ReactionMixin)
        .reactions
        .where(
          (reaction) =>
              reaction.trigger.type == TriggerType.longPress &&
              reaction.action.enabled,
        )
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
          onLongPress: onLongPressReactions.isEmpty
              ? null
              : () => FunctionsRepository.triggerAction(
                  context,
                  TriggerType.longPress,
                  reactions: onLongPressReactions,
                ),
          borderRadius: getBorderRadius(node),
          overlayColor: inkWell.overlayColor != null
              ? WidgetStatePropertyAll<Color>(
                  inkWell.overlayColor!.toFlutterColor(),
                )
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
          onLongPress: onLongPressReactions.isEmpty
              ? null
              : () => FunctionsRepository.triggerAction(
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
        return BorderRadius.all(
          Radius.elliptical(
            node.basicBoxLocal.width,
            node.basicBoxLocal.height,
          ),
        );
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
/// If the [SizeFit] of an axis is [SizeFit.shrinkWrap], the box hugs its child
/// on that axis.
///
/// If the [SizeFit] of an axis is [SizeFit.expanded], the box fills that axis
/// when the incoming constraints bound it, and otherwise takes the [SizeC] on
/// that axis (see [FitBox]).
///
/// Every other [SizeFit] (fixed, locked, flexible) takes the [SizeC] on that
/// axis. A flexible node's parent wraps it in a [Flexible], which lets it get
/// smaller than that but never larger.
class AdaptiveSizeFitBox extends StatelessWidget {
  /// The child [Widget] that will be fitted to the size of the [SizeC].
  final Widget? child;

  /// The [SizeFit] value that will be used to determine the width of the box.
  final SizeFit? horizontalFit;

  /// The [SizeFit] value that will be used to determine the height of the box.
  final SizeFit? verticalFit;

  /// The design size of the box.
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
    return FitBox.fromFits(
      horizontalFit: horizontalFit,
      verticalFit: verticalFit,
      size: size,
      child: child,
    );
  }
}

/// Renders an [IconModel]: Material icons and symbols from Google's prebuilt
/// SVGs, Cupertino icons from the cupertino_icons font.
class SvgIcon extends StatelessWidget {
  final IconModel icon;
  final Color? color;
  final double? size;
  final BoxFit fit;

  /// Material Symbols axes; see [IconModelExt.toSvgUrl].
  final double? fill;
  final double? weight;
  final double? grade;
  final double? opticalSize;

  const SvgIcon({
    super.key,
    required this.icon,
    this.color,
    this.size,
    this.fit = BoxFit.contain,
    this.fill,
    this.weight,
    this.grade,
    this.opticalSize,
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
      _ =>
        Theme.of(context).brightness == Brightness.light
            ? Colors.black
            : Colors.white,
    };
    final double dimension = size ?? Theme.of(context).iconTheme.size ?? 24;

    final IconData? cupertinoIcon = icon is CupertinoIcon
        ? cupertinoIconsByCodepoint[icon.codepoint]
        : null;
    if (cupertinoIcon != null) {
      return Icon(cupertinoIcon, size: dimension, color: iconColor);
    }

    final url = icon.toSvgUrl(
      fill: fill,
      weight: weight,
      grade: grade,
      opticalSize: opticalSize,
    );
    if (url == null) {
      log(
        'No icon source | name: ${icon.name} | type: ${icon.type} | '
        'codepoint: ${icon.codepoint} | fontFamily: ${icon.fontFamily} | '
        'fontPackage: ${icon.fontPackage}',
      );
      return SizedBox.square(dimension: dimension);
    }

    return SizedBox.square(
      dimension: dimension,
      child: SvgPicture.network(
        url,
        fit: fit,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        // Offline or unavailable icons leave their space empty.
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
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
  }) : assert(
         url != null || bytes != null,
         'Either url or bytes must be provided',
       );

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
      _ =>
        Theme.of(context).brightness == Brightness.light
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
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
    );
  }
}
