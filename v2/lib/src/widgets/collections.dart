// Widget recipes: collections. See lib/src/render/recipe.dart.
//
// List, grid and page views repeat their first child, the item template, as
// SDK 8.x's ListView, GridView and PageView built it in preview (at rest, no
// data): one node box per item, the first in the list's own scope (the one
// tools measure), the others scoped to their index. Tabs, accordions and
// expansion tiles are material controls, built as islands.
import 'dart:math' as math;

import 'package:codelessly_api_v2/codelessly_api.dart' as api;
import 'package:codelessly_api_v2/codelessly_api.dart'
    show Node, SizeFit, CollectionScrollProps, ListViewProps, GridViewProps, PageViewProps, ScrollProps, TableViewProps;
import 'package:flutter/material.dart' show Divider, VerticalDivider, SizedBox, Widget, SliverGridDelegate, SliverGridDelegateWithFixedCrossAxisCount, SliverGridDelegateWithMaxCrossAxisExtent;
import 'package:flutter/rendering.dart';

import '../render/convert.dart';
import '../render/layout/fit_box.dart';
import '../render/node_tree.dart';
import '../render/recipe.dart';
import 'collections_data_list.dart';
import 'collections_islands.dart';
import 'collections_list_runtime.dart';
import 'collections_layout.dart';
import 'collections_pagination.dart';
import 'collections_reorder.dart';
import 'collections_table.dart';

/// Recipes for the collections group, by node type.
final Map<String, WidgetRecipe> collectionsRecipes = {
  'listView': _listView,
  'gridView': _gridView,
  'pageView': _pageView,
  'tabs': tabsRecipe,
  'tabBar': tabBarRecipe,
  'accordion': accordionRecipe,
  'expansionTile': expansionTileRecipe,
  'pagination': paginationRecipe,
  'tableView': _tableView,
};

typedef _Container = ContainerRenderObjectMixin<RenderBox, ContainerBoxParentData<RenderBox>>;

extension on Node {
  bool get vertical => prop(CollectionScrollProps.scrollDirection) == api.Axis.vertical;
  Axis get axis => vertical ? Axis.vertical : Axis.horizontal;
  SizeFit get mainFit => vertical ? layout.height.fit : layout.width.fit;
  SizeFit get crossFit => vertical ? layout.width.fit : layout.height.fit;
  double get designMain => vertical ? layout.height.value : layout.width.value;
  double get designCross => vertical ? layout.width.value : layout.height.value;
  double get outerWidth => layout.width.value + layout.margin.horizontal;
  double get outerHeight => layout.height.value + layout.margin.vertical;
}

/// The scope of item [index] of the view [b] builds: the view's own for the
/// first built item, its own per index for the rest.
Object? _scope(NodeBuilder b, int index, int first) => index == first ? null : ('item', b.instance, b.id, index);

/// Places [count] items (the template [itemId] repeated) from index [first]
/// in [container].
void _syncItems(NodeBuilder b, Node n, _Container container, String? itemId, int count, {int first = 0}) {
  if (itemId == null || count <= 0) {
    b.syncChildren(container, const [], Slot(SlotKind.root, n));
    return;
  }
  b.syncChildren(
    container,
    List.filled(count, itemId),
    Slot(SlotKind.root, n),
    instances: [for (var i = first; i < first + count; i++) _scope(b, i, first)],
  );
}

