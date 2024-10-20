import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

class PassiveFloatingActionButtonTransformer
    extends NodeWidgetTransformer<FloatingActionButtonNode> {
  PassiveFloatingActionButtonTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    FloatingActionButtonNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return buildFromNode(context, node);
  }

  Widget buildFromProps(
    BuildContext context, {
    required FloatingActionButtonProperties props,
    double? width,
    double? height,
    WidgetBuildSettings settings =
        const WidgetBuildSettings(debugLabel: 'buildFromProps'),
  }) {
    final node = FloatingActionButtonNode(
      id: '',
      name: 'FAB',
      basicBoxLocal:
          NodeBox(0, 0, width ?? props.type.size, height ?? props.type.size),
      retainedOuterBoxLocal:
          NodeBox(0, 0, width ?? props.type.size, props.type.size),
      properties: props,
    );
    return buildFromNode(
      context,
      node,
      settings: settings,
    );
  }

  Widget buildPreview({
    FloatingActionButtonProperties? properties,
    FloatingActionButtonNode? node,
    double? width,
    VoidCallback? onPressed,
    WidgetBuildSettings settings =
        const WidgetBuildSettings(debugLabel: 'buildPreview'),
  }) {
    properties =
        properties ?? node?.properties ?? FloatingActionButtonProperties();
    final previewNode = FloatingActionButtonNode(
      properties: properties,
      id: '',
      name: 'FAB',
      basicBoxLocal:
          NodeBox(0, 0, width ?? properties.type.size, properties.type.size),
      retainedOuterBoxLocal:
          NodeBox(0, 0, width ?? properties.type.size, properties.type.size),
    );
    return PassiveFloatingActionButtonWidget(
      node: previewNode,
      onPressed: onPressed,
      settings: settings,
    );
  }

  Widget buildFromNode(
    BuildContext context,
    FloatingActionButtonNode node, {
    WidgetBuildSettings settings =
        const WidgetBuildSettings(debugLabel: 'buildFromNode'),
  }) {
    return PassiveFloatingActionButtonWidget(
      node: node,
      onPressed: () => onPressed(context, node.reactions),
      settings: settings,
    );
  }

  void onPressed(BuildContext context, List<Reaction> reactions) =>
      FunctionsRepository.triggerAction(context, TriggerType.click,
          reactions: reactions);
}

class PassiveFloatingActionButtonWidget extends StatelessWidget {
  final FloatingActionButtonNode node;
  final VoidCallback? onPressed;
  final double? elevation;
  final WidgetBuildSettings settings;

  const PassiveFloatingActionButtonWidget({
    super.key,
    required this.node,
    this.onPressed,
    this.elevation,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final FloatingActionButtonProperties fab = node.properties;
    return SizedBox(
      width: node.middleBoxLocal.width,
      height: node.middleBoxLocal.height,
      child: buildFAB(
        node.id,
        fab,
        onPressed: onPressed,
        elevation: elevation,
      ),
    );
  }

  static FloatingActionButton buildFAB(
    String fabID,
    FloatingActionButtonProperties fab, {
    VoidCallback? onPressed,
    double? elevation,
  }) {
    final ShapeBorder? shape = getFABShape(fab);
    switch (fab.type) {
      case FloatingActionButtonType.small:
        return FloatingActionButton.small(
          heroTag: null,
          onPressed: onPressed,
          backgroundColor: fab.backgroundColor.toFlutterColor(),
          foregroundColor: fab.foregroundColor.toFlutterColor(),
          elevation: elevation ?? fab.elevation,
          focusElevation: fab.focusElevation,
          hoverElevation: fab.hoverElevation,
          highlightElevation: fab.highlightElevation,
          focusColor: fab.focusColor?.toFlutterColor(),
          hoverColor: fab.hoverColor?.toFlutterColor(),
          splashColor: fab.splashColor?.toFlutterColor(),
          shape: shape,
          child: getFABIcon(fab),
        );
      case FloatingActionButtonType.regular:
        return FloatingActionButton(
          heroTag: null,
          onPressed: onPressed,
          backgroundColor: fab.backgroundColor.toFlutterColor(),
          foregroundColor: fab.foregroundColor.toFlutterColor(),
          elevation: elevation ?? fab.elevation,
          focusElevation: fab.focusElevation,
          hoverElevation: fab.hoverElevation,
          highlightElevation: fab.highlightElevation,
          focusColor: fab.focusColor?.toFlutterColor(),
          hoverColor: fab.hoverColor?.toFlutterColor(),
          splashColor: fab.splashColor?.toFlutterColor(),
          shape: shape,
          child: getFABIcon(fab),
        );
      case FloatingActionButtonType.large:
        return FloatingActionButton.large(
          heroTag: null,
          onPressed: onPressed,
          backgroundColor: fab.backgroundColor.toFlutterColor(),
          foregroundColor: fab.foregroundColor.toFlutterColor(),
          elevation: elevation ?? fab.elevation,
          focusElevation: fab.focusElevation,
          hoverElevation: fab.hoverElevation,
          highlightElevation: fab.highlightElevation,
          focusColor: fab.focusColor?.toFlutterColor(),
          hoverColor: fab.hoverColor?.toFlutterColor(),
          splashColor: fab.splashColor?.toFlutterColor(),
          shape: shape,
          child: getFABIcon(fab),
        );
      case FloatingActionButtonType.extended:
        return FloatingActionButton.extended(
          heroTag: null,
          onPressed: onPressed,
          extendedPadding:
              const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
          backgroundColor: fab.backgroundColor.toFlutterColor(),
          foregroundColor: fab.foregroundColor.toFlutterColor(),
          elevation: elevation ?? fab.elevation,
          focusElevation: fab.focusElevation,
          hoverElevation: fab.hoverElevation,
          highlightElevation: fab.highlightElevation,
          focusColor: fab.focusColor?.toFlutterColor(),
          hoverColor: fab.hoverColor?.toFlutterColor(),
          splashColor: fab.splashColor?.toFlutterColor(),
          extendedIconLabelSpacing: fab.extendedIconLabelSpacing,
          extendedTextStyle:
              TextUtils.retrieveTextStyleFromProp(fab.labelStyle),
          shape: shape,
          icon: !fab.icon.show ? null : getFABIcon(fab),
          label: Text(fab.label),
        );
    }
  }

  static Widget? getFABIcon(FloatingActionButtonProperties fab) {
    return retrieveIconWidget(
      fab.icon,
      null,
      fab.foregroundColor.toFlutterColor(),
    );
  }

  static ShapeBorder? getFABShape(FloatingActionButtonProperties fab) {
    if (fab.type == FloatingActionButtonType.extended) {
      if (fab.shape == CShapeBorder.stadium &&
          (fab.borderColor == null ||
              fab.borderWidth == null ||
              fab.borderWidth == 0)) {
        return const StadiumBorder();
      }
    } else {
      if (fab.shape == CShapeBorder.circle &&
          (fab.borderColor == null ||
              fab.borderWidth == null ||
              fab.borderWidth == 0)) {
        return const CircleBorder();
      }
    }
    return getShapeFromMixin(fab);
  }
}
