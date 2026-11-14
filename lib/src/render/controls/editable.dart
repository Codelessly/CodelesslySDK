// Text editing with no EditableText (codelessly_api
// docs/design/11-no-widgets.md §3.2): what `EditableText` and
// `TextEditingController` did around Flutter's `RenderEditable`, for the text
// field the SDK draws itself (render/controls/text_field.dart).
//
// [FieldEditor] holds the field's value (text, selection, composing range),
// talks to the platform's text input over the `TextInputClient` channel
// (typing, IME composition, the on-screen keyboard and its action key,
// autofill), applies the field's limits and formatters, keeps the undo
// history, and does the keyboard's editing: caret moves by character, word
// and line, selection with Shift, Backspace and Delete by character and
// word, select all, the clipboard, undo and redo, Enter and Space. Its
// geometry questions (where a line starts, the word at a point) go to the
// `RenderEditable` the field lays out.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curve;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/services.dart';

/// A field's edits, newest last, for undo and redo (Flutter's `UndoHistory`
/// logic): changes of the text within [coalesce] of the previous one are
/// one step; at most [limit] steps are kept.
class FieldUndoHistory {
  FieldUndoHistory({this.coalesce = const Duration(milliseconds: 500), this.limit = 100});

  final Duration coalesce;
  final int limit;

  final List<TextEditingValue> _stack = [];
  int _index = -1;
  DateTime? _last;

  /// The clock (a test sets it).
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  bool get canUndo => _index > 0;
  bool get canRedo => _index >= 0 && _index < _stack.length - 1;

  /// Starts again from [value] (the first step).
  void reset(TextEditingValue value) {
    _stack
      ..clear()
      ..add(value);
    _index = 0;
    _last = null;
  }

  /// Records [value], a new text.
  void push(TextEditingValue value) {
    if (_index < 0) {
      reset(value);
      return;
    }
    if (_stack[_index].text == value.text) {
      // The selection moved: the step remembers where the caret is.
      _stack[_index] = value;
      return;
    }
    _stack.removeRange(_index + 1, _stack.length);
    final t = now();
    final recent = _last != null && t.difference(_last!) < coalesce && _index > 0;
    if (recent) {
      _stack[_index] = value;
    } else {
      _stack.add(value);
      _index++;
      if (_stack.length > limit) {
        _stack.removeAt(0);
        _index--;
      }
    }
    _last = t;
  }

  /// The value before the current step (null: none).
  TextEditingValue? undo() {
    if (!canUndo) return null;
    _last = null;
    return _stack[--_index];
  }

  /// The value after it (null: none).
  TextEditingValue? redo() {
    if (!canRedo) return null;
    _last = null;
    return _stack[++_index];
  }
}

/// The scroll of a field's text (a long line, or lines past its height):
/// `RenderEditable.offset`, with no `Scrollable` behind it.
class FieldScrollOffset extends ViewportOffset {
  double _pixels = 0;
  double _viewport = 0;
  double _min = 0, _max = 0;

  @override
  double get pixels => _pixels;

  @override
  bool get hasPixels => true;

  /// How far it can scroll.
  double get maxScrollExtent => _max;
  double get viewportDimension => _viewport;

  @override
  bool applyViewportDimension(double viewportDimension) {
    _viewport = viewportDimension;
    return true;
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    _min = minScrollExtent;
    _max = math.max(minScrollExtent, maxScrollExtent);
    final clamped = _pixels.clamp(_min, _max).toDouble();
    if (clamped != _pixels) {
      _pixels = clamped;
      return false;
    }
    return true;
  }

  @override
  void correctBy(double correction) => _pixels += correction;

  @override
  void jumpTo(double pixels) {
    final p = pixels.clamp(_min, _max).toDouble();
    if (p == _pixels) return;
    _pixels = p;
    notifyListeners();
  }

  @override
  Future<void> animateTo(double to, {required Duration duration, required Curve curve}) async => jumpTo(to);

  @override
  ScrollDirection get userScrollDirection => ScrollDirection.idle;

  @override
  bool get allowImplicitScrolling => false;
}

