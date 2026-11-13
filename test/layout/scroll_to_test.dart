import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screen.dart' as harness;
import 'scroll_test.dart' show viewport;

// scrollTo with `item`: reveal one copy of a list's item template (Strata
// v2: the timeline and glossary jump to one layer among the wall's eleven).

Map<String, Json> page(String item) => {
      'col': {
        'type': 'column',
        'props': {'scrollable': true},
        'layout': {'width': 200, 'height': 200},
        'children': ['go', 'list'],
      },
      'go': {
        'type': 'box',
        'layout': {'width': 200, 'height': 40},
        'actions': [
          {
            'trigger': {'type': 'click'},
            'actions': [
              {'type': 'scrollTo', 'node': 'row', 'item': item, 'durationMs': 0},
            ],
          },
        ],
      },
      'list': {
        'type': 'listView',
        'props': {'scrollable': false},
        'layout': {'width': 200, 'height': {'hug': 500}},
        'bind': {'data': r'${rows}'},
        'children': ['row'],
      },
      'row': {
        'type': 'box',
        'layout': {'width': 200, 'height': 100},
      },
    };

const rows = Variable(name: 'rows', type: VariableType.list, value: [
  {'id': 'a'},
  {'id': 'b'},
  {'id': 'c'},
  {'id': 'd'},
  {'id': 'e'},
]);

// scrollTo waits for fonts in flight (Strata v2: the wall's load jump ran
// before the project's uploaded fonts arrived; the text above re-measured
// and the jump landed 73 px off).

// reveal.follow keeps an end marker in view while the content above it
// grows (a transcript pinned to its newest line), until the user scrolls.

Future<(harness.Screen, RenderDesignScroll)> _show(WidgetTester tester, {required bool follow}) async {
  final s = await harness.show(
    tester,
    {
      'col': {
        'type': 'column',
        'layout': {'width': 200, 'height': 120},
        'props': {'scrollable': true},
        'children': ['lines', 'end'],
      },
      'lines': {
        'type': 'box',
        'layout': {'width': 200, 'height': 300},
        'bind': {'layout.height': r'${h}'},
      },
      'end': {
        'type': 'box',
        'layout': {'width': 200, 'height': 10},
        'reveal': {'alignment': 1, 'duration': 0, 'follow': follow},
      },
    },
    variables: [harness.v('h', 300, VariableType.integer)],
  );
  RenderDesignScroll? viewport;
  void find(RenderObject r) {
    if (r is RenderDesignScroll) viewport = r;
    r.visitChildren(find);
  }

  find(s.tree.boxOf('col')!);
  await tester.pump();
  await tester.pump();
  return (s, viewport!);
}

