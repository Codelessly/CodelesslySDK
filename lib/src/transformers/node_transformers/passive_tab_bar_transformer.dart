import 'dart:math';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/functions_repository.dart';

class PassiveTabBarTransformer extends NodeWidgetTransformer<TabBarNode> {
  PassiveTabBarTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    TabBarNode node,
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    return buildFromNode(context, node, settings: settings);
  }

  Widget buildFromProps(
    BuildContext context, {
    required TabBarProperties props,
    required double height,
    required double width,
  }) {
    final node = TabBarNode(
      id: '',
      name: 'tabBar',
      basicBoxLocal: NodeBox(0, 0, width, height),
      alignment: AlignmentModel.none,
      properties: props,
    );
    return buildFromNode(context, node, settings: WidgetBuildSettings());
  }

  Widget buildPreview({
    TabBarProperties? properties,
    TabBarNode? node,
    double? height,
    double? width,
  }) {
    final previewNode = TabBarNode(
      properties: properties ?? node?.properties ?? TabBarProperties(),
      id: '',
      name: 'tabBar',
      basicBoxLocal: NodeBox(
          0, 0, width ?? 32, height ?? node?.basicBoxLocal.height ?? 56),
      retainedOuterBoxLocal: NodeBox(
          0, 0, width ?? 32, height ?? node?.basicBoxLocal.height ?? 56),
      initialIndex: node?.initialIndex ?? 0,
      isScrollable: node?.isScrollable ?? false,
      physics: node?.physics ?? ScrollPhysicsC.alwaysScrollableScrollPhysics,
    );
    return PassiveTabBarWidget(
      node: previewNode,
      settings: WidgetBuildSettings(),
    );
  }

  Widget buildFromNode(
    BuildContext context,
    TabBarNode node, {
    required WidgetBuildSettings settings,
  }) {
    return PassiveTabBarWidget(
      node: node,
      settings: settings,
      onChanged: (index) => onChanged(context, node, index),
    );
  }

  void onChanged(BuildContext context, TabBarNode node, int index) {
    final tab = node.properties.tabs[index];
    tab.reactions.forEach((reaction) {
      FunctionsRepository.performAction(context, reaction.action);
    });
  }
}

class PassiveTabBarWidget extends StatefulWidget {
  final TabBarNode node;
  final WidgetBuildSettings settings;
  final bool useIconFonts;
  final ValueChanged<int>? onChanged;

  const PassiveTabBarWidget({
    super.key,
    required this.node,
    required this.settings,
    this.useIconFonts = false,
    this.onChanged,
  });

  @override
  State<PassiveTabBarWidget> createState() => _PassiveTabBarWidgetState();
}

