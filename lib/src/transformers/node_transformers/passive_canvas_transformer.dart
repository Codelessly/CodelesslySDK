import 'dart:async';

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

    final NodeWidgetTransformer<BaseNode> transformer =
        manager.getTransformerByNode(appBarNode);

    if (transformer is PassiveAppBarTransformer) {
      final Widget appBarChild = manager.buildWidgetFromNode(
        appBarNode as AppBarNode,
        context,
        settings: settings.copyWith(
          // Passes through to build a PreferredSizeWidget directly.
          buildRawWidget: true,
        ),
      );

      assert(
        appBarChild is PreferredSizeWidget,
        'PassiveAppBarTransformer must return a PreferredSizeWidget',
      );

      return appBarChild as PreferredSizeWidget;
    } else {
      final Widget appBarChild = manager.buildWidgetFromNode(
        appBarNode,
        context,
        settings: settings,
      );

      return PreferredSize(
        preferredSize:
            Size.fromHeight(appBarPlaceholderNode.outerBoxLocal.height),
        child: SafeArea(child: appBarChild),
      );
    }
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
            // This would make it so auto scale layouts are top-center aligned
            // in the viewport. But this doesn't work if the layout is inside a
            // dialog. it will force it to top-center align in the dialog
            // which is not what we want.
            // ? Align(alignment: Alignment.topCenter, child: body)
            ? body
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

  /// This would not work if the canvas is expected to have 2 different forms.
  /// For that to work, a custom Form node is required. However, that's rarely
  /// the case most of the time, so this should work for most cases!
  Widget wrapWithFormAndAutofill({
    required CanvasNode node,
    required Widget child,
    required WidgetBuildSettings settings,
  }) {
    final Widget widget = Form(child: child);
    if (settings.isPreview) return widget;
    return AutofillGroup(
      key: ValueKey('autofill-group-${node.id}'),
      child: widget,
    );
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
      builder: (context) => wrapWithFormAndAutofill(
        node: node,
        settings: settings,
        child: switch (node.scaleMode) {
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
      ),
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
  late List<ActionModel> onLoadActions = collectOnLoadActions();

  // StreamSubscription? _subscription;

  bool didPerformOnLoadActions = false;

  @override
  void didUpdateWidget(covariant PassiveCanvasWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.node != oldWidget.node) {
      onLoadActions = collectOnLoadActions();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.settings.isPreview) return;

    if (didPerformOnLoadActions) return;
    didPerformOnLoadActions = true;

    triggerOnLoadActions(context);

    // _subscription?.cancel();
    // _subscription = context
    //     .read<Codelessly>()
    //     .dataManager
    //     .publishModelStream
    //     .listen((event) {
    //   logger.log('PassiveCanvasWidget',
    //       'Received publish event for canvas ${widget.node.id}');
    //   triggerOnLoadActions(context);
    // });
  }

  List<ActionModel> collectOnLoadActions() => widget.node.reactions
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

  void triggerOnLoadActions(BuildContext context) {
    if (onLoadActions.isEmpty) {
      logger.log('PassiveCanvasWidget',
          'No onLoad actions found for canvas ${widget.node.id}');
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
