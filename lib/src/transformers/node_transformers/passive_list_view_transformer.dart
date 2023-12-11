import 'dart:core';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';

class PassiveListViewTransformer extends NodeWidgetTransformer<ListViewNode> {
  PassiveListViewTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
      ListViewNode node, BuildContext context, WidgetBuildSettings settings) {
    return PassiveListViewWidget(
      node: node,
      manager: manager,
      settings: settings,
    );
  }
}

class PassiveListViewWidget extends StatelessWidget {
  final ListViewNode node;
  final NodeTransformerManager manager;
  final WidgetBuildSettings settings;

  const PassiveListViewWidget({
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

    final bool useCloudDatabase = node.properties.useCloudDatabase;

    if (useCloudDatabase) {
      final String? collectionPath = node.properties.collectionPath;

      final codelessly = context.read<Codelessly>();
      final codelesslyController = context.read<CodelesslyWidgetController>();

      if (codelessly.authManager.authData == null) {
        return codelesslyController.loadingBuilder?.call(context) ??
            const Center(child: CircularProgressIndicator());
      }

      final PublishSource source =
          codelessly.config?.publishSource ?? PublishSource.preview;
      final query = codelessly.firebaseFirestore.collection(
        '${source.rootDataCollection}/${codelessly.authManager.authData!.projectId}/$collectionPath',
      );

      return AdaptiveNodeBox(
        node: node,
        child: FirestoreQueryBuilder<Map<String, dynamic>>(
          query: query,
          builder: (context,
              FirestoreQueryBuilderSnapshot<Map<String, dynamic>> snapshot,
              child) {
            if (snapshot.isFetching) {
              return codelesslyController.loadingBuilder?.call(context) ??
                  const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return codelesslyController.errorBuilder?.call(
                    context,
                    snapshot.error,
                  ) ??
                  const Center(child: Text('Error'));
            }

            final List<QueryDocumentSnapshot<Map>> docs = snapshot.docs;
            final itemCount = docs.length;

            // Item Count always exists.
            return ListViewBuilder(
              primary: node.primary,
              shrinkWrap: (node.scrollDirection == AxisC.horizontal
                  ? node.isHorizontalWrap
                  : node.isVerticalWrap),
              itemCount: itemCount,
              padding: node.padding.flutterEdgeInsets,
              keyboardDismissBehavior:
                  node.keyboardDismissBehavior.flutterKeyboardDismissBehavior,
              physics:
                  node.physics.flutterScrollPhysics(node.shouldAlwaysScroll),
              scrollDirection: node.scrollDirection.flutterAxis,
              cacheExtent: node.properties.cacheExtent,
              reverse: node.reverse,
              itemExtent: node.properties.itemExtent,
              clipBehavior: node.clipsContent ? Clip.hardEdge : Clip.none,
              separatedBuilder: node.properties.hasSeparator
                  ? (context, index) => ListViewItemSeparator(
                        scrollDirection: node.scrollDirection,
                        properties: node.properties,
                      )
                  : null,
              itemBuilder: (context, index) {
                final doc = docs.elementAtOrNull(index);
                final id = doc?.id;
                final data = doc?.data();
                return IndexedItemProvider(
                  key: ValueKey(index),
                  item: IndexedItem(
                    index,
                    {
                      if (id != null) 'id': id,
                      ...?data,
                    },
                  ),
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
                );
              },
            );
          },
        ),
      );
    }

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
      child: ListViewBuilder(
        primary: node.primary,
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
        itemExtent: node.properties.itemExtent,
        clipBehavior: node.clipsContent ? Clip.hardEdge : Clip.none,
        separatedBuilder: (node.properties.itemCount != null || data != null) &&
                node.properties.hasSeparator
            ? (context, index) => ListViewItemSeparator(
                  scrollDirection: node.scrollDirection,
                  properties: node.properties,
                )
            : null,
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

class ListViewBuilder extends StatelessWidget {
  final bool shrinkWrap;
  final int? itemCount;
  final EdgeInsets? padding;
  final ScrollPhysics? physics;
  final Axis scrollDirection;
  final double? cacheExtent;
  final bool reverse;
  final bool primary;
  final double? itemExtent;
  final Clip clipBehavior;
  final IndexedWidgetBuilder? itemBuilder;
  final IndexedWidgetBuilder? separatedBuilder;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  const ListViewBuilder({
    super.key,
    required this.shrinkWrap,
    this.itemCount,
    this.padding,
    this.physics,
    required this.scrollDirection,
    this.cacheExtent,
    required this.reverse,
    this.itemExtent,
    required this.clipBehavior,
    this.itemBuilder,
    this.separatedBuilder,
    this.primary = false,
    required this.keyboardDismissBehavior,
  });

  @override
  Widget build(BuildContext context) {
    if (separatedBuilder != null) {
      return ListView.separated(
        primary: primary,
        shrinkWrap: shrinkWrap,
        itemCount: itemCount!,
        padding: padding,
        physics: physics,
        scrollDirection: scrollDirection,
        cacheExtent: cacheExtent,
        reverse: reverse,
        clipBehavior: clipBehavior,
        itemBuilder: itemBuilder!,
        separatorBuilder: separatedBuilder!,
        keyboardDismissBehavior: keyboardDismissBehavior,
      );
    }

    return ListView.builder(
      primary: primary,
      shrinkWrap: shrinkWrap,
      itemCount: itemCount,
      padding: padding,
      physics: physics,
      scrollDirection: scrollDirection,
      cacheExtent: cacheExtent,
      reverse: reverse,
      itemExtent: itemExtent,
      clipBehavior: clipBehavior,
      itemBuilder: itemBuilder!,
      keyboardDismissBehavior: keyboardDismissBehavior,
    );
  }
}

class ListViewItemSeparator extends StatelessWidget {
  final ListViewProperties properties;
  final AxisC scrollDirection;

  const ListViewItemSeparator({
    super.key,
    required this.properties,
    required this.scrollDirection,
  });

  @override
  Widget build(BuildContext context) {
    switch (properties.separator) {
      case ListItemSeparator.divider:
        if (scrollDirection.isHorizontal) {
          return VerticalDivider(
            width: properties.separatorSpacing,
            thickness: properties.dividerProperties.thickness,
            color: properties.dividerProperties.color.toFlutterColor(),
            indent: properties.dividerProperties.indent,
            endIndent: properties.dividerProperties.endIndent,
          );
        }
        return Divider(
          height: properties.separatorSpacing,
          thickness: properties.dividerProperties.thickness,
          color: properties.dividerProperties.color.toFlutterColor(),
          indent: properties.dividerProperties.indent,
          endIndent: properties.dividerProperties.endIndent,
        );
      case ListItemSeparator.space:
        return SizedBox(
          width:
              scrollDirection.isHorizontal ? properties.separatorSpacing : null,
          height:
              scrollDirection.isVertical ? properties.separatorSpacing : null,
        );
    }
  }
}
