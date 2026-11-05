import 'dart:async';
import 'dart:convert';

import 'package:codelessly_genui/codelessly_genui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

final List<Map<String, Object?>> form = [
  {'id': 'root', 'component': 'Column', 'children': ['title', 'email', 'qty', 'agree', 'plan', 'send']},
  {'id': 'title', 'component': 'Text', 'text': 'Order', 'variant': 'h3'},
  {'id': 'email', 'component': 'TextField', 'label': 'Email', 'value': {'path': '/email'}},
  {'id': 'qty', 'component': 'Slider', 'label': 'Quantity', 'min': 0, 'max': 10, 'step': 1, 'value': {'path': '/qty'},
   'action': {'event': {'name': 'qty_changed', 'context': {'qty': {'path': '/qty'}}}}},
  {'id': 'agree', 'component': 'CheckBox', 'label': 'Gift wrap', 'value': {'path': '/gift'},
   'action': {'event': {'name': 'gift_toggled'}}},
  {'id': 'plan', 'component': 'ChoicePicker', 'options': [{'label': 'Basic', 'value': 'basic'}, {'label': 'Pro', 'value': 'pro'}],
   'value': {'path': '/plan'}, 'action': {'event': {'name': 'plan_picked', 'context': {'plan': {'path': '/plan'}}}}},
  {'id': 'send', 'component': 'Button', 'child': 'sendLabel', 'variant': 'primary',
   'action': {'event': {'name': 'submit', 'context': {'email': {'path': '/email'}, 'qty': {'path': '/qty'}}}}},
  {'id': 'sendLabel', 'component': 'Text', 'text': 'Send order'},
];