/// [text] in [style] as the field draws it: its [runs] (ranges in their
/// styles, merged in order) and, while a word is being composed, the
/// composing range underlined (Flutter's
/// `TextEditingController.buildTextSpan`; a composed word is drawn plain).
TextSpan fieldTextSpan(String text, TextStyle style,
    {TextRange composing = TextRange.empty, List<(int, int, TextStyle)> runs = const []}) {
  if (composing.isValid && !composing.isCollapsed && composing.end <= text.length) {
    final under = style.merge(const TextStyle(decoration: TextDecoration.underline));
    return TextSpan(style: style, children: [
      TextSpan(text: composing.textBefore(text)),
      TextSpan(style: under, text: composing.textInside(text)),
      TextSpan(text: composing.textAfter(text)),
    ]);
  }
  final length = text.length;
  final live = [
    for (final r in runs)
      if (r.$2.clamp(0, length) > r.$1.clamp(0, length)) r,
  ];
  if (live.isEmpty) return TextSpan(text: text, style: style);
  final bounds = <int>{0, length, for (final r in live) ...[r.$1.clamp(0, length), r.$2.clamp(0, length)]}.toList()..sort();
  return TextSpan(style: style, children: [
    for (var i = 0; i + 1 < bounds.length; i++)
      TextSpan(
        text: text.substring(bounds[i], bounds[i + 1]),
        style: live
            .where((r) => r.$1 <= bounds[i] && r.$2 >= bounds[i + 1])
            .fold<TextStyle?>(null, (merged, r) => merged == null ? r.$3 : merged.merge(r.$3)),
      ),
  ]);
}

/// What the editor asks the field it edits.
abstract interface class FieldEditorHost {
  /// The laid-out text (null before layout).
  RenderEditable? get editable;

  /// The configuration of its text input connection.
  TextInputConfiguration get inputConfiguration;

  /// Where the text is on screen (for the platform's IME window): its size
  /// and transform, the composing range's and the caret's rects.
  void reportGeometry(TextInputConnection connection);

  /// Its value changed ([userChanged]: the user's typing changed the text).
  void valueChanged(TextEditingValue old, {required bool userChanged, SelectionChangedCause? cause});

  /// The keyboard's action key or Enter (submit, next, done...).
  void performAction(TextInputAction action);

  /// The platform closed the connection (the keyboard went away).
  void inputClosed();

  /// Shows [position] (scrolls the text to it).
  void reveal(TextPosition position);
}

/// A text field's editing state and its text input connection.
class FieldEditor with TextInputClient, TextSelectionDelegate implements AutofillClient {
  FieldEditor(this.host, {TextEditingValue value = TextEditingValue.empty}) : _value = value {
    history.reset(value);
  }

  final FieldEditorHost host;

  static int _ids = 0;

  @override
  final String autofillId = 'codelessly-field-${_ids++}';

  TextEditingValue _value;

  /// The text, selection and composing range.
  TextEditingValue get value => _value;

  /// Sets the value from outside (an action, a new bound value): the
  /// platform's editing state follows, no `changed` fires, the undo history
  /// records it.
  set value(TextEditingValue v) {
    final next = _clampSelection(v);
    if (next == _value) return;
    final old = _value;
    _value = next;
    if (old.text != next.text) history.push(next);
    _pushState();
    host.valueChanged(old, userChanged: false);
  }

  String get text => _value.text;
  TextSelection get selection => _value.selection;
  set selection(TextSelection s) => value = _value.copyWith(selection: s, composing: TextRange.empty);

  /// Empties the field (Flutter's `TextEditingController.clear`).
  void clear() => value = TextEditingValue.empty;

  final FieldUndoHistory history = FieldUndoHistory();

  // --- what the field sets ---------------------------------------------------------

  bool readOnly = false;
  bool obscureText = false;
  bool multiline = false;
  bool enableInteractiveSelection = true;

  /// At most this many characters (null: no limit).
  int? maxLength;

  /// Applied to each change the user makes (an upper-case formatter, a
  /// regex filter), before [maxLength].
  List<TextInputFormatter> formatters = const [];

  /// The keyboard's action key (null: done, or newline when multi-line).
  TextInputAction? inputAction;

  /// The autofill group the field is in (its form's).
  AutofillScope? autofillScope;

  // --- the connection ----------------------------------------------------------------

  TextInputConnection? _connection;

  /// Whether the platform's text input is attached to this field.
  bool get hasConnection => _connection != null && _connection!.attached;

  /// Attaches the platform's text input (the field took the focus) and
  /// shows the keyboard.
  void openConnection() {
    if (readOnly && !hasConnection) {
      // A read-only field takes the focus and selection keys, no keyboard.
      return;
    }
    if (!hasConnection) {
      final scope = autofillScope;
      final config = host.inputConfiguration;
      _connection = scope != null && config.autofillConfiguration.enabled
          ? scope.attach(this, config)
          : TextInput.attach(this, config);
      host.reportGeometry(_connection!);
      _connection!.setEditingState(_value);
    }
    _connection!.show();
  }

