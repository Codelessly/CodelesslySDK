import 'dart:ui' as ui;
// Table view: a running table builds its rows from bound data, only the cells on
// screen, and pins its header row and column while it scrolls.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import 'package:codelessly_sdk/src/widgets/collections_table.dart' show tableRowHeight;

import 'support.dart';

Map<String, Json> table() => {
      'table': {
        'type': 'tableView',
        'layout': {'width': 600, 'height': 400},
        'bind': {'data': r'${rows}'},
        'slots': {'cell': 'cell', 'columnHeader': 'colHeader', 'rowHeader': 'rowHeader'},
        'props': {
          'columns': [
            for (var c = 0; c < 50; c++) {'key': 'c$c', 'label': 'Col $c'},
          ],
          'columnWidth': 100,
          'rowHeaderWidth': 80,
          'rowHeight': 40,
          'headerHeight': 40,
        },
      },
      'cell': {'type': 'text', 'layout': {'width': 100, 'height': 20}, 'props': {'text': r'${item.value}'}},
      'colHeader': {'type': 'text', 'layout': {'width': 100, 'height': 20}, 'props': {'text': r'${item.label}'}},
      'rowHeader': {'type': 'text', 'layout': {'width': 80, 'height': 20}, 'props': {'text': r'R${item.rowIndex}'}},
    };

final rows = v('rows', [
  for (var r = 0; r < 1000; r++) {for (var c = 0; c < 50; c++) 'c$c': 'r${r}c$c'},
], VariableType.list);

/// The painted texts of the table and where they are.
Map<String, Offset> cells(WidgetTester tester) {
  final out = <String, Offset>{};
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.attached) out[o.text.toPlainText()] = o.localToGlobal(Offset.zero);
    o.visitChildren(visit);
  }

  visit(tester.renderObject(find.byType(TableView)));
  return out;
}

