import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/functions_repository.dart';

class PassiveCanvasTransformer extends NodeWidgetTransformer<CanvasNode> {
  PassiveCanvasTransformer(super.getNode, super.manager);

  static List<String> getBodyChildren(CanvasNode node) =>
      [...node.childrenOrEmpty]
        ..remove(node.properties.topAppBarPlaceholderId)
        ..remove(node.properties.navigationBarPlaceholderId);

  Widget _wrapInScaffoldForResponsive({
    required CanvasNode node,
    required BuildContext context,
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

    final BaseNode placeholderBody = getNode(node.properties.bodyId);
    Widget body;
    if (node.isScrollable) {
      final bool isVerticalScroll = node.scrollDirection == AxisC.vertical;
      final bool isHorizontalScroll = node.scrollDirection == AxisC.horizontal;
      final allChildren = placeholderBody.childrenOrEmpty.map(getNode).toList();

      final Map<bool, List<BaseNode>> groups =
          allChildren.groupListsBy<bool>((node) {
        return (isVerticalScroll &&
                (node.isVerticalExpanded || node.isVerticalFlexible)) ||
            (isHorizontalScroll &&
                (node.isHorizontalExpanded || node.isHorizontalFlexible));
      });

      groups.putIfAbsent(true, () => []);
      groups.putIfAbsent(false, () => []);

      final {
        true: List<BaseNode> expandingChildren,
        false: List<BaseNode> nonExpandingChildren
      } = groups;

      final expandingWidgets = expandingChildren.map((node) {
        return manager.buildWidgetFromNode(node, context, settings: settings);
      }).toList();

      final nonExpandingWidgets = nonExpandingChildren.map((node) {
        return manager.buildWidgetFromNode(node, context, settings: settings);
      }).toList();

      body = Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          ...expandingWidgets,
          SingleChildScrollView(
            scrollDirection: node.scrollDirection.flutterAxis,
            reverse: node.reverse,
            primary: node.primary,
            physics: node.physics.flutterScrollPhysics,
            keyboardDismissBehavior:
                node.keyboardDismissBehavior.flutterKeyboardDismissBehavior,
            child: Stack(
              clipBehavior: Clip.none,
              children: nonExpandingWidgets,
            ),
          ),
        ],
      );
    } else {
      body = manager.buildWidgetFromNode(placeholderBody, context,
          settings: settings);
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

  Widget _wrapInScaffoldForAutoScale({
    required CanvasNode node,
    required BuildContext context,
    PreferredSizeWidget? topAppBarPlaceholder,
    Widget? navigationBarPlaceholder,
    required WidgetBuildSettings settings,
  }) {
    final CanvasProperties props = node.properties;
    final BaseNode placeholderBody = getNode(node.properties.bodyId);
    Widget body = StrictNodeBox(
             node: placeholderBody,
             child: manager.buildWidgetFromNode(placeholderBody, context,
                settings: settings),
       );

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

    final Size screenSize = MediaQuery.sizeOf(context);
    final double screenWidth = screenSize.width;
    final double canvasWidth = node.outerBoxLocal.width;
    final double viewRatio = screenWidth / canvasWidth;

    body = FittedBox(
      fit: BoxFit.fitWidth,
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
    return switch (node.scaleMode) {
      ScaleMode.responsive => _wrapInScaffoldForResponsive(
          context: context,
          node: node,
          settings: settings,
        ),
      ScaleMode.autoScale => _wrapInScaffoldForAutoScale(
          context: context,
          node: node,
          settings: settings,
        )
    };
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