class _PassiveTabBarWidgetState extends State<PassiveTabBarWidget>
    with TickerProviderStateMixin {
  late TabController controller;

  late int initialIndex;
  late int length;

  @override
  void initState() {
    super.initState();
    initialIndex = widget.node.initialIndex;
    length = widget.node.properties.tabs.length;
    controller = TabController(
      length: widget.node.properties.tabs.length,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void didUpdateWidget(covariant PassiveTabBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (initialIndex != widget.node.initialIndex ||
        length != widget.node.properties.tabs.length) {
      controller.dispose();
      initialIndex = widget.node.initialIndex;
      length = widget.node.properties.tabs.length;
      controller = TabController(
        length: widget.node.properties.tabs.length,
        vsync: this,
        initialIndex: initialIndex,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width =
        widget.node.isHorizontalExpanded || widget.node.isHorizontalWrap
            ? null
            : widget.node.basicBoxLocal.width;
    final height = widget.node.isVerticalExpanded || widget.node.isVerticalWrap
        ? null
        : widget.node.basicBoxLocal.height;

    final TextStyle labelStyle =
        PassiveTextTransformer.retrieveTextStyleFromProp(
            widget.node.properties.labelStyle);

    final TextStyle unselectedLabelStyle =
        PassiveTextTransformer.retrieveTextStyleFromProp(
            widget.node.properties.unselectedLabelStyle);

    final Decoration? indicator = getIndicator();

    return SizedBox(
      width: width,
      height: height,
      child: Theme(
        data: Theme.of(context)
            .copyWith(useMaterial3: widget.node.properties.showDivider),
        child: TabBar(
          controller: controller,
          padding: widget.node.padding.flutterEdgeInsets,
          overlayColor: MaterialStateProperty.all(
              widget.node.properties.overlayColor?.toFlutterColor()),
          dividerColor: widget.node.properties.dividerColor?.toFlutterColor(),
          indicatorColor:
              widget.node.properties.indicatorColor.toFlutterColor(),
          indicatorPadding:
              widget.node.properties.indicatorPadding.flutterEdgeInsets,
          indicatorSize: widget.node.properties.indicatorSize.toFlutter(),
          isScrollable: widget.node.isScrollable,
          indicatorWeight:
              indicator != null ? 0 : widget.node.properties.indicatorWeight,
          labelStyle: labelStyle,
          indicator: indicator,
          splashBorderRadius:
              widget.node.properties.indicatorCornerRadius.borderRadius,
          splashFactory: NoSplash.splashFactory,
          labelColor: widget.node.properties.labelColor?.toFlutterColor(),
          labelPadding: widget.node.properties.labelPadding.flutterEdgeInsets,
          unselectedLabelColor:
              widget.node.properties.unselectedLabelColor?.toFlutterColor(),
          unselectedLabelStyle: unselectedLabelStyle,
          physics: widget.node.physics.flutterScrollPhysics,
          onTap: widget.onChanged,
          tabs: [
            for (final tab in widget.node.properties.tabs) getTab(context, tab)
          ],
        ),
      ),
    );
  }

  Widget getTab(BuildContext context, TabItem tab) {
    final String rawLabel = PropertyValueDelegate.getPropertyValue<String>(
            context, widget.node, 'tab-label-${tab.id}') ??
        tab.label;

    String label = PropertyValueDelegate.substituteVariables(context, rawLabel);
    final double effectiveIconSize =
        min(tab.icon.size ?? 24, widget.node.basicBoxLocal.height);

    Widget? iconWidget = widget.node.properties.contentType.showIcon
        ? retrieveIconWidget(tab.icon, effectiveIconSize, widget.useIconFonts)
        : null;

    if (iconWidget == null) return Tab(text: label);

    if (!widget.node.properties.contentType.showLabel) {
      return Tab(icon: iconWidget);
    }

    if (widget.node.properties.tabItemDirection == AxisC.vertical) {
      // can use text and icon property of the Tab.
      return Tab(
        text: label,
        icon: iconWidget,
        iconMargin: EdgeInsets.only(bottom: widget.node.properties.gap),
      );
    }

    return Tab(
      height: widget.node.basicBoxLocal.height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          SizedBox(width: widget.node.properties.gap),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }

  Decoration? getIndicator() {
    switch (widget.node.properties.indicatorStyle) {
      case TabIndicatorStyle.underline:
        return UnderlineTabIndicator(
          borderRadius:
              widget.node.properties.indicatorCornerRadius.borderRadius,
          borderSide: BorderSide(
            color: widget.node.properties.indicatorColor.toFlutterColor(),
            width: widget.node.properties.indicatorWeight,
          ),
        ).orNullIf(widget.node.properties.indicatorCornerRadius.isUniform &&
            widget.node.properties.indicatorCornerRadius == CornerRadius.zero);
      case TabIndicatorStyle.filled:
        return ShapeDecoration(
          color: widget.node.properties.indicatorColor.toFlutterColor(),
          shape: getShape(
            shape: widget.node.properties.indicatorShape,
            radius: widget.node.properties.indicatorCornerRadius,
            borderColor: widget.node.properties.indicatorColor,
            borderWidth: widget.node.properties.indicatorStyle ==
                    TabIndicatorStyle.border
                ? widget.node.properties.indicatorWeight
                : 0,
          ),
        );
      case TabIndicatorStyle.border:
        return ShapeDecoration(
          shape: getShape(
            shape: widget.node.properties.indicatorShape,
            radius: widget.node.properties.indicatorCornerRadius,
            borderColor: widget.node.properties.indicatorColor,
            borderWidth: widget.node.properties.indicatorStyle ==
                    TabIndicatorStyle.border
                ? widget.node.properties.indicatorWeight
                : 0,
          ),
        );
      case TabIndicatorStyle.none:
        return BoxDecoration();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}