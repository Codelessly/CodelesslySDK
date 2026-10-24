import 'dart:core';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';
import '../../ui/cloud_query_builder.dart';
import '../../ui/draggable_scroll_configuration.dart';

class PassiveGridViewTransformer extends NodeWidgetTransformer<GridViewNode> {
  PassiveGridViewTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    GridViewNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
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

  /// Sizes the grid by [ViewportLayout] around [builder].
  Widget box(ViewportContentBuilder builder, {required bool canShrinkWrap}) =>
      ViewportNodeBox(
        node: node,
        scrollDirection: node.scrollDirection,
        canShrinkWrap: canShrinkWrap,
        builder: builder,
      );

  @override
  Widget build(BuildContext context) {
    if (node.children.isEmpty) {
      return box(canShrinkWrap: true, (context, _) => const SizedBox());
    }
    final itemNode = node.children.first;
    // Cells of a row sized to its content stretch to the tallest one, unless
    // the item can't report its intrinsic size.
    final bool intrinsicRows = !subtreeBlocksIntrinsics(
      manager.getNode(itemNode),
      manager.getNode,
    );

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
          countTotal: node.paging == QueryPaging.button,
          readyIndexes:
              codelessly.cloudDatabase?.rules.readyIndexesFor(
                node.collectionPath ?? '',
              ) ??
              const {},
          builder: (context, snapshot, child) => ShowMorePager(
            pageSize: node.limit ?? 20,
            builder: (context, revealed, revealMore) => RelatedDocumentsLoader(
              fields: node.loadRelated,
              collectionPath: node.collectionPath ?? '',
              database: codelessly.cloudDatabase is FirestoreCloudDatabase
                  ? codelessly.cloudDatabase as FirestoreCloudDatabase
                  : null,
              docs: [
                for (final doc in snapshot.docs) {'id': doc.id, ...doc.data()},
              ],
              builder: (context, related) {
                reportQueryStatus(
                  context,
                  node.statusVariable,
                  queryStatusOf(
                    isFetching: snapshot.isFetching,
                    hasError: snapshot.hasError,
                    count: snapshot.docs.length,
                  ),
                );
                final CloudListItems items = CloudListItems(
                  snapshot: snapshot,
                  paging: node.paging,
                  revealed: revealed,
                  total: CloudQueryTotal.of(context),
                  skeleton: CloudListItems.showsSkeleton(context, snapshot),
                  revealMore: revealMore,
                  related: related,
                );
                // A layout with a status variable shows its own loading and
                // error states; a loading skeleton shows sample items.
                if (node.statusVariable != null &&
                    !items.skeleton &&
                    (snapshot.isFetching || snapshot.hasError)) {
                  return const SizedBox.shrink();
                }
                if (snapshot.isFetching && !items.skeleton) {
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

                final int itemCount = items.itemCount;

                return GridViewBuilder(
                  primary: node.primary,
                  gridDelegate: node.properties.gridDelegate,
                  intrinsicRows: intrinsicRows,
                  shrinkWrap: shrinkWrap,
                  itemCount: itemCount,
                  padding: node.padding.flutterEdgeInsets,
                  keyboardDismissBehavior: node
                      .keyboardDismissBehavior
                      .flutterKeyboardDismissBehavior,
                  physics: node.physics.flutterScrollPhysics(
                    node.shouldAlwaysScroll,
                  ),
                  scrollDirection: node.scrollDirection.flutterAxis,
                  cacheExtent: node.properties.cacheExtent,
                  reverse: node.reverse,
                  clipBehavior: node.clipsContent ? Clip.hardEdge : Clip.none,
                  itemBuilder: (context, index) {
                    if (items.isButton(index)) return items.buildButton();
                    items.onItemBuilt(index);
                    return IndexedItemProvider(
                      key: ValueKey(index),
                      item: IndexedItem(index, items.dataAt(index)),
                      child: Builder(
                        builder: (context) {
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
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
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

    // Nested in another scroll view, the grid is bounded by its own fit or
    // shrink-wraps; see [ViewportLayout].
    return box(
      canShrinkWrap: itemCount != null,
      (context, shrinkWrap) => GridViewBuilder(
        primary: node.primary,
        gridDelegate: node.properties.gridDelegate,
        intrinsicRows: intrinsicRows,
        shrinkWrap: shrinkWrap,
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
          child: Builder(
            builder: (context) {
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
            },
          ),
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

  /// With [GridDelegateProperties.shrinkWrapRows], whether the cells of a row
  /// stretch to its tallest item, like a [Row] in an [IntrinsicHeight].
  /// False lays each row out at its tallest item and leaves the others at
  /// their own size, for items that can't report intrinsic sizes.
  final bool intrinsicRows;

  const GridViewBuilder({
    super.key,
    required this.shrinkWrap,
    required this.gridDelegate,
    this.intrinsicRows = true,
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
    if (gridDelegate.shrinkWrapRows) {
      return DraggableScrollConfiguration(
        child: switch (gridDelegate) {
          FixedCrossAxisCountGridDelegateProperties props => _rows(
            props.crossAxisCount,
          ),
          MaxCrossAxisExtentGridDelegateProperties props => LayoutBuilder(
            builder: (context, constraints) {
              final bool vertical = scrollDirection == Axis.vertical;
              final double extent =
                  (vertical ? constraints.maxWidth : constraints.maxHeight) -
                  (vertical
                      ? padding?.horizontal ?? 0
                      : padding?.vertical ?? 0);
              // As SliverGridDelegateWithMaxCrossAxisExtent counts.
              return _rows(
                extent.isFinite
                    ? (extent /
                              (props.maxCrossAxisExtent +
                                  props.crossAxisSpacing))
                          .ceil()
                    : 1,
              );
            },
          ),
        },
      );
    }

    return DraggableScrollConfiguration(
      child: GridView.builder(
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
        clipBehavior: clipBehavior,
        itemBuilder: itemBuilder!,
        keyboardDismissBehavior: keyboardDismissBehavior,
        gridDelegate: switch (gridDelegate) {
          FixedCrossAxisCountGridDelegateProperties props =>
            SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: math.max(1, props.crossAxisCount),
              mainAxisExtent: props.mainAxisExtent,
              childAspectRatio: props.childAspectRatio,
              crossAxisSpacing: props.crossAxisSpacing,
              mainAxisSpacing: props.mainAxisSpacing,
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
      ),
    );
  }

  /// A grid whose rows (columns when it scrolls horizontally) are as long as
  /// their longest item: a list of rows of [crossAxisCount] equal cells.
  Widget _rows(int crossAxisCount) {
    final int count = math.max(1, crossAxisCount);
    final bool vertical = scrollDirection == Axis.vertical;
    final int? rowCount = itemCount == null
        ? null
        : (itemCount! / count).ceil();
    // The spacing goes before every row but the first, on the side that
    // faces the row before it.
    final double spacing = gridDelegate.mainAxisSpacing;
    final EdgeInsetsGeometry leading = switch ((vertical, reverse)) {
      (true, false) => EdgeInsets.only(top: spacing),
      (true, true) => EdgeInsets.only(bottom: spacing),
      (false, false) => EdgeInsetsDirectional.only(start: spacing),
      (false, true) => EdgeInsetsDirectional.only(end: spacing),
    };

    return ListView.builder(
      primary: primary,
      shrinkWrap: shrinkWrap,
      itemCount: rowCount,
      padding: padding,
      physics: physics,
      scrollDirection: scrollDirection,
      scrollCacheExtent: cacheExtent == null
          ? null
          : ScrollCacheExtent.pixels(cacheExtent!),
      reverse: reverse,
      clipBehavior: clipBehavior,
      keyboardDismissBehavior: keyboardDismissBehavior,
      itemBuilder: (context, row) {
        Widget line = Flex(
          direction: vertical ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: intrinsicRows
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
          spacing: gridDelegate.crossAxisSpacing,
          children: [
            for (int column = 0; column < count; column++)
              Expanded(
                child: switch (row * count + column) {
                  final int index
                      when itemCount == null || index < itemCount! =>
                    itemBuilder!(context, index),
                  _ => const SizedBox.shrink(),
                },
              ),
          ],
        );
        if (intrinsicRows) {
          line = vertical
              ? IntrinsicHeight(child: line)
              : IntrinsicWidth(child: line);
        }
        if (row == 0 || spacing <= 0) return line;
        return Padding(padding: leading, child: line);
      },
    );
  }
}
