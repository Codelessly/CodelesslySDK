// UiSession and CodelesslyView: a UI built and changed by edit ops renders
// progressively, re-applies only the boxes an op changed, shows nothing for
// a child that has not arrived (or a placeholder of the size an op gave),
// updates bindings when variables change, routes events to the session,
// undoes, and rejects what the trust profile does not allow.
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Catalog;
import 'package:flutter_test/flutter_test.dart';

Json _text(String text, {double w = 120}) => {
      'type': 'text',
      'layout': {'width': {'hug': w}, 'height': {'hug': 20}},
      'props': {'text': text, 'style': {'fontSize': 14, 'color': '#FF111827'}},
    };

const _canvas = {
  'type': 'canvas',
  'slots': {'body': 'page'},
  'layout': {'width': 390, 'height': {'hug': 300}},
};

Json _column(List<String> children) => {
      'type': 'column',
      'children': children,
      'layout': {'width': {'fill': 390}, 'height': {'hug': 100}},
      'props': {'spacing': 8, 'crossAxisAlignment': 'start'},
    };

List<Json> _ops() => [
      {'op': 'roots', 'roots': ['home']},
      {'op': 'set', 'id': 'home', 'node': _canvas},
      {'op': 'set', 'id': 'page', 'node': _column(['title', 'body', 'cta'])},
      {'op': 'set', 'id': 'title', 'node': _text('Flights to Lisbon')},
      {'op': 'set', 'id': 'body', 'node': _text('Three options')},
      {
        'op': 'set',
        'id': 'cta',
        'node': {
          ..._text('Confirm'),
          'actions': [
            {
              'trigger': {'type': 'click'},
              'actions': [
                {'type': 'componentEvent', 'event': 'confirm', 'value': {'flight': 'TP1351', 'seats': r'${seats}'}}
              ],
            }
          ],
        },
      },
    ];

/// Every node box on screen, by id (the render tree's boxes are render
/// objects without elements: walk the render tree), without the boxes of
/// pending children (they take no room: zero size).
Map<String, NodeBox> _boxes(WidgetTester tester, [UiSession? session]) {
  final out = <String, NodeBox>{};
  void visit(RenderObject o) {
    if (o is NodeBox && o.attached && (session == null || session.document[o.id] != null || session.node(o.id)?.bind.isEmpty == true)) out[o.id] = o;
    o.visitChildren(visit);
  }

  for (final v in tester.binding.renderViews) {
    visit(v);
  }
  return out;
}

Future<void> _show(WidgetTester tester, UiSession session) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: CodelesslyView(session: session))),
  ));
}

