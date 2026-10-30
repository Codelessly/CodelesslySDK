import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

String plain(List<InlineSpan> spans) =>
    TextSpan(children: spans).toPlainText(includePlaceholders: false);

TextSpan spanOf(List<InlineSpan> spans, String text) => spans
    .whereType<TextSpan>()
    .firstWhere((s) => s.text == text, orElse: () => throw 'no span "$text"');

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  const TextStyle base = TextStyle(fontSize: 13, color: Color(0xFFD7D9DE));

  test('inline markers become styles and disappear', () {
    final spans = markdownSpansFor(
      'Webhook **failing** since _Tuesday_, see `wh_8f2a91` @maya',
      base,
      MarkdownStyle(
        codeColor: ColorRGBA.fromHex('#E4B5F2'),
        mentionColor: ColorRGBA.fromHex('#B4ABFA'),
      ),
    );
    expect(plain(spans), 'Webhook failing since Tuesday, see wh_8f2a91 @maya');
    expect(spanOf(spans, 'failing').style!.fontWeight, FontWeight.w700);
    expect(spanOf(spans, 'Tuesday').style!.fontStyle, FontStyle.italic);
    expect(spanOf(spans, 'wh_8f2a91').style!.color, const Color(0xFFE4B5F2));
    expect(spanOf(spans, 'wh_8f2a91').style!.fontSize, 11.5);
    expect(spanOf(spans, '@maya').style!.color, const Color(0xFFB4ABFA));
    expect(spanOf(spans, '@maya').style!.fontWeight, FontWeight.w600);
  });

  test('only listed handles are mentions', () {
    final spans = markdownSpansFor(
      '@sam and @nobody',
      base,
      const MarkdownStyle(mentions: ['sam']),
    );
    expect(spanOf(spans, '@sam').style!.fontWeight, FontWeight.w600);
    expect(spanOf(spans, '@nobody').style, base);
  });

  test('lists get bullets and numbers, blank lines a short gap', () {
    final spans = markdownSpansFor(
      'Could you:\n- confirm the cert\n- send a test\n\n1. first\n2. second',
      base,
      const MarkdownStyle(paragraphGap: 8),
    );
    expect(
      plain(spans),
      'Could you:\n• confirm the cert\n• send a test\n\n1. first\n2. second',
    );
    final TextSpan gap = spans.whereType<TextSpan>().firstWhere(
      (s) => s.text == '\n' && s.style!.fontSize == 8,
    );
    expect(gap.style!.height, 1);
  });

  test('with markers shown the text is unchanged, markers dimmed', () {
    const String typed = 'Hi **Lena**\n\n- one `two`';
    final spans = markdownSpansFor(
      typed,
      base,
      MarkdownStyle(
        showMarkers: true,
        markerColor: ColorRGBA.fromHex('#454952'),
      ),
    );
    expect(plain(spans), typed);
    expect(spanOf(spans, '**').style!.color, const Color(0xFF454952));
    expect(spanOf(spans, 'Lena').style!.fontWeight, FontWeight.w700);
    expect(spanOf(spans, '- ').style!.fontWeight, FontWeight.w600);
  });

  test('markdownSpans reads the text and style of resolved spans', () {
    final spans = markdownSpans(
      [
        TextSpan(
          style: base,
          children: const [TextSpan(text: 'a **b**')],
        ),
      ],
      const MarkdownStyle(),
    );
    expect(plain(spans), 'a b');
    expect(spanOf(spans, 'b').style!.fontSize, 13);
  });
}
