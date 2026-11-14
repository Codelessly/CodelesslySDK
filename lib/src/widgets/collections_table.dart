// A running table view: a TableView
// (two_dimensional_scrollables) that scrolls along both axes, builds only
// the cells on screen and pins its header row and column. Its rows are its
// bound data (else `rowCount` indexes) and its columns its `columns`; each
// cell is a template slot's node box in the scope of its cell
// (`${item.value}`, `${item.label}`, `${item.rowIndex}`...).
//
// On a design canvas (not animating) the table keeps its render objects at
// rest (collections.dart).
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api show AxisSize, Decoration, EdgeInsets;
import 'package:codelessly_api/core.dart' show Node, SizeFit, TableColumn, TableViewProps, TriggerType;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import '../render/convert.dart';
import '../render/recipe.dart';
import '../runtime/expressions/bindings.dart';
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

/// A running table view [n]: its fit box, then a [TableView] island.
void tableViewRuntimeRecipe(NodeBuilder b, Node n, List<RenderBox> chain) => _tableIsland(b, n, chain);

void _tableIsland(NodeBuilder b, Node n, List<RenderBox> chain) {
  chain.add(b.fitBox('fit', n.layout.width.fit, n.layout.height.fit, Size(n.layout.width.value, n.layout.height.value)));
  final runtime = ListRuntime(b, n);
  final rows = tableRowsOf(runtime);
  chain.add(b.island('table', (context) => RuntimeTableView(runtime: runtime, rows: rows)));
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

class RuntimeTableView extends StatefulWidget {
  const RuntimeTableView({super.key, required this.runtime, required this.rows});

  final ListRuntime runtime;
  final List<Object?> rows;

  @override
  State<RuntimeTableView> createState() => _RuntimeTableViewState();
}

class _RuntimeTableViewState extends State<RuntimeTableView> {
  /// The body row under the pointer, -1 for none.
  int _hover = -1;

  @override
  Widget build(BuildContext context) {
    final r = widget.runtime, n = r.node;
    final rows = widget.rows;
    String? slot(String name) => n.slots[name] != null && r.b.nodeOf(n.slots[name]!) != null ? n.slots[name] : null;
    final cell = slot(TableViewProps.cell), columnHeader = slot(TableViewProps.columnHeader);
    final rowHeader = slot(TableViewProps.rowHeader), corner = slot(TableViewProps.corner);
    final List<TableColumn> columns = n.prop(TableViewProps.columns);
    final headerRow = columnHeader != null, headerColumn = rowHeader != null;
    final rowOffset = headerRow ? 1 : 0, columnOffset = headerColumn ? 1 : 0;
    final lineColor = n.prop(TableViewProps.gridLineColor), lineWidth = n.prop(TableViewProps.gridLineWidth);
    final line = lineColor.alpha == 0 || lineWidth <= 0 ? BorderSide.none : BorderSide(color: lineColor.flutter, width: lineWidth);
    final headerColor = n.prop(TableViewProps.headerColor)?.flutter;
    final stripe = n.prop(TableViewProps.stripeColor)?.flutter;
    final fill = n.prop(TableViewProps.fillWidth) && columns.isNotEmpty;
    final rowHeightKey = n.prop(TableViewProps.rowHeightKey), rowHeight = n.prop(TableViewProps.rowHeight);

    Widget template(String? id, Object key, int index, Object? item) {
      if (id == null) return const SizedBox.shrink();
      final instance = ProvidedItem('cell', r.b.instance, n.id, key);
      r.binder?.provideItem(r.b.source, instance, index: index, item: item);
      return SizedBox.expand(
        child: Align(alignment: Alignment.centerLeft, child: NodeChild(tree: r.tree, id: id, instance: instance)),
      );
    }

    final edge = n.prop(TableViewProps.horizontalPadding);
    final headerBorderColor = n.prop(TableViewProps.headerBorderColor)?.flutter;
    final headerBorder = headerBorderColor == null
        ? null
        : BorderSide(color: headerBorderColor, width: n.prop(TableViewProps.headerBorderWidth));
    final hoverColor = n.prop(TableViewProps.rowHoverColor)?.flutter;
    final selected = n.prop(TableViewProps.selectedRow);
    final selectedColor = n.prop(TableViewProps.selectedRowColor)?.flutter;
    final lastColumn = columns.length + columnOffset - 1;

    void tapRow(int rowIndex) => r.fire(TriggerType.rowTap.name, event: {
          'result': {'row': rows[rowIndex], 'rowIndex': rowIndex, 'item': rows[rowIndex]},
        });

    // A table needs a bounded box; where it gets none (in a scroll view), it
    // takes its design size. Its padding (a bordered frame's inset) holds
    // the cells in from the edge, so they don't paint over the border.
    final padding = n.layout.padding.flutter;
    final Widget table = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth ? constraints.maxWidth : n.layout.width.value;
        final headerWidth = headerColumn ? n.prop(TableViewProps.rowHeaderWidth) : 0.0;
        final widths = tableColumnWidths(columns, n.prop(TableViewProps.columnWidth), width - headerWidth - edge * 2);
        // Every column's width with the edges: a `fillWidth` table shares
        // what the viewport has beyond it.
        final laidTotal = headerWidth + edge * 2 + widths.fold<double>(0, (a, w) => a + w);
        return SizedBox(
        width: constraints.hasBoundedWidth ? null : n.layout.width.value,
        height: constraints.hasBoundedHeight ? null : n.layout.height.value,
        child: TableView.builder(
          clipBehavior: clip(n.prop(TableViewProps.clipBehavior)),
          diagonalDragBehavior: DiagonalDragBehavior.free,
          rowCount: rows.length + rowOffset,
          columnCount: columns.length + columnOffset,
          pinnedRowCount: headerRow && n.prop(TableViewProps.pinHeaderRow) ? 1 : 0,
          pinnedColumnCount: headerColumn && n.prop(TableViewProps.pinHeaderColumn) ? 1 : 0,
          columnBuilder: (index) {
            final header = headerColumn && index == 0;
            var width = header ? headerWidth : widths[index - columnOffset];
            final count = columns.length + columnOffset;
            if (n.prop(TableViewProps.stretchLastColumn) && index == count - 1 && constraints.hasBoundedWidth) {
              // The last column takes what the others leave.
              width = math.max(width, constraints.maxWidth - (laidTotal - width));
            }
            return TableSpan(
              extent: header || !fill ? FixedTableSpanExtent(width) : FillTableSpanExtent(width, laidTotal, columns.length),
              padding: SpanPadding(leading: index == 0 ? edge : 0, trailing: index == lastColumn ? edge : 0),
              foregroundDecoration: TableSpanDecoration(border: TableSpanBorder(trailing: line)),
              backgroundDecoration: header && headerColor != null ? TableSpanDecoration(color: headerColor) : null,
            );
          },
          rowBuilder: (index) {
            final header = headerRow && index == 0;
            final body = index - rowOffset;
            final Color? background = header
                ? headerColor
                : body == selected && selectedColor != null
                    ? selectedColor
                    : body == _hover && hoverColor != null
                        ? hoverColor
                        : (stripe != null && body.isOdd ? stripe : null);
            // The header's line takes room under its cells, as a bordered
            // box's does: they centre in the height above it.
            final headerLine = header && headerBorder != null ? headerBorder.width : 0.0;
            return TableSpan(
              extent: FixedTableSpanExtent(header
                  ? math.max(0.0, n.prop(TableViewProps.headerHeight) - headerLine)
                  : tableRowHeight(rows[body], rowHeightKey, rowHeight)),
              padding: headerLine > 0 ? SpanPadding(trailing: headerLine) : null,
              foregroundDecoration: TableSpanDecoration(
                  border: TableSpanBorder(trailing: header && headerBorder != null ? headerBorder : line)),
              backgroundDecoration: background == null ? null : TableSpanDecoration(color: background),
              onEnter: header || hoverColor == null ? null : (_) => setState(() => _hover = body),
              onExit: header || hoverColor == null ? null : (_) => setState(() => _hover = _hover == body ? -1 : _hover),
              recognizerFactories: header
                  ? const {}
                  : {
                      TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                        () => TapGestureRecognizer(),
                        (t) => t.onTap = () => tapRow(body),
                      ),
                    },
            );
          },
          cellBuilder: (context, vicinity) {
            final inHeaderRow = headerRow && vicinity.row == 0;
            final inHeaderColumn = headerColumn && vicinity.column == 0;
            final rowIndex = vicinity.row - rowOffset, columnIndex = vicinity.column - columnOffset;
            if (inHeaderRow && inHeaderColumn) return TableViewCell(child: template(corner, 'corner', 0, null));
            if (inHeaderRow) {
              final column = columns[columnIndex];
              return TableViewCell(
                child: template(columnHeader, ('column', columnIndex), columnIndex, {
                  'label': column.label,
                  'column': column.key,
                  'columnIndex': columnIndex,
                }),
              );
            }
            final row = rows[rowIndex];
            if (inHeaderColumn) {
              return TableViewCell(
                child: template(rowHeader, ('row', rowIndex), rowIndex, {'row': row, 'rowIndex': rowIndex}),
              );
            }
            final column = columns[columnIndex];
            final value = switch (row) {
              final Map m => m[column.key],
              final List l => l.elementAtOrNull(columnIndex),
              _ => null,
            };
            return TableViewCell(
              child: template(cell, (rowIndex, columnIndex), rowIndex, {
                'value': value,
                'row': row,
                'column': column.key,
                'rowIndex': rowIndex,
                'columnIndex': columnIndex,
              }),
            );
          },
        ),
      );
      },
    );
    return padding == EdgeInsets.zero ? table : Padding(padding: padding, child: table);
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

/// A body column of a `fillWidth` table: its [width] plus an equal share
/// ([count] columns) of what the viewport has beyond the [total] width of
/// every column.
class FillTableSpanExtent extends TableSpanExtent {
  const FillTableSpanExtent(this.width, this.total, this.count);

  final double width, total;
  final int count;

  @override
  double calculateExtent(TableSpanExtentDelegate delegate) =>
      width + (count == 0 ? 0 : math.max(0.0, delegate.viewportExtent - total) / count);
}
