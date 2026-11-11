import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/extensions.dart';

/// Draws the inline code of a text: the segments of its resolved text
/// wrapped in backticks take an [InlineCodeStyle] and lose their backticks
/// (see [TextNode.inlineCode]).
abstract final class InlineCode {
  /// The character that opens and closes a code segment.
  static const String tick = '`';

  /// [spans] with every segment between a pair of backticks drawn in
  /// [style], the backticks removed. Backticks pair up in order across the
  /// spans, so a segment can span several styled ranges; a last, unpaired
  /// backtick stays as typed. Returns [spans] itself when they have no pair
  /// of backticks.
  static List<InlineSpan> apply(List<InlineSpan> spans, InlineCodeStyle style) {
    final StringBuffer buffer = StringBuffer();
    void collect(InlineSpan span) {
      if (span is TextSpan) {
        if (span.text case final String text) buffer.write(text);
        span.children?.forEach(collect);
      } else {
        // A placeholder (a widget in the text) takes one character.
        buffer.write('￼');
      }
    }

    spans.forEach(collect);
    final String all = buffer.toString();
    final List<(int, int)> segments = codeSegments(all);
    if (segments.isEmpty) return spans;

    // What each character of the text is: a backtick to drop, code, or
    // neither.
    final List<_Kind> kinds = List.filled(all.length, _Kind.text);
    for (final (int start, int end) in segments) {
      kinds[start - 1] = _Kind.tick;
      kinds[end] = _Kind.tick;
      for (int i = start; i < end; i++) {
        kinds[i] = _Kind.code;
      }
    }
    bool isTick(int at) =>
        at >= 0 && at < kinds.length && kinds[at] == _Kind.tick;
    final String padding = ' ' * style.paddingSpaces.clamp(0, 8);
    bool isCode(int at) => kinds[at] == _Kind.code;

    final Color? color = style.color?.toFlutterColor();
    final Color? background = style.background?.toFlutterColor();
    final FontWeight? weight = style.fontWeight == null
        ? null
        : FontWeight.values[((style.fontWeight! / 100).round() - 1).clamp(
            0,
            8,
          )];

    TextStyle codeStyle(TextStyle inherited) {
      final double? size = inherited.fontSize;
      final FontWeight? codeWeight = weight ?? inherited.fontWeight;
      return TextStyle(
        fontFamily: _family(style.fontFamily, codeWeight, inherited.fontStyle),
        // The text's own font stands in while the code font loads.
        fontFamilyFallback: [?inherited.fontFamily],
        fontWeight: weight,
        color: color,
        backgroundColor: background,
        fontSize: size == null || style.fontSizeScale == 1
            ? null
            : size * style.fontSizeScale,
      );
    }

    int offset = 0;
    InlineSpan rebuild(InlineSpan span, TextStyle inherited) {
      if (span is! TextSpan) {
        offset += 1;
        return span;
      }
      final TextStyle effective = inherited.merge(span.style);
      final String? text = span.text;
      final List<InlineSpan> pieces = [];
      bool changed = false;
      if (text != null && text.isNotEmpty) {
        final StringBuffer run = StringBuffer();
        bool? runIsCode;
        void flush() {
          if (run.isEmpty) return;
          pieces.add(
            TextSpan(
              text: run.toString(),
              style: runIsCode == true ? codeStyle(effective) : null,
              recognizer: span.recognizer,
              mouseCursor: span.mouseCursor,
              onEnter: span.onEnter,
              onExit: span.onExit,
            ),
          );
          run.clear();
        }

        for (int i = 0; i < text.length; i++) {
          final int at = offset + i;
          if (isTick(at)) {
            changed = true;
            continue;
          }
          final bool code = isCode(at);
          if (code) changed = true;
          if (runIsCode != null && runIsCode != code) flush();
          runIsCode = code;
          // A segment's first and last characters follow and precede its
          // backticks: pad there, in the code's style.
          if (code && isTick(at - 1)) run.write(padding);
          run.write(text[i]);
          if (code && isTick(at + 1)) run.write(padding);
        }
        flush();
        offset += text.length;
      }
      final List<InlineSpan>? children = span.children
          ?.map((child) => rebuild(child, effective))
          .toList();
      final bool childrenChanged =
          children != null &&
          children.indexed.any((entry) => entry.$2 != span.children![entry.$1]);
      if (!changed && !childrenChanged) return span;
      return TextSpan(
        style: span.style,
        recognizer: span.recognizer,
        mouseCursor: span.mouseCursor,
        onEnter: span.onEnter,
        onExit: span.onExit,
        semanticsLabel: span.semanticsLabel,
        locale: span.locale,
        spellOut: span.spellOut,
        children: [...pieces, ...?children],
      );
    }

    return [
      for (final InlineSpan span in spans) rebuild(span, const TextStyle()),
    ];
  }

  /// The code segments of [text]: the ranges, without their backticks,
  /// between each pair of backticks, in order. An empty pair (` `` `) makes
  /// no segment but still drops its backticks.
  static List<(int, int)> codeSegments(String text) {
    final List<(int, int)> segments = [];
    int? open;
    for (int i = 0; i < text.length; i++) {
      if (text[i] != tick) continue;
      if (open == null) {
        open = i;
      } else {
        segments.add((open + 1, i));
        open = null;
      }
    }
    return segments;
  }

  /// [text] without the backticks of its code segments, as [apply] shows it.
  static String strip(String text) {
    final List<(int, int)> segments = codeSegments(text);
    if (segments.isEmpty) return text;
    final StringBuffer out = StringBuffer();
    int at = 0;
    for (final (int start, int end) in segments) {
      out.write(text.substring(at, start - 1));
      out.write(text.substring(start, end));
      at = end + 1;
    }
    out.write(text.substring(at));
    return out.toString();
  }

  /// The font family that draws [family]: a Google Fonts family is loaded
  /// in [weight] and [fontStyle]; any other family is used as named.
  static String? _family(
    String? family,
    FontWeight? weight,
    FontStyle? fontStyle,
  ) {
    if (family == null || family.trim().isEmpty) return null;
    final String name = family.trim();
    if (!GoogleFonts.asMap().containsKey(name)) return name;
    try {
      return GoogleFonts.getFont(
        name,
        fontWeight: weight,
        fontStyle: fontStyle,
      ).fontFamily;
    } catch (_) {
      return name;
    }
  }
}

enum _Kind { text, code, tick }
