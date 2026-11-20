import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codelessly_sdk/src/render/controls/spinner.dart' show RenderSpinner, SpinnerStyle;
import 'package:codelessly_sdk/src/render/node_view.dart' show SpinnerView;

import 'support.dart' as lists;

// A running list over data keeps what is in view where it is when items are
// put before it or taken out before it (scroll anchoring); at its start it
// shows what is put there unless `stickToStart` is false.

/// Messages [from] to [to] newest first (a reversed chat's data).
List<Object?> newestFirst(int from, int to) => [for (var i = to - 1; i >= from; i--) {'id': i, 'text': 'M$i'}];

/// Messages [from] to [to] in order.
List<Object?> inOrder(int from, int to) => [for (var i = from; i < to; i++) {'id': i, 'text': 'M$i'}];

Map<String, Json> list({bool reverse = false, Map<String, Object?> props = const {}, List<double>? padding}) => {
      'col': {
        'type': 'column',
        'children': ['list'],
        'layout': {'width': 300, 'height': 400},
      },
      'list': {
        'type': 'listView',
        'children': ['row'],
        'layout': {'width': 300, 'height': 400, 'padding': ?padding},
        'bind': {'data': r'${messages}'},
        'props': {'reverse': reverse, ...props},
      },
      'row': {
        'type': 'text',
        'layout': {'width': 300, 'height': 40},
        'props': {'text': r'${item.text}'},
      },
    };

