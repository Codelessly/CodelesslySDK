import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/functions_repository.dart';

class PassiveFloatingActionButtonTransformer
    extends NodeWidgetTransformer<FloatingActionButtonNode> {
  PassiveFloatingActionButtonTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    FloatingActionButtonNode node,
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    return buildFromNode(context, node, useFonts: false);
  }

  Widget buildFromProps(
    BuildContext context, {
    required FloatingActionButtonProperties props,
    double? width,
    required bool useFonts,
  }) {
    final node = FloatingActionButtonNode(
      id: '',
      name: 'FAB',
      basicBoxLocal: NodeBox(0, 0, width ?? props.type.size, props.type.size),
      retainedOuterBoxLocal:
          NodeBox(0, 0, width ?? props.type.size, props.type.size),
      properties: props,
    );
    return buildFromNode(context, node, useFonts: useFonts);
  }

  Widget buildPreview({
    FloatingActionButtonProperties? properties,
    FloatingActionButtonNode? node,
    double? width,
    VoidCallback? onPressed,
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
      useFonts: true,
    );
  }

  Widget buildFromNode(
    BuildContext context,
    FloatingActionButtonNode node, {
    required bool useFonts,
  }) {
    return PassiveFloatingActionButtonWidget(
      node: node,
      onPressed: () => onPressed(context, node.reactions),
      useFonts: useFonts,
    );
  }

  void onPressed(BuildContext context, List<Reaction> reactions) => reactions
      .where((reaction) => reaction.trigger.type == TriggerType.click)
      .forEach((reaction) =>
          FunctionsRepository.performAction(context, reaction.action));
}

class PassiveFloatingActionButtonWidget extends StatelessWidget {
  final FloatingActionButtonNode node;
  final VoidCallback? onPressed;
  final double? elevation;
  final bool useFonts;

  const PassiveFloatingActionButtonWidget({
    super.key,
    required this.node,
    this.onPressed,
    this.elevation,
    required this.useFonts,
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
        useFonts: useFonts,
      ),
    );
  }

  static FloatingActionButton buildFAB(
    String fabID,
    FloatingActionButtonProperties fab, {
    VoidCallback? onPressed,
    double? elevation,
    required bool useFonts,
  }) {
    final ShapeBorder? shape = getFABShape(fab);
    switch (fab.type) {
      case FloatingActionButtonType.small:
        return FloatingActionButton.small(
          heroTag: fabID,
          key: ValueKey(fab.type),
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
          child: getFABIcon(fab, useFonts: useFonts),
        );
      case FloatingActionButtonType.regular:
        return FloatingActionButton(
          heroTag: fabID,
          key: ValueKey(fab.type),
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
          child: getFABIcon(fab, useFonts: useFonts),
        );
      case FloatingActionButtonType.large:
        return FloatingActionButton.large(
          heroTag: fabID,
          key: ValueKey(fab.type),
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
          child: getFABIcon(fab, useFonts: useFonts),
        );
      case FloatingActionButtonType.extended:
        return FloatingActionButton.extended(
          heroTag: fabID,
          key: ValueKey(fab.type),
          onPressed: onPressed,
          extendedPadding: EdgeInsets.symmetric(vertical: 2, horizontal: 10),
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
              PassiveTextTransformer.retrieveTextStyleFromTextProp(
            fab.labelStyle,
          ),
          shape: shape,
          icon: !fab.icon.show ? null : getFABIcon(fab, useFonts: useFonts),
          label: Text(fab.label),
        );
    }
  }

  static Widget? getFABIcon(
    FloatingActionButtonProperties fab, {
    required bool useFonts,
  }) {
    if (!fab.icon.show) return null;
    if (!fab.icon.isIconAvailable) return null;
    switch (fab.icon.type) {
      case IconTypeEnum.icon:
        return SvgIcon(
          icon: fab.icon.icon!,
          color: fab.icon.color?.toFlutterColor(),
          size: fab.icon.size,
        );
      case IconTypeEnum.image:
        if (fab.icon.isSvgImage) {
          return SizedBox.square(
            dimension: fab.icon.size,
            child: SvgPicture.network(
              fab.icon.iconImage!,
              fit: BoxFit.contain,
              colorFilter: fab.icon.color != null
                  ? ColorFilter.mode(
                      fab.icon.color!.toFlutterColor(), BlendMode.srcIn)
                  : null,
            ),
          );
        }
        return SizedBox.square(
          dimension: fab.icon.size,
          child: Image.network(
            fab.icon.iconImage!,
            color: fab.icon.color?.toFlutterColor(),
            fit: BoxFit.contain,
          ),
        );
    }
  }

  static ShapeBorder? getFABShape(FloatingActionButtonProperties fab) {
    if (fab.type == FloatingActionButtonType.extended) {
      if (fab.shape == CShapeBorder.stadium &&
          (fab.borderColor == null ||
              fab.borderWidth == null ||
              fab.borderWidth == 0)) {
        return StadiumBorder();
      }
    } else {
      if (fab.shape == CShapeBorder.circle &&
          (fab.borderColor == null ||
              fab.borderWidth == null ||
              fab.borderWidth == 0)) {
        return CircleBorder();
      }
    }
    return getShapeFromMixin(fab);
  }
}
