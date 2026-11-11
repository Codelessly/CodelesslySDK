import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import 'support.dart';

List<Json> _rows(int wave) => [
  for (var i = 0; i < 40; i++)
    {'id': i, 'name': 'District $i wave $wave', 'select': i},
];

void main() {
  testWidgets(
    'full-height table templates update item scopes safely while scrolling and selecting rows',
    (tester) async {
      final screen = await show(
        tester,
        {
          'root': {
            'type': 'column',
            'children': ['table'],
            'layout': {'width': 600, 'height': 400},
          },
          'table': {
            'type': 'tableView',
            'layout': {'width': 600, 'height': 400},
            'bind': {'data': r'${rows}'},
            'slots': {'cell': 'cell', 'columnHeader': 'header'},
            'props': {
              'columns': [
                {'key': 'select', 'label': 'Select', 'width': 120},
                {'key': 'name', 'label': 'District', 'width': 480},
              ],
              'rowHeight': 80,
              'headerHeight': 40,
            },
          },
          'cell': {
            'type': 'row',
            'children': ['check', 'label'],
            'layout': {
              'width': {'fill': 120},
              'height': {'fill': 80},
            },
          },
          'check': {
            'type': 'checkbox',
            'layout': {'width': 48, 'height': 48},
            'bind': {
              'visible': r'${= item.column == "select"}',
              'value': r'${= selected == item.row.id}',
            },
            'actions': [
              {
                'trigger': {'type': 'changed'},
                'actions': [
                  {
                    'type': 'setVariable',
                    'variable': 'selected',
                    'value': r'${item.row.id}',
                  },
                ],
              },
            ],
          },
          'label': {
            'type': 'text',
            'layout': {
              'width': {'fill': 120},
              'height': {'fill': 80},
            },
            'props': {'text': r'${item.value}'},
          },
          'header': {
            'type': 'text',
            'layout': {
              'width': {'fill': 120},
              'height': {'fill': 40},
            },
            'props': {'text': r'${item.label}'},
          },
        },
        root: 'root',
        variables: [
          v('rows', _rows(0), VariableType.list),
          v('selected', -1, VariableType.integer),
        ],
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(Checkbox).hitTestable().first);
      await tester.pumpAndSettle();
      expect(screen['selected'], 0);
      expect(
        tester
            .widget<Checkbox>(find.byType(Checkbox).hitTestable().first)
            .value,
        true,
      );
      for (var wave = 1; wave <= 3; wave++) {
        screen.scope.set('rows', _rows(wave));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          textsUnder(tester.renderObject(find.byType(TableView))),
          contains('District 0 wave $wave'),
        );
      }
      final origin = tester.getTopLeft(find.byType(TableView));
      await tester.dragFrom(
        origin + const Offset(300, 240),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      screen.scope.set('rows', _rows(4));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(Checkbox).hitTestable().first);
      await tester.pumpAndSettle();
      expect(screen['selected'], greaterThan(0));
      expect(
        tester
            .widget<Checkbox>(find.byType(Checkbox).hitTestable().first)
            .value,
        true,
      );
      await tester.dragFrom(
        origin + const Offset(300, 120),
        const Offset(0, 1400),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        textsUnder(tester.renderObject(find.byType(TableView))),
        contains('District 0 wave 4'),
      );
    },
  );
  testWidgets(
    'a table viewport provider cannot synchronously mutate a mounted cell outside its layout subtree',
    (tester) async {
      final screen = await show(
        tester,
        {
          'table': {
            'type': 'tableView',
            'layout': {'width': 300, 'height': 160},
            'bind': {'data': r'${rows}'},
            'slots': {'cell': 'cell'},
            'props': {
              'columns': [
                {'key': 'name', 'width': 300},
              ],
              'rowHeight': 80,
            },
          },
          'cell': {
            'type': 'text',
            'layout': {
              'width': {'fill': 300},
              'height': {'fill': 80},
            },
            'props': {'text': r'${item.value}'},
          },
        },
        root: 'table',
        variables: [v('rows', _rows(0), VariableType.list)],
      );
      await tester.pumpAndSettle();
      var update = false;
      Widget host() => MaterialApp(
        home: Column(
          children: [
            SizedBox(
              width: 300,
              height: 160,
              child: NodeView(
                tree: screen.tree,
                rootId: 'table',
                interactive: true,
              ),
            ),
            SizedBox(
              width: 100,
              height: 80,
              child: TableView.builder(
                rowCount: 1,
                columnCount: 1,
                rowBuilder: (_) =>
                    const TableSpan(extent: FixedTableSpanExtent(80)),
                columnBuilder: (_) =>
                    const TableSpan(extent: FixedTableSpanExtent(100)),
                cellBuilder: (_, vicinity) {
                  if (update) {
                    screen.tree.binder!.provideItem(
                      screen.tree.source,
                      const ProvidedItem('cell', null, 'table', (0, 0)),
                      index: 0,
                      item: {
                        'value': 'Changed during viewport layout',
                        'row': _rows(1).first,
                        'column': 'name',
                        'rowIndex': 0,
                        'columnIndex': 0,
                      },
                    );
                  }
                  return TableViewCell(
                    child: Text(update ? 'updated' : 'initial'),
                  );
                },
              ),
            ),
          ],
        ),
      );
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      update = true;
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        textsUnder(tester.renderObject(find.byType(TableView).first)),
        contains('Changed during viewport layout'),
      );
    },
  );
}