/// The box SDK 8.x's ViewportNodeBox gave a scroll view: the design extent
/// across (filling when expanded) and along its axis unless it shrink-wraps
/// its items (filling when expanded).
///
/// At runtime a flexible scroll axis shrink-wraps its items too, within the
/// room its parent gives it, and scrolls once they outgrow it (as the SDK
/// 8.x runtime does), so what follows the list sits under its last item. A
/// design canvas keeps it at its design size, as the editor showed it.
RenderFitBox _viewportBox(NodeBuilder b, Node n, {required bool canShrinkWrap}) {
  final shrinkWrap = _hugsMain(b, n) && canShrinkWrap;
  final main = shrinkWrap ? null : n.designMain;
  final fillMain = n.mainFit == SizeFit.fill;
  final fillCross = n.crossFit == SizeFit.fill;
  return b.obtain<RenderFitBox>('viewport', RenderFitBox.new)
    ..width = n.vertical ? n.designCross : main
    ..height = n.vertical ? main : n.designCross
    ..fillWidth = n.vertical ? fillCross : fillMain
    ..fillHeight = n.vertical ? fillMain : fillCross
    ..aspectRatio = null;
}

Clip _clip(Node n) => clip(n.prop(CollectionScrollProps.clipBehavior));

/// Whether [n] hugs its items along its scroll axis: it hugs, or it is
/// flexible (hugs within the room it's given) in a running app.
bool _hugsMain(NodeBuilder b, Node n) =>
    n.mainFit == SizeFit.hug || (n.mainFit == SizeFit.flexible && b.tree.animates);

/// The item count a view shows in preview: its set count (bound data is a
/// runtime matter), null when endless.
int? _itemCount(Node n) => n.prop(CollectionScrollProps.itemCount);

/// How many items an endless view starts with, before layout asks for more.
int _startCount(RenderCollection view, double designMain, double itemMain) {
  final estimate = itemMain >= 1 ? ((designMain + 250) / itemMain).ceil() + 1 : 1;
  return math.max(estimate, view.childCount).clamp(1, RenderCollection.maxEndlessItems);
}

/// Whether intrinsic measurement can't see into [node]'s subtree (SDK
/// 8.x's subtreeBlocksIntrinsics): a viewport, or scrolling content.
bool _blocksIntrinsics(NodeBuilder b, Node node) {
  if (node.type == 'listView') {
    if (!listBuildsAllItems(node)) return true;
  } else if (const {'gridView', 'pageView', 'webView'}.contains(node.type)) {
    return true;
  } else if (node.type != 'canvas' && node.props.get(ScrollProps.scrollable)) {
    return true;
  }
  for (final c in node.childIds) {
    final child = b.nodeOf(c);
    if (child != null && _blocksIntrinsics(b, child)) return true;
  }
  return false;
}

bool _knownCount(Node n) => _itemCount(n) != null;

/// The list flows its items onto runs (a Wrap); only a plain list layout does.
bool _wraps(Node n) => n.prop(ListViewProps.wrap) && n.prop(ListViewProps.layout) == api.ListLayout.list;

/// SDK 8.x's listBuildsAllItems: the list lays every item out in a Flex (or
/// a Wrap) rather than a viewport, so it can be measured.
bool listBuildsAllItems(Node n) {
  if (_wraps(n)) return true;
  final stretchesHuggedCross =
      n.prop(ListViewProps.stretchItems) &&
      n.prop(ListViewProps.layout) == api.ListLayout.list &&
      n.crossFit == SizeFit.hug;
  return !n.prop(ListViewProps.scrollable) && (n.mainFit == SizeFit.hug || stretchesHuggedCross) && _knownCount(n);
}

/// A list item's extent along the list when the list sets it: its fixed
/// item extent, or the design extent of an item that fills.
double? _itemMain(Node list, Node item) {
  final extent = list.prop(ListViewProps.itemExtent);
  if (extent != null) return extent;
  final fit = list.vertical ? item.layout.height.fit : item.layout.width.fit;
  if (fit == SizeFit.fill || fit == SizeFit.flexible) return list.vertical ? item.outerHeight : item.outerWidth;
  return null;
}

