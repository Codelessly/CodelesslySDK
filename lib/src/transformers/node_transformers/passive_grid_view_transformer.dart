import 'dart:core';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

class PassiveGridViewTransformer extends NodeWidgetTransformer<GridViewNode> {
  PassiveGridViewTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
      GridViewNode node, BuildContext context, WidgetBuildSettings settings) {
    return PassiveGridViewWidget(
      node: node,
      manager: manager,
      settings: settings,
    );
  }
}

class PassiveGridViewWidget extends StatelessWidget {
  final GridViewNode node;
  final NodeTransformerManager manager;
  final WidgetBuildSettings settings;

  const PassiveGridViewWidget({
    super.key,
    required this.node,
    required this.manager,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    if (node.children.isEmpty) {
      return AdaptiveNodeBox(node: node, child: const SizedBox());
    }
    final itemNode = node.children.first;

    final List? data = PropertyValueDelegate.getVariableValueFromPath<List>(
          node.variables['data'] ?? '',
          scopedValues: ScopedValues.of(context),
        ) ??
        (node.variables['data'] != null ? [] : null);

    final int? itemCount;
    if (settings.isPreview) {
      itemCount = node.properties.itemCount ?? data?.length;
    } else {
      itemCount = data?.length ?? node.properties.itemCount;
    }

    return AdaptiveNodeBox(
      node: node,
      child: GridViewBuilder(
        primary: node.primary,
        gridDelegate: node.properties.gridDelegate,
        shrinkWrap: node.properties.itemCount != null &&
            (node.scrollDirection == AxisC.horizontal
                ? node.isHorizontalWrap
                : node.isVerticalWrap),
        itemCount: itemCount,
        padding: node.padding.flutterEdgeInsets,
        keyboardDismissBehavior:
            node.keyboardDismissBehavior.flutterKeyboardDismissBehavior,
        physics: node.physics.flutterScrollPhysics(node.shouldAlwaysScroll),
        scrollDirection: node.scrollDirection.flutterAxis,
        cacheExtent: node.properties.cacheExtent,
        reverse: node.reverse,
        clipBehavior: node.clipsContent ? Clip.hardEdge : Clip.none,
        itemBuilder: (context, index) => IndexedItemProvider(
          key: ValueKey(index),
          item: IndexedItem(index, data?.elementAtOrNull(index)),
          child: Builder(builder: (context) {
            // This builder is important to pass a context that has
            // the IndexedItemProvider.
            return KeyedSubtree(
              key: ValueKey(index),
              child: manager.buildWidgetByID(
                itemNode,
                context,
                settings: settings,
              ),
            );
          }),
        ),
      ),
    );
  }
}

class GridViewBuilder extends StatelessWidget {
  final bool shrinkWrap;
  final int? itemCount;
  final EdgeInsets? padding;
  final ScrollPhysics? physics;
  final Axis scrollDirection;
  final double? cacheExtent;
  final bool reverse;
  final bool primary;
  final Clip clipBehavior;
  final IndexedWidgetBuilder? itemBuilder;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final GridDelegateProperties gridDelegate;

  const GridViewBuilder({
    super.key,
    required this.shrinkWrap,
    required this.gridDelegate,
    this.itemCount,
    this.padding,
    this.physics,
    required this.scrollDirection,
    this.cacheExtent,
    required this.reverse,
    required this.clipBehavior,
    this.itemBuilder,
    this.primary = false,
    required this.keyboardDismissBehavior,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      primary: primary,
      shrinkWrap: shrinkWrap,
      itemCount: itemCount,
      padding: padding,
      physics: physics,
      scrollDirection: scrollDirection,
      cacheExtent: cacheExtent,
      reverse: reverse,
      clipBehavior: clipBehavior,
      itemBuilder: itemBuilder!,
      keyboardDismissBehavior: keyboardDismissBehavior,
      gridDelegate: switch (gridDelegate) {
        FixedCrossAxisCountGridDelegateProperties props =>
          SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: props.crossAxisCount,
            crossAxisSpacing: props.crossAxisSpacing,
            mainAxisSpacing: props.mainAxisSpacing,
            childAspectRatio: props.childAspectRatio,
            mainAxisExtent: props.mainAxisExtent,
          ),
        MaxCrossAxisExtentGridDelegateProperties props =>
          SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: props.maxCrossAxisExtent,
            mainAxisExtent: props.mainAxisExtent,
            childAspectRatio: props.childAspectRatio,
            crossAxisSpacing: props.crossAxisSpacing,
            mainAxisSpacing: props.mainAxisSpacing,
          ),
      },
    );
  }
}
