import 'package:codelessly_genui/codelessly_genui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'support.dart';

GenUiSession sessionWith(List<Map<String, Object?>> messages) {
  final session = GenUiSession(catalog: genUiCatalog(theme: testTheme));
  final issues = session.apply(messages);
  expect(issues, isEmpty);
  return session;
}

void main() {
  testWidgets('basic components', (tester) async {
    final session = sessionWith([
      create('b'),
      data('b', {'name': 'Ada Lovelace', 'nights': 4, 'tax': true, 'alerts': true, 'mode': ['train'], 'notes': ''}),
      components('b', [
        {'id': 'root', 'component': 'Card', 'child': 'col'},
        {'id': 'col', 'component': 'Column', 'children': ['h1', 'h3', 'body', 'cap', 'name', 'nights', 'tax', 'alerts', 'mode', 'div', 'buttons']},
        {'id': 'h1', 'component': 'Text', 'text': 'Heading one', 'variant': 'h1'},
        {'id': 'h3', 'component': 'Text', 'text': 'Heading three', 'variant': 'h3'},
        {'id': 'body', 'component': 'Text', 'text': 'Body text wraps across the width of the bubble when it is long enough to need two lines.'},
        {'id': 'cap', 'component': 'Text', 'text': 'A caption', 'variant': 'caption'},
        {'id': 'name', 'component': 'TextField', 'label': 'Name', 'value': {'path': '/name'}},
        {'id': 'nights', 'component': 'Slider', 'label': 'Nights', 'unit': ' nights', 'min': 1, 'max': 14, 'step': 1, 'value': {'path': '/nights'}},
        {'id': 'tax', 'component': 'CheckBox', 'label': 'Include taxes', 'value': {'path': '/tax'}},
        {'id': 'alerts', 'component': 'CodelesslySwitch', 'label': 'Price alerts', 'value': {'path': '/alerts'}},
        {'id': 'mode', 'component': 'ChoicePicker', 'label': 'Travel by', 'options': [{'label': 'Car', 'value': 'car'}, {'label': 'Train', 'value': 'train'}, {'label': 'Plane', 'value': 'plane'}], 'value': {'path': '/mode'}},
        {'id': 'div', 'component': 'Divider'},
        {'id': 'buttons', 'component': 'Row', 'justify': 'end', 'children': ['cancel', 'save']},
        {'id': 'cancel', 'component': 'Button', 'child': 'cancelL', 'variant': 'borderless', 'action': {'event': {'name': 'cancel'}}},
        {'id': 'cancelL', 'component': 'Text', 'text': 'Cancel'},
        {'id': 'save', 'component': 'Button', 'child': 'saveL', 'variant': 'primary', 'action': {'event': {'name': 'submit'}}},
        {'id': 'saveL', 'component': 'Text', 'text': 'Save'},
      ]),
    ]);
    addTearDown(session.dispose);
    await pumpSurfaces(tester, session, size: const Size(440, 760));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/basic_components.png'));
  });

  testWidgets('Codelessly extensions', (tester) async {
    final session = sessionWith([
      create('x'),
      data('x', {
        'months': [
          for (final (m, a, b) in [('Jan', 420, 180), ('Feb', 380, 220), ('Mar', 450, 160), ('Apr', 410, 240), ('May', 470, 200), ('Jun', 430, 260)])
            {'m': m, 'rent': a, 'food': b},
        ],
        'items': [
          {'name': 'Pressure-treated 2x8 joist, 12 ft', 'qty': 13, 'unit': 21.48, 'got': true},
          {'name': 'Composite deck board, 16 ft', 'qty': 32, 'unit': 38.9, 'got': false},
          {'name': 'Joist hanger 2x8', 'qty': 26, 'unit': 1.92, 'got': false},
        ],
        'used': 68,
        'share': 0.62,
      }),
      components('x', [
        {'id': 'root', 'component': 'Column', 'children': ['metrics', 'line', 'bars', 'gaugeRow', 'progress', 'table']},
        {'id': 'metrics', 'component': 'Row', 'children': ['m1', 'm2', 'm3']},
        {'id': 'm1', 'component': 'CodelesslyMetric', 'weight': 1, 'label': 'Total', 'value': {'call': 'formatCurrency', 'args': {'value': 1729.84, 'currency': 'USD'}, 'returnType': 'string'}, 'tone': 'accent'},
        {'id': 'm2', 'component': 'CodelesslyMetric', 'weight': 1, 'label': 'Saved', 'value': '12%', 'tone': 'positive', 'caption': 'vs. last month'},
        {'id': 'm3', 'component': 'CodelesslyMetric', 'weight': 1, 'label': 'Over', 'value': '2 items', 'tone': 'negative'},
        {'id': 'line', 'component': 'CodelesslyChart', 'title': 'Spending', 'chartType': 'line', 'data': {'path': '/months'}, 'xField': 'm', 'yLabelPrefix': r'$',
         'series': [{'field': 'rent', 'name': 'Rent'}, {'field': 'food', 'name': 'Food', 'dashed': true}], 'height': 170},
        {'id': 'bars', 'component': 'CodelesslyChart', 'chartType': 'bar', 'data': {'path': '/months'}, 'xField': 'm', 'height': 150,
         'series': [{'field': 'rent', 'name': 'Rent', 'stack': 'a'}, {'field': 'food', 'name': 'Food', 'stack': 'a'}]},
        {'id': 'gaugeRow', 'component': 'Row', 'justify': 'center', 'children': ['gauge']},
        {'id': 'gauge', 'component': 'CodelesslyGauge', 'value': {'path': '/used'}, 'unit': '%', 'label': 'Budget used', 'size': 170,
         'zones': [{'to': 60, 'color': '#26A69A'}, {'to': 85, 'color': '#FFB300'}, {'to': 100, 'color': '#EF5350'}]},
        {'id': 'progress', 'component': 'CodelesslyProgress', 'label': 'Materials bought', 'value': {'path': '/share'}},
        {'id': 'table', 'component': 'CodelesslyTable', 'rows': {'path': '/items'}, 'checkField': 'got',
         'columns': [{'header': 'Item', 'field': 'name'}, {'header': 'Qty', 'field': 'qty', 'format': 'number'}, {'header': 'Cost', 'expr': 'qty * unit', 'format': 'currency', 'total': true}]},
      ]),
    ]);
    addTearDown(session.dispose);
    await pumpSurfaces(tester, session, size: const Size(440, 1180));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/extensions.png'));
  });

  testWidgets('visualization expands to fullscreen, keeps state, and collapses back', (tester) async {
    final session = sessionWith(fixture('weight_loss'));
    addTearDown(session.dispose);
    await pumpSurfaces(tester, session, size: const Size(440, 900));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/visualization_inline.png'));

    tester.view.physicalSize = const Size(1280, 820);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('genui-expand-root')));
    await tester.pump(const Duration(milliseconds: 150));
    // Mid-flight: the hero transition is running.
    expect(find.byType(Hero), findsWidgets);
    await tester.pumpAndSettle();
    // Fullscreen shows every control in the side panel.
    expect(find.text('Weight'), findsWidgets);
    expect(find.text('Height'), findsOneWidget);
    expect(find.text('Sex'), findsOneWidget);
    await expectLater(find.byType(Navigator), matchesGoldenFile('goldens/visualization_fullscreen.png'));

    // Move the deficit slider fullscreen; the formulas recompute without the agent.
    final before = session.dataModelOf('wl')['deficit'];
    await tester.drag(find.byType(Slider).at(3), const Offset(120, 0));
    await tester.pumpAndSettle();
    final after = session.dataModelOf('wl')['deficit'];
    expect(after, isNot(before));

    await tester.tap(find.byKey(const ValueKey('genui-collapse-root')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('genui-collapse-root')), findsNothing);
    // Collapsed, the inline card shows the value set fullscreen.
    expect(find.text('${NumberFormat.decimalPattern().format(after)} kcal'), findsOneWidget);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/visualization_collapsed_after_edit.png'));
  });
}
