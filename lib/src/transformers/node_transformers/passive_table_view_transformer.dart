import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import '../../../codelessly_sdk.dart';

/// Renders a [TableViewNode] with a [TableView]: it scrolls along both
/// axes, builds only the cells on screen, and pins its header row and
/// column.
class PassiveTableViewTransformer extends NodeWidgetTransformer<TableViewNode> {
  /// Creates a [PassiveTableViewTransformer].
  PassiveTableViewTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    TableViewNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) => PassiveTableViewWidget(node: node, manager: manager, settings: settings);
}

/// The columns of [node]: a list bound to `variables['columns']`, else its
/// [TableViewProperties.columns].
List<TableColumnModel> tableColumnsOf(
  TableViewNode node,
  ScopedValues scopedValues,
) {
  final String? path = node.variables['columns'];
  if (path != null && path.trim().isNotEmpty) {
    final List? bound = PropertyValueDelegate.getVariableValueFromPath<List>(
      path,
      scopedValues: scopedValues,
    );
    if (bound != null)
      return [for (final v in bound) TableColumnModel.fromValue(v)];
  }
  return node.properties.columns;
}

/// The rows of [node]: its bound data, or [TableViewProperties.rowCount]
/// row indexes.
List<Object?> tableRowsOf(TableViewNode node, ScopedValues scopedValues) {
  final String? path = node.variables['data'];
  if (path != null && path.trim().isNotEmpty) {
    return PropertyValueDelegate.getVariableValueFromPath<List>(
          path,
          scopedValues: scopedValues,
        )?.cast<Object?>() ??
        const [];
  }
  return List<Object?>.generate(node.properties.rowCount ?? 0, (i) => i);
}

/// The table of a [TableViewNode].
class PassiveTableViewWidget extends StatelessWidget {
  /// The node.
  final TableViewNode node;

  /// Builds the cell template nodes.
  final NodeTransformerManager manager;

  /// The settings the node is built with.
  final WidgetBuildSettings settings;

  /// Creates a [PassiveTableViewWidget].
  const PassiveTableViewWidget({
    super.key,
    required this.node,
    required this.manager,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final TableViewProperties p = node.properties;
    final ScopedValues scopedValues = ScopedValues.of(context);
    final List<TableColumnModel> columns = tableColumnsOf(node, scopedValues);
    final List<Object?> rows = tableRowsOf(node, scopedValues);
    final bool headerRow = p.hasHeaderRow;
    final bool headerColumn = p.hasHeaderColumn;
    final int rowOffset = headerRow ? 1 : 0;
    final int columnOffset = headerColumn ? 1 : 0;
    final BorderSide line = p.gridLineColor == null || p.gridLineWidth <= 0
        ? BorderSide.none
        : BorderSide(
            color: p.gridLineColor!.toFlutterColor(),
            width: p.gridLineWidth,
          );
    final Color? headerColor = p.headerColor?.toFlutterColor();
    final Color? stripe = p.stripeColor?.toFlutterColor();

    Widget template(String id, IndexedItem item) {
      if (id.isEmpty) return const SizedBox.shrink();
      return IndexedItemProvider(
        item: item,
        child: Builder(
          builder: (context) => SizedBox.expand(
            child: Align(
              alignment: Alignment.centerLeft,
              child: manager.buildWidgetByID(id, context, settings: settings),
            ),
          ),
        ),
      );
    }

    // A table needs a bounded box; where it gets none (in a scroll view),
    // it takes its design size.
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.hasBoundedWidth ? null : node.basicBoxLocal.width,
        height: constraints.hasBoundedHeight ? null : node.basicBoxLocal.height,
        child: TableView.builder(
          clipBehavior: node.clipsContent ? Clip.hardEdge : Clip.none,
          diagonalDragBehavior: DiagonalDragBehavior.free,
          rowCount: rows.length + rowOffset,
          columnCount: columns.length + columnOffset,
          pinnedRowCount: headerRow && p.pinHeaderRow ? 1 : 0,
          pinnedColumnCount: headerColumn && p.pinHeaderColumn ? 1 : 0,
          columnBuilder: (index) {
            final bool header = headerColumn && index == 0;
            final double width = header
                ? p.rowHeaderWidth
                : columns[index - columnOffset].width ?? p.columnWidth;
            return TableSpan(
              extent: FixedTableSpanExtent(width),
              foregroundDecoration: TableSpanDecoration(
                border: TableSpanBorder(trailing: line),
              ),
              backgroundDecoration: header && headerColor != null
                  ? TableSpanDecoration(color: headerColor)
                  : null,
            );
          },
          rowBuilder: (index) {
            final bool header = headerRow && index == 0;
            final int body = index - rowOffset;
            return TableSpan(
              extent: FixedTableSpanExtent(
                header ? p.headerHeight : p.rowHeight,
              ),
              foregroundDecoration: TableSpanDecoration(
                border: TableSpanBorder(trailing: line),
              ),
              backgroundDecoration: header
                  ? (headerColor == null
                        ? null
                        : TableSpanDecoration(color: headerColor))
                  : (stripe != null && body.isOdd
                        ? TableSpanDecoration(color: stripe)
                        : null),
            );
          },
          cellBuilder: (context, vicinity) {
            final bool inHeaderRow = headerRow && vicinity.row == 0;
            final bool inHeaderColumn = headerColumn && vicinity.column == 0;
            final int rowIndex = vicinity.row - rowOffset;
            final int columnIndex = vicinity.column - columnOffset;
            if (inHeaderRow && inHeaderColumn) {
              return TableViewCell(
                child: template(p.cornerNodeId, IndexedItem(0, null)),
              );
            }
            if (inHeaderRow) {
              final TableColumnModel column = columns[columnIndex];
              return TableViewCell(
                child: template(
                  p.columnHeaderNodeId,
                  IndexedItem(columnIndex, {
                    'label': column.label,
                    'column': column.key,
                    'columnIndex': columnIndex,
                  }),
                ),
              );
            }
            final Object? row = rows[rowIndex];
            if (inHeaderColumn) {
              return TableViewCell(
                child: template(
                  p.rowHeaderNodeId,
                  IndexedItem(rowIndex, {'row': row, 'rowIndex': rowIndex}),
                ),
              );
            }
            final TableColumnModel column = columns[columnIndex];
            final Object? value = switch (row) {
              final Map map => map[column.key],
              final List list => list.elementAtOrNull(columnIndex),
              _ => null,
            };
            return TableViewCell(
              child: template(
                p.cellNodeId,
                IndexedItem(rowIndex, {
                  'value': value,
                  'row': row,
                  'column': column.key,
                  'rowIndex': rowIndex,
                  'columnIndex': columnIndex,
                }),
              ),
            );
          },
        ),
      ),
    );
  }
}