  /// Shows the keyboard again (a tap on the focused field).
  void showKeyboard() {
    if (hasConnection) {
      _connection!.show();
    } else {
      openConnection();
    }
  }

  /// Detaches it (the field lost the focus).
  void closeConnection() {
    _connection?.close();
    _connection = null;
    if (_value.composing.isValid) {
      final old = _value;
      _value = _value.copyWith(composing: TextRange.empty);
      host.valueChanged(old, userChanged: false);
    }
  }

  /// The configuration changed (keyboard type, action...): the connection
  /// takes it.
  void updateConfiguration() {
    if (hasConnection) _connection!.updateConfig(host.inputConfiguration);
  }

  /// Tells the platform where the text is now (after layout).
  void updateGeometry() {
    if (hasConnection) host.reportGeometry(_connection!);
  }

  void _pushState() {
    if (hasConnection) _connection!.setEditingState(_value);
  }

  TextEditingValue _clampSelection(TextEditingValue v) {
    final n = v.text.length;
    var s = v.selection;
    if (s.isValid && (s.baseOffset > n || s.extentOffset > n)) {
      s = s.copyWith(baseOffset: math.min(s.baseOffset, n), extentOffset: math.min(s.extentOffset, n));
    }
    var c = v.composing;
    if (c.isValid && c.end > n) c = TextRange.empty;
    return TextEditingValue(text: v.text, selection: s, composing: c);
  }

  /// Applies a change the user made ([fromPlatform]: the platform's text
  /// input sent it, and has it already).
  void _userEdit(TextEditingValue next, {bool fromPlatform = false, SelectionChangedCause? cause}) {
    next = _clampSelection(next);
    final old = _value;
    if (next.text != old.text) {
      if (readOnly) {
        // Only the selection may move.
        next = old.copyWith(selection: next.selection, composing: TextRange.empty);
      } else {
        for (final f in formatters) {
          next = f.formatEditUpdate(old, next);
        }
        if (maxLength case final int max when max > 0) {
          next = LengthLimitingTextInputFormatter(max).formatEditUpdate(old, next);
        }
      }
    }
    if (next == old) {
      if (fromPlatform) _pushState();
      return;
    }
    _value = next;
    final changed = next.text != old.text;
    if (changed) history.push(next);
    // The platform hears of changes it didn't make (and of what a formatter
    // made of its own).
    if (!fromPlatform || next != _lastFromPlatform) _pushState();
    host.valueChanged(old, userChanged: changed, cause: cause);
  }

  TextEditingValue? _lastFromPlatform;

  // --- TextInputClient -------------------------------------------------------------------

  @override
  TextEditingValue? get currentTextEditingValue => _value;

  @override
  AutofillScope? get currentAutofillScope => autofillScope;

  @override
  void updateEditingValue(TextEditingValue value) {
    if (value == _value) return;
    _lastFromPlatform = value;
    _userEdit(value, fromPlatform: true, cause: SelectionChangedCause.keyboard);
    _lastFromPlatform = null;
  }

