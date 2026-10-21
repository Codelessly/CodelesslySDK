import 'dart:core';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';
import '../../ui/cloud_query_builder.dart';
import '../../ui/draggable_scroll_configuration.dart';

class PassiveListViewTransformer extends NodeWidgetTransformer<ListViewNode> {
  PassiveListViewTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    ListViewNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
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

  /// The collection and query of the node, or null when the signed-out user
  /// may not read any of it.
  ({Query<Map<String, dynamic>> ref, CloudQuery query})? constructQuery(
    BuildContext context,
    Codelessly codelessly,
  ) {
    final PublishSource source =
        codelessly.config?.publishSource ?? PublishSource.preview;

    final String collectionPath = node.collectionPath ?? '';

    final Query<Map<String, dynamic>>
    ref = codelessly.firebaseFirestore.collection(
      '${source.rootDataCollection}/${codelessly.authManager.authData!.projectId}/$collectionPath',
    );

    // Owner-only collections only return the signed-in user's documents.
    final CloudDatabase? database = codelessly.cloudDatabase;
    final List<CloudWhereFilter>? readFilters = database == null
        ? const []
        : database.rules.readFilters(collectionPath, database.currentUserId());
    if (readFilters == null) return null;

    return (
      ref: ref,
      query: resolveCloudQuery(
        baseFilters: readFilters,
        whereFilters: node.whereFilters,
        orderByOperations: node.orderByFilters,
        scopedValues: ScopedValues.of(context),
        nullSubstitutionMode: settings.nullSubstitutionMode,
      ),
    );
  }

  /// Sizes the list by [ViewportLayout] around [builder].
  Widget box(ViewportContentBuilder builder, {required bool canShrinkWrap}) =>
      ViewportNodeBox(
        node: node,
        scrollDirection: node.scrollDirection,
        canShrinkWrap: canShrinkWrap,
        builder: builder,
      );

  /// Builds one item, placed as the editor lays it out; see [ListItemBox].
  Widget buildItem(BaseNode item, BuildContext context) => ListItemBox(
    item: item,
    scrollDirection: node.scrollDirection,
    itemExtent: node.properties.itemExtent,
    child: manager.buildWidgetByID(item.id, context, settings: settings),
  );

