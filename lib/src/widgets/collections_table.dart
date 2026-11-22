// A running table view: a table that scrolls along both axes, builds only
// the cells on screen and pins its header row and column
// ([RenderRunningTable]). Its rows are its bound data (else `rowCount`
// indexes) and its columns its `columns`; each cell is a template slot's
// node box in the scope of its cell (`${item.value}`, `${item.label}`,
// `${item.rowIndex}`...).
//
// On a design canvas (not animating) the table keeps its render objects at
// rest (collections.dart).
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api show AxisSize, Decoration, EdgeInsets, TextDirection;
import 'package:codelessly_api/core.dart' show Node, SizeFit, TableColumn, TableViewProps, TriggerType;
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../render/convert.dart';
import '../render/controls/focus.dart';
import '../render/controls/root.dart';
import '../render/controls/tokens.dart';
import '../render/node_tree.dart' show Slot, SlotKind;
import '../render/recipe.dart';
import '../runtime/expressions/bindings.dart';
import 'collections_layout.dart' show CollectionParentData;
import 'collections_list_runtime.dart';

/// The rows of a running table [r]: its bound data, or `rowCount` indexes.
List<Object?> tableRowsOf(ListRuntime r) {
  if (r.node.bind.containsKey('data')) return r.binder?.itemsOf(r.b.source, r.node, r.b.instance) ?? const [];
  return List<Object?>.generate(math.max(0, r.node.prop(TableViewProps.rowCount) ?? 0), (i) => i);
}

/// Whether table [n] draws a fill, stroke, shadow or rounded corners: the
/// node's shell around the table (a bordered, rounded week grid).
bool tableDecorated(Node n) {
  final d = n.decoration;
  return d.fills.any((f) => f.visible) || d.strokes.any((s) => s.visible) || d.effects.any((e) => e.visible) || !d.radius.isZero;
}