void main() {
  testWidgets('builds only the cells on screen, from the bound rows', (tester) async {
    await show(tester, table(), root: 'table', variables: [rows]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final shown = textsUnder(tester.renderObject(find.byType(TableView)));
    expect(shown, containsAll(['r0c0', 'Col 0', 'R0']));
    // 1,000 × 50 cells; about 10 rows × 6 columns are on screen.
    expect(shown.length, lessThan(200));
    expect(shown, isNot(contains('r999c49')));
  });

  testWidgets('pins the header row and column while scrolling', (tester) async {
    await show(tester, table(), root: 'table', variables: [rows]);
    await tester.pumpAndSettle();
    final origin = tester.getTopLeft(find.byType(TableView));
    await tester.dragFrom(origin + const Offset(300, 200), const Offset(-2000, -16000));
    await tester.pumpAndSettle();
    final shown = cells(tester);
    expect(shown.keys, isNot(contains('r0c0')));
    final headers = shown.entries.where((e) => e.key.startsWith('Col '));
    expect(headers, isNotEmpty);
    expect(headers.first.value.dy - origin.dy, lessThan(40));
    final rowHeaders = shown.entries.where((e) => RegExp(r'^R\d+$').hasMatch(e.key));
    expect(rowHeaders, isNotEmpty);
    expect(rowHeaders.first.value.dx - origin.dx, lessThan(80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('rowHeightKey gives a row its own height; fillWidth spreads the columns', (tester) async {
    // A week: an "open shifts" row as tall as its busiest day, then people.
    final week = v('week', [
      {'id': 'open', 'height': 150},
      {'id': 'ana'},
      {'id': 'bo', 'height': 'tall'},
    ], VariableType.list);
    final nodes = {
      'table': {
        'type': 'tableView',
        'layout': {'width': 1000, 'height': 400},
        'bind': {'data': r'${week}'},
        'slots': {'cell': 'cell', 'columnHeader': 'colHeader', 'rowHeader': 'rowHeader'},
        'props': {
          'columns': [for (var d = 0; d < 5; d++) {'key': 'd$d', 'label': 'D$d'}],
          'columnWidth': 100,
          'rowHeaderWidth': 160,
          'rowHeight': 70,
          'headerHeight': 60,
          'rowHeightKey': 'height',
          'fillWidth': true,
        },
      },
      'cell': {'type': 'text', 'layout': {'width': 60, 'height': 20}, 'props': {'text': r'${item.row.id}${item.columnIndex}'}},
      'colHeader': {'type': 'text', 'layout': {'width': 60, 'height': 20}, 'props': {'text': r'${item.label}'}},
      'rowHeader': {'type': 'text', 'layout': {'width': 60, 'height': 20}, 'props': {'text': r'${item.row.id}'}},
    };
    await show(tester, nodes, root: 'table', variables: [week]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final at = cells(tester);
    // Rows (texts centred in them): header 60, open 150, ana 70 (no
    // height), bo 70 (not a number).
    expect(at['ana']!.dy - at['open']!.dy, (150 + 70) / 2);
    expect(at['bo']!.dy - at['ana']!.dy, 70);
    // Columns: the 800 wide test view, 160 + 5 × 100 = 660, so each day
    // gets 28 more.
    expect(at['open1']!.dx - at['open0']!.dx, 128);
    expect(at['open4']!.dx - at['open0']!.dx, 512);
    expect(at['D0']!.dx, 160);
    expect(tableRowHeight({'h': '12'}, 'h', 40), 12);
    expect(tableRowHeight({'h': -3}, 'h', 40), 40);
    expect(tableRowHeight('x', 'h', 40), 40);
  });

  testWidgets('fillWidth never makes a column narrower than its width', (tester) async {
    final nodes = table();
    (nodes['table']!['props'] as Map)['fillWidth'] = true;
    await show(tester, nodes, root: 'table', variables: [rows]);
    await tester.pumpAndSettle();
    final at = cells(tester);
    // 80 + 50 × 100 is wider than the 600 box: every column keeps its 100.
    expect(at['r0c1']!.dx - at['r0c0']!.dx, 100);
  });

  testWidgets('a table with a padding (a bordered frame) lays its cells inside it', (tester) async {
    final t = table();
    final node = Map<String, Object?>.from(t['table']!);
    node['layout'] = {'width': 600, 'height': 400, 'padding': [1, 1, 1, 1]};
    node['decoration'] = {'radius': 14, 'strokes': [{'color': '#FFD3CDC0'}], 'strokeWidth': 1};
    t['table'] = node;
    final screen = await show(tester, t, root: 'table', variables: [rows]);
    await tester.pumpAndSettle();
    final origin = screen.tree.boxOf('table')!.localToGlobal(Offset.zero);
    final view = tester.getRect(find.byType(TableView));
    expect(view.topLeft - origin, const Offset(1, 1));
    expect(view.size, const Size(598, 398));
  });

  testWidgets('a table draws its decoration: border and rounded corners around the cells', (tester) async {
    final t = table();
    final node = Map<String, Object?>.from(t['table']!);
    node['layout'] = {'width': 600, 'height': 400, 'padding': [2, 2, 2, 2]};
    node['decoration'] = {
      'fills': [{'color': '#FFFFFFFF'}],
      'radius': 14,
      'strokes': [{'color': '#FFFF0000'}],
      'strokeWidth': 2,
      'clip': 'antiAlias',
    };
    t['table'] = node;
    t['colHeader'] = {...t['colHeader']!, 'type': 'box', 'decoration': {'fills': [{'color': '#FF0000FF'}]}, 'layout': {'width': {'fill': 100}, 'height': {'fill': 100}}};
    final screen = await show(tester, t, root: 'table', variables: [rows]);
    await tester.pumpAndSettle();
    final box = screen.tree.boxOf('table')!;
    final origin = box.localToGlobal(Offset.zero);
    final view = tester.binding.renderViews.first;
    final image = await tester.runAsync(() => (view.debugLayer! as OffsetLayer).toImage(origin & box.size));
    final bytes = (await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    int r(int x, int y) => bytes.getUint8((y * image!.width + x) * 4);
    int b(int x, int y) => bytes.getUint8((y * image!.width + x) * 4 + 2);
    expect(r(0, 200), greaterThan(200), reason: 'the left border is drawn');
    expect(b(0, 200), lessThan(60), reason: 'not covered by a cell');
    // Outside the rounded corner: the page, neither the border nor a cell.
    expect([r(1, 1), b(1, 1)], [greaterThan(200), greaterThan(200)], reason: 'the rounded corner clips');
  });

  testWidgets('a design canvas keeps the table at rest, showing its bound rows', (tester) async {
    await show(tester, table(), root: 'table', variables: [rows], interactive: false);
    expect(find.byType(TableView), findsNothing);
    await tester.pumpAndSettle();
    final shown = <String>[];
    void visit(RenderObject o) {
      if (o is RenderParagraph) shown.add(o.text.toPlainText());
      o.visitChildren(visit);
    }

    visit(tester.renderObject(find.byType(NodeView)));
    expect(shown, containsAll(['Col 0', 'r0c0', 'r1c2']));
  });

  testWidgets('flex columns share the room; rows hover, select and report taps', (tester) async {
    final nodes = table();
    final t = nodes['table']!;
    nodes['table'] = {
      ...t,
      'layout': {'width': 600, 'height': 400},
      'slots': {'cell': 'cell', 'columnHeader': 'colHeader'},
      'bind': {'data': r'${rows}', 'props.selectedRow': r'${selected}'},
      'props': {
        ...(t['props'] as Map),
        'columns': [
          {'key': 'c0', 'label': 'Col 0', 'width': 100, 'flex': 1},
          {'key': 'c1', 'label': 'Col 1', 'width': 100},
          {'key': 'c2', 'label': 'Col 2', 'width': 100, 'flex': 3},
        ],
        'horizontalPadding': 16,
        'rowHoverColor': '#FF222228',
        'selectedRowColor': '#FF2E2E36',
        'selectedRowEdgeColor': '#FFFFD400',
        'headerBorderColor': '#FF34343C',
        'headerBorderWidth': 2,
      },
      'actions': [
        reaction('rowTap', [
          {'type': 'setVariable', 'variable': 'selected', 'value': r'${result.rowIndex}'},
        ]),
      ],
    };
    final s = await show(tester, nodes, root: 'table', variables: [rows, v('selected', -1, VariableType.integer)]);
    await tester.pumpAndSettle();
    final shown = cells(tester);
    // 600 - 32 padding - 300 fixed = 268 spare: c0 gets 67, c2 201.
    expect(shown['Col 1']!.dx - shown['Col 0']!.dx, closeTo(167, 1));
    expect(shown['Col 2']!.dx - shown['Col 1']!.dx, closeTo(100, 1));
    expect(shown['Col 0']!.dx - tester.getTopLeft(find.byType(TableView)).dx, closeTo(16, 1));
    await tester.tapAt(shown['r2c1']! + const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(s['selected'], 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('at rest a data-bound table shows its rows in each cell\'s scope', (tester) async {
    await show(tester, table(), root: 'table', variables: [rows], interactive: false);
    final shown = <String>{};
    void visit(RenderObject o) {
      if (o is RenderParagraph && o.attached) shown.add(o.text.toPlainText());
      o.visitChildren(visit);
    }

    visit(tester.renderObject(find.byType(NodeView)));
    // Header labels, row headers and cell values of the first rows, as the
    // running table shows them; only the cells that fit the design size.
    expect(shown, containsAll(['Col 0', 'Col 4', 'R0', 'R1', 'r0c0', 'r1c3']));
    expect(shown, isNot(contains('r999c0')));
  });

  testWidgets('at rest a table that fills its height builds the rows it has room for', (tester) async {
    final t = table();
    t['table'] = {...t['table']!, 'layout': {'width': 600, 'height': {'fill': 1}}};
    await show(tester, {
      'root': {'type': 'column', 'children': ['table'], 'layout': {'width': 600, 'height': 400},
               'props': {'crossAxisAlignment': 'stretch'}},
      ...t,
    }, root: 'root', variables: [rows], interactive: false);
    final shown = <String>{};
    void visit(RenderObject o) {
      if (o is RenderParagraph && o.attached) shown.add(o.text.toPlainText());
      o.visitChildren(visit);
    }

    visit(tester.renderObject(find.byType(NodeView)));
    expect(shown, containsAll(['Col 0', 'R0', 'r0c0', 'r5c0']));
  });

  testWidgets('at rest a table\'s cells follow its bound data when it changes', (tester) async {
    final small = v('rows', [
      for (var r = 0; r < 3; r++) {for (var c = 0; c < 3; c++) 'c$c': 'r${r}c$c'},
    ], VariableType.list);
    final s = await show(tester, table(), root: 'table', variables: [small], interactive: false);
    Set<String> shown() {
      final out = <String>{};
      void visit(RenderObject o) {
        if (o is RenderParagraph && o.attached) out.add(o.text.toPlainText());
        o.visitChildren(visit);
      }

      visit(tester.renderObject(find.byType(NodeView)));
      return out;
    }

    expect(shown(), contains('r0c0'));
    // New rows (a capture's values, a variable edit): the cells show them.
    s.scope.set('rows', [
      for (var r = 0; r < 3; r++) {for (var c = 0; c < 3; c++) 'c$c': 'new${r}c$c'},
    ]);
    await tester.pumpAndSettle();
    expect(shown(), containsAll(['new0c0', 'new2c2']));
    expect(shown(), isNot(contains('r0c0')));
  });
}
