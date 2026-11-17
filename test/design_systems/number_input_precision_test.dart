// NumberInput with a fractional step keeps the step's precision: typed
// cents are saved as typed, and the arrow keys step by the step, although
// the variable was declared with a whole number (`state amount=0`).
import 'package:codelessly_sdk/src/render/controls/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cards.dart';
import '../support/keyboard.dart';

const _page = '''
state amount=0
Page
  Section
    NumberInput#amt bind=amount step=0.01 showStepper=true label="Amount"
    Text#shown "Amount {money(amount,"\$",2)} raw {amount}"
    Button#save "Save"
''';

RenderTextField fieldIn(WidgetTester tester, String id) {
  RenderTextField? field;
  void visit(RenderObject o) {
    if (o is RenderTextField) field = o;
    o.visitChildren(visit);
  }

  visit(boxOf(tester, id));
  return field!;
}

void main() {
  testWidgets('typed cents are kept: 25.50 is 25.5, not 26', (tester) async {
    await showCards(tester, _page);
    await tester.tapAt(centerOf(tester, 'amt/field'));
    await tester.pump();
    tester.testTextInput.enterText('25.50');
    await settle(tester);
    expect(textOf(tester, 'shown'), r'Amount $25.50 raw 25.5');
    // Leaving the field keeps what was typed.
    await tester.tapAt(centerOf(tester, 'save'));
    await settle(tester);
    expect(textOf(tester, 'shown'), r'Amount $25.50 raw 25.5');
    expect(fieldIn(tester, 'amt').editor.text, anyOf('25.5', '25.50'));
  });

  testWidgets('ArrowUp and ArrowDown on the focused field step by 0.01', (tester) async {
    await showCards(tester, _page);
    final keys = Keyboard(tester);
    for (var i = 0; i < 12 && keys.focusedId != 'field'; i++) {
      await keys.tab();
    }
    expect(keys.focusedId, 'field');
    await keys.up();
    await keys.up();
    await keys.up();
    expect(textOf(tester, 'shown'), r'Amount $0.03 raw 0.03');
    expect(fieldIn(tester, 'amt').editor.text, '0.03');
    await keys.down();
    expect(textOf(tester, 'shown'), r'Amount $0.02 raw 0.02');
  });

  testWidgets('the stepper buttons step by 0.01 too', (tester) async {
    await showCards(tester, _page);
    await tester.tapAt(centerOf(tester, 'amt/up'));
    await settle(tester, 200);
    await tester.tapAt(centerOf(tester, 'amt/up'));
    await settle(tester, 200);
    expect(textOf(tester, 'shown'), r'Amount $0.02 raw 0.02');
  });

  testWidgets('a whole step keeps whole numbers whole', (tester) async {
    await showCards(tester, _page.replaceFirst('step=0.01', 'step=1'));
    final keys = Keyboard(tester);
    for (var i = 0; i < 12 && keys.focusedId != 'field'; i++) {
      await keys.tab();
    }
    await keys.up();
    await keys.up();
    expect(textOf(tester, 'shown'), r'Amount $2.00 raw 2');
  });
}
