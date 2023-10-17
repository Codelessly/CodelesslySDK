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

  Widget _wrapInScaffoldForResponsive({
    required CanvasNode node,
    required BuildContext context,
    PreferredSizeWidget? topAppBarPlaceholder,
    Widget? navigationBarPlaceholder,
    required WidgetBuildSettings settings,
  }) {
    final CanvasProperties props = node.properties;

    BaseNode? appBarPlaceholderNode;
    if (props.topAppBarPlaceholderId != null) {
      appBarPlaceholderNode = getNode(props.topAppBarPlaceholderId!);
    }
    PreferredSizeWidget? appBar = topAppBarPlaceholder ??
        ((props.topAppBarPlaceholderId != null)
            ? PreferredSize(
                preferredSize: Size.fromHeight(
                    appBarPlaceholderNode!.outerBoxLocal.height),
                child: manager.buildWidgetByID(
                  props.topAppBarPlaceholderId!,
                  context,
                  settings: settings,
                ))
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
    Widget body = manager.buildWidgetFromNode(
      placeholderBody,
      context,
      settings: settings,
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

    // Optionally expand if needed. Layout is responsive, so it doesn't matter
    // unless the other scaffold properties are set.
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
          settings: settings,
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
    Widget body = manager.buildWidgetFromNode(
      placeholderBody,
      context,
      settings: settings,
    );

    BaseNode? appBarPlaceholderNode;
    if (props.topAppBarPlaceholderId != null) {
      appBarPlaceholderNode = getNode(props.topAppBarPlaceholderId!);
    }
    PreferredSizeWidget? appBar = topAppBarPlaceholder ??
        ((props.topAppBarPlaceholderId != null)
            ? PreferredSize(
                preferredSize: Size.fromHeight(
                    appBarPlaceholderNode!.outerBoxLocal.height),
                child: manager.buildWidgetByID(
                  props.topAppBarPlaceholderId!,
                  context,
                  settings: settings,
                ))
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

    body = FittedBox(
      fit: BoxFit.fitWidth,
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: node.outerBoxLocal.width,
        height: node.outerBoxLocal.height,
        child: body,
      ),
    );

    if (node.constraints.maxWidth != null) {
      body = Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: node.resolvedConstraints.maxWidth!),
              child: body,
            ),
          ),
        ],
      );
    }

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

    // For auto scaling:
    //
    // width: Always expanding because the layout should grow to fit the screen
    // horizontally always, not just when shrinking and the FittedBox that
    // does the auto-scaling has a BoxFit.fitWidth.
    //
    // height: Only expand vertically if the layout is scrollable and vertical.
    // That means the canvas fills are expanded to fill the viewport and the
    // content is scrollable inside without being cut off. However, if the
    // layout is not scrollable vertically and the canvas is shrink-wrapping,
    // we set height to null to allow it to shrink-wrap.
    body = SizedBox(
      width: double.infinity,
      height: node.isScrollable && node.scrollDirection.isVertical
          ? double.infinity
          : null,
      child: body,
    );

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
        child: !node.isScrollable
            ? Align(alignment: Alignment.topCenter, child: body)
            : body,
      );
    }

    return manager.getTransformer<PassiveRectangleTransformer>().buildRectangle(
          node,
          children: [scaffold],
          settings: settings,
        );
  }

  void onFaBPressed(BuildContext context, CanvasNode node) {
    FunctionsRepository.triggerAction(
        context,
        node: node,
        TriggerType.click,
        reactions: node.properties.floatingActionButton?.reactions);
  }

  @override
  Widget buildWidget(
    CanvasNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
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