void main() {
  for (final (item, expected) in [('c', 240.0), (r'${= "d"}', 340.0), ('1', 140.0)]) {
    testWidgets('a scroll-to action reveals the copy of a repeated node for item $item', (tester) async {
      final screen = await harness.show(tester, page(item), variables: [rows]);
      final view = viewport(screen.tree);
      await tester.tapAt(view.localToGlobal(const Offset(100, 20)));
      await tester.pump();
      await tester.pump();
      expect(view.pixels, expected);
    });
  }

  testWidgets('a scroll-to offset can be a formula', (tester) async {
    final nodes = page('c');
    ((nodes['go']!['actions'] as List).first['actions'] as List).first['offset'] = r'${= -number(shift)}';
    final screen = await harness.show(tester, nodes, variables: [rows, const Variable(name: 'shift', value: '60')]);
    final view = viewport(screen.tree);
    await tester.tapAt(view.localToGlobal(const Offset(100, 20)));
    await tester.pump();
    expect(view.pixels, 300);
  });

  testWidgets('a scroll-to run when the screen loads waits for the view to lay out', (tester) async {
    final nodes = page('d');
    nodes['col']!['actions'] = (nodes['go']!['actions'] as List).map((r) => {...(r as Map), 'trigger': {'type': 'load'}}).toList();
    final screen = await harness.show(tester, nodes, variables: [rows]);
    final view = viewport(screen.tree);
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    expect(view.pixels, 340);
  });

  testWidgets('without an item a scroll-to goes to the first copy', (tester) async {
    final screen = await harness.show(tester, page(''), variables: [rows]);
    final view = viewport(screen.tree);
    await tester.tapAt(view.localToGlobal(const Offset(100, 20)));
    await tester.pump();
    expect(view.pixels, 40);
  });

  group('fonts still loading', () {
    testWidgets('a scroll-to waits for a font that is still loading, then lands on its target', (tester) async {
      final load = Completer<void>();
      CodelesslyFonts.track(load.future);
      final screen = await harness.show(tester, page('d'), variables: [rows]);
      final view = viewport(screen.tree);
      await tester.tapAt(view.localToGlobal(const Offset(100, 20)));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(view.pixels, 0, reason: 'still waiting for the font');
      load.complete();
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(view.pixels, 340);
    });
  });

  group('keeping a node in view', () {
    testWidgets('following keeps the end in view as content grows, until the user scrolls away', (tester) async {
      final (s, viewport) = await _show(tester, follow: true);
      expect(viewport.offset, closeTo(190, .1), reason: 'revealed at the bottom: 310 - 120');

      setVariableIn(s.scope, 'h', 500);
      await tester.pump();
      await tester.pump();
      expect(viewport.offset, closeTo(390, .1), reason: 'followed the end down');

      // Shorter content clamps the offset: still following.
      setVariableIn(s.scope, 'h', 400);
      await tester.pump();
      await tester.pump();
      setVariableIn(s.scope, 'h', 450);
      await tester.pump();
      await tester.pump();
      expect(viewport.offset, closeTo(340, .1));

      // A program scrolls (a scrollTo action) as the content grows: still
      // following.
      viewport.jumpBy(-30);
      setVariableIn(s.scope, 'h', 480);
      await tester.pump();
      await tester.pump();
      expect(viewport.offset, closeTo(370, .1));

      // The user drags it down (scrolling up): it stops following.
      await tester.drag(find.byType(NodeView), const Offset(0, 100));
      await tester.pump();
      final left = viewport.offset;
      expect(left, lessThan(370));
      setVariableIn(s.scope, 'h', 700);
      await tester.pump();
      await tester.pump();
      expect(viewport.offset, closeTo(left, .1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('without following the node is revealed once', (tester) async {
      final (s, viewport) = await _show(tester, follow: false);
      expect(viewport.offset, closeTo(190, .1));
      setVariableIn(s.scope, 'h', 500);
      await tester.pump();
      await tester.pump();
      expect(viewport.offset, closeTo(190, .1));
    });

    testWidgets('a node asked for by a binding is scrolled into view', (tester) async {
      final s = await harness.show(
        tester,
        {
          'col': {
            'type': 'column',
            'layout': {'width': 200, 'height': 120},
            'props': {'scrollable': true},
            'children': ['spacer', 'target', 'tail'],
          },
          'spacer': {
            'type': 'box',
            'layout': {'width': 200, 'height': 300},
          },
          'target': {
            'type': 'box',
            'layout': {'width': 200, 'height': 40},
            'reveal': {'when': false, 'alignment': 0, 'duration': 100},
            'bind': {'reveal.when': r'${reveal}'},
          },
          'tail': {
            'type': 'box',
            'layout': {'width': 200, 'height': 200},
          },
        },
        variables: [harness.v('reveal', false, VariableType.boolean)],
      );
      RenderDesignScroll? viewport;
      void find(RenderObject r) {
        if (r is RenderDesignScroll) viewport = r;
        r.visitChildren(find);
      }

      find(s.tree.boxOf('col')!);
      expect(viewport!.offset, 0);
      setVariableIn(s.scope, 'reveal', true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(viewport!.offset, closeTo(300, .1));
      // A false-to-true request can reveal it again after manual scrolling.
      setVariableIn(s.scope, 'reveal', false);
      viewport!.jumpBy(-300);
      await tester.pump();
      setVariableIn(s.scope, 'reveal', true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(viewport!.offset, closeTo(300, .1));
      expect(tester.takeException(), isNull);
    });
  });

  group('scroll events', () {
    testWidgets(
      'scrolling writes its position to variables and reports when it ends, also after an animated scroll-to',
      (tester) async {
        final doc = LayoutDocument.fromJson({
          'roots': ['body'],
          'nodes': {
            'body': {
              'type': 'column',
              'layout': {'width': 200, 'height': 120},
              'props': {'scrollable': true},
              'children': ['a', 'b'],
              'actions': [
                {
                  'trigger': {'type': 'scroll'},
                  'actions': [
                    {
                      'type': 'setVariable',
                      'variable': 'offset',
                      'value': r'${result.offset}',
                    },
                    {
                      'type': 'setVariable',
                      'variable': 'progress',
                      'value': r'${result.progress}',
                    },
                  ],
                },
                {
                  'trigger': {'type': 'scrollEnd'},
                  'actions': [
                    {
                      'type': 'setVariable',
                      'variable': 'ended',
                      'op': 'add',
                      'value': '1',
                    },
                  ],
                },
                {
                  'trigger': {'type': 'click'},
                  'actions': [
                    {
                      'type': 'scrollTo',
                      'node': 'b',
                      'durationMs': 200,
                      'axis': 'vertical',
                    },
                  ],
                },
              ],
            },
            'a': {
              'type': 'box',
              'layout': {'width': 200, 'height': 120},
            },
            'b': {
              'actions': [
                {
                  'trigger': {'type': 'enterViewport', 'visibleFraction': .9},
                  'actions': [
                    {'type': 'setVariable', 'variable': 'entered', 'value': '1'},
                  ],
                },
              ],
              'type': 'box',
              'layout': {'width': 200, 'height': 120},
            },
          },
        });
        final values = NodeValues(DocumentSource(doc));
        final scope = VariableScope([
          const Variable(
            id: 'v',
            name: 'entered',
            type: VariableType.integer,
            value: 0,
          ),
          const Variable(
            id: 'o',
            name: 'offset',
            type: VariableType.decimal,
            value: 0.0,
          ),
          const Variable(
            id: 'p',
            name: 'progress',
            type: VariableType.decimal,
            value: 0.0,
          ),
          const Variable(
            id: 'e',
            name: 'ended',
            type: VariableType.integer,
            value: 0,
          ),
        ]);
        final tree = NodeTree(values, binder: NodeBinder(scope: scope));
        final context = RuntimeActionContext(
          scope: scope,
          tree: tree,
          nodeValues: values,
        );
        tree.interactions = TreeReactions(
          runner: const CodelesslyActions(),
          context: context,
        );
        addTearDown(tree.dispose);
        addTearDown(scope.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Align(
              alignment: Alignment.topLeft,
              child: NodeView(tree: tree, rootId: 'body', interactive: true),
            ),
          ),
        );
        expect(visibleShare(tree.boxOf('b')!), 0);
        await tester.sendEventToBinding(
          const PointerScrollEvent(
            position: Offset(80, 80),
            scrollDelta: Offset(0, 50),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(scope.read('offset'), 50);
        expect(scope.read('progress'), closeTo(50 / 120, 1e-6));
        await tester.pump(const Duration(milliseconds: 120));
        expect(scope.read('ended'), 1);
        final move = const CodelesslyActions().trigger(
          doc['body']!,
          'click',
          context,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          (scope.read('offset') as num).toDouble(),
          inExclusiveRange(50, 120),
        );
        await tester.pump(const Duration(milliseconds: 120));
        await move;
        await tester.pump();
        expect(scope.read('offset'), 120);
        expect(scope.read('progress'), 1);
        expect(visibleShare(tree.boxOf('b')!), 1);
        expect(scope.read('entered'), 1);
        expect(tree.boxOf('b')!.localToGlobal(Offset.zero).dy, closeTo(0, 1e-6));
        await tester.pump(const Duration(milliseconds: 120));
      },
    );
  });
}
