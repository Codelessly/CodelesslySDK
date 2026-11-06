import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TextNode clock({required bool tabular}) => TextNode(
    id: 'clock',
    name: 'Clock',
    basicBoxLocal: NodeBox(0, 0, 200, 40),
    data: '1:48:00',
    textMixedProps: [StartEndProp(start: 0, end: 7, fontSize: 32)],
    tabularFigures: tabular,
  );

  /// The font features of each text span built for [node].
  List<List<FontFeature>?> featuresOf(TextNode node) => [
    for (final InlineSpan span in TextUtils.buildTextSpansForProps(
      null,
      node.data,
      node: node,
      props: node.textMixedProps,
      variablesOverrides: const [],
      nullSubstitutionMode: NullSubstitutionMode.noChange,
      replaceVariablesWithSymbol: false,
    ))
      span.style?.fontFeatures,
  ];

  test('a text with tabular figures sets the font feature on its spans', () {
    expect(featuresOf(clock(tabular: true)), [
      [const FontFeature.tabularFigures()],
    ]);
    expect(featuresOf(clock(tabular: false)), [null]);
  });

  test('tabular figures keep the span\'s own size and text', () {
    final TextSpan span = TextUtils.buildTextSpansForProps(
      null,
      '1:48:00',
      node: clock(tabular: true),
      props: clock(tabular: true).textMixedProps,
      variablesOverrides: const [],
      nullSubstitutionMode: NullSubstitutionMode.noChange,
      replaceVariablesWithSymbol: false,
    ).single;
    expect(span.toPlainText(), '1:48:00');
    expect(span.style?.fontSize, 32);
    expect(span.style?.fontFeatures, [const FontFeature.tabularFigures()]);
  });
}
