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

import 'package:codelessly_api/core.dart' as api show AxisSize, Decoration, EdgeInsets;
import 'package:codelessly_api/core.dart' show Node, SizeFit, TableColumn, TableViewProps, TriggerType;
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../render/convert.dart';
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
  return d.fills.any((f) => f.visible) ||
      d.strokes.any((s) => s.visible) ||
      d.effects.any((e) => e.visible) ||
      !d.radius.isZero;
}

/// A running table view [n]: its fit box, then a [RenderRunningTable] that
/// builds the cells in view.
void tableViewRuntimeRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  chain.add(b.fitBox('fit', n.layout.width.fit, n.layout.height.fit, Size(n.layout.width.value, n.layout.height.value)));
  final r = ListRuntime(b, n);
  final rows = tableRowsOf(r);
  String? slot(String name) => n.slots[name] != null && b.nodeOf(n.slots[name]!) != null ? n.slots[name] : null;
  final cell = slot(TableViewProps.cell), columnHeader = slot(TableViewProps.columnHeader);
  final rowHeader = slot(TableViewProps.rowHeader), corner = slot(TableViewProps.corner);
  final List<TableColumn> columns = n.prop(TableViewProps.columns);
  final headerRow = columnHeader != null, headerColumn = rowHeader != null;
  final rowOffset = headerRow ? 1 : 0, columnOffset = headerColumn ? 1 : 0;
  final lineColor = n.prop(TableViewProps.gridLineColor), lineWidth = n.prop(TableViewProps.gridLineWidth);
  final headerBorderColor = n.prop(TableViewProps.headerBorderColor)?.flutter;
  final rowHeightKey = n.prop(TableViewProps.rowHeightKey), rowHeight = n.prop(TableViewProps.rowHeight);
  // Its padding (a bordered frame's inset) holds the cells in from the
  // edge, so they don't paint over the border.
  final padding = n.layout.padding.flutter;
  if (padding != EdgeInsets.zero) {
    chain.add(b.obtain<RenderPadding>('tablePadding', () => RenderPadding(padding: padding, textDirection: TextDirection.ltr))
      ..padding = padding);
  }
  final view = b.obtain<RenderRunningTable>('runningTable', RenderRunningTable.new);
  view
    ..clipBehavior = clip(n.prop(TableViewProps.clipBehavior))
    ..designSize = Size(n.layout.width.value, n.layout.height.value)
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
    ..rowHeights = [
      if (headerRow) n.prop(TableViewProps.headerHeight),
      for (final row in rows) tableRowHeight(row, rowHeightKey, rowHeight),
    ]
    ..gridLine = lineColor.alpha == 0 || lineWidth <= 0 ? null : BorderSide(color: lineColor.flutter, width: lineWidth)
    ..headerBorder =
        headerBorderColor == null ? null : BorderSide(color: headerBorderColor, width: n.prop(TableViewProps.headerBorderWidth))
    ..headerColor = n.prop(TableViewProps.headerColor)?.flutter
    ..stripeColor = n.prop(TableViewProps.stripeColor)?.flutter
    ..hoverColor = n.prop(TableViewProps.rowHoverColor)?.flutter
    ..selectedRow = n.prop(TableViewProps.selectedRow)
    ..selectedColor = n.prop(TableViewProps.selectedRowColor)?.flutter
    ..onRowTap = ((rowIndex) => r.fire(TriggerType.rowTap.name, event: {
          'result': {'row': rows[rowIndex], 'rowIndex': rowIndex, 'item': rows[rowIndex]},
        }))
    // The cells of the window in view: each a template slot's node box in
    // the scope of its cell.
    ..onWindow = (cells) {
      final ids = <String>[], instances = <Object?>[], built = <(int, int)>[];
      for (final (row, col) in cells) {
        final inHeaderRow = headerRow && row == 0, inHeaderColumn = headerColumn && col == 0;
        final rowIndex = row - rowOffset, columnIndex = col - columnOffset;
        final String? id;
        final Object key;
        final int index;
        final Object? item;
        if (inHeaderRow && inHeaderColumn) {
          (id, key, index, item) = (corner, 'corner', 0, null);
        } else if (inHeaderRow) {
          final column = columns[columnIndex];
          (id, key, index, item) = (
            columnHeader,
            ('column', columnIndex),
            columnIndex,
            {'label': column.label, 'column': column.key, 'columnIndex': columnIndex},
          );
        } else if (inHeaderColumn) {
          (id, key, index, item) = (rowHeader, ('row', rowIndex), rowIndex, {'row': rows[rowIndex], 'rowIndex': rowIndex});
        } else {
          final column = columns[columnIndex];
          final row_ = rows[rowIndex];
          (id, key, index, item) = (
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
    ..changed();
  chain.add(view);
}

/// [n] as the table inside its shell: filling the padded box, without the
/// shell's padding, margin or decoration.
Node tableContent(Node n) {
  final l = n.layout;
  final p = l.padding;
  api.AxisSize inner(api.AxisSize s, double pad) => s.fit == SizeFit.hug
      ? api.AxisSize.hug(math.max(0, s.value - pad))
      : api.AxisSize.fill(math.max(0, s.value - pad));
  return n.copyWith(
    layout: l.copyWith(
      width: inner(l.width, p.horizontal),
      height: inner(l.height, p.vertical),
      padding: api.EdgeInsets.zero,
      margin: api.EdgeInsets.zero,
    ),
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
class RenderRunningTable extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, CollectionParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, CollectionParentData>
    implements MouseTrackerAnnotation {
  RenderRunningTable() {
    _pan = PanGestureRecognizer(debugOwner: this)
      ..onStart = ((_) => _stopFling())
      ..onUpdate = ((d) => scrollBy(-d.delta))
      ..onEnd = ((d) => _fling(-d.velocity.pixelsPerSecond));
    _tap = TapGestureRecognizer(debugOwner: this)
      ..onTapUp = (d) {
        final row = bodyRowAt(globalToLocal(d.globalPosition));
        if (row != null) onRowTap?.call(row);
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

  /// Every row's height, the header's first when there is one.
  List<double> rowHeights = const [];
  BorderSide? gridLine, headerBorder;
  Color? headerColor, stripeColor, hoverColor, selectedColor;
  int selectedRow = -1;

  /// A body row was tapped (its index in the rows).
  void Function(int rowIndex)? onRowTap;

  /// Builds the cells at (row, column), header spans included, as this
  /// box's children in that order; returns the ones it built (a cell with
  /// no template is left out).
  List<(int, int)> Function(List<(int, int)> cells)? onWindow;

  /// The recipe ran: spans, looks or data may have changed.
  void changed() {
    _wanted = null;
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
    final offset = headerColumn ? 1 : 0;
    final extents = <double>[
      if (headerColumn) rowHeaderWidth,
      for (final w in widths) w + share,
    ];
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
    _rowStarts = _starts(rowHeights);
  }

  // --- scrolling ---

  Offset _scroll = Offset.zero;

  /// How far it is scrolled along each axis.
  Offset get scrollOffset => _scroll;

  Offset get _maxScroll =>
      Offset(math.max(0.0, _tableWidth - size.width), math.max(0.0, _tableHeight - size.height));

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
  double computeMaxIntrinsicHeight(double width) => designSize.height;

  // A table needs a bounded box; where it gets none (in a scroll view), it
  // takes its design size.
  Size _sizeFor(BoxConstraints c) => c.constrain(
      Size(c.hasBoundedWidth ? c.maxWidth : designSize.width, c.hasBoundedHeight ? c.maxHeight : designSize.height));

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeFor(constraints);

  @override
  void performLayout() {
    size = _sizeFor(constraints);
    _measureSpans(size.width);
    _scroll = _clamped(_scroll);
    final window = _window();
    if (!_listEquals(window, _wanted)) {
      _wanted = window;
      final build = onWindow;
      if (build != null) invokeLayoutCallback<BoxConstraints>((_) => _cells = build(window));
    }
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
      final w = math.max(0.0, _columnExtents[c] - lead - trail), h = math.max(0.0, rowHeights[r] - line);
      child.layout(BoxConstraints.loose(Size(w, h)), parentUsesSize: true);
      (child.parentData! as CollectionParentData).offset =
          Offset(_columnStarts[c] + lead, _rowStarts[r] + (h - child.size.height) / 2);
    }
  }

  // --- paint: the body, then what is pinned over it ---

  /// The four parts: (rows pinned, columns pinned), in paint order.
  static const _parts = [(false, false), (true, false), (false, true), (true, true)];

  Rect _clipOf(bool rowsPinned, bool columnsPinned) => Rect.fromLTRB(
        columnsPinned ? 0 : _pinnedWidth,
        rowsPinned ? 0 : _pinnedHeight,
        columnsPinned ? _pinnedWidth : size.width,
        rowsPinned ? _pinnedHeight : size.height,
      );

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
      for (var c = c0; c <= c1; c++) {
        canvas.drawRect(Rect.fromLTWH(_columnStarts[c + 1] - line.width, top, line.width, bottom - top).shift(origin), paint);
      }
      for (var r = r0; r <= r1; r++) {
        if (r == 0 && _headerLine > 0) continue;
        canvas.drawRect(Rect.fromLTWH(left, _rowStarts[r + 1] - line.width, right - left, line.width).shift(origin), paint);
      }
    }
    if (_headerLine > 0 && r0 == 0 && rowsPinned == _rowPinned(0)) {
      canvas.drawRect(
          Rect.fromLTWH(left, _rowStarts[1] - _headerLine, right - left, _headerLine).shift(origin), Paint()..color = headerBorder!.color);
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
    // What is pinned is on top.
    for (final (rowsPinned, columnsPinned) in _parts.reversed) {
      if (rowsPinned && !pinHeaderRow || columnsPinned && !pinHeaderColumn) continue;
      if (!_clipOf(rowsPinned, columnsPinned).contains(position)) continue;
      final children = getChildrenAsList();
      for (var i = math.min(children.length, _cells.length) - 1; i >= 0; i--) {
        final (r, c) = _cells[i];
        if (_rowPinned(r) != rowsPinned || _columnPinned(c) != columnsPinned) continue;
        final child = children[i];
        final at = (child.parentData! as CollectionParentData).offset + _shift(r, c);
        if (result.addWithPaintOffset(offset: at, position: position, hitTest: (result, p) => child.hitTest(result, position: p))) {
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
  PointerExitEventListener? get onExit => (_) => _setHover(-1);
  @override
  MouseCursor get cursor => MouseCursor.defer;
  @override
  bool get validForMouseTracker => attached;

  @override
  void detach() {
    _stopFling();
    super.detach();
  }

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
