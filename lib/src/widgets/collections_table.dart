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

import 'package:codelessly_api/codelessly_api.dart' show Node, TableColumn, TableViewProps;
import 'package:flutter/material.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import '../render/convert.dart';
import '../render/recipe.dart';
import '../runtime/expressions/bindings.dart';
import 'collections_list_runtime.dart';

/// The rows of a running table [r]: its bound data, or `rowCount` indexes.
List<Object?> tableRowsOf(ListRuntime r) {
  if (r.node.bind.containsKey('data')) return r.binder?.itemsOf(r.tree.source, r.node, r.b.instance) ?? const [];
  return List<Object?>.generate(math.max(0, r.node.prop(TableViewProps.rowCount) ?? 0), (i) => i);
}

/// A running table view [n]: its fit box, then a [TableView] island.
void tableViewRuntimeRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  chain.add(b.fitBox('fit', n.layout.width.fit, n.layout.height.fit, Size(n.layout.width.value, n.layout.height.value)));
  final runtime = ListRuntime(b, n);
  final rows = tableRowsOf(runtime);
  chain.add(b.island('table', (context) => RuntimeTableView(runtime: runtime, rows: rows)));
}

class RuntimeTableView extends StatelessWidget {
  const RuntimeTableView({super.key, required this.runtime, required this.rows});

  final ListRuntime runtime;
  final List<Object?> rows;

  @override
  Widget build(BuildContext context) {
    final r = runtime, n = r.node;
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

    Widget template(String? id, Object key, int index, Object? item) {
      if (id == null) return const SizedBox.shrink();
      final instance = ProvidedItem('cell', r.b.instance, n.id, key);
      r.binder?.provideItem(r.tree.source, instance, index: index, item: item);
      return SizedBox.expand(
        child: Align(alignment: Alignment.centerLeft, child: NodeChild(tree: r.tree, id: id, instance: instance)),
      );
    }

    // A table needs a bounded box; where it gets none (in a scroll view), it
    // takes its design size.
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
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
            double widthOf(int i) => headerColumn && i == 0
                ? n.prop(TableViewProps.rowHeaderWidth)
                : columns[i - columnOffset].width ?? n.prop(TableViewProps.columnWidth);
            var width = widthOf(index);
            final count = columns.length + columnOffset;
            if (n.prop(TableViewProps.stretchLastColumn) && index == count - 1 && constraints.hasBoundedWidth) {
              var others = 0.0;
              for (var i = 0; i < count - 1; i++) {
                others += widthOf(i);
              }
              width = math.max(width, constraints.maxWidth - others);
            }
            return TableSpan(
              extent: FixedTableSpanExtent(width),
              foregroundDecoration: TableSpanDecoration(border: TableSpanBorder(trailing: line)),
              backgroundDecoration: header && headerColor != null ? TableSpanDecoration(color: headerColor) : null,
            );
          },
          rowBuilder: (index) {
            final header = headerRow && index == 0;
            final body = index - rowOffset;
            return TableSpan(
              extent: FixedTableSpanExtent(header ? n.prop(TableViewProps.headerHeight) : n.prop(TableViewProps.rowHeight)),
              foregroundDecoration: TableSpanDecoration(border: TableSpanBorder(trailing: line)),
              backgroundDecoration: header
                  ? (headerColor == null ? null : TableSpanDecoration(color: headerColor))
                  : (stripe != null && body.isOdd ? TableSpanDecoration(color: stripe) : null),
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
      ),
    );
  }
}
