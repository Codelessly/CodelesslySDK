import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_actions_test.dart'
    show body, brandRegular, canvas, layoutOf, pumpLayouts, text;

/// The color of the span that shows [label].
Color? spanColor(WidgetTester tester, String label) {
  Color? color;
  for (final RichText rich in tester.widgetList<RichText>(
    find.byType(RichText),
  )) {
    rich.text.visitChildren((InlineSpan span) {
      if (span is TextSpan && span.text == label) color = span.style?.color;
      return true;
    });
  }
  return color;
}

void main() {
  testWidgets('a fill binding on a text recolors the whole text', (tester) async {
    final TextNode bound = text('label', 'mainBody', 'Mystery', brandRegular)
      ..variables['fill'] = r"${= 2 > 1 ? '#C9A24A' : '#B6AA90'}";
    final TextNode plain = text('plain', 'mainBody', 'Heist', brandRegular);
    await pumpLayouts(tester, [
      layoutOf('layout', [
        canvas('main', 'mainBody'),
        body('mainBody', 'main', ['label', 'plain']),
        bound,
        plain,
      ]),
    ]);
    await tester.pump();

    expect(spanColor(tester, 'Mystery'), const Color(0xFFC9A24A));
    // Without a binding the span keeps its own fill.
    expect(spanColor(tester, 'Heist'), isNot(const Color(0xFFC9A24A)));
  });
}