/// A running table view [n]: its fit box, then a [RenderRunningTable] that
/// builds the cells in view.
void tableViewRuntimeRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  chain.add(b.fitBox('fit', n.layout.width.fit, n.layout.height.fit, Size(n.layout.width.value, n.layout.height.value)));
  final r = ListRuntime(b, n);
  var sourceRows = tableRowsOf(r);
  var rows = sourceRows;
  String? slot(String name) => n.slots[name] != null && b.nodeOf(n.slots[name]!) != null ? n.slots[name] : null;
  final cell = slot(TableViewProps.cell), columnHeader = slot(TableViewProps.columnHeader);
  final rowHeader = slot(TableViewProps.rowHeader), corner = slot(TableViewProps.corner);
  final sourceColumns = n.prop(TableViewProps.columns);
  final List<TableColumn> columns = n.behaviors.textDirection == api.TextDirection.rtl ? sourceColumns.reversed.toList() : sourceColumns;
  final headerRow = columnHeader != null, headerColumn = rowHeader != null;
  final rowOffset = headerRow ? 1 : 0, columnOffset = headerColumn ? 1 : 0;
  final lineColor = n.prop(TableViewProps.gridLineColor), lineWidth = n.prop(TableViewProps.gridLineWidth);
  final headerBorderColor = n.prop(TableViewProps.headerBorderColor)?.flutter;
  final rowHeightKey = n.prop(TableViewProps.rowHeightKey), rowHeight = n.prop(TableViewProps.rowHeight);
  final minTouchRow = n.prop(TableViewProps.sortable) ? 44.0 : 0.0;
  // Its padding (a bordered frame's inset) holds the cells in from the
  // edge, so they don't paint over the border.
  final padding = n.layout.padding.flutter;
  if (padding != EdgeInsets.zero) {
    chain.add(b.obtain<RenderPadding>('tablePadding', () => RenderPadding(padding: padding, textDirection: TextDirection.ltr))..padding = padding);
  }
  // The template of table cell (row, col), header spans counted, and its key, index and item for the rows as they
  // are now (null id: no template for it).
  (String?, Object, int, Object?) cellAt(int row, int col) {
    final inHeaderRow = headerRow && row == 0, inHeaderColumn = headerColumn && col == 0;
    final rowIndex = row - rowOffset, columnIndex = col - columnOffset;
    if (inHeaderRow && inHeaderColumn) return (corner, 'corner', 0, null);
    if (inHeaderRow) {
      final column = columns[columnIndex];
      return (columnHeader, ('column', columnIndex), columnIndex, {'label': column.label, 'column': column.key, 'columnIndex': columnIndex});
    }
    if (inHeaderColumn) return (rowHeader, ('row', rowIndex), rowIndex, {'row': rows[rowIndex], 'rowIndex': rowIndex});
    final column = columns[columnIndex];
    final row_ = rows[rowIndex];
    return (
      cell,
      (rowIndex, columnIndex),
      rowIndex,
      {
        'value': switch (row_) {
          final Map m => m[column.key],
          final List l => l.elementAtOrNull(columnIndex),
          _ => null,
        },
        'row': row_,
        'column': column.key,
        'rowIndex': rowIndex,
        'columnIndex': columnIndex,
      },
    );
  }

  final view = b.obtain<RenderRunningTable>('runningTable', RenderRunningTable.new);
  view.configureSort(n.prop(TableViewProps.sortable), n.prop(TableViewProps.sortColumn), n.prop(TableViewProps.sortAscending));
  view.configureDirection(n.behaviors.textDirection == api.TextDirection.rtl, columns.length);
  rows = sortTableRows(sourceRows, view.sortColumn, view.sortAscending);
  view.rowLabel = (index) => columns
      .map(
        (c) =>
            '${c.label.isEmpty ? c.key : c.label}: ${switch (rows[index]) {
              final Map row => row[c.key] ?? '',
              final List row => row.elementAtOrNull(columns.indexOf(c)) ?? '',
              _ => '',
            }}',
      )
      .join(', ');
  void refreshCells() {
    view.rowHeights = [if (headerRow) math.max(minTouchRow, n.prop(TableViewProps.headerHeight)), for (final row in rows) math.max(minTouchRow, tableRowHeight(row, rowHeightKey, rowHeight))];
    view.reconcileCursor();
    for (final (row, col) in view.builtCells) {
      final (id, key, index, item) = cellAt(row, col);
      if (id == null) continue;
      r.binder?.provideItem(b.source, ProvidedItem('cell', b.instance, n.id, key), index: index, item: item);
    }
    view.changed();
  }

  view
    ..clipBehavior = clip(n.prop(TableViewProps.clipBehavior))
    ..designSize = Size(n.layout.width.value, n.layout.height.value)
    ..hugHeight = n.layout.height.fit == SizeFit.hug
    ..columns = columns
    ..columnWidth = n.prop(TableViewProps.columnWidth)
    ..rowHeaderWidth = headerColumn ? n.prop(TableViewProps.rowHeaderWidth) : 0
    ..edge = n.prop(TableViewProps.horizontalPadding)
    ..fillWidth = n.prop(TableViewProps.fillWidth) && columns.isNotEmpty
    ..stretchLastColumn = n.prop(TableViewProps.stretchLastColumn)
    ..headerRow = headerRow
    ..headerColumn = headerColumn
    ..pinHeaderRow = headerRow && n.prop(TableViewProps.pinHeaderRow)
    ..pinHeaderColumn = headerColumn && n.prop(TableViewProps.pinHeaderColumn)
    ..rowHeights = [if (headerRow) math.max(minTouchRow, n.prop(TableViewProps.headerHeight)), for (final row in rows) math.max(minTouchRow, tableRowHeight(row, rowHeightKey, rowHeight))]
    ..gridLine = lineColor.alpha == 0 || lineWidth <= 0 ? null : BorderSide(color: lineColor.flutter, width: lineWidth)
    ..columnLines = n.prop(TableViewProps.columnLines)
    ..headerBorder = headerBorderColor == null ? null : BorderSide(color: headerBorderColor, width: n.prop(TableViewProps.headerBorderWidth))
    ..headerColor = n.prop(TableViewProps.headerColor)?.flutter
    ..stripeColor = n.prop(TableViewProps.stripeColor)?.flutter
    ..hoverColor = n.prop(TableViewProps.rowHoverColor)?.flutter
    ..selectedRow = n.prop(TableViewProps.selectedRow)
    ..selectedColor = n.prop(TableViewProps.selectedRowColor)?.flutter ?? (n.prop(TableViewProps.sortable) ? ControlTokens.of(b).primary.withValues(alpha: .12) : null)
    ..focusColor = ControlTokens.of(b).focusBorder
    ..onSort = (columnIndex, ascending) {
      rows = sortTableRows(sourceRows, columns[columnIndex].key, ascending);
      refreshCells();
      r.fire(
        TriggerType.sort.name,
        event: {
          'result': {'column': columns[columnIndex].key, 'columnIndex': columnIndex, 'ascending': ascending},
        },
      );
    }
    ..onRowTap = ((rowIndex) => r.fire(
      TriggerType.rowTap.name,
      event: {
        'result': {'row': rows[rowIndex], 'rowIndex': rowIndex, 'item': rows[rowIndex]},
      },
    ))
    // The cells of the window in view: each a template slot's node box in
    // the scope of its cell.
    ..onWindow = (cells) {
      final ids = <String>[], instances = <Object?>[], built = <(int, int)>[];
      for (final (row, col) in cells) {
        final (id, key, index, item) = cellAt(row, col);
        if (id == null) continue;
        final instance = ProvidedItem('cell', b.instance, n.id, key);
        r.binder?.provideItem(b.source, instance, index: index, item: item);
        ids.add(id);
        instances.add(instance);
        built.add((row, col));
      }
      b.syncChildren(view, ids, Slot(SlotKind.root, n), instances: instances);
      return built;
    }
    ..reconcileCursor()
    ..changed();
  // New data (a variable edit, a capture's values) with as many rows leaves the node as it was, so this recipe does
  // not run again: the cells built move to their new items in place, as the table at rest's do (collections.dart).
  // Without it they kept showing their old items. (Another row count changes the node: the recipe runs again.)
  if (n.bind.containsKey('data') && r.binder != null) {
    final binder = r.binder!;
    binder.onItemsChanged(n.id, b.instance, (items) {
      if (items.length != sourceRows.length) return;
      sourceRows = items;
      rows = sortTableRows(sourceRows, view.sortColumn, view.sortAscending);
      refreshCells();
    });
  } else {
    r.binder?.onItemsChanged(n.id, b.instance, null);
  }
  chain.add(view);
}

