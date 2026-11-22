// A child that fills, in a row that wraps (`Row wrap=true`, or
// `phone.wrap=true` on a phone): nothing flexes in a run, so it hugs its
// content where that can be measured. Where it cannot (a line that scrolls
// sideways: Cards' ChipTabs, Tabs and Segments; a field) and the document
// has no design size for it (a text never has), it is a line of its own, as
// wide as the row. It was 0 wide: the tabs of a toolbar that wraps on a
// phone were not drawn.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cards.dart';

const _page = '''
state kind="All"
state q=""
Column#page w=fill pad=16 gap=12
  Row#bar gap=12 middle phone.wrap=true
    ChipTabs#chips @kind tabs=["All","Open","Closed","Archived"]
    Button#go "New"
  Row#always gap=12 middle wrap=true
    Tabs#tabs @kind tabs=["All","Open","Closed","Archived"]
    Segments#seg @kind options=["All","Open"]
    Input#find "Search" @q w=fill
    Row#strip w=fill scroll gap=8
      Text#one "One"
      Text#two "Two"
    Text#label "A text"
    Row#plain w=fill
      Text#in "in a row"
''';

void main() {
  testWidgets('on a phone: each is a line as wide as the row, what follows it on the next', (tester) async {
    await showCards(tester, _page, size: const Size(390, 800));
    tester.takeException();
    for (final id in ['chips', 'tabs', 'seg', 'find', 'strip']) {
      final r = rectOf(tester, id);
      expect(r.left, 16, reason: id);
      expect(r.width, 358, reason: id);
      expect(r.height, greaterThanOrEqualTo(20), reason: id);
    }
    // The button under the tabs it was written beside.
    expect(rectOf(tester, 'go').top, greaterThanOrEqualTo(rectOf(tester, 'chips').bottom));
    expect(rectOf(tester, 'go').left, 16);
    // What hugs still hugs, and everything is drawn inside the row.
    expect(rectOf(tester, 'label').width, lessThan(120));
    for (final id in ['label', 'plain', 'in', 'one', 'two']) {
      final r = rectOf(tester, id);
      expect(r.width, greaterThan(0), reason: id);
      expect(r.left, greaterThanOrEqualTo(16), reason: id);
      expect(r.right, lessThanOrEqualTo(374), reason: id);
    }
  });

  testWidgets('in a wide window the row that wraps only on a phone is one line; the one that always wraps is as on a phone', (tester) async {
    await showCards(tester, _page, size: const Size(1280, 800));
    tester.takeException();
    final chips = rectOf(tester, 'chips'), go = rectOf(tester, 'go');
    expect(go.center.dy, closeTo(chips.center.dy, 1));
    expect(chips.right, lessThan(go.left));
    expect(chips.width, greaterThan(1000));
    for (final id in ['tabs', 'seg', 'find', 'strip']) {
      expect(rectOf(tester, id).width, 1248, reason: id);
    }
  });
}
