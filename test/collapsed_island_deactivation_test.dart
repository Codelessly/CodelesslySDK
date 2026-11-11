import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lists/support.dart';

void main() {
  testWidgets('closing a preview under LayoutBuilder releases collapsed table checkbox islands', (tester) async {
    final screen = await show(tester, {
      'root': {'type': 'column', 'children': ['table'], 'layout': {'width': 600, 'height': 400}},
      'table': {
        'type': 'tableView',
        'layout': {'width': 600, 'height': 400},
        'bind': {'data': r'${rows}'},
        'slots': {'cell': 'cell'},
        'props': {
          'columns': [{'key': 'select', 'width': 100}, {'key': 'name', 'width': 500}],
          'rowHeight': 80,
        },
      },
      'cell': {'type': 'row', 'children': ['check', 'text'], 'layout': {'width': {'fill': 100}, 'height': {'fill': 80}}},
      'check': {
        'type': 'checkbox',
        'layout': {'width': 48, 'height': 48},
        'bind': {'visible': r'${= showAll || item.column == "select"}', 'value': r'${= selected == item.row.id}'},
        'actions': [{
          'trigger': {'type': 'changed'},
          'actions': [{'type': 'setVariable', 'variable': 'selected', 'value': r'${item.row.id}'}],
        }],
      },
      'text': {'type': 'text', 'props': {'text': r'${item.value}'}, 'layout': {'width': {'fill': 100}, 'height': {'fill': 80}}},
    }, root: 'root', variables: [
      v('showAll', true, VariableType.boolean), v('selected', -1, VariableType.integer),
      v('rows', [for (var i = 0; i < 24; i++) {'id': i, 'select': i, 'name': 'District $i'}], VariableType.list),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).hitTestable().first);
    await tester.pumpAndSettle();
    expect(screen['selected'], 0);
    screen.scope.set('showAll', false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(MaterialApp(home: LayoutBuilder(builder: (_, _) => const SizedBox())));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Checkbox), findsNothing);
  });
  testWidgets('a collapsed checkbox island survives breakpoint reparenting and preview reopen', (tester) async {
    final scope = VariableScope([v('shown', true, VariableType.boolean)]);
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
      'roots': ['root'],
      'nodes': {
        'root': {'type': 'column', 'children': ['check'], 'layout': {'width': 300, 'height': 100}},
        'check': {'type': 'checkbox', 'layout': {'width': 48, 'height': 48}, 'bind': {'visible': r'${shown}'}},
      },
    })), binder: NodeBinder(scope: scope));
    addTearDown(tree.dispose);
    addTearDown(scope.dispose);
    final key = GlobalKey();
    Widget preview(bool desktop, {bool open = true}) => MaterialApp(home: LayoutBuilder(builder: (_, _) {
      if (!open) return const SizedBox();
      final view = NodeView(key: key, tree: tree, rootId: 'root', interactive: true);
      return desktop ? Align(alignment: Alignment.topLeft, child: view) : Center(child: view);
    }));
    await tester.pumpWidget(preview(false));
    await tester.pumpAndSettle();
    final checkboxState = tester.state(find.byType(Checkbox));
    scope.set('shown', false);
    await tester.pumpAndSettle();
    await tester.pumpWidget(preview(true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.state(find.byType(Checkbox)), same(checkboxState));
    scope.set('shown', true);
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox).hitTestable(), findsOneWidget);
    scope.set('shown', false);
    await tester.pumpAndSettle();
    await tester.pumpWidget(preview(true, open: false));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(preview(false));
    scope.set('shown', true);
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

}