/// [n] as the table inside its shell: filling the padded box, without the
/// shell's padding, margin or decoration.
Node tableContent(Node n) {
  final l = n.layout;
  final p = l.padding;
  api.AxisSize inner(api.AxisSize s, double pad) => s.fit == SizeFit.hug ? api.AxisSize.hug(math.max(0, s.value - pad)) : api.AxisSize.fill(math.max(0, s.value - pad));
  return n.copyWith(
    layout: l.copyWith(width: inner(l.width, p.horizontal), height: inner(l.height, p.vertical), padding: api.EdgeInsets.zero, margin: api.EdgeInsets.zero),
    decoration: api.Decoration.none,
  );
}

/// The widths of [columns] in [available] pixels: their own (or
/// [fallback]), and the room left over shared by their `flex`.
List<double> tableColumnWidths(List<TableColumn> columns, double fallback, double available) {
  final base = [for (final c in columns) c.width ?? fallback];
  final flexTotal = columns.fold<double>(0, (a, c) => a + c.flex);
  final spare = available - base.fold<double>(0, (a, b) => a + b);
  if (flexTotal <= 0 || !spare.isFinite || spare <= 0) return base;
  return [for (var i = 0; i < columns.length; i++) base[i] + spare * columns[i].flex / flexTotal];
}

/// A table that scrolls along both axes, as a `TableView` does: only the
/// cells in view are built ([onWindow]), the header row and column stay in
/// place when pinned, a body row shows the pointer over it and reports a
/// tap. Its spans are the rows' heights and the columns' widths for the
/// width it is given (`fillWidth` shares what is left; the last column can
/// take it all).
class RenderRunningTable extends RenderBox with ContainerRenderObjectMixin<RenderBox, CollectionParentData>, RenderBoxContainerDefaultsMixin<RenderBox, CollectionParentData> implements MouseTrackerAnnotation {
  RenderRunningTable() {
    _pan = PanGestureRecognizer(debugOwner: this)
      ..onStart = ((_) => _stopFling())
      ..onUpdate = ((d) => scrollBy(-d.delta))
      ..onEnd = ((d) => _fling(-d.velocity.pixelsPerSecond));
    _tap = TapGestureRecognizer(debugOwner: this)
      ..onTapUp = (d) {
        final local = globalToLocal(d.globalPosition);
        final header = headerColumnAt(local);
        if (header != null && sortable) {
          focusNode.requestFocus(highlight: false);
          _cursorRow = -1;
          _cursorColumn = header;
          _sort(header);
          return;
        }
        final row = bodyRowAt(local);
        if (row != null) {
          focusNode.requestFocus(highlight: false);
          _cursorRow = row;
          _select(row);
        }
      };
  }

  late final PanGestureRecognizer _pan;
  late final TapGestureRecognizer _tap;

  Clip clipBehavior = Clip.hardEdge;
  Size designSize = Size.zero;
  List<TableColumn> columns = const [];
  double columnWidth = 100, rowHeaderWidth = 0, edge = 0;
  bool fillWidth = false, stretchLastColumn = false;
  bool headerRow = false, headerColumn = false, pinHeaderRow = false, pinHeaderColumn = false;

  /// Every row's height, the header's first when there is one: the least
  /// a row is (a row whose cell's content is taller is as tall as that:
  /// [_rowExtents]).
  List<double> rowHeights = const [];

  /// Whether the table is as tall as its rows (at most what it is given)
  /// rather than the height it is given: a table of three rows is three
  /// rows tall, one of fifty scrolls in its cap.
  bool hugHeight = false;

  /// The height a row's tallest cell built so far needs, by row (header
  /// counted), where that is more than its [rowHeights]: text that wraps to
  /// more lines than the row has. Kept while the same rows are shown, so a
  /// row scrolled out keeps its height.
  final Map<int, double> _rowNeeds = {};

  /// The room above and under a cell's content in a row grown to it.
  static const double _grownRowPad = 8;

  /// The rows' heights as laid out: [rowHeights], each at least what its
  /// content needs.
  List<double> _rowExtents = const [];

  /// The least a column with no width of its own is squeezed to where a
  /// table that fills its width is given less than its columns' widths.
  static const double _minSqueezedColumn = 72;
  BorderSide? gridLine, headerBorder;

  /// Whether [gridLine] is drawn between columns too.
  bool columnLines = true;
  Color? headerColor, stripeColor, hoverColor, selectedColor;
  int selectedRow = -1;

  bool sortable = false, sortAscending = true, rightToLeft = false;
  bool? _configuredDirection;
  String sortColumn = '';
  bool _sortConfigured = false;
  String _configuredKey = '';
  bool _configuredAscending = true;
  Color focusColor = const Color(0xFF387DF5);
  String Function(int rowIndex)? rowLabel;
  void Function(int columnIndex, bool ascending)? onSort;
  int _cursorRow = -1, _cursorColumn = 0;

  /// A bound sort preference replaces the current one; an unchanged initial
  /// preference leaves a header choice in place across ordinary rebuilds.
  void configureSort(bool enabled, String key, bool ascending) {
    sortable = enabled;
    if (!_sortConfigured || key != _configuredKey || ascending != _configuredAscending) {
      sortColumn = key;
      sortAscending = ascending;
      _configuredKey = key;
      _configuredAscending = ascending;
      _sortConfigured = true;
    }
  }

  void configureDirection(bool rtl, int count) {
    rightToLeft = rtl;
    if (_configuredDirection != rtl) {
      _cursorColumn = rtl ? math.max(0, count - 1) : 0;
      _configuredDirection = rtl;
    }
  }

