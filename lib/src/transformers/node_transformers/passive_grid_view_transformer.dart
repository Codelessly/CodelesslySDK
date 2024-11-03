import 'dart:core';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';
import '../../logging/error_logger.dart';
import '../../ui/draggable_scroll_configuration.dart';

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

            return GridViewBuilder(
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
              physics:
                  node.physics.flutterScrollPhysics(node.shouldAlwaysScroll),
              scrollDirection: node.scrollDirection.flutterAxis,
              cacheExtent: node.properties.cacheExtent,
              reverse: node.reverse,
              clipBehavior: node.clipsContent ? Clip.hardEdge : Clip.none,
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
    return DraggableScrollConfiguration(
      child: GridView.builder(
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
      ),
    );
  }
}
