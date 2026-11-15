// Markdown in texts and text fields (`TextProps.markdown`,
// `TextFieldProps.markdown`): the text and the styled runs that show it,
// drawn by the text's own spans (node_tree.dart) or the field's
// (controls/text_field.dart).
//
// A text shows its Markdown without the markers: `**on**` is "on" in bold,
// a `- ` item starts with a bullet. A field keeps every character, the
// markers dimmed (`showMarkers`), so the cursor and the selection stay where
// the user typed them.
import 'package:codelessly_api/core.dart' as api;

/// A `markdown` prop read: the colors and fonts of its parts.
final class MarkdownLook {
  const MarkdownLook({
    this.codeColor,
    this.codeBackground,
    this.codeFontFamily = 'JetBrains Mono',
    this.linkColor,
    this.mentionColor,
    this.mentionBackground,
    this.mentions = const [],
    this.bulletColor,
    this.markerColor,
    this.showMarkers = false,
    this.paragraphGap = 6,
  });

  final api.Color? codeColor, codeBackground, linkColor, mentionColor, mentionBackground, bulletColor, markerColor;
  final String codeFontFamily;

  /// The names drawn as mentions (`@maya`); empty: any `@name`.
  final List<String> mentions;

  /// Keeps the markers, dimmed: the text is the input's, character for
  /// character (a text field's live preview).
  final bool showMarkers;

  /// The height of a blank line between paragraphs (a hidden-marker text).
  final double paragraphGap;

  /// [json] read (a `markdown` prop), null when it is not a map.
  static MarkdownLook? of(Object? json, {bool? showMarkers}) {
    final m = api.readMap(json);
    if (m == null) return null;
    api.Color? color(String key) => api.Color.fromJson(m[key]);
    return MarkdownLook(
      codeColor: color('codeColor'),
      codeBackground: color('codeBackground'),
      codeFontFamily: api.readString(m['codeFontFamily']) ?? 'JetBrains Mono',
      linkColor: color('linkColor'),
      mentionColor: color('mentionColor'),
      mentionBackground: color('mentionBackground'),
      mentions: api.readStrings(m['mentions']),
      bulletColor: color('bulletColor'),
      markerColor: color('markerColor'),
      showMarkers: showMarkers ?? (m['showMarkers'] == true),
      paragraphGap: api.readDouble(m['paragraphGap']) ?? 6,
    );
  }
}

/// Inline Markdown: **bold**, `code`, _italic_, @mentions and links.
final RegExp _inline = RegExp(
  r'(\*\*[^*\n]+\*\*)|(`[^`\n]+`)|((?<![\w])_[^_\n]+_(?![\w]))|((?<![\w])@[a-zA-Z][\w-]*)|((?:https?://)?[\w-]+(?:\.[\w-]+)*\.(?:io|com|org|net|dev|app)(?:/[\w/.?=&%-]*\w)?)',
);
final RegExp _bullet = RegExp(r'^(\s*)([-*]) ');
final RegExp _numbered = RegExp(r'^(\s*)(\d+)[.)] ');

/// [source] as Markdown in [look]: the text to show and the runs that style
/// it, over a base text of [color] and [fontSize] (what the dimmed markers
/// and the smaller code are made from). With [MarkdownLook.showMarkers] the
/// text is [source] itself.
(String, List<api.TextRun>) markdownRuns(String source, MarkdownLook look, {api.Color? color, double? fontSize}) {
  final out = StringBuffer();
  final runs = <api.TextRun>[];
  final markers = look.showMarkers;
  // A theme color by name has no value to dim.
  final dimColor =
      look.markerColor ?? (color == null || color.name != null ? null : color.withAlpha((color.alpha * 0.35).round()));
  final dim = api.TextStyle(color: dimColor);
  final bullet = api.TextStyle(color: look.bulletColor, fontWeight: markers ? 600 : null);
  final code = api.TextStyle(
    fontFamily: look.codeFontFamily,
    fontSize: (fontSize ?? 14) - 1.5,
    fontWeight: 400,
    color: look.codeColor,
    backgroundColor: look.codeBackground,
  );
  void add(String text, [api.TextStyle? style]) {
    if (text.isEmpty) return;
    final start = out.length;
    out.write(text);
    if (style != null && !style.isEmpty) runs.add(api.TextRun(start, out.length, style));
  }

  void inline(String line) {
    var at = 0;
    void wrapped(String marker, String inner, api.TextStyle inside) {
      if (markers) add(marker, dim);
      add(inner, inside);
      if (markers) add(marker, dim);
    }

    for (final m in _inline.allMatches(line)) {
      add(line.substring(at, m.start));
      final s = m[0]!;
      if (m[1] != null) {
        wrapped('**', s.substring(2, s.length - 2), const api.TextStyle(fontWeight: 700));
      } else if (m[2] != null) {
        wrapped('`', s.substring(1, s.length - 1), code);
      } else if (m[3] != null) {
        wrapped('_', s.substring(1, s.length - 1), const api.TextStyle(fontStyle: api.FontStyle.italic));
      } else if (m[4] != null) {
        final known = look.mentions.isEmpty || look.mentions.contains(s.substring(1));
        add(
          s,
          known
              ? api.TextStyle(color: look.mentionColor, fontWeight: 600, backgroundColor: look.mentionBackground)
              : null,
        );
      } else {
        final link = look.linkColor ?? color;
        add(
          s,
          api.TextStyle(
            color: link,
            decoration: api.TextDecoration.underline,
            decorationColor: link == null || link.name != null ? null : link.withAlpha((link.alpha * 0.4).round()),
          ),
        );
      }
      at = m.end;
    }
    add(line.substring(at));
  }

  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    final last = i == lines.length - 1;
    if (line.trim().isEmpty && !markers) {
      // A blank line between paragraphs is a short gap, not a full line.
      if (!last && out.isNotEmpty)
        add('$line\n', api.TextStyle(fontSize: look.paragraphGap <= 0 ? 0.1 : look.paragraphGap, height: 1));
      continue;
    }
    final m = _bullet.firstMatch(line) ?? _numbered.firstMatch(line);
    if (m != null) {
      if (markers) {
        add(line.substring(0, m.end), bullet);
      } else {
        final numbered = m.pattern == _numbered;
        add('${m[1]}${numbered ? '${m[2]}.' : '•'} ', bullet);
      }
      line = line.substring(m.end);
    }
    inline(line);
    if (!last) add('\n');
  }
  return (out.toString(), runs);
}