  /// When filtering removes the focused row, keep the table focused on its
  /// nearest remaining row (or its header when no rows remain).
  void reconcileCursor() {
    final count = rowHeights.length - (headerRow ? 1 : 0);
    if (_cursorRow >= count) _cursorRow = count > 0 ? count - 1 : -1;
    if (selectedRow >= count) selectedRow = -1;
    _cursorColumn = _cursorColumn.clamp(0, math.max(0, columns.length - 1));
    markNeedsSemanticsUpdate();
  }

  late final ControlFocusNode focusNode = ControlFocusNode(this, onActivate: _activate, onKey: _onKey, onFocusChange: (_) => _focusChanged())
    ..onHighlightChange = _focusChanged
    ..label = () => _semanticLabel;

  void _focusChanged() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  String get _semanticLabel {
    final bodyCount = rowHeights.length - (headerRow ? 1 : 0);
    if (_cursorRow < 0) {
      if (columns.isEmpty) return 'Table, no columns';
      final c = columns[_cursorColumn.clamp(0, columns.length - 1)];
      final name = c.label.isEmpty ? c.key : c.label;
      return sortable
          ? 'Sort by $name, ${sortColumn == c.key
                ? sortAscending
                      ? 'ascending'
                      : 'descending'
                : 'not sorted'}'
          : '$name column header';
    }
    return 'Row ${_cursorRow + 1} of $bodyCount, ${rowLabel?.call(_cursorRow) ?? ''}${selectedRow == _cursorRow ? ', selected' : ''}';
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final key = event.logicalKey;
    if ({LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.home, LogicalKeyboardKey.end}.contains(key)) {
      focusNode.requestFocus(highlight: true);
    }
    if (key == LogicalKeyboardKey.arrowDown) return _moveRow(1);
    if (key == LogicalKeyboardKey.arrowUp) return _moveRow(-1);
    if (key == LogicalKeyboardKey.home) return _setCursor(0, _cursorColumn);
    if (key == LogicalKeyboardKey.end) return _setCursor(rowHeights.length - (headerRow ? 1 : 0) - 1, _cursorColumn);
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowLeft) {
      final forward = key == LogicalKeyboardKey.arrowRight ? 1 : -1;
      return _setCursor(_cursorRow, (_cursorColumn + forward).clamp(0, math.max(0, columns.length - 1)));
    }
    return false;
  }

  bool _moveRow(int delta) {
    final count = rowHeights.length - (headerRow ? 1 : 0);
    if (count <= 0) return true;
    return _setCursor((_cursorRow + delta).clamp(headerRow ? -1 : 0, count - 1), _cursorColumn);
  }

  bool _setCursor(int row, int column) {
    if (row == _cursorRow && column == _cursorColumn) return true;
    _cursorRow = row;
    _cursorColumn = column;
    if (_columnStarts.length > column + (headerColumn ? 1 : 0) + 1) {
      final c = column + (headerColumn ? 1 : 0);
      final left = _columnStarts[c], right = _columnStarts[c + 1];
      final visibleLeft = _scroll.dx + _pinnedWidth, visibleRight = _scroll.dx + size.width;
      if (left < visibleLeft) scrollBy(Offset(left - visibleLeft, 0));
      if (right > visibleRight) scrollBy(Offset(right - visibleRight, 0));
    }
    if (row >= 0 && row < rowHeights.length - (headerRow ? 1 : 0)) {
      final top = _rowStarts[row + (headerRow ? 1 : 0)];
      final bottom = _rowStarts[row + (headerRow ? 1 : 0) + 1];
      final visibleTop = _scroll.dy + _pinnedHeight;
      final visibleBottom = _scroll.dy + size.height;
      if (top < visibleTop) scrollBy(Offset(0, top - visibleTop));
      if (bottom > visibleBottom) scrollBy(Offset(0, bottom - visibleBottom));
    }
    _focusChanged();
    return true;
  }

  void _sort(int columnIndex) {
    if (!sortable || columnIndex < 0 || columnIndex >= columns.length) return;
    final key = columns[columnIndex].key;
    sortAscending = sortColumn == key ? !sortAscending : true;
    sortColumn = key;
    selectedRow = -1;
    onSort?.call(columnIndex, sortAscending);
    _focusChanged();
  }

  void _select(int row) {
    if (row < 0 || row >= rowHeights.length - (headerRow ? 1 : 0)) return;
    selectedRow = row;
    onRowTap?.call(row);
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void _activate() {
    if (_cursorRow < 0) {
      _sort(_cursorColumn);
    } else {
      _select(_cursorRow);
    }
  }

  /// A body row was tapped (its index in the rows).
  void Function(int rowIndex)? onRowTap;

  /// Builds the cells at (row, column), header spans included, as this
  /// box's children in that order; returns the ones it built (a cell with
  /// no template is left out).
  List<(int, int)> Function(List<(int, int)> cells)? onWindow;

  /// The recipe ran: spans, looks or data may have changed.
  void changed() {
    _wanted = null;
    _rowNeeds.clear();
    markNeedsLayout();
    markNeedsPaint();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! CollectionParentData) child.parentData = CollectionParentData();
  }

  // --- spans ---

  List<double> _columnExtents = const [];
  List<double> _columnStarts = const [0], _rowStarts = const [0];

  int get _columnCount => columns.length + (headerColumn ? 1 : 0);
  double get _tableWidth => _columnStarts.last;
  double get _tableHeight => _rowStarts.last;
  double get _pinnedWidth => pinHeaderColumn && _columnCount > 0 ? _columnStarts[1] : 0;
  double get _pinnedHeight => pinHeaderRow && rowHeights.isNotEmpty ? _rowStarts[1] : 0;
  double get _headerLine => headerRow && headerBorder != null ? headerBorder!.width : 0;

  static List<double> _starts(List<double> extents) {
    final out = List<double>.filled(extents.length + 1, 0);
    for (var i = 0; i < extents.length; i++) {
      out[i + 1] = out[i] + extents[i];
    }
    return out;
  }

  void _measureSpans(double viewport) {
    final count = _columnCount;
    final widths = tableColumnWidths(columns, columnWidth, viewport - rowHeaderWidth - edge * 2);
    // Every column's width with the edges: a `fillWidth` table shares what
    // the viewport has beyond it.
    final total = rowHeaderWidth + edge * 2 + widths.fold<double>(0, (a, w) => a + w);
    final share = fillWidth && widths.isNotEmpty ? math.max(0.0, viewport - total) / widths.length : 0.0;
    // A table as wide as its place that is given less than its columns'
    // widths (a phone): the columns with no width of their own give way
    // alike, down to a width a word still fits, before it scrolls sideways.
    if (fillWidth && viewport.isFinite && total > viewport) {
      final free = [for (var i = 0; i < columns.length; i++) if (columns[i].width == null) i];
      final freeTotal = free.fold<double>(0, (a, i) => a + widths[i]);
      if (freeTotal > 0) {
        final k = math.max(0.0, freeTotal - (total - viewport)) / freeTotal;
        for (final i in free) {
          widths[i] = math.max(math.min(widths[i], _minSqueezedColumn), widths[i] * k);
        }
      }
    }
    final offset = headerColumn ? 1 : 0;
    final extents = <double>[if (headerColumn) rowHeaderWidth, for (final w in widths) w + share];
    if (stretchLastColumn && extents.isNotEmpty && viewport.isFinite) {
      // The last column takes what the others leave.
      final last = count - 1;
      final own = last < offset ? rowHeaderWidth : widths[last - offset];
      extents[last] = math.max(extents[last], viewport - (total - own));
    }
    // The table's edges are inside its first and last columns.
    if (extents.isNotEmpty) {
      extents[0] += edge;
      extents[extents.length - 1] += edge;
    }
    _columnExtents = extents;
    _columnStarts = _starts(extents);
    _measureRows();
  }

  void _measureRows() {
    _rowExtents = [for (var r = 0; r < rowHeights.length; r++) math.max(rowHeights[r], _rowNeeds[r] ?? 0)];
    _rowStarts = _starts(_rowExtents);
  }

  // --- scrolling ---

  Offset _scroll = Offset.zero;

  /// How far it is scrolled along each axis.
  Offset get scrollOffset => _scroll;

  Offset get _maxScroll => Offset(math.max(0.0, _tableWidth - size.width), math.max(0.0, _tableHeight - size.height));

  Offset _clamped(Offset v) {
    final max = _maxScroll;
    return Offset(v.dx.clamp(0.0, max.dx), v.dy.clamp(0.0, max.dy));
  }

  /// Scrolls by [delta], as a drag or the wheel does, within its extent.
  void scrollBy(Offset delta) {
    final next = _clamped(_scroll + delta);
    if (next == _scroll) return;
    _scroll = next;
    // More cells only when the window in view leaves what is built.
    if (_listEquals(_window(), _wanted)) {
      markNeedsPaint();
    } else {
      markNeedsLayout();
    }
    markNeedsSemanticsUpdate();
  }

  Ticker? _ticker;
  FrictionSimulation? _flingX, _flingY;

  void _stopFling() {
    _ticker?.stop();
  }

  void _fling(Offset velocity) {
    if (velocity.distance < 50) return;
    _flingX = FrictionSimulation(0.135, _scroll.dx, velocity.dx);
    _flingY = FrictionSimulation(0.135, _scroll.dy, velocity.dy);
    _ticker ??= Ticker(_tick);
    _ticker!
      ..stop()
      ..start();
  }

  void _tick(Duration elapsed) {
    final t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final x = _flingX!, y = _flingY!;
    final before = _scroll;
    scrollBy(Offset(x.x(t), y.x(t)) - _scroll);
    if ((x.isDone(t) && y.isDone(t)) || (_scroll == before && t > 0.05)) _ticker?.stop();
  }

  // --- the window in view ---

  List<(int, int)>? _wanted;
  List<(int, int)> _cells = const [];

  /// The cells built for the window in view, (row, column) with header spans counted, as [onWindow] returned them.
  List<(int, int)> get builtCells => _cells;

  static bool _listEquals(List<(int, int)> a, List<(int, int)>? b) {
    if (b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// The spans of [starts] that show between [from] and [to], with one more
  /// either side so a short scroll builds nothing.
  static (int, int) _range(List<double> starts, double from, double to) {
    final count = starts.length - 1;
    if (count <= 0) return (0, -1);
    var first = 0;
    while (first < count - 1 && starts[first + 1] <= from) {
      first++;
    }
    var last = first;
    while (last < count - 1 && starts[last + 1] < to) {
      last++;
    }
    return (math.max(0, first - 1), math.min(count - 1, last + 1));
  }

  List<(int, int)> _window() {
    final (r0, r1) = _range(_rowStarts, _scroll.dy + _pinnedHeight, _scroll.dy + size.height);
    final (c0, c1) = _range(_columnStarts, _scroll.dx + _pinnedWidth, _scroll.dx + size.width);
    final rows = [if (pinHeaderRow && r0 > 0) 0, for (var r = r0; r <= r1; r++) r];
    final cols = [if (pinHeaderColumn && c0 > 0) 0, for (var c = c0; c <= c1; c++) c];
    return [
      for (final r in rows)
        for (final c in cols) (r, c),
    ];
  }

  bool _rowPinned(int r) => pinHeaderRow && r == 0;
  bool _columnPinned(int c) => pinHeaderColumn && c == 0;

  /// Where a cell's content is moved to by the scroll.
  Offset _shift(int r, int c) => Offset(_columnPinned(c) ? 0 : -_scroll.dx, _rowPinned(r) ? 0 : -_scroll.dy);

  // --- layout ---

  @override
  double computeMinIntrinsicWidth(double height) => 0;
  @override
  double computeMaxIntrinsicWidth(double height) => designSize.width;
  @override
  double computeMinIntrinsicHeight(double width) => 0;
  @override
  double computeMaxIntrinsicHeight(double width) => hugHeight ? _rowsHeight : designSize.height;

  double get _rowsHeight => rowHeights.fold<double>(0, (a, h) => a + h);

  // A table needs a bounded box; where it gets none (in a scroll view), it
  // takes its design size. One that hugs its height is as tall as its rows,
  // at most what it is given.
  Size _sizeFor(BoxConstraints c, [double? rows]) => c.constrain(Size(
      c.hasBoundedWidth ? c.maxWidth : designSize.width,
      hugHeight ? math.min(rows ?? _rowsHeight, c.maxHeight) : (c.hasBoundedHeight ? c.maxHeight : designSize.height)));

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeFor(constraints);

  @override
  void performLayout() {
    size = _sizeFor(constraints);
    // A new width wraps the cells' text anew.
    if (_measuredWidth != size.width) {
      _measuredWidth = size.width;
      _rowNeeds.clear();
    }
    _measureSpans(size.width);
    // The cells in view are built and measured; a row whose content is
    // taller than the row grows to it, which moves the rows under it (and,
    // in a table as tall as its rows, the table's foot), so what is in view
    // is found again: a few rounds settle it.
    for (var round = 0; round < 4; round++) {
      if (hugHeight) size = _sizeFor(constraints, _tableHeight);
      _scroll = _clamped(_scroll);
      final window = _window();
      if (!_listEquals(window, _wanted)) {
        _wanted = window;
        final build = onWindow;
        if (build != null) invokeLayoutCallback<BoxConstraints>((_) => _cells = build(window));
      }
      var grew = false;
      var i = 0;
      for (var child = firstChild; child != null; child = childAfter(child), i++) {
        if (i >= _cells.length) continue;
        final (r, c) = _cells[i];
        if (r >= rowHeights.length || c >= _columnExtents.length) continue;
        final lead = c == 0 ? edge : 0.0, trail = c == _columnExtents.length - 1 ? edge : 0.0;
        final w = math.max(0.0, _columnExtents[c] - lead - trail);
        final line = r == 0 ? _headerLine : 0.0;
        final natural = w > 0 ? child.getMaxIntrinsicHeight(w) : 0.0;
        if (natural.isFinite && natural > rowHeights[r] - line + 0.5) {
          final need = natural + line + _grownRowPad * 2;
          if (need > (_rowNeeds[r] ?? 0) + 0.5) {
            _rowNeeds[r] = need;
            grew = true;
          }
        }
      }
      if (!grew) break;
      _measureRows();
    }
    if (hugHeight) size = _sizeFor(constraints, _tableHeight);
    _scroll = _clamped(_scroll);
    var i = 0;
    for (var child = firstChild; child != null; child = childAfter(child), i++) {
      if (i >= _cells.length) {
        child.layout(const BoxConstraints.tightFor(width: 0, height: 0));
        continue;
      }
      final (r, c) = _cells[i];
      final lead = c == 0 ? edge : 0.0, trail = c == _columnExtents.length - 1 ? edge : 0.0;
      // The header's line takes room under its cells, as a bordered box's
      // does: they center in the height above it.
      final line = r == 0 ? _headerLine : 0.0;
      final w = math.max(0.0, _columnExtents[c] - lead - trail), h = math.max(0.0, _rowExtents[r] - line);
      child.layout(BoxConstraints.loose(Size(w, h)), parentUsesSize: true);
      (child.parentData! as CollectionParentData).offset = Offset(_columnStarts[c] + lead, _rowStarts[r] + (h - child.size.height) / 2);
    }
  }

  double? _measuredWidth;

  // --- paint: in layout order, what is pinned first ---

  /// The four parts: (rows pinned, columns pinned), in paint order: the
  /// pinned corner, the pinned header row, the pinned header column, then
  /// the scrolled cells, as a header above (or beside) a list paints in
  /// Flutter. Each part is clipped to its own area, so the order only shows
  /// where two meet on a fractional edge: there the cells paint over the
  /// header's last fraction of a pixel, as a list under a header does.
  static const _parts = [(true, true), (true, false), (false, true), (false, false)];

  Rect _clipOf(bool rowsPinned, bool columnsPinned) => Rect.fromLTRB(columnsPinned ? 0 : _pinnedWidth, rowsPinned ? 0 : _pinnedHeight, columnsPinned ? _pinnedWidth : size.width, rowsPinned ? _pinnedHeight : size.height);

  int _hover = -1;

  Color? _rowColor(int r) {
    if (headerRow && r == 0) return headerColor;
    final body = r - (headerRow ? 1 : 0);
    if (body == selectedRow && selectedColor != null) return selectedColor;
    if (body == _hover && hoverColor != null) return hoverColor;
    return stripeColor != null && body.isOdd ? stripeColor : null;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (rowHeights.isEmpty && _columnExtents.isEmpty) return;
    context.pushClipRect(needsCompositing, offset, Offset.zero & size, (context, offset) {
      for (final (rowsPinned, columnsPinned) in _parts) {
        if (rowsPinned && !pinHeaderRow || columnsPinned && !pinHeaderColumn) continue;
        final clip = _clipOf(rowsPinned, columnsPinned);
        if (clip.isEmpty) continue;
        context.pushClipRect(needsCompositing, offset, clip, (context, offset) => _paintPart(context, offset, rowsPinned, columnsPinned));
      }
      if (focusNode.showsHighlight && rowHeights.isNotEmpty && columns.isNotEmpty) {
        final canvas = context.canvas;
        final rect = _cursorRow < 0 && headerRow
            ? Rect.fromLTWH(_columnStarts[_cursorColumn + (headerColumn ? 1 : 0)] - _scroll.dx, 0, _columnExtents[_cursorColumn + (headerColumn ? 1 : 0)], _pinnedHeight)
            : _cursorRow >= 0
            ? Rect.fromLTWH(1, _rowStarts[_cursorRow + (headerRow ? 1 : 0)] - _scroll.dy, size.width - 2, _rowExtents[_cursorRow + (headerRow ? 1 : 0)])
            : Rect.zero;
        if (!rect.isEmpty)
          canvas.drawRect(
            rect.deflate(1).shift(offset),
            Paint()
              ..color = focusColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
      }
    }, clipBehavior: clipBehavior == Clip.none ? Clip.hardEdge : clipBehavior);
  }

  void _paintPart(PaintingContext context, Offset offset, bool rowsPinned, bool columnsPinned) {
    final canvas = context.canvas;
    final dx = columnsPinned ? 0.0 : -_scroll.dx, dy = rowsPinned ? 0.0 : -_scroll.dy;
    final origin = offset + Offset(dx, dy);
    // The rows and columns of this part that show.
    final (r0, r1) = rowsPinned ? (0, 0) : _range(_rowStarts, _scroll.dy + _pinnedHeight, _scroll.dy + size.height);
    final (c0, c1) = columnsPinned ? (0, 0) : _range(_columnStarts, _scroll.dx + _pinnedWidth, _scroll.dx + size.width);
    if (r1 < r0 || c1 < c0) return;
    final left = _columnStarts[c0], right = _columnStarts[c1 + 1];
    final top = _rowStarts[r0], bottom = _rowStarts[r1 + 1];
    for (var r = r0; r <= r1; r++) {
      if (rowsPinned != _rowPinned(r)) continue;
      final color = _rowColor(r);
      if (color != null) {
        canvas.drawRect(Rect.fromLTRB(left, _rowStarts[r], right, _rowStarts[r + 1]).shift(origin), Paint()..color = color);
      }
    }
    if (headerColumn && headerColor != null && c0 == 0 && columnsPinned == _columnPinned(0)) {
      canvas.drawRect(Rect.fromLTRB(_columnStarts[0], top, _columnStarts[1], bottom).shift(origin), Paint()..color = headerColor!);
    }
    var i = 0;
    for (var child = firstChild; child != null && i < _cells.length; child = childAfter(child), i++) {
      final (r, c) = _cells[i];
      if (_rowPinned(r) != rowsPinned || _columnPinned(c) != columnsPinned) continue;
      context.paintChild(child, origin + (child.parentData! as CollectionParentData).offset);
    }
    // A span's trailing line, inside the span at its end; the header's own
    // under the header row.
    final line = gridLine;
    if (line != null && line.width > 0) {
      final paint = Paint()..color = line.color;
      for (var c = c0; columnLines && c <= c1; c++) {
        canvas.drawRect(Rect.fromLTWH(_columnStarts[c + 1] - line.width, top, line.width, bottom - top).shift(origin), paint);
      }
      for (var r = r0; r <= r1; r++) {
        if (r == 0 && _headerLine > 0) continue;
        canvas.drawRect(Rect.fromLTWH(left, _rowStarts[r + 1] - line.width, right - left, line.width).shift(origin), paint);
      }
    }
    if (_headerLine > 0 && r0 == 0 && rowsPinned == _rowPinned(0)) {
      canvas.drawRect(Rect.fromLTWH(left, _rowStarts[1] - _headerLine, right - left, _headerLine).shift(origin), Paint()..color = headerBorder!.color);
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    var i = 0;
    for (var c = firstChild; c != null; c = childAfter(c), i++) {
      if (!identical(c, child)) continue;
      final at = (child.parentData! as CollectionParentData).offset + (i < _cells.length ? _shift(_cells[i].$1, _cells[i].$2) : Offset.zero);
      transform.translateByDouble(at.dx, at.dy, 0, 1);
      return;
    }
  }

  // --- pointer ---

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // What is pinned first (the parts' areas don't overlap).
    for (final (rowsPinned, columnsPinned) in _parts) {
      if (rowsPinned && !pinHeaderRow || columnsPinned && !pinHeaderColumn) continue;
      if (!_clipOf(rowsPinned, columnsPinned).contains(position)) continue;
      final children = getChildrenAsList();
      for (var i = math.min(children.length, _cells.length) - 1; i >= 0; i--) {
        final (r, c) = _cells[i];
        if (_rowPinned(r) != rowsPinned || _columnPinned(c) != columnsPinned) continue;
        final child = children[i];
        final at = (child.parentData! as CollectionParentData).offset + _shift(r, c);
        if (result.addWithPaintOffset(
          offset: at,
          position: position,
          hitTest: (result, p) => child.hitTest(result, position: p),
        )) {
          return true;
        }
      }
      return false;
    }
    return false;
  }

  /// The body row at [local] (its index in the rows), or null over the
  /// header or past the last row.
  int? bodyRowAt(Offset local) {
    if (rowHeights.isEmpty || local.dy < 0 || local.dy >= size.height) return null;
    final y = pinHeaderRow && local.dy < _pinnedHeight ? local.dy : local.dy + _scroll.dy;
    if (y >= _tableHeight) return null;
    var r = 0;
    while (r < rowHeights.length - 1 && _rowStarts[r + 1] <= y) {
      r++;
    }
    final body = r - (headerRow ? 1 : 0);
    return body < 0 ? null : body;
  }

  /// The sortable body column under a header press, without the row header.
  int? headerColumnAt(Offset local) {
    if (!headerRow || local.dy < 0 || local.dy >= (_rowExtents.isEmpty ? rowHeights.first : _rowExtents.first) || local.dx < 0 || local.dx >= size.width) return null;
    final x = pinHeaderColumn && local.dx < _pinnedWidth ? local.dx : local.dx + _scroll.dx;
    for (var c = headerColumn ? 1 : 0; c < _columnExtents.length; c++) {
      if (x >= _columnStarts[c] && x < _columnStarts[c + 1]) return c - (headerColumn ? 1 : 0);
    }
    return null;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      _pan.addPointer(event);
      _tap.addPointer(event);
    } else if (event is PointerHoverEvent) {
      _setHover(bodyRowAt(event.localPosition) ?? -1);
    } else if (event is PointerScrollEvent) {
      GestureBinding.instance.pointerSignalResolver.register(event, (e) => scrollBy((e as PointerScrollEvent).scrollDelta));
    }
  }

  void _setHover(int row) {
    if (row == _hover) return;
    _hover = row;
    if (hoverColor != null) markNeedsPaint();
  }

  @override
  PointerEnterEventListener? get onEnter => null;
  @override
  PointerExitEventListener? get onExit =>
      (_) => _setHover(-1);
  @override
  MouseCursor get cursor => MouseCursor.defer;
  @override
  bool get validForMouseTracker => attached;

  @override
  void detach() {
    _stopFling();
    super.detach();
    focusNode.leave();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    final root = RenderControlRoot.of(this);
    if (root != null) focusNode.join(root.focus);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    final count = rowHeights.length - (headerRow ? 1 : 0);
    config
      ..isSemanticBoundary = true
      ..isButton = true
      ..isFocused = focusNode.hasFocus
      ..isEnabled = true
      ..isSelected = _cursorRow >= 0 && selectedRow == _cursorRow
      ..label = _semanticLabel
      ..value = _cursorRow < 0 ? 'header ${_cursorColumn + 1} of ${columns.length}' : 'row ${_cursorRow + 1} of ${rowHeights.length - (headerRow ? 1 : 0)}'
      ..textDirection = rightToLeft ? TextDirection.rtl : TextDirection.ltr
      ..onTap = _activate
      ..onFocus = () {
        focusNode.requestFocus();
      };
    if (count > 0) {
      final next = (_cursorRow + 1).clamp(0, count - 1);
      final previous = (_cursorRow - 1).clamp(headerRow ? -1 : 0, count - 1);
      config
        ..increasedValue = 'row ${next + 1} of $count'
        ..decreasedValue = previous < 0 ? 'column header' : 'row ${previous + 1} of $count'
        ..onIncrease = () {
          _moveRow(1);
        }
        ..onDecrease = () {
          _moveRow(-1);
        };
    }
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {}

  @override
  void dispose() {
    _ticker?.dispose();
    _pan.dispose();
    _tap.dispose();
    super.dispose();
  }
}

/// A body row's height: its own number at [key] (when the row is a map that
/// has one), else [fallback].
double tableRowHeight(Object? row, String key, double fallback) {
  if (key.isEmpty || row is! Map) return fallback;
  final v = row[key];
  final h = v is num ? v.toDouble() : double.tryParse('$v');
  return h != null && h.isFinite && h > 0 ? h : fallback;
}

/// Stable data ordering for a table header. Numbers sort numerically,
/// strings without case, and missing values last in either direction.
List<Object?> sortTableRows(List<Object?> source, String key, bool ascending) {
  if (key.isEmpty) return [...source];
  final indexed = [for (var i = 0; i < source.length; i++) (i, source[i])];
  Object? value(Object? row) => row is Map ? row[key] : null;
  indexed.sort((a, b) {
    final x = value(a.$2), y = value(b.$2);
    if (x == null || y == null)
      return x == y
          ? a.$1.compareTo(b.$1)
          : x == null
          ? 1
          : -1;
    final order = x is num && y is num ? x.compareTo(y) : '$x'.toLowerCase().compareTo('$y'.toLowerCase());
    return order == 0
        ? a.$1.compareTo(b.$1)
        : ascending
        ? order
        : -order;
  });
  return [for (final entry in indexed) entry.$2];
}
