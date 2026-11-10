import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/widgets.dart';

import 'markdown_spans.dart';

/// A [TextEditingController] that shows its text as live Markdown while
/// [markdown] is set: `**bold**` bold, `_italic_` italic, `` `code` `` in
/// the code font, list markers and @mentions colored. Every character stays
/// (the markers are dimmed, see [MarkdownStyle.showMarkers]), so the cursor
/// and selection work as in plain text.
class MarkdownTextEditingController extends TextEditingController {
  /// Creates a [MarkdownTextEditingController] showing [text].
  MarkdownTextEditingController({super.text, MarkdownStyle? markdown})
    // A private field can't be a named initializing formal.
    // ignore: prefer_initializing_formals
    : _markdown = markdown;

  MarkdownStyle? _markdown;

  /// The Markdown style; null shows plain text.
  MarkdownStyle? get markdown => _markdown;

  set markdown(MarkdownStyle? value) {
    if (value == _markdown) return;
    _markdown = value;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final MarkdownStyle? markdown = _markdown;
    // While an input method composes a word, show its underline instead.
    if (markdown == null || (withComposing && value.isComposingRangeValid)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    return TextSpan(
      style: style,
      children: markdownSpansFor(
        text,
        style ?? const TextStyle(),
        markdown.showMarkers ? markdown : markdown.copyWith(showMarkers: true),
      ),
    );
  }
}
