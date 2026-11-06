import 'dart:convert';

/// Pulls complete JSON objects out of JSON text that arrives in pieces, so
/// each A2UI message can be applied the moment its closing brace arrives,
/// before the rest of the reply has streamed.
///
/// [depth] is the nesting level of the objects to emit:
/// - 0 for JSONL or concatenated objects (`{...}\n{...}`), the A2UI
///   streaming transport;
/// - 2 for the items of an array inside an object, e.g. the
///   `{"messages": [{...}, {...}]}` input of the render tool.
///
/// Text outside JSON (prose, code fences) at depth 0 is skipped.
class A2uiJsonStreamParser {
  A2uiJsonStreamParser({this.depth = 0});

  final int depth;
  final StringBuffer _buffer = StringBuffer();
  int _level = 0;
  bool _inString = false;
  bool _escaped = false;
  int? _start;
  int _offset = 0;
  String _text = '';

  /// Adds [chunk] and returns the objects it completed, in order.
  List<Map<String, Object?>> add(String chunk) {
    _buffer.write(chunk);
    _text = _buffer.toString();
    final List<Map<String, Object?>> out = [];
    for (; _offset < _text.length; _offset++) {
      final String ch = _text[_offset];
      if (_inString) {
        if (_escaped) {
          _escaped = false;
        } else if (ch == r'\') {
          _escaped = true;
        } else if (ch == '"') {
          _inString = false;
        }
        continue;
      }
      if (_level < depth || (_level == depth && _start == null)) {
        // Outside the objects to emit: only track structure.
        if (ch == '"' && _level > 0) _inString = true;
      } else if (ch == '"') {
        _inString = true;
        continue;
      }
      if (ch == '{' || ch == '[') {
        if (_level == depth && ch == '{') _start = _offset;
        _level++;
      } else if (ch == '}' || ch == ']') {
        if (_level == 0) continue;
        _level--;
        if (_level == depth && _start != null) {
          final String json = _text.substring(_start!, _offset + 1);
          _start = null;
          try {
            final Object? decoded = jsonDecode(json);
            if (decoded is Map<String, Object?>) out.add(decoded);
          } on FormatException {
            // A malformed object is dropped; the final validation reports it.
          }
        }
      }
    }
    return out;
  }

  /// All text added so far.
  String get text => _text;
}
