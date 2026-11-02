import 'dart:core';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
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

  /// Explicit wrap spacing belongs to the scrollable, cross-axis run layout;
  /// separator spacing belongs to the intrinsic, non-scrolling wrap layout.
  bool get usesScrollableWrap =>
      node.properties.isWrapping &&
      (node.properties.wrapSpacing != 0 || node.properties.wrapRunSpacing != 0);

  /// Sizes the list by [ViewportLayout] around [builder].
  ///
  /// A scrollable wrapping list is sized by [WrapNodeBox] instead, and the
  /// flag given to [builder] says whether its runs scroll along the cross axis.
  Widget box(ViewportContentBuilder builder, {required bool canShrinkWrap}) =>
      usesScrollableWrap
      ? WrapNodeBox(node: node, builder: builder)
      : ViewportNodeBox(
          node: node,
          scrollDirection: node.scrollDirection,
          canShrinkWrap: canShrinkWrap,
          builder: builder,
        );

  /// Lays out all [itemCount] items in a [Flex] instead of a viewport, for a
  /// list that [listBuildsAllItems]. It looks the same, and a Row or Column
  /// around it can measure it (a viewport can't report intrinsic sizes), so
  /// a stretched row of cards keeps equal heights with a list in one of them.
  Widget staticList(
    BuildContext context,
    int itemCount,
    IndexedWidgetBuilder itemBuilder,
  ) {
    if (listWraps(node) && !usesScrollableWrap) {
      return wrappedList(context, itemCount, itemBuilder);
    }
    final bool vertical = node.scrollDirection == AxisC.vertical;
    final List<Widget> items = [
      for (int index = 0; index < itemCount; index++) ...[
        if (index > 0 && node.properties.hasSeparator)
          ListViewItemSeparator(
            scrollDirection: node.scrollDirection,
            properties: node.properties,
          ),
        itemBuilder(context, index),
      ],
    ];
    final Widget flex = Padding(
      padding: node.padding.flutterEdgeInsets,
      child: Flex(
        direction: node.scrollDirection.flutterAxis,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: node.reverse ? items.reversed.toList() : items,
      ),
    );
    // The cross axis follows [ViewportLayout]: fill when expanded and
    // bounded, else the design size. The scroll axis hugs the items.
    final SizeFit crossFit = vertical ? node.horizontalFit : node.verticalFit;
    final double designCross = vertical
        ? node.basicBoxLocal.width
        : node.basicBoxLocal.height;
    final bool fill = crossFit == SizeFit.expanded;
    return FitBox(
      width: vertical ? designCross : null,
      height: vertical ? null : designCross,
      fillWidth: vertical && fill,
      fillHeight: !vertical && fill,
      child: node.clipsContent ? ClipRect(child: flex) : flex,
    );
  }

  /// Lays out all [itemCount] items of a wrapping list (see [listWraps]) in
  /// a [Wrap] along the scroll direction: items flow onto a new run when
  /// they don't fit, with the separator's spacing between items and
  /// [ListViewProperties.runSpacing] between runs, all aligned to the start.
  ///
  /// The list is sized by its own fits: fixed takes its design size, expanded
  /// fills a bounded axis, and shrink-wrap hugs (along the scroll direction,
  /// the widest run; across it, the runs).
  Widget wrappedList(
    BuildContext context,
    int itemCount,
    IndexedWidgetBuilder itemBuilder,
  ) {
    final List<Widget> items = [
      for (int index = 0; index < itemCount; index++)
        itemBuilder(context, index),
    ];
    final Widget wrap = Padding(
      padding: node.padding.flutterEdgeInsets,
      child: Wrap(
        direction: node.scrollDirection.flutterAxis,
        spacing: listWrapSpacing(node),
        runSpacing: math.max(0, node.properties.runSpacing),
        children: node.reverse ? items.reversed.toList() : items,
      ),
    );
    return FitBox(
      width: node.horizontalFit == SizeFit.shrinkWrap
          ? null
          : node.basicBoxLocal.width,
      height: node.verticalFit == SizeFit.shrinkWrap
          ? null
          : node.basicBoxLocal.height,
      fillWidth: node.horizontalFit == SizeFit.expanded,
      fillHeight: node.verticalFit == SizeFit.expanded,
      child: node.clipsContent ? ClipRect(child: wrap) : wrap,
    );
  }

  /// Builds one item, placed as the editor lays it out; see [ListItemBox].
  /// Legacy wrapping lists retain their item sizing and scroll behavior.
  Widget buildItem(BaseNode item, BuildContext context) {
    final Widget child = manager.buildWidgetByID(
      item.id,
      context,
      settings: settings,
    );
    if (usesScrollableWrap) {
      return WrapItemBox(
        item: item,
        scrollDirection: node.scrollDirection,
        itemExtent: node.properties.itemExtent,
        child: child,
      );
    }
    return ListItemBox(
      item: item,
      scrollDirection: node.scrollDirection,
      itemExtent: node.properties.itemExtent,
      inWrap: listWraps(node) && !usesScrollableWrap,
      child: child,
    );
  }

  Widget wrapped(bool scrolls, int itemCount, IndexedWidgetBuilder builder) =>
      WrappedItems(
        itemCount: itemCount,
        itemBuilder: builder,
        direction: node.scrollDirection.flutterAxis,
        spacing: node.properties.wrapSpacing,
        runSpacing: node.properties.wrapRunSpacing,
        alignment: node.properties.wrapAlignment.flutterWrapAlignment,
        padding: node.padding.flutterEdgeInsets,
        scrolls: scrolls,
        physics: node.physics.flutterScrollPhysics(false),
        keyboardDismissBehavior:
            node.keyboardDismissBehavior.flutterKeyboardDismissBehavior,
        clipBehavior: node.clipsContent ? Clip.hardEdge : Clip.none,
      );

  @override
  Widget build(BuildContext context) {
    // A list a drop target owns rebuilds as drags move over it, to open the
    // slot where the drop would land.
    final DropTargetBoxState? target = DropTargetScope.forList(
      context,
      node.id,
    );
    if (target == null || settings.isPreview) return buildList(context, null);
    return ListenableBuilder(
      listenable: target.controller,
      builder: (context, _) => buildList(context, target),
    );
  }

  /// Builds the list; [target] is the drop target that owns it, if any.
  Widget buildList(BuildContext context, DropTargetBoxState? target) {
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

      // A loaded query always has a known length, so it can shrink-wrap;
      // a stacked list's Stack has only positioned children and can't.
      return box(
        canShrinkWrap:
            !node.properties.stacked &&
            node.properties.layout != ListLayout.stack,
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

                // A wrapping list builds every item at once, so it shows the
                // loaded items without paging further.
                if (node.properties.isWrapping) {
                  final int loaded = snapshot.docs.length;
                  return wrapped(shrinkWrap, loaded, (context, index) {
                    final doc = snapshot.docs[index];
                    return IndexedItemProvider(
                      key: ValueKey(index),
                      item: IndexedItem(index, {'id': doc.id, ...doc.data()}),
                      child: Builder(
                        builder: (context) => KeyedSubtree(
                          key: ValueKey(index),
                          child: buildItem(item, context),
                        ),
                      ),
                    );
                  });
                }

                if (node.properties.stacked) {
                  return StackedItems(
                    itemCount: snapshot.docs.length,
                    clipBehavior: node.clipsContent ? Clip.hardEdge : Clip.none,
                    itemBuilder: (context, index) => IndexedItemProvider(
                      key: ValueKey(index),
                      item: IndexedItem(index, items.dataAt(index)),
                      child: Builder(
                        builder: (context) => buildItem(item, context),
                      ),
                    ),
                  );
                }

                if (node.properties.layout == ListLayout.stack) {
                  return StackedListItems(
                    node: node,
                    item: item,
                    values: [
                      for (int index = 0; index < itemCount; index++)
                        if (!items.isButton(index)) items.dataAt(index),
                    ],
                    manager: manager,
                    settings: settings,
                  );
                }

                // Item Count always exists.
                return ListViewBuilder(
                  primary: node.primary,
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
                  itemExtent: node.properties.itemExtent,
                  clipBehavior: node.clipsContent ? Clip.hardEdge : Clip.none,
                  separatedBuilder: node.properties.hasSeparator
                      ? (context, index) => ListViewItemSeparator(
                          scrollDirection: node.scrollDirection,
                          properties: node.properties,
                        )
                      : null,
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
                            child: buildItem(item, context),
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

    int? itemCount;
    if (settings.isPreview) {
      itemCount = node.properties.itemCount ?? data?.length;
    } else {
      itemCount = data?.length ?? node.properties.itemCount;
    }

    if (node.properties.layout == ListLayout.stack) {
      return box(
        canShrinkWrap: false,
        (context, _) => StackedListItems(
          node: node,
          item: item,
          values: [
            for (int i = 0; i < (itemCount ?? 0); i++) data?.elementAtOrNull(i),
          ],
          manager: manager,
          settings: settings,
        ),
      );
    }

    // Data-backed rows have stable identity across inserts and reorders.
    final ids = data
        ?.map((value) => value is Map ? value['id'] : null)
        .toList();
    Object itemKey(int index) {
      final id = ids?.elementAtOrNull(index);
      return id != null &&
              ids!.where((candidate) => candidate == id).length == 1
          ? ('id', id)
          : ('index', index);
    }

    Widget dataItemBuilder(BuildContext context, int index) =>
        IndexedItemProvider(
          key: ValueKey(itemKey(index)),
          item: IndexedItem(index, data?.elementAtOrNull(index)),
          child: Builder(
            builder: (context) {
              // This builder is important to pass a context that has
              // the IndexedItemProvider.
              Widget child = KeyedSubtree(
                key: ValueKey(itemKey(index)),
                child: buildItem(item, context),
              );
              if (target != null) {
                target.registerListScrollable(context);
                child = target.registerItem(
                  identity: itemKey(index),
                  index: index,
                  value: data?.elementAtOrNull(index),
                  axis: node.scrollDirection.flutterAxis,
                  child: child,
                );
              }
              // Negative spacing overlaps the items (an avatar stack): each
              // but the last takes that much less room and the next one is
              // drawn over it.
              final double overlap = listItemOverlap(node);
              if (overlap > 0 && index < (itemCount ?? 0) - 1) {
                child = OverlapBox(
                  overlap: overlap,
                  axis: node.scrollDirection.flutterAxis,
                  child: child,
                );
              }
              return child;
            },
          ),
        );

    // While a drag is over the target that owns this list, a slot opens
    // where the drop would land: drawn with the item it lands before, so no
    // item changes index (a list reuses items by index, and the dragged item
    // must keep its state), or after the last item.
    final int? slotAt = target?.slotBefore?.clamp(0, itemCount ?? 0);
    Widget slot(BuildContext context) => target!.buildSlot(
      context,
      node.scrollDirection.flutterAxis,
      (context, id) => manager.buildWidgetByID(
        id,
        context,
        settings: const WidgetBuildSettings(
          debugLabel: 'drop slot',
          withReactions: false,
          withVisibility: false,
        ),
      ),
    );
    Widget itemBuilder(BuildContext context, int index) {
      if (slotAt == null) return dataItemBuilder(context, index);
      if (index == itemCount) return slot(context);
      if (index != slotAt) return dataItemBuilder(context, index);
      return Flex(
        direction: node.scrollDirection.flutterAxis,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [slot(context), dataItemBuilder(context, index)],
      );
    }

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

    if (slotAt != null && itemCount != null && slotAt == itemCount) {
      itemCount = itemCount + 1;
    }

    // Legacy stacked and wrapping layouts keep their placement and physics.
    if (node.properties.stacked) {
      return box(
        canShrinkWrap: false,
        (context, _) => StackedItems(
          itemCount: itemCount ?? 0,
          clipBehavior: node.clipsContent ? Clip.hardEdge : Clip.none,
          itemBuilder: itemBuilder,
        ),
      );
    }
    if (usesScrollableWrap) {
      return box(
        canShrinkWrap: true,
        (context, scrolls) => wrapped(scrolls, itemCount ?? 0, itemBuilder),
      );
    }
    if (itemCount != null && listBuildsAllItems(node)) {
      return staticList(context, itemCount, itemBuilder);
    }

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

/// The items of a [ListLayout.stack] list: layered in the list's padded box,
/// each placed at its item node's bound `x`/`y`, evaluated for that item, or
/// at the item node's design offset when not bound.
class StackedListItems extends StatelessWidget {
  /// The list.
  final ListViewNode node;

  /// The list's item node, built once per value.
  final BaseNode item;

  /// One value per item, read as `${item}` by the item's nodes.
  final List<Object?> values;

  final NodeTransformerManager manager;
  final WidgetBuildSettings settings;

  const StackedListItems({
    super.key,
    required this.node,
    required this.item,
    required this.values,
    required this.manager,
    required this.settings,
  });

  /// Where [item] starts on an axis: its bound value, else its design offset
  /// from [list]'s padded box.
  static double offsetOf(
    BaseNode item,
    BaseNode list,
    String property,
    ScopedValues scopedValues,
  ) {
    final num? bound = PropertyValueDelegate.getPropertyValue<num>(
      item,
      property,
      scopedValues: scopedValues,
    );
    if (bound != null && bound.isFinite) return bound.toDouble();
    return property == 'x'
        ? item.outerBoxLocal.x - list.innerBoxLocal.edgeLeft
        : item.outerBoxLocal.y - list.innerBoxLocal.edgeTop;
  }

  @override
  Widget build(BuildContext context) {
    final List<Listenable> listenables =
        manager is PassiveNodeTransformerManager
        ? (manager as PassiveNodeTransformerManager).listenablesFor(
            context,
            item,
          )
        : const [];
    return Padding(
      padding: node.padding.flutterEdgeInsets,
      child: Stack(
        clipBehavior: node.clipsContent ? Clip.hardEdge : Clip.none,
        children: [
          for (int index = 0; index < values.length; index++)
            IndexedItemProvider(
              key: ValueKey(index),
              item: IndexedItem(index, values[index]),
              // A component builder between the provider and the Positioned,
              // so the offset reads this item and rebuilds when the
              // variables it uses change.
              child: _StackedItem(
                listenables: listenables,
                builder: (context) {
                  final ScopedValues scope = ScopedValues.of(context);
                  return Positioned(
                    key: ValueKey('stacked item $index'),
                    left: offsetOf(item, node, 'x', scope),
                    top: offsetOf(item, node, 'y', scope),
                    child: manager.buildWidgetByID(
                      item.id,
                      context,
                      settings: settings,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Rebuilds [builder] when [listenables] change. Builds no render object, so
/// the [Positioned] it returns reaches the [Stack].
class _StackedItem extends StatefulWidget {
  final List<Listenable> listenables;
  final WidgetBuilder builder;

  const _StackedItem({required this.listenables, required this.builder});

  @override
  State<_StackedItem> createState() => _StackedItemState();
}

class _StackedItemState extends State<_StackedItem> {
  Listenable? _listenable;

  void _changed() => setState(() {});

  void _listen() {
    _listenable?.removeListener(_changed);
    _listenable = widget.listenables.isEmpty
        ? null
        : Listenable.merge(widget.listenables);
    _listenable?.addListener(_changed);
  }

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant _StackedItem old) {
    super.didUpdateWidget(old);
    if (!const ListEquality<Listenable>().equals(
      old.listenables,
      widget.listenables,
    )) {
      _listen();
    }
  }

  @override
  void dispose() {
    _listenable?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
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
        // Negative spacing is an overlap the items take care of.
        if (properties.separatorSpacing < 0) return const SizedBox.shrink();
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

/// The items of a stacked list: drawn on top of each other in the list's
/// box, each at its top center, the first item on top.
class StackedItems extends StatelessWidget {
  /// Creates a [StackedItems].
  const StackedItems({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.clipBehavior = Clip.none,
  });

  /// How many items.
  final int itemCount;

  /// Builds an item.
  final IndexedWidgetBuilder itemBuilder;

  /// Whether items moved outside the box are clipped.
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: clipBehavior,
    children: [
      // Built last to first, so the first item paints over the rest and
      // takes taps first.
      for (int index = itemCount - 1; index >= 0; index--)
        Positioned.fill(
          key: ValueKey(index),
          child: Align(
            alignment: Alignment.topCenter,
            child: itemBuilder(context, index),
          ),
        ),
    ],
  );
}

/// The items of a wrapping list: laid out by a [Wrap] along [direction],
/// flowing onto further lines (runs) when a line is full, each item at its
/// own size.
///
/// With [scrolls], the runs scroll along the cross axis when they don't fit
/// the box; otherwise the box grows with them.
class WrappedItems extends StatelessWidget {
  /// Creates a [WrappedItems].
  const WrappedItems({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.direction = Axis.horizontal,
    this.spacing = 0,
    this.runSpacing = 0,
    this.alignment = WrapAlignment.start,
    this.padding = EdgeInsets.zero,
    this.scrolls = false,
    this.physics,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.clipBehavior = Clip.none,
  });

  /// How many items.
  final int itemCount;

  /// Builds an item.
  final IndexedWidgetBuilder itemBuilder;

  /// The wrap direction: the list's scroll direction.
  final Axis direction;

  /// The gap between two items of a line.
  final double spacing;

  /// The gap between two lines.
  final double runSpacing;

  /// How the items of a line are placed along it.
  final WrapAlignment alignment;

  /// The list's padding, around the runs.
  final EdgeInsets padding;

  /// Whether the runs scroll along the cross axis.
  final bool scrolls;

  /// The physics of that scroll.
  final ScrollPhysics? physics;

  /// See [ScrollView.keyboardDismissBehavior].
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// Whether the runs are clipped to the box.
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final Widget wrap = Wrap(
      direction: direction,
      spacing: spacing,
      runSpacing: runSpacing,
      alignment: alignment,
      children: [
        for (int index = 0; index < itemCount; index++)
          itemBuilder(context, index),
      ],
    );
    if (scrolls) {
      return DraggableScrollConfiguration(
        child: SingleChildScrollView(
          primary: false,
          scrollDirection: direction == Axis.horizontal
              ? Axis.vertical
              : Axis.horizontal,
          padding: padding,
          physics: physics,
          keyboardDismissBehavior: keyboardDismissBehavior,
          clipBehavior: clipBehavior,
          child: wrap,
        ),
      );
    }
    final Widget padded = Padding(padding: padding, child: wrap);
    return clipBehavior == Clip.none
        ? padded
        : ClipRect(clipBehavior: clipBehavior, child: padded);
  }
}

/// How far a list's items overlap: its negative space separator's spacing.
double listItemOverlap(ListViewNode node) =>
    node.properties.hasSeparator &&
        node.properties.separator == ListItemSeparator.space &&
        node.properties.separatorSpacing < 0
    ? -node.properties.separatorSpacing
    : 0;

/// Lays [child] out at its size but takes [overlap] less room along [axis],
/// so the next item of a list is drawn over its end.
class OverlapBox extends SingleChildRenderObjectWidget {
  /// Creates an [OverlapBox].
  const OverlapBox({
    super.key,
    required this.overlap,
    required this.axis,
    super.child,
  });

  /// How much less room the child takes.
  final double overlap;

  /// The list's direction.
  final Axis axis;

  @override
  RenderOverlapBox createRenderObject(BuildContext context) =>
      RenderOverlapBox(overlap: overlap, axis: axis);

  @override
  void updateRenderObject(BuildContext context, RenderOverlapBox renderObject) {
    renderObject
      ..overlap = overlap
      ..axis = axis;
  }
}

/// The render object of [OverlapBox].
class RenderOverlapBox extends RenderProxyBox {
  /// Creates a [RenderOverlapBox].
  RenderOverlapBox({required double overlap, required Axis axis})
    : _overlap = overlap,
      _axis = axis;

  double _overlap;
  Axis _axis;

  set overlap(double value) {
    if (value == _overlap) return;
    _overlap = value;
    markNeedsLayout();
  }

  set axis(Axis value) {
    if (value == _axis) return;
    _axis = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final RenderBox child = this.child!;
    child.layout(constraints.loosen(), parentUsesSize: true);
    final Size size = child.size;
    this.size = constraints.constrain(
      _axis == Axis.horizontal
          ? Size(math.max(0, size.width - _overlap), size.height)
          : Size(size.width, math.max(0, size.height - _overlap)),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      child!.hitTest(result, position: position);

  @override
  Rect get paintBounds => Offset.zero & child!.size;
}
