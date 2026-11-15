// Markdown in texts and text fields (render/markdown.dart): Switchboard's
// message bodies (`TextProps.markdown`) and its reply composer
// (`TextFieldProps.markdown`).
import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_sdk/src/render/markdown.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fields.dart';
import '../support/screen.dart';

/// The style of [part] of [text] by [runs] (merged where they overlap).
api.TextStyle styleOf(String text, List<api.TextRun> runs, String part) {
  final at = text.indexOf(part);
  expect(at, isNonNegative, reason: 'no "$part" in "$text"');
  return runs
      .where((r) => r.start <= at && r.end >= at + part.length)
      .fold(api.TextStyle.empty, (s, r) => s.merge(r.style));
}

const _base = api.Color(0xFFD7D9DE);

void main() {
  test('inline markers become styles and disappear', () {
    final (text, runs) = markdownRuns(
      'Webhook **failing** since _Tuesday_, see `wh_8f2a91` @maya',
      const MarkdownLook(codeColor: api.Color(0xFFE4B5F2), mentionColor: api.Color(0xFFB4ABFA)),
      color: _base,
      fontSize: 13,
    );
    expect(text, 'Webhook failing since Tuesday, see wh_8f2a91 @maya');
    expect(styleOf(text, runs, 'failing').fontWeight, 700);
    expect(styleOf(text, runs, 'Tuesday').fontStyle, api.FontStyle.italic);
    final code = styleOf(text, runs, 'wh_8f2a91');
    expect((code.color, code.fontSize, code.fontFamily), (const api.Color(0xFFE4B5F2), 11.5, 'JetBrains Mono'));
    expect(styleOf(text, runs, '@maya').color, const api.Color(0xFFB4ABFA));
    expect(styleOf(text, runs, 'Webhook'), api.TextStyle.empty);
  });

  test('only listed names are mentions', () {
    final (text, runs) = markdownRuns('@sam and @nobody', const MarkdownLook(mentions: ['sam']));
    expect(styleOf(text, runs, '@sam').fontWeight, 600);
    expect(styleOf(text, runs, '@nobody'), api.TextStyle.empty);
  });

  test('lists get bullets and numbers, a blank line a short gap', () {
    final (text, runs) = markdownRuns(
      'Could you:\n- confirm the cert\n- send a test\n\n1. first\n2. second',
      const MarkdownLook(paragraphGap: 8),
    );
    expect(text, 'Could you:\n• confirm the cert\n• send a test\n\n1. first\n2. second');
    final gap = runs.singleWhere((r) => r.style.fontSize == 8);
    expect((text.substring(gap.start, gap.end), gap.style.height), ('\n', 1.0));
  });

  test('with the markers shown the text is the source, the markers dimmed', () {
    const typed = 'Hi **Lena**\n\n- one `two`';
    final (text, runs) = markdownRuns(typed, const MarkdownLook(showMarkers: true, markerColor: api.Color(0xFF454952)));
    expect(text, typed);
    expect(styleOf(text, runs, '**').color, const api.Color(0xFF454952));
    expect(styleOf(text, runs, 'Lena').fontWeight, 700);
    expect(styleOf(text, runs, '- ').fontWeight, 600);
    // No marker color: the text's own, faded.
    final (_, faded) = markdownRuns('**a**', const MarkdownLook(showMarkers: true), color: _base);
    expect(faded.first.style.color, _base.withAlpha(89));
  });

  testWidgets('a text with markdown draws its bound text without the markers', (tester) async {
    final s = await show(
      tester,
      {
        'col': {
          'type': 'column',
          'children': ['body'],
          'layout': {'width': 400, 'height': 200},
        },
        'body': {
          'type': 'text',
          'layout': {
            'width': {'fill': 400},
          },
          'props': {
            'text': r'${body}',
            'style': {'fontSize': 13, 'color': '#FFD7D9DE'},
            'markdown': {'codeColor': '#FFE4B5F2', 'codeBackground': '#FF24202C'},
          },
        },
      },
      variables: [v('body', 'Our `tracking.updated` webhook **stopped**')],
    );
    RenderParagraph paragraph() {
      RenderParagraph? found;
      void visit(RenderObject o) {
        if (o is RenderParagraph) found ??= o;
        o.visitChildren(visit);
      }

      visit(s.tree.boxOf('body')!);
      return found!;
    }

    expect(paragraph().text.toPlainText(), 'Our tracking.updated webhook stopped');
    final spans = <TextSpan>[];
    paragraph().text.visitChildren((span) {
      if (span is TextSpan && span.text != null) spans.add(span);
      return true;
    });
    final code = spans.singleWhere((t) => t.text == 'tracking.updated');
    expect(
      (code.style!.color, code.style!.backgroundColor, code.style!.fontFamily),
      (const Color(0xFFE4B5F2), const Color(0xFF24202C), 'JetBrains Mono'),
    );
    expect(spans.singleWhere((t) => t.text == 'stopped').style!.fontWeight, FontWeight.w700);
  });

  testWidgets('a text field with markdown keeps what is typed and styles it as it goes', (tester) async {
    await show(tester, {
      'col': {
        'type': 'column',
        'children': ['composer'],
        'layout': {'width': 400, 'height': 200},
      },
      'composer': {
        'type': 'textField',
        'layout': {
          'width': {'fill': 400},
        },
        'props': {
          'maxLines': 6,
          'style': {'fontSize': 13.5, 'color': '#FFD7D9DE'},
          'markdown': {
            'markerColor': '#FF454952',
            'mentionColor': '#FFB4ABFA',
            'mentions': ['priya'],
            'showMarkers': true,
          },
        },
      },
    });
    await typeInto(tester, 'Thanks, **checking** now @priya');
    final f = textField(tester);
    expect(f.editor.text, 'Thanks, **checking** now @priya');
    final spans = <TextSpan>[];
    void visit(RenderObject o) {
      if (o is RenderEditable) {
        o.text!.visitChildren((span) {
          if (span is TextSpan && span.text != null) spans.add(span);
          return true;
        });
      }
      o.visitChildren(visit);
    }

    visit(f);
    expect(spans.map((s) => s.text).join(), 'Thanks, **checking** now @priya');
    expect(spans.firstWhere((s) => s.text == '**').style!.color, const Color(0xFF454952));
    expect(spans.singleWhere((s) => s.text == 'checking').style!.fontWeight, FontWeight.w700);
    expect(spans.singleWhere((s) => s.text == '@priya').style!.color, const Color(0xFFB4ABFA));
  });

  testWidgets('a markdown text written as one styled run keeps that run\'s style', (tester) async {
    final s = await show(tester, {
      'col': {
        'type': 'column',
        'children': ['body'],
        'layout': {'width': 400, 'height': 200},
      },
      'body': {
        'type': 'text',
        'layout': {
          'width': {'fill': 400},
        },
        'props': {
          'text': 'a **b**',
          'runs': [
            {
              'start': 0,
              'end': 7,
              'style': {'fontSize': 13.5, 'height': 1.55},
            },
          ],
          'markdown': <String, Object?>{},
        },
      },
    });
    RenderParagraph? paragraph;
    void visit(RenderObject o) {
      if (o is RenderParagraph) paragraph ??= o;
      o.visitChildren(visit);
    }

    visit(s.tree.boxOf('body')!);
    final spans = <TextSpan>[];
    paragraph!.text.visitChildren((span) {
      if (span is TextSpan && span.text != null) spans.add(span);
      return true;
    });
    expect(spans.map((t) => t.text).join(), 'a b');
    for (final t in spans) {
      expect((t.style!.fontSize, t.style!.height), (13.5, 1.55), reason: t.text);
    }
  });
}
