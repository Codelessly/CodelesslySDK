// A dialog whose body is taller than a phone's screen scrolls inside the
// window, so its last button can be reached; a dialog that fits is laid out
// as it was, with nothing to scroll.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cards.dart';

String _page(int lines) => '''
state agreed="no"
Page
  Section
    Button#open "Open" onTap={open big}
    Text#state "Agreed: {agreed}"
Dialog#big "Terms" "Read them all."
  each i in range(0,$lines)
    Text "Line {i} of a long body that keeps going"
  Row gap=8
    Button.outline#later "Later" onTap={close}
    Button#agree "I agree" onTap={agreed="yes"; close}
''';

void main() {
  const phone = Size(390, 700);

  testWidgets('a tall dialog on a phone: nothing overflows, and a drag brings its button into reach', (tester) async {
    await showCards(tester, _page(30), size: phone);
    await tester.tapAt(centerOf(tester, 'open'));
    await settle(tester);
    expect(tester.takeException(), isNull, reason: 'the body does not overflow the screen');
    expect(rectOf(tester, 'agree').top, greaterThan(phone.height), reason: 'the button starts below the fold');
    // Drag the body up until the button shows.
    for (var i = 0; i < 6 && rectOf(tester, 'agree').bottom > phone.height - 8; i++) {
      await tester.dragFrom(const Offset(195, 500), const Offset(0, -320));
      await settle(tester, 300);
    }
    final button = rectOf(tester, 'agree');
    expect(button.bottom, lessThanOrEqualTo(phone.height));
    expect(button.top, greaterThanOrEqualTo(0));
    await tester.tapAt(button.center);
    await settle(tester);
    expect(textOf(tester, 'state'), 'Agreed: yes');
    expect(shown(tester, 'agree'), isFalse, reason: 'the dialog closed');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a mouse wheel scrolls it too', (tester) async {
    await showCards(tester, _page(30), size: phone);
    await tester.tapAt(centerOf(tester, 'open'));
    await settle(tester);
    final before = rectOf(tester, 'agree').top;
    final wheel = TestPointer(7, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(wheel.hover(const Offset(195, 400)));
    await tester.sendEventToBinding(wheel.scroll(const Offset(0, 300)));
    await settle(tester, 300);
    expect(rectOf(tester, 'agree').top, lessThan(before));
    await tester.sendEventToBinding(wheel.removePointer(location: const Offset(195, 400)));
  });

  testWidgets('a dialog that fits is as tall as its content and does not move', (tester) async {
    await showCards(tester, _page(3), size: phone);
    await tester.tapAt(centerOf(tester, 'open'));
    await settle(tester);
    final button = rectOf(tester, 'agree');
    expect(button.bottom, lessThan(phone.height));
    await tester.dragFrom(const Offset(195, 350), const Offset(0, -200));
    await settle(tester, 300);
    expect(rectOf(tester, 'agree'), button);
    await tester.tapAt(button.center);
    await settle(tester);
    expect(textOf(tester, 'state'), 'Agreed: yes');
  });
}