void _listView(NodeBuilder b, Node n, List<RenderBox> chain) {
  final itemId = n.children.firstOrNull;
  final item = itemId == null ? null : b.nodeOf(itemId);
  if (itemId == null || item == null) {
    chain.add(_viewportBox(b, n, canShrinkWrap: true));
    return;
  }
  if (b.tree.animates && usesDataList(n)) return _dataList(b, n, chain, itemId, item);
  if (b.tree.animates) {
    final handle = reorderHandleOf(b, itemId);
    if (reordersItems(n, hasData: ListRuntime(b, n).data != null, handle: handle)) {
      chain.add(_viewportBox(b, n, canShrinkWrap: true));
      final itemExtent = n.prop(ListViewProps.itemExtent);
      final separated = n.prop(ListViewProps.separator) != api.ListSeparator.none;
      return reorderRecipe(
        b,
        n,
        chain,
        itemId: itemId,
        handle: handle,
        itemMain: listItemMain(item, vertical: n.vertical, itemExtent: itemExtent),
        itemExtent: listItemExtent(n, item, vertical: n.vertical, itemExtent: itemExtent),
        stretch: n.prop(ListViewProps.stretchItems),
        gap: separated ? math.max(0, n.prop(ListViewProps.spacing)) : 0,
      );
    }
  }
  final count = _itemCount(n);
  final layout = n.prop(ListViewProps.layout);
  final vertical = n.vertical;
  final padding = n.layout.padding.flutter;
  final reversePaint = n.prop(ListViewProps.reversePaintOrder);

  if (layout == api.ListLayout.stack) {
    // Layered in the padded box, each at the item's position.
    chain.add(_viewportBox(b, n, canShrinkWrap: false));
    final at = n.prop(ListViewProps.itemPosition);
    final origin = Offset(padding.left + (at?.dx ?? 0), padding.top + (at?.dy ?? 0));
    final view = b.obtain<RenderLayeredItems>('stack', RenderLayeredItems.new)
      ..clipBehavior = _clip(n)
      ..paintReversed = reversePaint
      ..itemConstraints = ((_) => const BoxConstraints())
      ..placeAt = ((_, _) => origin)
      ..onNeedItems = null
      ..changed();
    _syncItems(b, n, view, itemId, count ?? 0);
    chain.add(view);
    return;
  }

  final itemMain = _itemMain(n, item);
  if (layout == api.ListLayout.deck) {
    // Layered, the first on top, each at the top centre (a horizontal
    // list's: centre left).
    chain.add(_viewportBox(b, n, canShrinkWrap: false));
    final view = b.obtain<RenderLayeredItems>('deck', RenderLayeredItems.new)
      ..clipBehavior = _clip(n)
      ..paintReversed = !reversePaint
      ..itemConstraints = ((box) {
        final loose = BoxConstraints.loose(box);
        if (itemMain == null) return loose;
        return vertical
            ? loose.copyWith(minHeight: itemMain.clamp(0, box.height), maxHeight: itemMain.clamp(0, box.height))
            : loose.copyWith(minWidth: itemMain.clamp(0, box.width), maxWidth: itemMain.clamp(0, box.width));
      })
      ..placeAt = (vertical
          ? (box, it) => Offset((box.width - it.width) / 2, 0)
          : (box, it) => Offset(0, (box.height - it.height) / 2))
      ..onNeedItems = null
      ..changed();
    _syncItems(b, n, view, itemId, count ?? 0);
    chain.add(view);
    return;
  }

  final separator = n.prop(ListViewProps.separator);
  final spacing = n.prop(ListViewProps.spacing);
  final stretchItems = n.prop(ListViewProps.stretchItems);

  if (_wraps(n)) {
    // A Wrap of every item, sized by the list's own fits.
    chain.add(
      b.fitBox('wrapFit', n.layout.width.fit, n.layout.height.fit, Size(n.layout.width.value, n.layout.height.value)),
    );
    bool fills(SizeFit f) => f == SizeFit.fill || f == SizeFit.flexible;
    final extent = n.prop(ListViewProps.itemExtent);
    var w = fills(item.layout.width.fit) ? item.outerWidth : null;
    var h = fills(item.layout.height.fit) ? item.outerHeight : null;
    if (extent != null) {
      if (vertical) {
        h = extent;
      } else {
        w = extent;
      }
    }
    final view = b.obtain<RenderWrapItems>('wrap', RenderWrapItems.new)
      ..clipBehavior = _clip(n)
      ..paintReversed = false
      ..onNeedItems = null
      ..axis = n.axis
      ..padding = padding
      ..spacing = n.prop(ListViewProps.wrapSpacing)
      ..runSpacing = n.prop(ListViewProps.runSpacing)
      ..alignment = RunAlignment.values.byName(n.prop(ListViewProps.wrapAlignment).name)
      ..crossAlignment = switch (n.prop(ListViewProps.wrapCrossAlignment)) {
        api.WrapCrossAlignment.start => -1,
        api.WrapCrossAlignment.center => 0,
        api.WrapCrossAlignment.end => 1,
      }
      ..hugWidth = n.layout.width.fit == SizeFit.hug
      ..hugHeight = n.layout.height.fit == SizeFit.hug
      ..stretch = stretchItems
      ..measure = !_blocksIntrinsics(b, item)
      ..itemWidth = w
      ..itemHeight = h
      ..markNeedsLayout();
    // Reversed, the last item first.
    final total = count ?? 0;
    final reversed = n.prop(CollectionScrollProps.reverse);
    b.syncChildren(
      view,
      List.filled(total, itemId),
      Slot(SlotKind.root, n),
      instances: [for (var k = 0; k < total; k++) _scope(b, reversed ? total - 1 - k : k, 0)],
    );
    chain.add(view);
    return;
  }

  final divider = separator == api.ListSeparator.divider
      ? ListDivider(
          color: n.prop(ListViewProps.dividerColor).flutter,
          thickness: n.prop(ListViewProps.dividerThickness),
          indent: n.prop(ListViewProps.dividerIndent),
          endIndent: n.prop(ListViewProps.dividerEndIndent),
        )
      : null;
  // Separators only between a known number of items; a negative space
  // overlaps them.
  final separated = count != null && separator != api.ListSeparator.none;
  final gap = separated ? (spacing < 0 ? 0.0 : spacing) : 0.0;
  final overlap = count != null && separator == api.ListSeparator.space && spacing < 0 ? -spacing : 0.0;

  final view = b.obtain<RenderListItems>('list', RenderListItems.new)
    ..clipBehavior = _clip(n)
    ..paintReversed = false
    ..dropTarget(b.tree.animates ? b.tree : null, n.id);
  final container = view as _Container;

  if (listBuildsAllItems(n)) {
    // Every item in a Flex: the scroll axis hugs them (or keeps its own
    // size, the items running on past it), the cross axis fills, hugs or
    // keeps its design size.
    final hugMain = n.mainFit == SizeFit.hug;
    final hugCross = n.crossFit == SizeFit.hug;
    chain.add(
      b.obtain<RenderFitBox>('viewport', RenderFitBox.new)
        ..width = vertical ? (hugCross ? null : n.designCross) : (hugMain ? null : n.designMain)
        ..height = vertical ? (hugMain ? null : n.designMain) : (hugCross ? null : n.designCross)
        ..fillWidth = vertical ? n.crossFit == SizeFit.fill : n.mainFit == SizeFit.fill
        ..fillHeight = vertical ? n.mainFit == SizeFit.fill : n.crossFit == SizeFit.fill
        ..aspectRatio = null,
    );
    final stretch = stretchItems && (!hugCross || !_blocksIntrinsics(b, item));
    view
      ..measurable = true
      ..onNeedItems = null
      ..update(
        axis: n.axis,
        reverse: n.prop(CollectionScrollProps.reverse),
        anchorEnd: false,
        padding: padding,
        hugMain: hugMain,
        hugCross: hugCross,
        stretch: stretch,
        itemMain: itemMain,
        gap: gap,
        overlap: overlap,
        divider: divider,
        itemCount: count,
        cacheExtent: 0,
      );
    _syncItems(b, n, container, itemId, count!);
    chain.add(view);
    return;
  }

  // A ListView: endless without a count (it builds what covers its
  // viewport), shrink-wrapping its items when it hugs them and can.
  final box = _viewportBox(b, n, canShrinkWrap: count != null);
  chain.add(box);
  view
    ..measurable = false
    ..onNeedItems = ((c) => _syncItems(b, n, container, itemId, c))
    ..update(
      axis: n.axis,
      reverse: n.prop(CollectionScrollProps.reverse),
      anchorEnd: true,
      padding: padding,
      hugMain: _hugsMain(b, n) && count != null,
      hugCross: false,
      stretch: stretchItems,
      itemMain: itemMain,
      gap: gap,
      overlap: overlap,
      divider: divider,
      itemCount: count,
      cacheExtent: n.prop(CollectionScrollProps.cacheExtent) ?? 250,
    );
  final start = count ?? _startCount(view, n.designMain, itemMain ?? (vertical ? item.outerHeight : item.outerWidth));
  _syncItems(b, n, container, itemId, start);
  chain.add(view);
}