void main() {
  ScrollPosition position(WidgetTester tester) => tester
      .state<ScrollableState>(find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)))
      .position;

  /// Where the row reading [text] is drawn, or null when it is not built.
  Rect? rectOf(WidgetTester tester, String text) {
    Rect? found;
    void visit(RenderObject o) {
      if (found != null) return;
      if (o is RenderParagraph && o.attached && o.hasSize && o.text.toPlainText() == text) {
        found = o.localToGlobal(Offset.zero) & o.size;
        return;
      }
      o.visitChildren(visit);
    }

    for (final root in tester.renderObjectList<RenderBox>(find.byType(NodeView))) {
      visit(root);
    }
    return found;
  }

  /// The first row whose top is in the 400-high view, from its top.
  String firstInView(WidgetTester tester, {bool fromBottom = false}) {
    String? best;
    double? at;
    void visit(RenderObject o) {
      if (o is RenderParagraph && o.attached && o.hasSize) {
        final y = o.localToGlobal(Offset.zero).dy;
        if (y >= -0.5 && y + o.size.height <= 400.5 && (at == null || (fromBottom ? y > at! : y < at!))) {
          at = y;
          best = o.text.toPlainText();
        }
      }
      o.visitChildren(visit);
    }

    visit(tester.renderObjectList<RenderBox>(find.byType(NodeView)).first);
    return best!;
  }

  group('a reversed list (a chat, newest first)', () {
    testWidgets('scrolled up, newer messages put at its start move nothing in view', (tester) async {
      final s = await lists.show(tester, list(reverse: true), variables: [lists.v('messages', newestFirst(0, 40), VariableType.list)]);
      await tester.pumpAndSettle();
      final p = position(tester);
      p.jumpTo(300);
      await tester.pumpAndSettle();
      final reading = firstInView(tester);
      final before = rectOf(tester, reading)!;

      s.scope.set('messages', newestFirst(0, 41));
      await tester.pumpAndSettle();
      expect(rectOf(tester, reading), before, reason: 'one new message');

      s.scope.set('messages', newestFirst(0, 45));
      await tester.pumpAndSettle();
      expect(rectOf(tester, reading), before, reason: 'four more');

      // The new ones are there below, the newest at the very bottom: one
      // drag reaches it.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(firstInView(tester, fromBottom: true), 'M44');
    });

    testWidgets('an older page put at its far end moves nothing', (tester) async {
      final s = await lists.show(tester, list(reverse: true), variables: [lists.v('messages', newestFirst(20, 40), VariableType.list)]);
      await tester.pumpAndSettle();
      final p = position(tester);
      p.jumpTo(p.maxScrollExtent - 50);
      await tester.pumpAndSettle();
      final reading = firstInView(tester);
      final before = rectOf(tester, reading)!;

      s.scope.set('messages', newestFirst(0, 40));
      await tester.pumpAndSettle();
      expect(rectOf(tester, reading), before);
    });

    testWidgets('at its start (the newest) it shows a new message, as a browser does at a page top', (tester) async {
      final s = await lists.show(tester, list(reverse: true), variables: [lists.v('messages', newestFirst(0, 40), VariableType.list)]);
      await tester.pumpAndSettle();
      final before = rectOf(tester, 'M39')!;
      s.scope.set('messages', newestFirst(0, 41));
      await tester.pumpAndSettle();
      expect(rectOf(tester, 'M39'), before.shift(const Offset(0, -40)));
      expect(firstInView(tester, fromBottom: true), 'M40');
      expect(position(tester).pixels, position(tester).minScrollExtent);
    });

    testWidgets('stickToStart=false: at its start too a new message moves nothing (it waits below)', (tester) async {
      final s = await lists.show(tester, list(reverse: true, props: {'stickToStart': false}),
          variables: [lists.v('messages', newestFirst(0, 40), VariableType.list)]);
      await tester.pumpAndSettle();
      final before = rectOf(tester, 'M39')!;
      s.scope.set('messages', newestFirst(0, 41));
      await tester.pumpAndSettle();
      expect(rectOf(tester, 'M39'), before);
      final p = position(tester);
      expect(p.minScrollExtent, -40, reason: 'the new one is a scroll away');
      p.jumpTo(p.minScrollExtent);
      await tester.pumpAndSettle();
      expect(firstInView(tester, fromBottom: true), 'M40');
    });

    testWidgets('stickToStart=false shows new messages while they do not fill the list', (tester) async {
      final s = await lists.show(tester, list(reverse: true, props: {'stickToStart': false}),
          variables: [lists.v('messages', newestFirst(0, 3), VariableType.list)]);
      await tester.pumpAndSettle();
      s.scope.set('messages', newestFirst(0, 4));
      await tester.pumpAndSettle();
      expect(rectOf(tester, 'M3')!.top, 360);
      expect(rectOf(tester, 'M2')!.top, 320);
    });

    testWidgets('messages taken out before what is in view move nothing', (tester) async {
      final s = await lists.show(tester, list(reverse: true), variables: [lists.v('messages', newestFirst(0, 40), VariableType.list)]);
      await tester.pumpAndSettle();
      position(tester).jumpTo(300);
      await tester.pumpAndSettle();
      final reading = firstInView(tester);
      final before = rectOf(tester, reading)!;
      // The three newest go (deleted, or a provisional copy replaced).
      s.scope.set('messages', newestFirst(0, 37));
      await tester.pumpAndSettle();
      expect(rectOf(tester, reading), before);
    });

    testWidgets('rows of their own heights: rows put in and taken out between its start and the view move nothing', (tester) async {
      List<Object?> rows(Iterable<int> ids) => [for (final i in ids) {'id': i, 'text': 'M$i', 'h': 30 + (i * 37) % 90}];
      final doc = list(reverse: true);
      doc['row'] = {...doc['row']!, 'bind': {'layout.height': r'${item.h}'}};
      final s = await lists.show(tester, doc, variables: [lists.v('messages', rows([for (var i = 59; i >= 0; i--) i]), VariableType.list)]);
      await tester.pumpAndSettle();
      position(tester).jumpTo(750);
      await tester.pumpAndSettle();
      final reading = firstInView(tester);
      final before = rectOf(tester, reading)!;
      // Two newer at the start, and three between the start and the view
      // taken out: the anchor passes to the row in view.
      s.scope.set('messages', rows([61, 60, 59, 58, 54, for (var i = 53; i >= 0; i--) i]));
      await tester.pumpAndSettle();
      expect(rectOf(tester, reading), before);
      // And again, with one put back.
      s.scope.set('messages', rows([62, 61, 60, 59, 56, 58, 54, for (var i = 53; i >= 0; i--) i]));
      await tester.pumpAndSettle();
      expect(rectOf(tester, reading), before);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
      await tester.pumpAndSettle();
      expect(firstInView(tester, fromBottom: true), 'M62');
    });

    testWidgets('a quoted message not loaded yet: load it, then scroll to it by its id', (tester) async {
      final s = await lists.show(tester, list(reverse: true), variables: [lists.v('messages', newestFirst(180, 200), VariableType.list)]);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 'M3'), isNull);
      // Pages load until the message is there (older ones at the far end:
      // nothing in view moves), then the list goes to it.
      s.scope.set('messages', newestFirst(0, 200));
      await tester.pumpAndSettle();
      expect(firstInView(tester, fromBottom: true), 'M199');
      final node = Node.fromJson({
        'type': 'box',
        'actions': [
          lists.reaction('click', [
            {'type': 'scrollTo', 'node': 'row', 'item': '3', 'alignment': 0.5},
          ]),
        ],
      }, id: 'x')!;
      final run = const CodelesslyActions().run(node, 'click', s.context);
      await tester.pumpAndSettle();
      await run;
      await tester.pumpAndSettle();
      final at = rectOf(tester, 'M3');
      expect(at, isNotNull);
      expect(at!.top, inInclusiveRange(0, 360), reason: 'in view');
    });

    testWidgets('a long list keeps its place with most items never built', (tester) async {
      final s = await lists.show(tester, list(reverse: true), variables: [lists.v('messages', newestFirst(0, 500), VariableType.list)]);
      await tester.pumpAndSettle();
      final p = position(tester);
      p.jumpTo(8000);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 'M0'), isNull, reason: 'far items are not built');
      final reading = firstInView(tester);
      final before = rectOf(tester, reading)!;
      s.scope.set('messages', newestFirst(0, 520));
      await tester.pumpAndSettle();
      expect(rectOf(tester, reading), before, reason: 'twenty newer, none of them built');
      s.scope.set('messages', newestFirst(0, 520).sublist(0, 510) + [for (var i = -1; i > -30; i--) {'id': i, 'text': 'M$i'}]);
      await tester.pumpAndSettle();
      expect(rectOf(tester, reading), before, reason: 'oldest taken out and older put after');
    });
  });

  group('a list in reading order', () {
    testWidgets('scrolled down, items put at the top or taken out above move nothing', (tester) async {
      final s = await lists.show(tester, list(padding: [0, 24, 0, 16]), variables: [lists.v('messages', inOrder(10, 60), VariableType.list)]);
      await tester.pumpAndSettle();
      position(tester).jumpTo(500);
      await tester.pumpAndSettle();
      final reading = firstInView(tester);
      final before = rectOf(tester, reading)!;

      s.scope.set('messages', inOrder(0, 60));
      await tester.pumpAndSettle();
      expect(rectOf(tester, reading), before, reason: 'ten put at the top');

      s.scope.set('messages', inOrder(5, 60));
      await tester.pumpAndSettle();
      expect(rectOf(tester, reading), before, reason: 'five taken out at the top');

      s.scope.set('messages', [...inOrder(5, 15), ...inOrder(100, 103), ...inOrder(15, 60)]);
      await tester.pumpAndSettle();
      expect(rectOf(tester, reading), before, reason: 'three put between the top and the view');

      // Back at the top, with its padding.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 8000));
      await tester.pumpAndSettle();
      expect(rectOf(tester, 'M5')!.top, 24);
    });

    testWidgets('at the top it shows what is put there (unchanged)', (tester) async {
      final s = await lists.show(tester, list(padding: [0, 24, 0, 16]), variables: [lists.v('messages', inOrder(10, 60), VariableType.list)]);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 'M10')!.top, 24);
      s.scope.set('messages', inOrder(9, 60));
      await tester.pumpAndSettle();
      expect(rectOf(tester, 'M9')!.top, 24);
      expect(rectOf(tester, 'M10')!.top, 64);
    });
  });

  group('a list that sticks to its end', () {
    testWidgets('jumpToLatest=false draws no button of its own', (tester) async {
      await lists.show(tester, list(props: {'stickToEnd': true, 'jumpToLatest': false}),
          variables: [lists.v('messages', inOrder(0, 30), VariableType.list)]);
      await tester.pumpAndSettle();
      final p = position(tester);
      p.jumpTo(p.maxScrollExtent - 200);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('followListLatest')), findsNothing);
    });
  });

  group('pulled to refresh', () {
    Future<(RenderSpinner, bool)> pulled(WidgetTester tester, String style) async {
      final doc = list(props: {'pullToRefresh': true, 'refreshStyle': style, 'physics': 'bouncing'});
      await lists.show(tester, doc, variables: [lists.v('messages', inOrder(0, 30), VariableType.list)]);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(find.byType(CustomScrollView)));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      final indicator = find.byKey(const ValueKey('Codelessly pull to refresh'));
      expect(indicator, findsOneWidget);
      final spinner = tester.renderObject<RenderSpinner>(find.descendant(of: indicator, matching: find.byType(SpinnerView)));
      final disc = find.descendant(of: indicator, matching: find.byType(DecoratedBox)).evaluate().isNotEmpty;
      await gesture.up();
      await tester.pumpAndSettle();
      return (spinner, disc);
    }

    testWidgets('refreshStyle=spinner draws iOS ticks with no disc', (tester) async {
      final (spinner, disc) = await pulled(tester, 'spinner');
      expect(spinner.style, SpinnerStyle.ticks);
      expect(disc, isFalse);
    });

    testWidgets('the default draws the disc, as before', (tester) async {
      final (spinner, disc) = await pulled(tester, 'disc');
      expect(spinner.style, SpinnerStyle.arc);
      expect(disc, isTrue);
    });
  });
}
