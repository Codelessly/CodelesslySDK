import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../codelessly_sdk.dart';

/// Inline Markdown: **bold**, _italic_, `code`, @mentions and links.
final RegExp _inline = RegExp(
  r'(\*\*[^*\n]+\*\*)|(`[^`\n]+`)|((?<![\w])_[^_\n]+_(?![\w]))|((?<![\w])@[a-zA-Z][\w-]*)|((?:https?://)?[\w-]+(?:\.[\w-]+)*\.(?:io|com|org|net|dev|app)(?:/[\w/.?=&%-]*\w)?)',
);
final RegExp _bullet = RegExp(r'^(\s*)([-*]) ');
final RegExp _numbered = RegExp(r'^(\s*)(\d+)[.)] ');

/// Renders [spans] (a text node's resolved text) as Markdown in [style]:
/// paragraphs, `- ` and `1. ` list items, **bold**, _italic_, `code`,
/// links and @mentions. The text takes the style of its first run.
///
/// With [MarkdownStyle.showMarkers] the markers stay in the text, dimmed, so
/// the result has exactly the characters of the input: the live preview of a
/// text field.
List<InlineSpan> markdownSpans(List<InlineSpan> spans, MarkdownStyle style) {
  final StringBuffer text = StringBuffer();
  TextStyle? base;
  void visit(InlineSpan span, TextStyle? parent) {
    if (span is! TextSpan) return;
    final TextStyle? merged = parent?.merge(span.style) ?? span.style;
    if (span.text != null) {
      text.write(span.text);
      base ??= merged;
    }
    for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
      visit(child, merged);
    }
  }

  for (final InlineSpan span in spans) {
    visit(span, null);
  }
  return markdownSpansFor(text.toString(), base ?? const TextStyle(), style);
}

/// Markdown spans for [text] in [base] (see [markdownSpans]).
List<InlineSpan> markdownSpansFor(
  String text,
  TextStyle base,
  MarkdownStyle style,
) {
  final Color? color = base.color;
  final TextStyle dim = base.copyWith(
    color: style.markerColor?.toFlutterColor() ?? color?.withValues(alpha: 0.35),
  );
  final TextStyle bullet = base.copyWith(
    color: style.bulletColor?.toFlutterColor() ?? color,
    fontWeight: style.showMarkers ? FontWeight.w600 : null,
  );
  final List<InlineSpan> out = <InlineSpan>[];
  final List<String> lines = text.split('\n');
  for (int i = 0; i < lines.length; i++) {
    String line = lines[i];
    final bool last = i == lines.length - 1;
    final bool blank = line.trim().isEmpty;
    if (blank && !style.showMarkers) {
      // A blank line between paragraphs is a short gap, not a full line.
      if (!last && out.isNotEmpty) {
        out.add(
          TextSpan(
            text: '$line\n',
            style: base.copyWith(
              fontSize: style.paragraphGap <= 0 ? 0.1 : style.paragraphGap,
              height: 1,
            ),
          ),
        );
      }
      continue;
    }
    final RegExpMatch? m = _bullet.firstMatch(line) ?? _numbered.firstMatch(line);
    if (m != null) {
      if (style.showMarkers) {
        out.add(TextSpan(text: line.substring(0, m.end), style: bullet));
      } else {
        final bool numbered = m.pattern == _numbered;
        out.add(
          TextSpan(
            text: '${m[1]}${numbered ? '${m[2]}.' : '•'} ',
            style: bullet,
          ),
        );
      }
      line = line.substring(m.end);
    }
    out.addAll(_inlineSpans(line, base, style, dim));
    if (!last) out.add(TextSpan(text: '\n', style: base));
  }
  return out;
}

List<InlineSpan> _inlineSpans(
  String text,
  TextStyle base,
  MarkdownStyle style,
  TextStyle dim,
) {
  final List<InlineSpan> spans = <InlineSpan>[];
  final bool markers = style.showMarkers;
  int at = 0;
  void wrapped(String marker, String inner, TextStyle inside) {
    if (markers) spans.add(TextSpan(text: marker, style: dim));
    spans.add(TextSpan(text: inner, style: inside));
    if (markers) spans.add(TextSpan(text: marker, style: dim));
  }

  for (final RegExpMatch m in _inline.allMatches(text)) {
    if (m.start > at) {
      spans.add(TextSpan(text: text.substring(at, m.start), style: base));
    }
    final String s = m[0]!;
    if (m[1] != null) {
      wrapped(
        '**',
        s.substring(2, s.length - 2),
        base.copyWith(fontWeight: FontWeight.w700),
      );
    } else if (m[2] != null) {
      wrapped(
        '`',
        s.substring(1, s.length - 1),
        _codeStyle(base, style),
      );
    } else if (m[3] != null) {
      wrapped(
        '_',
        s.substring(1, s.length - 1),
        base.copyWith(fontStyle: FontStyle.italic),
      );
    } else if (m[4] != null) {
      final bool known =
          style.mentions.isEmpty || style.mentions.contains(s.substring(1));
      spans.add(
        TextSpan(
          text: s,
          style: known
              ? base.copyWith(
                  color: style.mentionColor?.toFlutterColor() ?? base.color,
                  fontWeight: FontWeight.w600,
                  backgroundColor: style.mentionBackground?.toFlutterColor(),
                )
              : base,
        ),
      );
    } else {
      final Color? link = style.linkColor?.toFlutterColor() ?? base.color;
      spans.add(
        TextSpan(
          text: s,
          style: base.copyWith(
            color: link,
            decoration: TextDecoration.underline,
            decorationColor: link?.withValues(alpha: 0.4),
          ),
        ),
      );
    }
    at = m.end;
  }
  if (at < text.length) {
    spans.add(TextSpan(text: text.substring(at), style: base));
  }
  return spans;
}

/// Inline code: the code font (a Google Font, loaded on demand), a little
/// smaller, in the code colors.
TextStyle _codeStyle(TextStyle base, MarkdownStyle style) {
  TextStyle code = base.copyWith(
    fontSize: (base.fontSize ?? 14) - 1.5,
    color: style.codeColor?.toFlutterColor() ?? base.color,
    backgroundColor: style.codeBackground?.toFlutterColor(),
    fontWeight: FontWeight.w400,
  );
  try {
    code = GoogleFonts.getFont(style.codeFontFamily, textStyle: code);
  } catch (_) {
    code = code.copyWith(
      fontFamily: style.codeFontFamily,
      fontFamilyFallback: const <String>['monospace'],
    );
  }
  return code;
}
