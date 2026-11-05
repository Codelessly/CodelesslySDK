import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  TextNode label(List<String> features, {bool tabular = false}) => TextNode(
    id: 'time',
    name: 'Time',
    basicBoxLocal: NodeBox(0, 0, 200, 40),
    data: '7:42 PM, 43 watts',
    textMixedProps: [
      StartEndProp(start: 0, end: 7, fontSize: 32),
      StartEndProp(start: 7, end: 17, fontSize: 14),
    ],
    fontFeatures: features,
    tabularFigures: tabular,
  );

  List<TextSpan> spansOf(TextNode node, {bool preview = false}) =>
      TextUtils.buildTextSpansForProps(
        null,
        node.data,
        node: node,
        props: node.textMixedProps,
        variablesOverrides: const [],
        nullSubstitutionMode: NullSubstitutionMode.noChange,
        replaceVariablesWithSymbol: preview,
      );

  test('lnum gives every span lining figures, keeping its own style', () {
    final List<TextSpan> spans = spansOf(label(['lnum']));
    expect(spans, hasLength(2));
    for (final TextSpan span in spans) {
      expect(span.style?.fontFeatures, [const FontFeature.liningFigures()]);
    }
    expect(spans.first.style?.fontSize, 32);
    expect(spans.last.style?.fontSize, 14);
    expect(spans.map((s) => s.toPlainText()).join(), '7:42 PM, 43 watts');
  });

  test('values, several features and tabularFigures combine', () {
    expect(
      spansOf(label(['smcp', 'liga=0'], tabular: true))
          .first
          .style
          ?.fontFeatures,
      [
        const FontFeature.enable('smcp'),
        const FontFeature.disable('liga'),
        const FontFeature.tabularFigures(),
      ],
    );
    expect(spansOf(label(['salt=2'])).first.style?.fontFeatures, [
      const FontFeature('salt', 2),
    ]);
    expect(spansOf(label(const [])).first.style?.fontFeatures, isNull);
  });

  test('a node built from JSON renders and measures its features', () {
    final TextNode node = TextNode.fromJson({
      ...label(const []).toJson(),
      'fontFeatures': ['lnum'],
    });
    final TextPainter painter = TextPainter(
      text: TextSpan(children: spansOf(node, preview: true)),
      textDirection: TextDirection.ltr,
    )..layout();
    final TextSpan root = painter.text! as TextSpan;
    for (final InlineSpan span in root.children!) {
      expect(span.style?.fontFeatures, [const FontFeature.liningFigures()]);
    }
    painter.dispose();
  });

  testWidgets('the rendered text node paints with lining figures', (
    tester,
  ) async {
    final TextNode node = label(['lnum']);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) => TextUtils.buildTextForTextNode(
            context,
            node,
            variablesOverrides: const [],
            nullSubstitutionMode: NullSubstitutionMode.noChange,
            replaceVariablesWithSymbol: true,
          ),
        ),
      ),
    );
    final RichText text = tester.widget<RichText>(find.byType(RichText));
    final List<FontFeature> features = [];
    text.text.visitChildren((InlineSpan span) {
      if (span is TextSpan && span.text != null) {
        features.addAll(span.style?.fontFeatures ?? const []);
      }
      return true;
    });
    expect(features, [
      const FontFeature.liningFigures(),
      const FontFeature.liningFigures(),
    ]);
  });
}
