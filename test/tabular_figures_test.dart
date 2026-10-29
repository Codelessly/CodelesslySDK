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

  /// Every font feature the spans built for [node] carry.
  List<FontFeature> featuresOf(TextNode node) {
    final List<FontFeature> features = [];
    for (final InlineSpan span in TextUtils.buildTextSpansForProps(
      null,
      node.data,
      node: node,
      props: node.textMixedProps,
      variablesOverrides: const [],
      nullSubstitutionMode: NullSubstitutionMode.noChange,
      replaceVariablesWithSymbol: false,
    )) {
      // visitChildren skips a span without text of its own, like a wrapper.
      features.addAll(span.style?.fontFeatures ?? const []);
      span.visitChildren((InlineSpan child) {
        features.addAll(child.style?.fontFeatures ?? const []);
        return true;
      });
    }
    return features;
  }

  test('a text with tabular figures sets the font feature on its spans', () {
    expect(featuresOf(clock(tabular: true)), [
      const FontFeature.tabularFigures(),
    ]);
    expect(featuresOf(clock(tabular: false)), isEmpty);
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
    final TextSpan inner = span.children!.single as TextSpan;
    expect(inner.style?.fontSize, 32);
  });
}