  @override
  Widget build(BuildContext context) {
    if (node.children.isEmpty) {
      return box(canShrinkWrap: true, (context, _) => const SizedBox());
    }
    final itemNode = node.children.first;
    final BaseNode item = manager.getNode(itemNode);

    final bool useCloudDatabase = node.useCloudDatabase;

    if (useCloudDatabase && !settings.isPreview) {
      final codelessly = context.read<Codelessly>();
      final codelesslyController = context.read<CodelesslyWidgetController>();

      if (codelessly.authManager.authData == null) {
        return box(
          canShrinkWrap: true,
          (context, _) =>
              codelesslyController.loadingBuilder?.call(context) ??
              const Center(child: CircularProgressIndicator()),
        );
      }

      final query = constructQuery(context, codelessly);
      if (query == null) {
        return box(
          canShrinkWrap: true,
          (context, _) => const SizedBox.shrink(),
        );
      }

      // A loaded query always has a known length, so it can shrink-wrap.
      return box(
        canShrinkWrap: true,
        (context, shrinkWrap) => CloudQueryBuilder(
          ref: query.ref,
          query: query.query,
          pageSize: node.limit ?? 20,
          builder: (context, snapshot, child) {
            if (snapshot.isFetching) {
              return codelesslyController.loadingBuilder?.call(context) ??
                  const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              final String message = describeCloudError(snapshot.error);
              DebugLogger.instance.printInfo(
                'Could not load ${node.collectionPath}: $message',
                name: node.type,
              );
              return codelesslyController.errorBuilder?.call(
                    context,
                    ErrorLog(
                      timestamp: DateTime.now(),
                      message: message,
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
              shrinkWrap: shrinkWrap,
              itemCount: itemCount,
              padding: node.padding.flutterEdgeInsets,
              keyboardDismissBehavior:
                  node.keyboardDismissBehavior.flutterKeyboardDismissBehavior,
              physics: node.physics.flutterScrollPhysics(
                node.shouldAlwaysScroll,
              ),
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
                // Load the next page when the last loaded item shows.
                if (index == itemCount - 1 &&
                    snapshot.hasMore &&
                    !snapshot.isFetchingMore) {
                  snapshot.fetchMore();
                }
                final doc = docs.elementAtOrNull(index);
                final id = doc?.id;
                final data = doc?.data();
                return IndexedItemProvider(
                  key: ValueKey(index),
                  item: IndexedItem(index, {'id': ?id, ...?data}),
                  child: Builder(
                    builder: (context) {
                      // This builder is important to pass a context that has
                      // the IndexedItemProvider.
                      return KeyedSubtree(
                        key: ValueKey(index),
                        child: buildItem(item, context),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      );
    }

    final List? data =
        PropertyValueDelegate.getVariableValueFromPath<List>(
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

    Widget itemBuilder(BuildContext context, int index) => IndexedItemProvider(
      key: ValueKey(index),
      item: IndexedItem(index, data?.elementAtOrNull(index)),
      child: Builder(
        builder: (context) {
          // This builder is important to pass a context that has
          // the IndexedItemProvider.
          return KeyedSubtree(
            key: ValueKey(index),
            child: buildItem(item, context),
          );
        },
      ),
    );

    Widget list(
      bool shrinkWrap,
      int? itemCount,
      NullableIndexedWidgetBuilder builder,
    ) => ListViewBuilder(
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
      separatedBuilder:
          (node.properties.itemCount != null || data != null) &&
              node.properties.hasSeparator
          ? (context, index) => ListViewItemSeparator(
              scrollDirection: node.scrollDirection,
              properties: node.properties,
            )
          : null,
      itemBuilder: builder,
    );

    // An endless list with items of free extent ends after a viewport's
    // worth of items that take no space, so they cannot be built without
    // limit; see [EndlessList]. A fixed item extent is bounded by Flutter.
    if (itemCount == null && node.properties.itemExtent == null) {
      final Axis axis = node.scrollDirection.flutterAxis;
      return box(
        canShrinkWrap: false,
        (context, _) => EndlessList(
          axis: axis,
          estimatedItemExtent: node.scrollDirection == AxisC.vertical
              ? item.outerBoxLocal.height
              : item.outerBoxLocal.width,
          cacheExtent:
              node.properties.cacheExtent ??
              RenderAbstractViewport.defaultCacheExtent,
          builder: (context, endsAt, extents) => list(
            false,
            null,
            (context, index) => endsAt(index)
                ? null
                : ItemExtentReporter(
                    extents: extents,
                    index: index,
                    axis: axis,
                    child: itemBuilder(context, index),
                  ),
          ),
        ),
      );
    }

    // Nested in another scroll view, the list is bounded by its own fit or
    // shrink-wraps; see [ViewportLayout].
    return box(
      canShrinkWrap: itemCount != null,
      (context, shrinkWrap) => list(shrinkWrap, itemCount, itemBuilder),
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
  final NullableIndexedWidgetBuilder? itemBuilder;
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
              scrollCacheExtent: cacheExtent == null
                  ? null
                  : ScrollCacheExtent.pixels(cacheExtent!),
              reverse: reverse,
              clipBehavior: clipBehavior,
              itemBuilder: (context, index) => itemBuilder!(context, index)!,
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
            scrollCacheExtent: cacheExtent == null
                ? null
                : ScrollCacheExtent.pixels(cacheExtent!),
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
          width: scrollDirection.isHorizontal
              ? properties.separatorSpacing
              : null,
          height: scrollDirection.isVertical
              ? properties.separatorSpacing
              : null,
        );
    }
  }
}
