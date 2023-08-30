import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/functions_repository.dart';

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
      onPressed: () => onFaBPressed(context, node),
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
      final Size screenSize = MediaQuery.sizeOf(context);
      final double screenWidth = screenSize.width;
      final double canvasWidth = node.outerBoxLocal.width;
      final double viewRatio = screenWidth / canvasWidth;

      body = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: viewRatio < 1 ? canvasWidth : screenWidth,
          // This fixes an auto scale crash when a simple canvas with no
          // scrolling because the FittedBox needs to have a non-zero height.
          //
          // The scrollview normally takes care of that, but under this
          // condition, a fixed height is required for auto-scaling.
          height: node.isScrollable ? null : node.outerBoxLocal.height,
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

    final bool needsAScaffold = appBar != null ||
        floatingActionButton != null ||
        bottomNavigationBar != null;

    if (needsAScaffold) body = SizedBox.expand(child: body);

    final Widget scaffold;

    if (needsAScaffold) {
      scaffold = Scaffold(
        backgroundColor: retrieveBackgroundColor(context, node),
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: props.floatingActionButton?.location
            .toFloatingActionButtonLocation(),
        bottomNavigationBar: bottomNavigationBar,
        body: body,
      );
    } else {
      scaffold = Material(
        color: retrieveBackgroundColor(context, node),
        child: body,
      );
    }

    return manager.getTransformer<PassiveRectangleTransformer>().buildRectangle(
      node,
      children: [scaffold],
    );
  }

  void onFaBPressed(BuildContext context, CanvasNode node) {
    FunctionsRepository.triggerAction(context, node, TriggerType.click,
        reactions: node.properties.floatingActionButton?.reactions);
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

  static Color? retrieveBackgroundColor(BuildContext context, CanvasNode node) {
    final fills = <PaintModel>[
      for (final fill in node.fills)
        PropertyValueDelegate.getPropertyValue(
            context, node, 'fill-${fill.id}') ??
            fill
    ];
    if (fills.length == 1 && fills[0].type == PaintType.solid) {
      return fills[0].color?.toFlutterColor(opacity: fills[0].opacity);
    }
    return Colors.transparent;
  }
}
