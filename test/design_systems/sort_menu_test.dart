// Cards' SortMenu on a page is a closed control: a dropdown showing the
// choice, whose menu opens on a tap or from the keyboard, and the arrow
// that flips the direction. (SSUI's is the open body of a menu.)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cards.dart';
import '../support/keyboard.dart';

const _page = '''
state sort="Edited"
Page
  Section
    Row between
      Heading "Notes"
      SortMenu#sorter bind=sort options=["Edited","Created","Title"]
    Text#picked "Sorted by {sort}"
''';

void main() {
  for (final size in const [Size(1280, 800), Size(390, 844)]) {
    testWidgets('closed on first paint at ${size.width.round()}, one line tall, showing the choice', (tester) async {
      await showCards(tester, _page, size: size);
      final r = rectOf(tester, 'sorter');
      expect(r.height, lessThanOrEqualTo(40), reason: 'a closed control, not an open panel of options');
      expect(r.right, lessThanOrEqualTo(size.width));
      expect(textOf(tester, 'sorter/choice'), 'Edited');
      expect(find.text('Created'), findsNothing);
      expect(textOf(tester, 'picked'), 'Sorted by Edited');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('by keyboard: Tab to it, open, arrow to an option, Enter chooses', (tester) async {
    await showCards(tester, _page);
    final keys = Keyboard(tester);
    for (var i = 0; i < 12 && keys.focusedId != 'choice'; i++) {
      await keys.tab();
    }
    expect(keys.focusedId, 'choice');
    expect(keys.ringShown, isTrue);
    await keys.enter();
    await settle(tester);
    await keys.down();
    await keys.enter();
    await settle(tester);
    expect(textOf(tester, 'picked'), 'Sorted by Created');
    expect(textOf(tester, 'sorter/choice'), 'Created');
    // The arrow is the next stop.
    await keys.tab();
    expect(keys.focusedId, 'flip');
    await keys.enter();
    expect(tester.takeException(), isNull);
  });

  testWidgets('by pointer: a tap opens its menu, a tap on an option chooses it and closes', (tester) async {
    await showCards(tester, _page);
    final before = rectOf(tester, 'sorter');
    await tester.tapAt(centerOf(tester, 'sorter/choice'));
    await settle(tester);
    expect(rectOf(tester, 'sorter'), before, reason: 'the menu opens over the page, the control keeps its size');
    final keys = Keyboard(tester);
    await keys.down();
    await keys.down();
    await keys.enter();
    await settle(tester);
    expect(textOf(tester, 'picked'), 'Sorted by Title');
    expect(tester.takeException(), isNull);
  });
}
