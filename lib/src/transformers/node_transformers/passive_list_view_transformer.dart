import 'dart:core';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';
import '../../logging/error_logger.dart';
import '../../ui/draggable_scroll_configuration.dart';

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

  Query<Map<String, dynamic>> constructQuery(
      BuildContext context, Codelessly codelessly) {
    final PublishSource source =
        codelessly.config?.publishSource ?? PublishSource.preview;

    final String collectionPath = node.collectionPath ?? '';

    Query<Map<String, dynamic>> query = codelessly.firebaseFirestore.collection(
      '${source.rootDataCollection}/${codelessly.authManager.authData!.projectId}/$collectionPath',
    );

    return constructQueryFromRef(
      query,
      whereFilters: node.whereFilters,
      orderByOperations: node.orderByFilters,
      scopedValues: ScopedValues.of(context),
      nullSubstitutionMode: settings.nullSubstitutionMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (node.children.isEmpty) {
      return AdaptiveNodeBox(node: node, child: const SizedBox());
    }
    final itemNode = node.children.first;

    final bool useCloudDatabase = node.useCloudDatabase;

    if (useCloudDatabase && !settings.isPreview) {
      final codelessly = context.read<Codelessly>();
      final codelesslyController = context.read<CodelesslyWidgetController>();

      if (codelessly.authManager.authData == null) {
        return codelesslyController.loadingBuilder?.call(context) ??
            const Center(child: CircularProgressIndicator());
      }

      final query = constructQuery(context, codelessly);

      return AdaptiveNodeBox(
        node: node,
        child: FirestoreQueryBuilder<Map<String, dynamic>>(
          query: query,
          pageSize: node.limit ?? 20,
          builder: (context, snapshot, child) {
            if (snapshot.isFetching) {
              return codelesslyController.loadingBuilder?.call(context) ??
                  const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return codelesslyController.errorBuilder?.call(
                    context,
                    ErrorLog(
                      timestamp: DateTime.now(),
                      message: snapshot.error?.toString() ?? 'Unknown error',
                      type: 'firestore_query_error',
                    ),
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
                    {if (id != null) 'id': id, ...?data},
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

    // If this ListView is inside another scrollable, Flutter will crash
    // if shrinkWrap is false in order to enforce this ListView to take
    // up its own space by itself since it will be inside an unbounded space.
    // This statement remains true even if this inner ListView is wrapped with
    // SizedBoxes and nested deeply inside other widgets, Flutter will crash
    // regardless unless shrinkwrap is true.
    // https://stackoverflow.com/a/54587532/4327834
    final ScrollableState? parentScrollable = Scrollable.maybeOf(context);

    final bool shrinkWrap = parentScrollable != null
        ? true
        : node.properties.itemCount != null &&
            (node.scrollDirection == AxisC.horizontal
                ? node.isHorizontalWrap
                : node.isVerticalWrap);

    return AdaptiveNodeBox(
      node: node,
      child: ListViewBuilder(
        primary: node.primary,
        shrinkWrap: shrinkWrap,
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
    required this.scrollDirection,
    required this.reverse,
    required this.clipBehavior,
    required this.keyboardDismissBehavior,
    this.itemCount,
    this.padding,
    this.physics,
    this.cacheExtent,
    this.itemExtent,
    this.itemBuilder,
    this.separatedBuilder,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollConfiguration(
      child: Builder(
        builder: (context) {
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
        },
      ),
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