void main() {
  group('incremental updates', () {
    testWidgets('a data model update rebuilds only the components that read it', (tester) async {
      final builds = <String>[];
      final session = GenUiSession(catalog: genUiCatalog(theme: testTheme, debugOnBuild: builds.add));
      addTearDown(session.dispose);
      session.apply([
        create('s'),
        data('s', {'a': 'one', 'b': 'two'}),
        components('s', [
          {'id': 'root', 'component': 'Column', 'children': ['ta', 'tb', 'tc']},
          {'id': 'ta', 'component': 'Text', 'text': {'path': '/a'}},
          {'id': 'tb', 'component': 'Text', 'text': {'path': '/b'}},
          {'id': 'tc', 'component': 'Text', 'text': 'static'},
        ]),
      ]);
      await pumpSurfaces(tester, session);
      expect(find.text('one', findRichText: true), findsOneWidget);
      final State before = tester.state(find.byType(CodelesslyNodeView).at(2));
      builds.clear();

      session.apply(data('s', 'uno', '/a'));
      await tester.pump();
      expect(builds, ['ta']);
      expect(find.text('uno', findRichText: true), findsOneWidget);
      expect(find.text('two', findRichText: true), findsOneWidget);
      // The untouched component keeps its widget state.
      expect(identical(tester.state(find.byType(CodelesslyNodeView).at(2)), before), isTrue);
    });

    testWidgets('updateComponents replaces one component without rebuilding its siblings', (tester) async {
      final builds = <String>[];
      final session = GenUiSession(catalog: genUiCatalog(theme: testTheme, debugOnBuild: builds.add));
      addTearDown(session.dispose);
      session.apply([
        create('s'),
        components('s', [
          {'id': 'root', 'component': 'Column', 'children': ['ta', 'tb']},
          {'id': 'ta', 'component': 'Text', 'text': 'first'},
          {'id': 'tb', 'component': 'Text', 'text': 'second'},
        ]),
      ]);
      await pumpSurfaces(tester, session);
      builds.clear();
      session.apply(components('s', [
        {'id': 'tb', 'component': 'Text', 'text': 'second, edited', 'variant': 'h3'},
      ]));
      await tester.pump();
      expect(builds, ['tb']);
      expect(find.text('second, edited', findRichText: true), findsOneWidget);
      expect(find.text('first', findRichText: true), findsOneWidget);
    });

    testWidgets('a calc formula recomputes on the device when its input changes', (tester) async {
      final session = GenUiSession(catalog: genUiCatalog(theme: testTheme));
      addTearDown(session.dispose);
      session.apply([
        create('s'),
        data('s', {'qty': 2, 'price': 12.5}),
        components('s', [
          {'id': 'root', 'component': 'Text', 'text': {'call': 'formatString', 'args': {'value': r'Total ${calc(expr:"qty * price")}'}, 'returnType': 'string'}},
        ]),
      ]);
      await pumpSurfaces(tester, session);
      expect(find.text('Total 25', findRichText: true), findsOneWidget);
      session.apply(data('s', 4, '/qty'));
      await tester.pump();
      expect(find.text('Total 50', findRichText: true), findsOneWidget);
    });

    testWidgets('a streamed reply renders before it ends, one message at a time', (tester) async {
      final session = GenUiSession(catalog: genUiCatalog(theme: testTheme));
      addTearDown(session.dispose);
      await pumpSurfaces(tester, session);
      final String tool = jsonEncode({
        'messages': [
          create('s'),
          data('s', {'name': 'Ada'}),
          components('s', [
            {'id': 'root', 'component': 'Text', 'text': {'path': '/name'}},
          ]),
          data('s', 'Grace', '/name'),
        ],
      });
      final feed = session.openStream(depth: 2);
      final cut = tool.indexOf('Grace') - 40;
      for (int i = 0; i < cut; i += 7) {
        feed.add(tool.substring(i, i + 7 > cut ? cut : i + 7));
      }
      await tester.pump();
      expect(feed.messages, hasLength(3));
      expect(find.text('Ada', findRichText: true), findsOneWidget);
      feed.add(tool.substring(cut));
      await tester.pump();
      expect(feed.messages, hasLength(4));
      expect(feed.issues, isEmpty);
      expect(find.text('Grace', findRichText: true), findsOneWidget);
    });

    test('the stream parser reads JSONL with prose around it', () {
      final parser = A2uiJsonStreamParser();
      final out = <Map<String, Object?>>[];
      const text = 'Here you go:\n{"a": "x}"}\n{"b": [1, {"c": 2}]}\nDone.';
      for (final ch in text.split('')) {
        out.addAll(parser.add(ch));
      }
      expect(out, [
        {'a': 'x}'},
        {
          'b': [1, {'c': 2}],
        },
      ]);
    });
  });

  group('events', () {
    late GenUiSession session;
    late List<GenUiEvent> events;
    late StreamSubscription sub;

    Future<void> pumpForm(WidgetTester tester) async {
      session = GenUiSession(catalog: genUiCatalog(theme: testTheme));
      events = [];
      sub = session.events.listen(events.add);
      session.apply([
        create('f'),
        data('f', {'email': '', 'qty': 2, 'gift': false, 'plan': ['basic']}),
        components('f', form),
      ]);
      await pumpSurfaces(tester, session);
    }

    tearDown(() {
      sub.cancel();
      session.dispose();
    });

    testWidgets('typing writes the data model; submit sends a typed action with it', (tester) async {
      await pumpForm(tester);
      await tester.enterText(find.byType(TextField), 'ada@example.com');
      await tester.pump();
      expect(session.dataModelOf('f')['email'], 'ada@example.com');
      final changed = events.whereType<GenUiValueChanged>().last;
      expect(changed.path, '/email');
      expect(changed.value, 'ada@example.com');

      await tester.tap(find.text('Send order'));
      await tester.pumpAndSettle();
      final action = events.whereType<GenUiActionEvent>().single;
      expect(action.name, 'submit');
      expect(action.interaction, GenUiInteraction.formSubmit);
      expect(action.sourceComponentId, 'send');
      expect(action.context, {'email': 'ada@example.com', 'qty': 2});
      expect(action.dataModel['email'], 'ada@example.com');
      final message = action.toA2uiMessage();
      expect(message['version'], 'v0.9.1');
      expect((message['action']! as Map)['surfaceId'], 'f');
      expect(session.clientDataModel()!['surfaces'], {'f': session.dataModelOf('f')});
    });

    testWidgets('a slider writes while dragging and commits its action on release', (tester) async {
      await pumpForm(tester);
      final Finder slider = find.byType(Slider);
      await tester.drag(slider, const Offset(140, 0));
      await tester.pumpAndSettle();
      final int qty = session.dataModelOf('f')['qty'] as int;
      expect(qty, greaterThan(2));
      expect(events.whereType<GenUiValueChanged>().map((e) => e.path), contains('/qty'));
      final action = events.whereType<GenUiActionEvent>().single;
      expect(action.interaction, GenUiInteraction.sliderCommit);
      expect(action.context, {'qty': qty});
    });

    testWidgets('a checkbox toggle and a choice send their actions', (tester) async {
      await pumpForm(tester);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(session.dataModelOf('f')['gift'], true);
      await tester.tap(find.text('Pro'));
      await tester.pumpAndSettle();
      expect(session.dataModelOf('f')['plan'], ['pro']);
      final actions = events.whereType<GenUiActionEvent>().toList();
      expect(actions.map((a) => a.interaction), [GenUiInteraction.toggle, GenUiInteraction.selection]);
      expect(actions.last.context, {'plan': ['pro']});
    });

    testWidgets('table checkboxes update their row and report the toggle', (tester) async {
      session = GenUiSession(catalog: genUiCatalog(theme: testTheme));
      events = [];
      sub = session.events.listen(events.add);
      session.apply([
        create('t'),
        data('t', {'items': [
          {'name': '2x6 joist', 'qty': 13, 'cost': 14.2, 'got': false},
          {'name': 'Deck screws', 'qty': 4, 'cost': 39, 'got': false},
        ]}),
        components('t', [
          {'id': 'root', 'component': 'CodelesslyTable', 'rows': {'path': '/items'}, 'checkField': 'got',
           'columns': [
             {'header': 'Item', 'field': 'name'},
             {'header': 'Qty', 'field': 'qty', 'format': 'number'},
             {'header': 'Total', 'expr': 'qty * cost', 'format': 'currency', 'total': true},
           ],
           'action': {'event': {'name': 'inventory_checked', 'context': {'items': {'path': '/items'}}}}},
        ]),
      ]);
      await pumpSurfaces(tester, session);
      expect(find.text(r'$340.60'), findsOneWidget);
      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();
      final items = session.dataModelOf('t')['items'] as List;
      expect((items[1] as Map)['got'], true);
      expect((items[0] as Map)['got'], false);
      final action = events.whereType<GenUiActionEvent>().single;
      expect(action.interaction, GenUiInteraction.toggle);
      expect(((action.context['items'] as List)[1] as Map)['got'], true);
    });
  });

  group('validation', () {
    testWidgets('an invalid component shows a placeholder and is reported', (tester) async {
      final session = GenUiSession(catalog: genUiCatalog(theme: testTheme));
      addTearDown(session.dispose);
      final issues = session.apply([
        create('v'),
        components('v', [
          {'id': 'root', 'component': 'Column', 'children': ['ok', 'bad']},
          {'id': 'ok', 'component': 'Text', 'text': 'still here'},
          {'id': 'bad', 'component': 'Slider', 'label': 'No max', 'value': 3},
        ]),
      ]);
      expect(issues.single.code, 'VALIDATION_FAILED');
      expect(issues.single.path, '/components/2/max');
      await pumpSurfaces(tester, session);
      expect(find.text('still here', findRichText: true), findsOneWidget);
      expect(find.textContaining('bad could not be shown', findRichText: true), findsOneWidget);
    });

    test('check reports unknown components, dangling references and a missing root', () {
      final session = GenUiSession();
      addTearDown(session.dispose);
      final issues = session.check([
        create('c'),
        components('c', [
          {'id': 'main', 'component': 'Column', 'children': ['ghost']},
          {'id': 'x', 'component': 'Carousel'},
        ]),
      ]);
      final text = issues.join('\n');
      expect(text, contains('Carousel'));
      expect(text, contains('No component has id "root"'));
    });

    test('a valid surface checks clean', () {
      final session = GenUiSession();
      addTearDown(session.dispose);
      expect(session.check(fixture('weight_loss')), isEmpty);
      expect(session.check([create('d'), data('d', {'email': '', 'qty': 1, 'gift': false, 'plan': []}), components('d', form)]), isEmpty);
    });
  });
}
