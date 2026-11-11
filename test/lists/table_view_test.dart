// Table view: a running table builds its rows from bound data, only the cells on
// screen, and pins its header row and column while it scrolls.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

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

  testWidgets('a design canvas keeps the table at rest', (tester) async {
    await show(tester, table(), root: 'table', variables: [rows], interactive: false);
    expect(find.byType(TableView), findsNothing);
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
}
