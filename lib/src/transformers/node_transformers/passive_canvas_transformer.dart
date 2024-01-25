import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/functions_repository.dart';

class PassiveCanvasTransformer extends NodeWidgetTransformer<CanvasNode> {
  PassiveCanvasTransformer(super.getNode, super.manager);

  static List<String> getBodyChildren(CanvasNode node) =>
      [...node.childrenOrEmpty]
        ..remove(node.properties.topAppBarPlaceholderId)
        ..remove(node.properties.navigationBarPlaceholderId);

  PreferredSizeWidget? getAppBar(
    BuildContext context,
    CanvasNode node,
    WidgetBuildSettings settings,
  ) {
    if (node.properties.topAppBarPlaceholderId == null) return null;
    SinglePlaceholderNode appBarPlaceholderNode =
        getNode(node.properties.topAppBarPlaceholderId!)
            as SinglePlaceholderNode;
    final childId = appBarPlaceholderNode.childrenOrEmpty.firstOrNull;
    if (childId == null) return null;

    final BaseNode appBarNode = getNode(childId);

    Widget? appBarChild = manager.buildWidgetByID(
      appBarPlaceholderNode.id,
      context,
      settings: settings,
    );

    if (appBarNode is! AppBarNode) {
      // wrap with SafeArea if not an AppBarNode.
      appBarChild = SafeArea(child: appBarChild);
    }

    return PreferredSize(
      preferredSize:
          Size.fromHeight(appBarPlaceholderNode.outerBoxLocal.height),
      child: SafeArea(child: appBarChild),
    );
  }

  Widget? getNavigationBar(
    BuildContext context,
    CanvasNode node,
    WidgetBuildSettings settings,
  ) {
    if (node.properties.navigationBarPlaceholderId == null) return null;
    SinglePlaceholderNode navigationBarPlaceholderNode =
        getNode(node.properties.navigationBarPlaceholderId!)
            as SinglePlaceholderNode;

    if (navigationBarPlaceholderNode.childrenOrEmpty.isEmpty) return null;

    final navigationBarNode =
        getNode(navigationBarPlaceholderNode.childrenOrEmpty.first);

    Widget navBar = manager.buildWidgetByID(
      node.properties.navigationBarPlaceholderId!,
      context,
      settings: settings,
    );

    if (navigationBarNode is! NavigationBarNode) {
      navBar = SafeArea(child: navBar);
    }

    return navBar;
  }

  Widget? getFAB(
    BuildContext context,
    CanvasNode node,
    WidgetBuildSettings settings,
  ) {
    if (node.properties.floatingActionButton == null) return null;
    return PassiveFloatingActionButtonWidget.buildFAB(
      node.id,
      node.properties.floatingActionButton!,
      useFonts: false,
      onPressed: () => onFaBPressed(context, node),
    );
  }

  Widget wrapWithSafeArea(SafeAreaModel safeArea, Widget body) {
    if (!safeArea.enabled) return body;
    return SafeArea(
      left: safeArea.left,
      top: safeArea.top,
      right: safeArea.right,
      bottom: safeArea.bottom,
      child: body,
    );
  }

  Widget _wrapInScaffoldForResponsive({
    required CanvasNode node,
    required BuildContext context,
    required WidgetBuildSettings settings,
  }) {
    final CanvasProperties props = node.properties;

    PreferredSizeWidget? appBar = getAppBar(context, node, settings);
    Widget? bottomNavigationBar = getNavigationBar(context, node, settings);
    Widget? floatingActionButton = getFAB(context, node, settings);

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
        physics: node.physics.flutterScrollPhysics(node.shouldAlwaysScroll),
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

    body = wrapWithSafeArea(props.safeArea, body);

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
    required WidgetBuildSettings settings,
  }) {
    final CanvasProperties props = node.properties;
    final BaseNode placeholderBody = getNode(node.properties.bodyId);
    Widget body = manager.buildWidgetFromNode(
      placeholderBody,
      context,
      settings: settings,
    );

    PreferredSizeWidget? appBar = getAppBar(context, node, settings);
    Widget? bottomNavigationBar = getNavigationBar(context, node, settings);
    Widget? floatingActionButton = getFAB(context, node, settings);

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
        physics: node.physics.flutterScrollPhysics(node.shouldAlwaysScroll),
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

    body = wrapWithSafeArea(props.safeArea, body);

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
    return PassiveCanvasWidget(
      node: node,
      settings: settings,
      builder: (context) => switch (node.scaleMode) {
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
      },
    );
  }

  static Color? retrieveBackgroundColor(BuildContext context, CanvasNode node) {
    final fills = <PaintModel>[
      for (final fill in node.fills)
        PropertyValueDelegate.getPropertyValue(
              node,
              'fill-${fill.id}',
              scopedValues: ScopedValues.of(context),
            ) ??
            fill
    ];
    if (fills.length == 1 &&
        fills[0].type == PaintType.solid &&
        fills[0].visible) {
      return fills[0].color?.toFlutterColor(opacity: fills[0].opacity);
    }
    return Colors.transparent;
  }
}

class PassiveCanvasWidget extends StatefulWidget {
  final CanvasNode node;
  final WidgetBuildSettings settings;
  final WidgetBuilder builder;

  const PassiveCanvasWidget({
    super.key,
    required this.node,
    required this.settings,
    required this.builder,
  });

  @override
  State<PassiveCanvasWidget> createState() => _PassiveCanvasWidgetState();
}

class _PassiveCanvasWidgetState extends State<PassiveCanvasWidget> {
  bool shouldPerformOnLoadActions = true;

  StreamSubscription? _subscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (shouldPerformOnLoadActions) {
      shouldPerformOnLoadActions = false;
      if (widget.settings.isPreview) return;

      triggerOnLoadActions(context);

      _subscription?.cancel();
      _subscription = context
          .read<Codelessly>()
          .dataManager
          .publishModelStream
          .listen((event) {
        logger.log('PassiveCanvasWidget',
            'Received publish event for canvas ${widget.node.id}');
        triggerOnLoadActions(context);
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void triggerOnLoadActions(BuildContext context) {
    logger.log('PassiveCanvasWidget',
        'Checking for onLoad actions on canvas ${widget.node.id}');
    // perform onLoad actions. This must always be the last step in this method.
    final onLoadActions = widget.node.reactions
        .whereTriggerType(TriggerType.load)
        .map((e) => e.action)
        .where((action) =>
            action.enabled &&
            // Because calling api is handled in LayoutBuilder.
            action.type != ActionType.callApi &&
            action.type != ActionType.navigation &&
            action.type != ActionType.submit &&
            action.type != ActionType.link)
        .toList();

    if (onLoadActions.isEmpty) {
      logger.log('PassiveCanvasWidget',
          'No onLoad actions found for canvas ${widget.node.id}');
      return;
    }

    logger.log('PassiveCanvasWidget', 'Performing actions on canvas load');
    executeActionAt(0, onLoadActions);
  }

  void executeActionAt(int index, List<ActionModel> actions) {
    if (index >= actions.length) return;

    final action = actions[index];
    final future = FunctionsRepository.performAction(
      context,
      action,
      notify: false,
    );

    if (future is! Future || action.nonBlocking) {
      executeActionAt(index + 1, actions);
    } else {
      future.whenComplete(() => executeActionAt(index + 1, actions));
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