/// A running list that pages, groups into sections or swipes: a
/// [DataListView] island in its viewport box.
void _dataList(NodeBuilder b, Node n, List<RenderBox> chain, String itemId, Node item) {
  chain.add(_viewportBox(b, n, canShrinkWrap: true));
  final vertical = n.vertical;
  final separator = n.prop(ListViewProps.separator);
  final spacing = n.prop(ListViewProps.spacing);
  final color = n.prop(ListViewProps.dividerColor).flutter;
  Widget gap() => switch (separator) {
        api.ListSeparator.divider when vertical => Divider(
            height: spacing,
            thickness: n.prop(ListViewProps.dividerThickness),
            color: color,
            indent: n.prop(ListViewProps.dividerIndent),
            endIndent: n.prop(ListViewProps.dividerEndIndent)),
        api.ListSeparator.divider => VerticalDivider(
            width: spacing,
            thickness: n.prop(ListViewProps.dividerThickness),
            color: color,
            indent: n.prop(ListViewProps.dividerIndent),
            endIndent: n.prop(ListViewProps.dividerEndIndent)),
        _ when spacing < 0 => const SizedBox.shrink(),
        _ => SizedBox(width: vertical ? null : spacing, height: vertical ? spacing : null),
      };
  final itemExtent = n.prop(ListViewProps.itemExtent);
  dataListRecipe(
    b,
    n,
    chain,
    itemId: itemId,
    itemExtent: listItemExtent(n, item, vertical: vertical, itemExtent: itemExtent),
    itemMain: listItemMain(item, vertical: vertical, itemExtent: itemExtent),
    stretch: n.prop(ListViewProps.stretchItems),
    separatorExtent: math.max(0, spacing),
    separator: separator == api.ListSeparator.none ? null : gap,
    scrollable: n.prop(ListViewProps.scrollable),
  );
}