void main() {
  tearDown(() {
    NodeBox.debugCountApplies = false;
    NodeBox.debugApplyCounts.clear();
  });

  testWidgets('nothing shows until a root canvas exists; then the UI paints as ops arrive', (tester) async {
    final session = UiSession();
    await _show(tester, session);
    expect(_boxes(tester, session), isEmpty);
    final ops = _ops();
    session.apply([ops[0]]);
    await tester.pump();
    expect(_boxes(tester, session), isEmpty, reason: 'the root is pending');
    session.apply([ops[1]]);
    await tester.pump();
    expect(_boxes(tester, session).keys, ['home']);
    session.apply([ops[2]]);
    await tester.pump();
    // The column's children have not arrived: it waits for its first (no
    // empty shell), and so does the canvas; no errors.
    expect(_boxes(tester, session).keys.toSet(), {'home'});
    expect(tester.takeException(), isNull);
    NodeBox.debugCountApplies = true;
    NodeBox.debugApplyCounts.clear();
    session.apply([ops[3]]);
    await tester.pump();
    expect(_boxes(tester, session).keys.toSet(), {'home', 'page', 'title'});
    // The first child of a container that showed nothing yet: the container
    // shows (its waiting children get their boxes).
    expect(NodeBox.debugApplyCounts, {'home': 1, 'page': 1, 'title': 1, 'body': 1, 'cta': 1});
    NodeBox.debugApplyCounts.clear();
    session.apply([ops[4]]);
    await tester.pump();
    // Any later child: only the box that waited for it.
    expect(NodeBox.debugApplyCounts, {'body': 1});
    session.apply(ops.sublist(5));
    await tester.pump();
    expect(_boxes(tester, session).keys.toSet(), {'home', 'page', 'title', 'body', 'cta'});
    expect(tester.takeException(), isNull);
    expect(session.pending, isEmpty);
  });

  testWidgets('an op re-applies only the boxes it changed (and the parent of a node that arrives)', (tester) async {
    final session = UiSession();
    session.apply({'ops': _ops()});
    await _show(tester, session);
    await tester.pump();
    NodeBox.debugCountApplies = true;
    NodeBox.debugApplyCounts.clear();
    session.apply([
      {'op': 'patch', 'id': 'body', 'patch': {'props': {'text': 'Two options'}}}
    ]);
    await tester.pump();
    expect(NodeBox.debugApplyCounts, {'body': 1});
    NodeBox.debugApplyCounts.clear();
    // Placing a node under a parent that did not list it changes the
    // parent's child list: the parent and its children re-apply (a child's
    // slot holds its parent node).
    session.apply([
      {'op': 'set', 'id': 'note', 'parent': 'page', 'index': 1, 'node': _text('Prices include bags')}
    ]);
    await tester.pump();
    expect(NodeBox.debugApplyCounts.keys.toSet(), {'note', 'page', 'title', 'body', 'cta'});
    NodeBox.debugApplyCounts.clear();
    // A patch: only the node.
    session.apply([
      {'op': 'patch', 'id': 'note', 'patch': {'props': {'text': 'Bags included'}}}
    ]);
    await tester.pump();
    expect(NodeBox.debugApplyCounts, {'note': 1});
    NodeBox.debugApplyCounts.clear();
    session.apply([
      {'op': 'remove', 'ids': ['note']}
    ]);
    await tester.pump();
    expect(NodeBox.debugApplyCounts.keys.toSet(), {'page', 'title', 'body', 'cta', 'note'});
    expect(_boxes(tester, session).containsKey('note'), isFalse);
  });

  testWidgets('streamed operations apply as their text completes, whatever the chunks, and the result is the tool result', (tester) async {
    final session = UiSession();
    await _show(tester, session);
    final text = jsonEncode({'ops': _ops()});
    final controller = StreamController<String>();
    final done = session.applyStream(controller.stream);
    // Up to the end of the page op: canvas and column, no children yet.
    final cut = text.indexOf('{"op":"set","id":"title"');
    for (var i = 0; i < cut; i += 7) {
      controller.add(text.substring(i, i + 7 > cut ? cut : i + 7));
      await tester.pump();
    }
    expect(_boxes(tester, session).keys.toSet(), {'home'});
    expect(session.streaming.value, isTrue);
    controller.add(text.substring(cut));
    await controller.close();
    final r = await done;
    await tester.pump();
    expect(r.applied, [0, 1, 2, 3, 4, 5]);
    expect(r.errors, isEmpty);
    expect(r.rev, 1);
    expect(session.rev, 1);
    expect(_boxes(tester, session).length, 5);
    expect(r.toModelJson()['rejected'], isEmpty);
  });

  testWidgets('a stream that ends with children missing reports them dangling', (tester) async {
    final session = UiSession();
    final r = await session.applyStream(Stream.value(jsonEncode({'ops': _ops().take(4).toList()})));
    expect({for (final d in r.errors) d.code}, {'dangling_child'});
    expect(r.pending, {'body', 'cta'});
  });

  testWidgets('a placeholder of the size an op gave holds the place of a pending child', (tester) async {
    final session = UiSession();
    await _show(tester, session);
    final ops = _ops();
    session.apply([
      ops[0],
      ops[1],
      {
        ...ops[2],
        'placeholders': {
          'body': {'width': 200, 'height': 48}
        },
      },
      ops[3],
    ]);
    await tester.pump();
    final boxes = _boxes(tester, session);
    expect(boxes['body']!.size, const Size(200, 48));
    expect(boxes.containsKey('cta'), isFalse);
    session.apply([ops[4]]);
    await tester.pump();
    expect(_boxes(tester, session)['body']!.node!.type, 'text');
  });

  testWidgets('variable operations update bindings live, and events reach the session with their node and payload', (tester) async {
    final session = UiSession();
    session.apply({
      'ops': [
        ..._ops(),
        {
          'op': 'vars',
          'scope': 'home',
          'set': {
            'seats': {'type': 'integer', 'value': 1}
          },
        },
        {'op': 'patch', 'id': 'body', 'patch': {'bind': {'props.text': r'${seats} seats'}}},
      ],
    });
    await _show(tester, session);
    await tester.pump();
    String bodyText() => '${_boxes(tester, session)['body']!.node!.props.toJson(null)['text']}';
    expect(bodyText(), '1 seats');
    session.apply([
      {'op': 'vars', 'scope': 'home', 'set': {'seats': 3}}
    ]);
    await tester.pump();
    expect(bodyText(), '3 seats');
    final events = <UiEvent>[];
    final sub = session.events.listen(events.add);
    final cta = _boxes(tester, session)['cta']!;
    await tester.tapAt(cta.localToGlobal(cta.size.center(Offset.zero)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    expect(events.single.event, 'confirm');
    expect(events.single.source, 'cta');
    expect(events.single.value, {'flight': 'TP1351', 'seats': 3});
    expect(events.single.toModelMessage(), contains('"confirm"'));
    unawaited(sub.cancel());
  });

  testWidgets('undo and redo a batch; the rendered UI follows', (tester) async {
    final session = UiSession();
    session.apply({'ops': _ops()});
    await _show(tester, session);
    session.apply([
      {'op': 'patch', 'id': 'title', 'patch': {'props': {'text': 'Flights to Porto'}}},
      {'op': 'remove', 'ids': ['body']},
    ]);
    await tester.pump();
    expect(_boxes(tester, session).containsKey('body'), isFalse);
    expect(session.undo(), isTrue);
    await tester.pump();
    expect(_boxes(tester, session).containsKey('body'), isTrue);
    expect(session.document['title']!.props.toJson(null)['text'], 'Flights to Lisbon');
    expect(session.redo(), isTrue);
    await tester.pump();
    expect(_boxes(tester, session).containsKey('body'), isFalse);
    expect(session.undo(), isTrue);
    expect(session.undo(), isTrue);
    expect(session.document.nodes, isEmpty);
    expect(session.undo(), isFalse);
  });

  test('the agent profile by default: scripts, links, feature types are rejected', () {
    final session = UiSession(catalog: standardCatalog);
    final r = session.apply({
      'ops': [
        ..._ops(),
        {'op': 'set', 'id': 'v', 'parent': 'page', 'node': {'type': 'video', 'layout': {'width': 100, 'height': 60}}},
        {
          'op': 'patch',
          'id': 'cta',
          'patch': {
            'actions': [
              {
                'trigger': {'type': 'click'},
                'actions': [
                  {'type': 'runScript', 'script': 'x'}
                ],
              }
            ],
          },
        },
      ],
    });
    expect({for (final d in r.errors) (d.op, d.code)}, {(6, 'capability_not_allowed'), (7, 'capability_not_allowed')});
    expect(session.tools.first['name'], 'ui_apply');
    expect(jsonEncode(session.tools), isNot(contains('"video"')));
    expect(session.outline()['outline'], hasLength(5));
  });

  test('an edit to a field another author changed since is rejected with the current value', () {
    final session = UiSession();
    session.apply({'ops': _ops()});
    final read = session.rev;
    session.apply([
      {'op': 'patch', 'id': 'title', 'patch': {'props': {'text': 'Mine'}}}
    ], author: 'person');
    final r = session.apply({
      'baseRev': read,
      'ops': [
        {'op': 'patch', 'id': 'title', 'patch': {'props': {'text': 'Agent'}}}
      ],
    });
    expect(r.errors.single.code, 'stale_rev');
    expect(session.document['title']!.props.toJson(null)['text'], 'Mine');
  });

  test('with arrival fades on, a node that arrives in a stream fades in; they are off by default', () async {
    final plain = UiSession();
    await plain.applyStream(Stream.value(jsonEncode({'ops': _ops()})));
    expect(plain.node('title')!.behaviors.animations, isEmpty);
    final faded = UiSession(arrivalFade: const Duration(milliseconds: 180));
    await faded.applyStream(Stream.value(jsonEncode({'ops': _ops()})));
    final a = faded.node('title')!.behaviors.animations.single;
    expect(a.preset, 'enter');
    expect(a.duration, 180);
    // The document itself is as the model wrote it.
    expect(faded.document['title']!.behaviors.animations, isEmpty);
  });
}