  @override
  void performAction(TextInputAction action) {
    if (action == TextInputAction.newline && multiline) return;
    host.performAction(action);
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void connectionClosed() {
    if (_connection == null) return;
    _connection = null;
    host.inputClosed();
  }

  @override
  void insertContent(KeyboardInsertedContent content) {}

  // --- AutofillClient ----------------------------------------------------------------------

  @override
  TextInputConfiguration get textInputConfiguration => host.inputConfiguration;

  @override
  void autofill(TextEditingValue newEditingValue) => updateEditingValue(newEditingValue);

  // --- TextSelectionDelegate ---------------------------------------------------------------

  @override
  TextEditingValue get textEditingValue => _value;

  @override
  void userUpdateTextEditingValue(TextEditingValue value, SelectionChangedCause cause) => _userEdit(value, cause: cause);

  @override
  void hideToolbar([bool hideHandles = true]) {}

  @override
  void bringIntoView(TextPosition position) => host.reveal(position);

  @override
  bool get cutEnabled => !readOnly && !obscureText && enableInteractiveSelection;

  @override
  bool get copyEnabled => !obscureText && enableInteractiveSelection;

  @override
  bool get pasteEnabled => !readOnly && enableInteractiveSelection;

  @override
  void cutSelection(SelectionChangedCause cause) {
    final s = _value.selection;
    if (!cutEnabled || !s.isValid || s.isCollapsed) return;
    Clipboard.setData(ClipboardData(text: s.textInside(_value.text)));
    _replaceSelection('', cause: cause);
  }

  @override
  void copySelection(SelectionChangedCause cause) {
    final s = _value.selection;
    if (!copyEnabled || !s.isValid || s.isCollapsed) return;
    Clipboard.setData(ClipboardData(text: s.textInside(_value.text)));
  }

  @override
  Future<void> pasteText(SelectionChangedCause cause) async {
    if (!pasteEnabled) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text;
    if (t == null || t.isEmpty) return;
    _replaceSelection(t, cause: cause);
  }

  @override
  void selectAll(SelectionChangedCause cause) {
    if (!enableInteractiveSelection && !readOnly) return;
    _userEdit(_value.copyWith(
        selection: TextSelection(baseOffset: 0, extentOffset: _value.text.length), composing: TextRange.empty),
        cause: cause);
  }

  // --- editing --------------------------------------------------------------------------------

  /// Replaces the selection with [insert] (the caret after it).
  void _replaceSelection(String insert, {SelectionChangedCause cause = SelectionChangedCause.keyboard}) {
    final v = _value;
    final s = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
    final text = v.text.replaceRange(s.start, s.end, insert);
    _userEdit(TextEditingValue(text: text, selection: TextSelection.collapsed(offset: s.start + insert.length)), cause: cause);
  }

  void _deleteRange(int start, int end) {
    if (start == end || readOnly) return;
    final a = math.min(start, end), b = math.max(start, end);
    _userEdit(TextEditingValue(text: _value.text.replaceRange(a, b, ''), selection: TextSelection.collapsed(offset: a)));
  }

  void _select(TextSelection s) {
    _userEdit(_value.copyWith(selection: s, composing: TextRange.empty), cause: SelectionChangedCause.keyboard);
    host.reveal(s.extent);
  }

  /// Undoes the last step.
  void undo() {
    final v = history.undo();
    if (v != null) _restore(v);
  }

  /// Redoes it.
  void redo() {
    final v = history.redo();
    if (v != null) _restore(v);
  }

  void _restore(TextEditingValue v) {
    if (readOnly) return;
    final old = _value;
    _value = _clampSelection(v.copyWith(composing: TextRange.empty));
    _pushState();
    host.valueChanged(old, userChanged: old.text != _value.text, cause: SelectionChangedCause.keyboard);
  }

  // --- the keyboard ------------------------------------------------------------------------------

  static bool get _apple =>
      defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;

  /// A key while the field has the focus; true when it was the field's.
  /// Characters are not: they come from the platform's text input
  /// (`updateEditingValue`). Tab and Escape are the focus scope's.
  bool handleKey(KeyEvent event) {
    if (event is KeyUpEvent) return false;
    final key = event.logicalKey;
    final kb = HardwareKeyboard.instance;
    final shift = kb.isShiftPressed;
    final primary = _apple ? kb.isMetaPressed : kb.isControlPressed;
    final word = _apple ? kb.isAltPressed : kb.isControlPressed;
    final lineMod = _apple && kb.isMetaPressed;

    if (primary && !kb.isAltPressed) {
      switch (key) {
        case LogicalKeyboardKey.keyA:
          selectAll(SelectionChangedCause.keyboard);
          return true;
        case LogicalKeyboardKey.keyC:
          copySelection(SelectionChangedCause.keyboard);
          return true;
        case LogicalKeyboardKey.keyX:
          cutSelection(SelectionChangedCause.keyboard);
          return true;
        case LogicalKeyboardKey.keyV:
          pasteText(SelectionChangedCause.keyboard);
          return true;
        case LogicalKeyboardKey.keyZ:
          shift ? redo() : undo();
          return true;
        case LogicalKeyboardKey.keyY when !_apple:
          redo();
          return true;
      }
    }

    final v = _value;
    final text = v.text;
    final sel = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: text.length);
    final ext = sel.extentOffset;

    int charBack(int at) => at <= 0 ? 0 : (CharacterBoundary(text).getLeadingTextBoundaryAt(at - 1) ?? 0);
    int charForward(int at) => at >= text.length ? text.length : (CharacterBoundary(text).getTrailingTextBoundaryAt(at) ?? text.length);
    int wordBack(int at) {
      final e = host.editable;
      if (obscureText || e == null) return 0;
      return at <= 0 ? 0 : (e.wordBoundaries.moveByWordBoundary.getLeadingTextBoundaryAt(at - 1) ?? 0);
    }

    int wordForward(int at) {
      final e = host.editable;
      if (obscureText || e == null) return text.length;
      return at >= text.length ? text.length : (e.wordBoundaries.moveByWordBoundary.getTrailingTextBoundaryAt(at) ?? text.length);
    }

    int lineStart(int at) {
      final e = host.editable;
      if (e == null || !multiline) return 0;
      return e.getLineAtOffset(TextPosition(offset: at)).start;
    }

    int lineEnd(int at) {
      final e = host.editable;
      if (e == null || !multiline) return text.length;
      final line = e.getLineAtOffset(TextPosition(offset: at));
      // The end of a wrapped line is before its newline.
      var end = line.end;
      if (end > line.start && end <= text.length && text[end - 1] == '\n') end--;
      return end;
    }

    void moveTo(int offset, {bool collapseFirst = false}) {
      offset = offset.clamp(0, text.length);
      if (shift) {
        if (!enableInteractiveSelection) return;
        _select(TextSelection(baseOffset: sel.baseOffset, extentOffset: offset));
      } else {
        _select(TextSelection.collapsed(offset: offset));
      }
    }

    switch (key) {
      case LogicalKeyboardKey.arrowLeft:
        if (!shift && !sel.isCollapsed && !word && !lineMod) {
          moveTo(sel.start);
        } else {
          moveTo(lineMod ? lineStart(ext) : word ? wordBack(ext) : charBack(ext));
        }
        return true;
      case LogicalKeyboardKey.arrowRight:
        if (!shift && !sel.isCollapsed && !word && !lineMod) {
          moveTo(sel.end);
        } else {
          moveTo(lineMod ? lineEnd(ext) : word ? wordForward(ext) : charForward(ext));
        }
        return true;
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.arrowDown:
        final down = key == LogicalKeyboardKey.arrowDown;
        final e = host.editable;
        if (lineMod || !multiline || e == null) {
          moveTo(down ? text.length : 0);
        } else {
          final from = TextPosition(offset: ext, affinity: sel.affinity);
          final to = down ? e.getTextPositionBelow(from) : e.getTextPositionAbove(from);
          moveTo(to.offset == ext ? (down ? text.length : 0) : to.offset);
        }
        return true;
      case LogicalKeyboardKey.home:
        moveTo(kb.isControlPressed ? 0 : lineStart(ext));
        return true;
      case LogicalKeyboardKey.end:
        moveTo(kb.isControlPressed ? text.length : lineEnd(ext));
        return true;
      case LogicalKeyboardKey.backspace:
        if (readOnly) return true;
        if (!sel.isCollapsed) {
          _replaceSelection('');
        } else {
          _deleteRange(lineMod ? lineStart(ext) : word ? wordBack(ext) : charBack(ext), ext);
        }
        return true;
      case LogicalKeyboardKey.delete:
        if (readOnly) return true;
        if (!sel.isCollapsed) {
          _replaceSelection('');
        } else {
          _deleteRange(ext, lineMod ? lineEnd(ext) : word ? wordForward(ext) : charForward(ext));
        }
        return true;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (multiline && (inputAction == null || inputAction == TextInputAction.newline || shift)) {
          if (!readOnly) _replaceSelection('\n');
        } else {
          _commitComposing();
          host.performAction(inputAction ?? TextInputAction.done);
        }
        return true;
      case LogicalKeyboardKey.space:
        // The focus scope would press the field; a space is typed instead.
        if (!readOnly && !primary) _replaceSelection(' ');
        return true;
    }
    return false;
  }