/// A running grid that pages: a [DataListView] island laying a grid.
void _pagedGrid(NodeBuilder b, Node n, List<RenderBox> chain, String itemId) {
  chain.add(_viewportBox(b, n, canShrinkWrap: true));
  final max = n.prop(GridViewProps.maxCrossAxisExtent);
  final SliverGridDelegate delegate = max != null
      ? SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: max,
          mainAxisSpacing: n.prop(GridViewProps.mainAxisSpacing),
          crossAxisSpacing: n.prop(GridViewProps.crossAxisSpacing),
          childAspectRatio: n.prop(GridViewProps.childAspectRatio),
          mainAxisExtent: n.prop(GridViewProps.mainAxisExtent))
      : SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: n.prop(GridViewProps.crossAxisCount),
          mainAxisSpacing: n.prop(GridViewProps.mainAxisSpacing),
          crossAxisSpacing: n.prop(GridViewProps.crossAxisSpacing),
          childAspectRatio: n.prop(GridViewProps.childAspectRatio),
          mainAxisExtent: n.prop(GridViewProps.mainAxisExtent));
  dataListRecipe(b, n, chain, itemId: itemId, gridDelegate: delegate);
}

void _gridView(NodeBuilder b, Node n, List<RenderBox> chain) {
  final itemId = n.children.firstOrNull;
  final item = itemId == null ? null : b.nodeOf(itemId);
  if (itemId == null || item == null) {
    chain.add(_viewportBox(b, n, canShrinkWrap: true));
    return;
  }
  if (b.tree.animates && n.pagination != null && !n.prop(GridViewProps.shrinkWrapRows)) {
    return _pagedGrid(b, n, chain, itemId);
  }
  final count = _itemCount(n);
  chain.add(_viewportBox(b, n, canShrinkWrap: count != null));
  final view = b.obtain<RenderGridItems>('grid', RenderGridItems.new)
    ..clipBehavior = _clip(n)
    ..paintReversed = false
    ..axis = n.axis
    ..reverse = n.prop(CollectionScrollProps.reverse)
    ..padding = n.layout.padding.flutter
    ..crossAxisCount = n.prop(GridViewProps.crossAxisCount)
    ..maxCrossAxisExtent = n.prop(GridViewProps.maxCrossAxisExtent)
    ..mainAxisSpacing = n.prop(GridViewProps.mainAxisSpacing)
    ..crossAxisSpacing = n.prop(GridViewProps.crossAxisSpacing)
    ..childAspectRatio = n.prop(GridViewProps.childAspectRatio)
    ..mainAxisExtent = n.prop(GridViewProps.mainAxisExtent)
    ..shrinkWrapRows = n.prop(GridViewProps.shrinkWrapRows)
    ..intrinsicRows = !_blocksIntrinsics(b, item)
    ..hugMain = n.mainFit == SizeFit.hug && count != null
    ..itemCount = count
    ..cacheExtent = n.prop(CollectionScrollProps.cacheExtent) ?? 250
    ..changed();
  final container = view as _Container;
  view.onNeedItems = (c) => _syncItems(b, n, container, itemId, c);
  final start = count ?? (view.childCount < 2 ? 2 : view.childCount);
  _syncItems(b, n, container, itemId, start);
  chain.add(view);
}

