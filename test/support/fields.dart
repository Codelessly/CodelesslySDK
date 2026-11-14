// Text fields in tests: the SDK's text field is a render object
// (render/controls/text_field.dart), not an EditableText, so tests find it
// in the render tree and type through the fake text input channel.
import 'package:codelessly_sdk/src/render/controls/text_field.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every text field on screen, in paint order.
List<RenderTextField> textFields(WidgetTester tester) {
  final out = <RenderTextField>[];
  void visit(RenderObject o) {
    if (o is RenderTextField) out.add(o);
    o.visitChildren(visit);
  }

  for (final v in tester.binding.renderViews) {
    visit(v);
  }
  return out;
}

/// The [index]th text field on screen (the only one when there is one).
RenderTextField textField(WidgetTester tester, [int index = 0]) => textFields(tester)[index];

/// Focuses [field] (the first on screen by default) and types [text] over
/// what it holds, as `tester.enterText` does for an EditableText.
Future<void> typeInto(WidgetTester tester, String text, {RenderTextField? field}) async {
  final f = field ?? textField(tester);
  if (!f.focusNode.hasFocus) {
    f.requestFocus();
    await tester.pump();
  }
  tester.testTextInput.enterText(text);
  await tester.pump();
}

/// Taps [field] at its text (its global centre).
Future<void> tapField(WidgetTester tester, RenderTextField field) async {
  await tester.tapAt(field.localToGlobal(field.contentRect.center));
  await tester.pump();
}
