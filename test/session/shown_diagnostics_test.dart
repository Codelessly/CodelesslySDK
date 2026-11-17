// A valid document can show nothing. Recorded SSUI generations
// (tool/stream/streams/live/2026-11-14-ssui) did: a retry replaced the
// canvas with a column, base turns lost their only container to one
// rejected op, a reservation card's texts drew transparent. Once a view has
// laid the UI out, UiSession.shownDiagnostics says what shows wrong, as
// diagnostics a host adds to the tool result.
import 'dart:io';

import 'package:codelessly_api/validate.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Card; // ignore: deprecated_member_use
import 'package:flutter_test/flutter_test.dart';


Future<DesignSystem> _ssui() => DesignSystem.load((ref) async {
      final f = File('design_systems/ssui/$ref');
      return f.existsSync() ? f.readAsStringSync() : null;
    });

/// A card: a canvas whose body column holds [children] (node id → node);
/// [inner]: nodes that other nodes list (a list's item template).
List<Map<String, Object?>> _card(Map<String, Map<String, Object?>> children,
        {Map<String, Object?> vars = const {}, Map<String, Map<String, Object?>> inner = const {}}) =>
    [
      {'op': 'roots', 'roots': ['c']},
      {'op': 'set', 'id': 'c', 'node': {'type': 'canvas', 'slots': {'body': 'col'}, 'layout': {'width': 360, 'height': {'hug': 300}}}},
      if (vars.isNotEmpty) {'op': 'vars', 'scope': 'c', 'set': vars},
      {
        'op': 'set',
        'id': 'col',
        'node': {
          'type': 'column',
          'children': children.keys.toList(),
          'layout': {'width': {'fill': 360}, 'height': {'hug': 300}, 'padding': 12},
        },
      },
      for (final e in {...children, ...inner}.entries) {'op': 'set', 'id': e.key, 'node': e.value},
    ];

/// A session that validates as a host should: strictEditCheck with the
/// SDK's formula parser.
UiSession _strict({DesignSystem? ds}) =>
    UiSession(designSystem: ds, check: strictEditCheck(ValidateOptions(formulas: FormulaEvaluator.report, components: ds?.components, theme: ds?.tokens)));

/// [ops] applied to [session] with no errors.
void _ok(UiSession session, List<Map<String, Object?>> ops) {
  final r = session.apply(ops);
  expect(r.errors, isEmpty, reason: '${r.errors}');
}

const _text = {'width': {'fill': 336}, 'height': {'hug': 20}};

Future<List<EditDiagnostic>> _shown(WidgetTester tester, UiSession session) async {
  await tester.pumpWidget(MaterialApp(home: Material(child: SingleChildScrollView(child: CodelesslyView(session: session)))));
  await tester.pump();
  final out = session.shownDiagnostics();
  await tester.pumpWidget(const SizedBox());
  return out;
}