void _pageView(NodeBuilder b, Node n, List<RenderBox> chain) {
  final itemId = n.children.firstOrNull;
  final item = itemId == null ? null : b.nodeOf(itemId);
  if (itemId == null || item == null) {
    chain.add(_viewportBox(b, n, canShrinkWrap: true));
    return;
  }
  // A page view can't size itself to its pages.
  chain.add(_viewportBox(b, n, canShrinkWrap: false));
  final count = _itemCount(n);
  final fraction = n.prop(PageViewProps.viewportFraction);
  final padEnds = n.prop(PageViewProps.padEnds);
  final initial = n.prop(PageViewProps.initialPage);
  final (first, last) = RenderPageItems.builtRange(
    viewportFraction: fraction,
    padEnds: padEnds,
    initialPage: initial,
    itemCount: count,
    cache: n.prop(PageViewProps.allowImplicitScrolling),
  );
  final view = b.obtain<RenderPageItems>('pages', RenderPageItems.new)
    ..clipBehavior = _clip(n)
    ..paintReversed = false
    ..onNeedItems = null
    ..axis = n.axis
    ..reverse = n.prop(CollectionScrollProps.reverse)
    ..viewportFraction = fraction
    ..padEnds = padEnds
    ..initialPage = initial
    ..firstIndex = first
    ..itemCount = count
    ..pageMotion = n.prop(PageViewProps.pageMotion)
    ..changed();
  _syncItems(b, n, view, itemId, last - first + 1, first: first);
  chain.add(view);
}

