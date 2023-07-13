import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

class PassiveCanvasTransformer extends NodeWidgetTransformer<CanvasNode> {
  PassiveCanvasTransformer(super.getNode, super.manager);

  static List<String> getBodyChildren(CanvasNode node) =>
      [...node.childrenOrEmpty]
        ..remove(node.properties.topAppBarPlaceholderId)
        ..remove(node.properties.navigationBarPlaceholderId);

  Widget _wrapInScaffold({
    required CanvasNode node,
    required BuildContext context,
    required Widget body,
    PreferredSizeWidget? topAppBarPlaceholder,
    Widget? navigationBarPlaceholder,
    required WidgetBuildSettings settings,
  }) {
    final CanvasProperties props = node.properties;

    PreferredSizeWidget? appBar = topAppBarPlaceholder ??
        ((props.topAppBarPlaceholderId != null)
            ? manager.buildWidgetByID(
                props.topAppBarPlaceholderId!,
                context,
                settings: settings,
              ) as PreferredSizeWidget
            : null);
    Widget? floatingActionButton = (props.floatingActionButton != null)
        ? PassiveFloatingActionButtonWidget.buildFAB(
            node.id,
            props.floatingActionButton!,
            useFonts: false,
          )
        : null;
    Widget? bottomNavigationBar = navigationBarPlaceholder ??
        ((props.navigationBarPlaceholderId != null)
            ? manager.buildWidgetByID(
                props.navigationBarPlaceholderId!, context,
                settings: settings)
            : null);

    if (node.isScrollable && node.scaleMode == ScaleMode.responsive) {
      body = SingleChildScrollView(
        scrollDirection: node.scrollDirection.flutterAxis,
        reverse: node.reverse,
        primary: node.primary,
        physics: node.physics.flutterScrollPhysics,
        keyboardDismissBehavior:
            node.keyboardDismissBehavior.flutterKeyboardDismissBehavior,
        child: body,
      );
    }

    if (node.scaleMode == ScaleMode.autoScale) {
      final double screenWidth = MediaQuery.of(context).size.width;
      final double canvasWidth = node.outerBoxLocal.width;
      final double viewRatio = screenWidth / canvasWidth;

      body = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: viewRatio < 1 ? canvasWidth : screenWidth,
          child: body,
        ),
      );

      if (node.isScrollable) {
        body = SingleChildScrollView(
          scrollDirection: node.scrollDirection.flutterAxis,
          reverse: node.reverse,
          primary: node.primary,
          physics: node.physics.flutterScrollPhysics,
          keyboardDismissBehavior:
              node.keyboardDismissBehavior.flutterKeyboardDismissBehavior,
          child: body,
        );
      }
    }

    body = SizedBox.expand(child: body);

    final bool needsAScaffold = appBar != null ||
        floatingActionButton != null ||
        bottomNavigationBar != null;

    final Widget scaffold;

    if (needsAScaffold) {
      scaffold = Scaffold(
        backgroundColor: retrieveBackgroundColor(node),
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: props.floatingActionButton?.location
            .toFloatingActionButtonLocation(),
        bottomNavigationBar: bottomNavigationBar,
        body: body,
      );
    } else {
      scaffold = Material(
        color: retrieveBackgroundColor(node),
        child: body,
      );
    }

    return manager.getTransformer<PassiveRectangleTransformer>().buildRectangle(
      node,
      children: [scaffold],
    );
  }

  @override
  Widget buildWidget(
    CanvasNode node,
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    final BaseNode placeholderBody = getNode(node.properties.bodyId);
    Widget child = manager.buildWidgetFromNode(placeholderBody, context,
        settings: settings);

    if (node.isScrollable) {
      if (node.scrollDirection == AxisC.vertical &&
          (placeholderBody.isVerticalExpanded ||
              placeholderBody.isVerticalFlexible)) {
        child = SizedBox(
          height: placeholderBody.basicBoxLocal.height,
          child: child,
        );
      } else if (node.scrollDirection == AxisC.horizontal &&
          (placeholderBody.isHorizontalExpanded ||
              placeholderBody.isHorizontalFlexible)) {
        child = SizedBox(
          width: placeholderBody.basicBoxLocal.width,
          child: child,
        );
      }
    }

    return _wrapInScaffold(
      context: context,
      node: node,
      body: child,
      settings: settings,
    );
  }

  static Color? retrieveBackgroundColor(CanvasNode node) {
    if (node.fills.length == 1 && node.fills[0].type == PaintType.solid) {
      return node.fills[0].color
          ?.toFlutterColor(opacity: node.fills[0].opacity);
    }
    return node.fills.isNotEmpty ? Colors.transparent : Colors.white;
  }
}