void main() {
  testWidgets('a card that shows its text reports nothing', (tester) async {
    final session = _strict();
    addTearDown(session.dispose);
    _ok(session, _card({
      't': {'type': 'text', 'layout': _text, 'props': {'text': 'Hello', 'style': {'color': '#FF111827'}}},
    }));
    expect(await _shown(tester, session), isEmpty);
  });

  testWidgets('a card whose body never arrived: empty_view names what to send', (tester) async {
    final session = _strict();
    addTearDown(session.dispose);
    _ok(session, [
      {'op': 'roots', 'roots': ['c']},
      {'op': 'set', 'id': 'c', 'node': {'type': 'canvas', 'slots': {'body': 'card'}, 'layout': {'width': 360, 'height': {'hug': 300}}}},
    ]);
    final d = (await _shown(tester, session)).singleWhere((d) => d.code == 'empty_view');
    expect(d.message, contains('its content "card" never arrived'));
  });

  testWidgets('everything hidden by a visible binding: empty_view says to check them', (tester) async {
    final session = _strict();
    addTearDown(session.dispose);
    _ok(session, _card({
      't': {'type': 'text', 'layout': _text, 'props': {'text': 'Done', 'style': {'color': '#FF111827'}}, 'bind': {'visible': r'${done}'}},
    }, vars: {'done': {'type': 'boolean', 'value': false}}));
    final d = (await _shown(tester, session)).singleWhere((d) => d.code == 'empty_view');
    expect(d.message, contains('hidden, empty or has no size'));
  });

  group('lists', () {
    Map<String, Object?> list(String data, {List<String> children = const ['row']}) => {
          'type': 'listView',
          'children': children,
          'layout': {'width': {'fill': 336}, 'height': 120},
          'bind': {'data': data},
        };
    final row = {'type': 'text', 'layout': _text, 'props': {'text': r'${item.name}', 'style': {'color': '#FF111827'}}};
    const people = {'type': 'list', 'value': [{'name': 'Ana', 'status': 'Paid'}, {'name': 'Bo', 'status': 'Due'}]};

    testWidgets('a list whose data is not a list: list_empty says what it gives', (tester) async {
      final session = _strict();
      addTearDown(session.dispose);
      _ok(session, _card({
        'title': {'type': 'text', 'layout': _text, 'props': {'text': 'People', 'style': {'color': '#FF111827'}}},
        'l': list(r'${who}'),
      }, inner: {'row': row}, vars: {'who': {'type': 'text', 'value': 'Ana, Bo'}}));
      final d = (await _shown(tester, session)).singleWhere((d) => d.code == 'list_empty');
      expect(d.error, isTrue);
      expect(d.message, contains(r'its data ${who} gives the text "Ana, Bo"'));
    });

    testWidgets('a list with data and no item template: list_empty says to add one', (tester) async {
      final session = _strict();
      addTearDown(session.dispose);
      _ok(session, _card({
        'title': {'type': 'text', 'layout': _text, 'props': {'text': 'People', 'style': {'color': '#FF111827'}}},
        'l': list(r'${people}', children: const []),
      }, vars: {'people': people}));
      final d = (await _shown(tester, session)).singleWhere((d) => d.code == 'list_empty');
      expect(d.message, contains('no item template'));
    });

    testWidgets('a list that shows its items reports nothing', (tester) async {
      final session = _strict();
      addTearDown(session.dispose);
      _ok(session, _card({'l': list(r'${people}')}, inner: {'row': row}, vars: {'people': people}));
      expect(await _shown(tester, session), isEmpty);
    });
  });

  testWidgets('a text in a transparent color: text_no_color', (tester) async {
    final session = _strict();
    addTearDown(session.dispose);
    _ok(session, _card({
      'a': {'type': 'text', 'layout': _text, 'props': {'text': 'Shown', 'style': {'color': '#FF111827'}}},
      'b': {'type': 'text', 'layout': _text, 'props': {'text': 'Mon', 'style': {'color': '#00000000'}}},
    }));
    final d = (await _shown(tester, session)).singleWhere((d) => d.code == 'text_no_color');
    expect((d.nodeId, d.error), ('b', false));
    expect(d.message, contains('transparent color'));
  });

  testWidgets('a design system button whose bound label gives nothing: empty_label', (tester) async {
    final ds = (await tester.runAsync(_ssui))!;
    final session = _strict(ds: ds);
    addTearDown(session.dispose);
    _ok(session, _card({
      'title': {'type': 'text', 'layout': _text, 'props': {'text': 'Order', 'style': {'color': '#FF111827'}}},
      'go': {
        'type': 'Button',
        'props': {'label': 'x'},
        'bind': {'props.label': r'${= confirmLabel}'},
        'layout': {'width': {'hug': 80}, 'height': {'hug': 28}},
      },
    }, vars: {'confirmLabel': {'type': 'text', 'value': ''}}));
    final d = (await _shown(tester, session)).singleWhere((d) => d.code == 'empty_label');
    expect(d.nodeId, 'go');
    expect(d.message, contains(r'"go" (Button) shows an empty label: "${= confirmLabel}" gave nothing'));
  });

  testWidgets('a progress bar at zero and an unchecked checkbox show their track and box: no component_empty', (tester) async {
    final ds = (await tester.runAsync(_ssui))!;
    final session = _strict(ds: ds);
    addTearDown(session.dispose);
    _ok(session, _card({
      'bar': {'type': 'ProgressBar', 'props': {'value': 0}, 'layout': {'width': {'fill': 336}, 'height': 6}},
      'tick': {'type': 'Checkbox', 'props': {'value': 'done'}, 'layout': {'width': {'hug': 16}, 'height': {'hug': 16}}},
    }, vars: {'done': {'type': 'boolean', 'value': false}}));
    expect(await _shown(tester, session), isEmpty);
  });
}