/// The most cells a table builds at rest along an axis beyond its design
/// size (none past it are shown).
const int _maxTableSpans = 200;

/// A table view at rest: its fit box → the cells that fit its design size,
/// each a template slot repeated (SDK 8.x's `TableView.builder`). Rows are
/// [TableViewProps.rowCount] (bound data is a runtime matter).
void _tableView(NodeBuilder b, Node n, List<RenderBox> chain) {
  if (b.tree.animates) return tableViewRuntimeRecipe(b, n, chain);
  final design = Size(n.layout.width.value, n.layout.height.value);
  chain.add(b.fitBox('fit', n.layout.width.fit, n.layout.height.fit, design));
  String? slot(String name) => n.slots[name].let((id) => id != null && b.nodeOf(id) != null ? id : null);
  final cell = slot(TableViewProps.cell), columnHeader = slot(TableViewProps.columnHeader);
  final rowHeader = slot(TableViewProps.rowHeader), corner = slot(TableViewProps.corner);
  final headerRow = columnHeader != null, headerColumn = rowHeader != null;
  final columns = n.prop(TableViewProps.columns);
  final rowCount = math.max(0, n.prop(TableViewProps.rowCount) ?? 0);

  // The spans that show in the design size (a cell past it is cut off).
  List<double> fit(List<double> all, double extent) {
    final out = <double>[];
    var at = 0.0;
    for (final e in all) {
      if (at >= extent || out.length >= _maxTableSpans) break;
      out.add(e);
      at += e;
    }
    return out;
  }

  final columnWidths = fit([
    if (headerColumn) n.prop(TableViewProps.rowHeaderWidth),
    for (final c in columns) c.width ?? n.prop(TableViewProps.columnWidth),
  ], design.width);
  final rowHeights = fit([
    if (headerRow) n.prop(TableViewProps.headerHeight),
    for (var i = 0; i < math.min(rowCount, _maxTableSpans); i++) n.prop(TableViewProps.rowHeight),
  ], design.height);

  final ids = <String>[], instances = <Object?>[], cells = <(int, int)>[];
  final firsts = <String>{};
  void add(String? id, int r, int c) {
    if (id == null) return;
    ids.add(id);
    // The first of each template in the table's own scope (what tools
    // measure), the others in their cell's.
    instances.add(firsts.add(id) ? null : ('cell', b.instance, b.id, r, c));
    cells.add((r, c));
  }

  for (var r = 0; r < rowHeights.length; r++) {
    for (var c = 0; c < columnWidths.length; c++) {
      final inHeaderRow = headerRow && r == 0, inHeaderColumn = headerColumn && c == 0;
      add(
          inHeaderRow && inHeaderColumn
              ? corner
              : inHeaderRow
                  ? columnHeader
                  : inHeaderColumn
                      ? rowHeader
                      : cell,
          r,
          c);
    }
  }
  final lineColor = n.prop(TableViewProps.gridLineColor), lineWidth = n.prop(TableViewProps.gridLineWidth);
  final view = b.obtain<RenderTableItems>('table', RenderTableItems.new)
    ..clipBehavior = clip(n.prop(TableViewProps.clipBehavior))
    ..columnWidths = columnWidths
    ..rowHeights = rowHeights
    ..cells = cells
    ..headerRow = headerRow
    ..headerColumn = headerColumn
    ..headerColor = n.prop(TableViewProps.headerColor)?.flutter
    ..stripeColor = n.prop(TableViewProps.stripeColor)?.flutter
    ..gridLine = lineColor.alpha == 0 || lineWidth <= 0 ? null : BorderSide(color: lineColor.flutter, width: lineWidth)
    ..changed();
  b.syncChildren(view as _Container, ids, Slot(SlotKind.root, n), instances: instances);
  chain.add(view);
}
