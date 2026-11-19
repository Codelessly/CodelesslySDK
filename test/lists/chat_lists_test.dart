import 'dart:ui' show Tristate;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart' as lists;
import '../support/keyboard.dart';

// A list that sticks to its end (ListViewProps.stickToEnd), as a chat or a
// log needs: it opens at the end, follows new items only while at the end,
// and keeps its place when older items are put in front.


List<Object?> messages(int from, int to) => [for (var i = from; i < to; i++) {'id': i, 'text': 'M$i'}];

Map<String, Json> chat() => {
      'col': {
        'type': 'column',
        'children': ['list'],
        'layout': {'width': 300, 'height': 400},
      },
      'list': {
        'type': 'listView',
        'children': ['row'],
        'layout': {'width': 300, 'height': 400},
        'bind': {'data': r'${messages}'},
        'props': {'stickToEnd': true},
      },
      'row': {
        'type': 'text',
        'layout': {'width': 300, 'height': 40},
        'props': {'text': r'${item.text}'},
      },
    };

void main() {
  group('a list that sticks to its end', () {
    ScrollPosition position(WidgetTester tester) => tester
        .state<ScrollableState>(find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)))
        .position;

    /// The message at the top of the list's 400-high viewport.
    String topRow(WidgetTester tester, lists.Screen s) {
      final list = s.tree.boxOf('list')!;
      final top = list.localToGlobal(Offset.zero).dy;
      final hit = tester.renderObjectList<RenderBox>(find.byType(NodeView)).first;
      String? found;
      double best = double.infinity;
      void visit(RenderObject o) {
        if (o is RenderParagraph && o.attached && o.hasSize) {
          final y = o.localToGlobal(Offset.zero).dy;
          if (y >= top - 1 && y < best) {
            best = y;
            found = o.text.toPlainText();
          }
        }
        o.visitChildren(visit);
      }

      visit(hit);
      return found!;
    }

    testWidgets('with a padding of its own it opens at its end too (round 11b: it asserted, no message drawn)', (tester) async {
      final doc = chat();
      doc['list'] = {
        ...doc['list']!,
        'layout': <String, Object?>{'width': 300, 'height': 400, 'padding': [28, 24, 28, 16]},
      };
      final s = await lists.show(tester, doc, variables: [lists.v('messages', messages(0, 30), VariableType.list)]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final p = position(tester);
      expect(p.pixels, p.maxScrollExtent);
      expect(topRow(tester, s), isNotEmpty);
    });

    testWidgets('opens at its end and follows new messages while there', (tester) async {
      final s = await lists.show(tester, chat(), variables: [lists.v('messages', messages(0, 30), VariableType.list)]);
      await tester.pumpAndSettle();
      final p = position(tester);
      expect(p.pixels, p.maxScrollExtent);
      expect(p.maxScrollExtent, 30 * 40 - 400);
      expect(topRow(tester, s), 'M20');

      s.scope.set('messages', messages(0, 31));
      await tester.pumpAndSettle();
      expect(p.pixels, p.maxScrollExtent);
      expect(topRow(tester, s), 'M21');
    });

    testWidgets('stays put when scrolled up, also when older messages are added in front', (tester) async {
      final s = await lists.show(tester, chat(), variables: [lists.v('messages', messages(10, 40), VariableType.list)]);
      await tester.pumpAndSettle();
      final p = position(tester);
      p.jumpTo(p.maxScrollExtent - 200);
      await tester.pumpAndSettle();
      final reading = topRow(tester, s);
      expect(reading, 'M25');

      s.scope.set('messages', messages(10, 41));
      await tester.pumpAndSettle();
      expect(topRow(tester, s), reading, reason: 'a new message while scrolled up');

      // Older messages loaded in front.
      s.scope.set('messages', messages(0, 41));
      await tester.pumpAndSettle();
      expect(topRow(tester, s), reading, reason: 'older messages put in front');
      // And they are there above it.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 4000));
      await tester.pumpAndSettle();
      expect(topRow(tester, s), 'M0');

      // Back at the end, it follows again.
      p.jumpTo(p.maxScrollExtent);
      await tester.pumpAndSettle();
      s.scope.set('messages', messages(0, 42));
      await tester.pumpAndSettle();
      expect(p.pixels, p.maxScrollExtent);
      expect(topRow(tester, s), 'M32');
    });

    testWidgets('offers a named return button by touch, Enter, and Space after the reader scrolls up', (tester) async {
      final semantics = tester.ensureSemantics();
      final s = await lists.show(tester, chat(), variables: [lists.v('messages', messages(0, 30), VariableType.list)]);
      await tester.pumpAndSettle();
      final p = position(tester);
      final keys = Keyboard(tester);
      final latest = find.byKey(const ValueKey('followListLatest'));
      expect(latest, findsNothing);

      p.jumpTo(p.maxScrollExtent - 200);
      await tester.pumpAndSettle();
      expect(latest, findsOneWidget);
      final named = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Jump to latest');
      final spoken = tester.getSemantics(named).getSemanticsData();
      expect(spoken.label, 'Jump to latest');
      expect(spoken.flagsCollection.isButton, isTrue);
      expect(spoken.hasAction(SemanticsAction.tap), isTrue);
      expect(keys.stopIds(s.tree.boxOf('list')!).where((id) => id == 'list'), hasLength(1));
      s.scope.set('messages', messages(0, 31));
      await tester.pumpAndSettle();
      expect(p.pixels, lessThan(p.maxScrollExtent));
      await tester.tap(latest);
      await tester.pumpAndSettle();
      expect(p.pixels, p.maxScrollExtent);
      expect(latest, findsNothing);
      expect(keys.focused, isNull, reason: 'a pointer press does not create a keyboard focus ring');

      for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
        p.jumpTo(p.maxScrollExtent - 200);
        await tester.pumpAndSettle();
        expect(latest, findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(keys.focusedText, 'Jump to latest');
        expect(keys.ringShown, isTrue);
        expect(tester.getSemantics(named).getSemanticsData().flagsCollection.isFocused, Tristate.isTrue);
        if (key == LogicalKeyboardKey.enter) {
          await keys.escape();
          expect(keys.focused, isNull);
          expect(latest, findsOneWidget, reason: 'Escape leaves the log paused');
          await keys.tab();
          expect(keys.focusedText, 'Jump to latest');
        }
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        expect(p.pixels, p.maxScrollExtent);
        expect(latest, findsNothing);
      }
      semantics.dispose();
    });

    testWidgets('places the return target at the reading end on a dark RTL phone', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await lists.show(tester, chat(),
          variables: [lists.v('messages', messages(0, 30), VariableType.list)],
          theme: ThemeData.dark(), direction: TextDirection.rtl);
      await tester.pumpAndSettle();
      final p = position(tester);
      p.jumpTo(p.maxScrollExtent - 200);
      await tester.pumpAndSettle();
      final latest = find.byKey(const ValueKey('followListLatest'));
      final rect = tester.getRect(latest);
      expect(rect.width, greaterThanOrEqualTo(44));
      expect(rect.height, greaterThanOrEqualTo(44));
      expect(rect.left, lessThan(100), reason: 'directional end mirrors to the left in RTL');
      await tester.tap(latest);
      await tester.pumpAndSettle();
      expect(p.pixels, p.maxScrollExtent);
    });

    testWidgets('with pull to refresh still opens at its end, follows, and refreshes when pulled at the top', (tester) async {
      final nodes = chat();
      nodes['list'] = {
        ...nodes['list']!,
        'props': {'stickToEnd': true, 'pullToRefresh': true},
        'actions': [
          lists.reaction('refresh', [
            {'type': 'setVariable', 'variable': 'refreshed', 'op': 'add', 'value': '1'},
          ]),
        ],
      };
      final s = await lists.show(tester, nodes,
          variables: [lists.v('messages', messages(0, 30), VariableType.list), lists.v('refreshed', 0, VariableType.integer)]);
      await tester.pumpAndSettle();
      expect(find.byType(RefreshIndicator), findsOneWidget);
      final p = position(tester);
      expect(p.pixels, p.maxScrollExtent);
      expect(topRow(tester, s), 'M20');

      s.scope.set('messages', messages(0, 31));
      await tester.pumpAndSettle();
      expect(topRow(tester, s), 'M21', reason: 'it follows new messages at the end');

      // Scrolled to the top, a pull refreshes.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 4000));
      await tester.pumpAndSettle();
      expect(topRow(tester, s), 'M0');
      await tester.fling(find.byType(CustomScrollView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(s['refreshed'], 1);
    });
  });
}
