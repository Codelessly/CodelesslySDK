// A card dragged onto a drop target whose onDrop takes it out of the list
// it was in (a board's column): the drag ends cleanly although the dragged
// node is gone by the time it does.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cards.dart';

const _board = '''
state cards=[{"id":"ST-1","title":"Write spec","status":"Backlog"},{"id":"ST-2","title":"Design","status":"Backlog"},{"id":"ST-3","title":"Ship","status":"Ready"}]
Page
  Section
    Text#summary "{count(cards,c=>c.status=="Backlog")} backlog, {count(cards,c=>c.status=="Ready")} ready"
    Row gap=16 top
      BoardColumn#backlog "Backlog" count={count(cards,c=>c.status=="Backlog")} tone="neutral" drop=task onDrop={cards=updateWhere(cards,c=>c.id==result.data,c=>with(c,"status","Backlog"))}
        each c in filter(cards,x=>x.status=="Backlog")
          TaskCard#card "Product" "{c.title}" code="{c.id}" drag=task(c.id)
      BoardColumn#ready "Ready" count={count(cards,c=>c.status=="Ready")} tone="info" drop=task onDrop={cards=updateWhere(cards,c=>c.id==result.data,c=>with(c,"status","Ready"))}
        each c in filter(cards,x=>x.status=="Ready")
          TaskCard#readyCard "Product" "{c.title}" code="{c.id}" drag=task(c.id)
''';

void main() {
  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    testWidgets('a card dropped on another column moves there and nothing throws (${kind.name})', (tester) async {
      await showCards(tester, _board);
      expect(textOf(tester, 'summary'), '2 backlog, 1 ready');
      final from = boxesOf(tester, 'card').first;
      final start = from.localToGlobal(from.size.center(Offset.zero));
      final to = centerOf(tester, 'ready');
      final g = await tester.startGesture(start, kind: kind);
      // The test platform is a phone's: a drag starts on a hold.
      await tester.pump(const Duration(milliseconds: 700));
      for (var i = 1; i <= 12; i++) {
        await g.moveTo(Offset.lerp(start, to, i / 12)!, timeStamp: Duration(milliseconds: 16 * i));
        // Two moves between frames: the second arrives before the frame that
        // lays out what the first changed.
        await g.moveBy(const Offset(1, 0), timeStamp: Duration(milliseconds: 16 * i + 4));
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull, reason: 'move $i');
        // What is dragged is the card as it shows, with its call's parameters.
        if (i == 6) expect(boxesOf(tester, 'card/chipText').map((b) => b.size.width), everyElement(greaterThan(40)));
      }
      await g.up(timeStamp: const Duration(milliseconds: 200));
      await settle(tester, 1000);
      expect(tester.takeException(), isNull);
      expect(textOf(tester, 'summary'), '1 backlog, 2 ready');
      // The card is in the other column now (a list's later copies are `id#n`).
      expect(shown(tester, 'card#1'), isFalse);
      expect(shown(tester, 'readyCard#1'), isTrue);
      expect(textOf(tester, 'readyCard/title'), 'Write spec');
      // The board still takes the pointer: a second card moves too.
      final again = centerOf(tester, 'card');
      final g2 = await tester.startGesture(again, kind: kind);
      await tester.pump(const Duration(milliseconds: 700));
      for (var i = 1; i <= 12; i++) {
        await g2.moveTo(Offset.lerp(again, centerOf(tester, 'ready'), i / 12)!, timeStamp: Duration(milliseconds: 16 * i));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g2.up(timeStamp: const Duration(milliseconds: 200));
      await settle(tester, 1000);
      expect(tester.takeException(), isNull);
      expect(textOf(tester, 'summary'), '0 backlog, 3 ready');
    });
  }
}
