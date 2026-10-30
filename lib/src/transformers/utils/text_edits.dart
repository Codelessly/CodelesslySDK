import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/services.dart';

/// The edits a rich text composer makes at a text field's cursor: the
/// operations of an [EditTextAction], list continuation on Enter, and what
/// the field's triggers read about the cursor.
///
/// Each edit takes the field's current value and returns the new one, with
/// the cursor (or selection) where typing would leave it. An invalid
/// selection counts as a cursor at the end of the text.
abstract final class TextEdits {
  static final RegExp _whitespace = RegExp(r'\s');
  static final RegExp _listMarker = RegExp(r'^(- |\d+\. )');
  static final RegExp _numberedMarker = RegExp(r'^\d+\. ');
  static final RegExp _listItem = RegExp(r'^(- |(\d+)\. )(.*)$');

  /// [value]'s selection, or a cursor at the end when it has none.
  static TextSelection selectionOf(TextEditingValue value) =>
      value.selection.isValid && value.selection.end <= value.text.length
      ? value.selection
      : TextSelection.collapsed(offset: value.text.length);

  /// Wraps the selection in [before] and [after], keeping the wrapped text
  /// selected, or inserts the empty pair with the cursor between.
  static TextEditingValue wrap(
    TextEditingValue value,
    String before,
    String after,
  ) {
    final TextSelection sel = selectionOf(value);
    final String selected = sel.textInside(value.text);
    final String text = value.text.replaceRange(
      sel.start,
      sel.end,
      '$before$selected$after',
    );
    final int start = sel.start + before.length;
    return TextEditingValue(
      text: text,
      selection: selected.isEmpty
          ? TextSelection.collapsed(offset: start)
          : TextSelection(
              baseOffset: start,
              extentOffset: start + selected.length,
            ),
    );
  }

  /// Turns the lines the selection touches into `- ` items, or `1. `, `2. `
  /// ones when [numbered], or back into plain lines when they all are such
  /// items already. The cursor goes to the end of the lines.
  static TextEditingValue toggleList(
    TextEditingValue value, {
    bool numbered = false,
  }) {
    final String text = value.text;
    final TextSelection sel = selectionOf(value);
    final int start = _lineStart(text, sel.start);
    int end = text.indexOf('\n', sel.end);
    if (end < 0) end = text.length;
    final List<String> lines = text.substring(start, end).split('\n');
    final bool all = lines.every(
      (line) =>
          numbered ? _numberedMarker.hasMatch(line) : line.startsWith('- '),
    );
    final String out = [
      for (int i = 0; i < lines.length; i++)
        all
            ? lines[i].replaceFirst(_listMarker, '')
            : '${numbered ? '${i + 1}. ' : '- '}'
                  '${lines[i].replaceFirst(_listMarker, '')}',
    ].join('\n');
    return TextEditingValue(
      text: text.replaceRange(start, end, out),
      selection: TextSelection.collapsed(offset: start + out.length),
    );
  }

  /// Inserts [insert] in place of the selection, with a space before it when
  /// the character before isn't whitespace (so a Mention button's `@` starts
  /// a new word).
  static TextEditingValue insert(TextEditingValue value, String insert) {
    final TextSelection sel = selectionOf(value);
    final String pre =
        sel.start > 0 && !_whitespace.hasMatch(value.text[sel.start - 1])
        ? ' '
        : '';
    return TextEditingValue(
      text: value.text.replaceRange(sel.start, sel.end, '$pre$insert'),
      selection: TextSelection.collapsed(
        offset: sel.start + pre.length + insert.length,
      ),
    );
  }

  /// Replaces the word ending at the cursor (see [wordStart]), and the
  /// selection if any, with [replacement]: the `@ma` being typed becomes the
  /// picked `@maya `.
  static TextEditingValue replaceWord(
    TextEditingValue value,
    String replacement,
  ) {
    final TextSelection sel = selectionOf(value);
    final int start = wordStart(value.text, sel.start);
    return TextEditingValue(
      text: value.text.replaceRange(start, sel.end, replacement),
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  /// [text] in place of everything, cursor at its end.
  static TextEditingValue setText(String text) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );

  /// Enter inside a list item: continues the list on a new line (`- ` or
  /// the next number), or, on an empty item, ends it by removing the
  /// marker. Null when the cursor isn't at a list item, or text is selected.
  static TextEditingValue? continueList(TextEditingValue value) {
    final TextSelection sel = value.selection;
    if (!sel.isValid || !sel.isCollapsed) return null;
    final String text = value.text;
    final int at = sel.baseOffset;
    final int lineStart = _lineStart(text, at);
    final RegExpMatch? m = _listItem.firstMatch(text.substring(lineStart, at));
    if (m == null) return null;
    if (m[3]!.trim().isEmpty) {
      return TextEditingValue(
        text: text.replaceRange(lineStart, at, ''),
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }
    final String next = m[2] != null ? '${int.parse(m[2]!) + 1}. ' : '- ';
    return TextEditingValue(
      text: text.replaceRange(at, at, '\n$next'),
      selection: TextSelection.collapsed(offset: at + 1 + next.length),
    );
  }

  /// Applies [operation] with the given inputs (variables already
  /// substituted) to [value]. Null for [EditTextOperation.focus], which
  /// doesn't change the text.
  static TextEditingValue? apply(
    TextEditingValue value,
    EditTextOperation operation, {
    String text = '',
    String before = '',
    String? after,
    bool numbered = false,
  }) => switch (operation) {
    EditTextOperation.wrap => wrap(value, before, after ?? before),
    EditTextOperation.toggleList => toggleList(value, numbered: numbered),
    EditTextOperation.insert => insert(value, text),
    EditTextOperation.replaceWord => replaceWord(value, text),
    EditTextOperation.setText => setText(text),
    EditTextOperation.clear => setText(''),
    EditTextOperation.focus => null,
  };

  /// Where the word ending at [offset] in [text] starts: the run of
  /// non-whitespace characters before it.
  static int wordStart(String text, int offset) {
    int start = offset.clamp(0, text.length);
    while (start > 0 && !_whitespace.hasMatch(text[start - 1])) {
      start--;
    }
    return start;
  }

  /// What a text field's triggers read in `${result}` about [value]:
  /// - `value`: the text,
  /// - `word`: the word ending at the cursor (`@ma` while typing a mention),
  ///   empty while text is selected,
  /// - `cursor`: the cursor's offset,
  /// - `selectionStart`, `selectionEnd`: the selection (both the cursor
  ///   when nothing is selected).
  static Map<String, Object> resultOf(TextEditingValue value) {
    final TextSelection sel = selectionOf(value);
    final int cursor = sel.extentOffset.clamp(0, value.text.length);
    return {
      'value': value.text,
      'word': sel.isCollapsed
          ? value.text.substring(wordStart(value.text, cursor), cursor)
          : '',
      'cursor': cursor,
      'selectionStart': sel.start,
      'selectionEnd': sel.end,
    };
  }

  static int _lineStart(String text, int offset) =>
      offset <= 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;
}