  void _commitComposing() {
    if (!_value.composing.isValid) return;
    final old = _value;
    _value = _value.copyWith(composing: TextRange.empty);
    _pushState();
    host.valueChanged(old, userChanged: false);
  }
}

/// A caret that blinks while its field has the focus (`EditableText`'s
/// cursor timer): on for 500 ms, off for 500 ms, on again at each edit.
class CaretBlink {
  CaretBlink(this.visible);

  final ValueNotifier<bool> visible;
  Timer? _timer;

  /// Whether carets blink (off in tests that compare pixels).
  static bool enabled = true;

  bool get running => _timer != null;

  /// Shows the caret and starts blinking.
  void start() {
    visible.value = true;
    _timer?.cancel();
    _timer = enabled ? Timer.periodic(const Duration(milliseconds: 500), (_) => visible.value = !visible.value) : null;
  }

  /// Hides it and stops.
  void stop() {
    _timer?.cancel();
    _timer = null;
    visible.value = false;
  }

  /// An edit: the caret shows at once and blinks from now.
  void restart() {
    if (running || visible.value) start();
  }
}

/// Runs [callback] after the current frame (never during layout or paint).
void afterFrame(VoidCallback callback) {
  final binding = SchedulerBinding.instance;
  binding.addPostFrameCallback((_) => callback());
  binding.ensureVisualUpdate();
}
