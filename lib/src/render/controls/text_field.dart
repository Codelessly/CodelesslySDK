// `textField` as a render object (codelessly_api
// docs/design/11-no-widgets.md §3.2): SSUI's field frame
// (render/controls/field_frame.dart) around Flutter's `RenderEditable`,
// edited by a [FieldEditor] (render/controls/editable.dart) instead of an
// `EditableText`. No widget, no Material: the label sits above the box, the
// colors are tokens, and the field takes part in its root's focus order
// (Tab from a button reaches it).
//
// The runtime's side (the `focus` and `editText` actions, forms and their
// `validate` action) is reached through [TextFieldServices], which the
// widgets layer passes to [textFieldRecipe] (render can't import runtime).
import 'dart:async' show scheduleMicrotask;
import 'dart:ui' as ui show BoxHeightStyle, BoxWidthStyle;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Node, SizeFit, TextFieldProps;
import 'package:flutter/foundation.dart' show ValueNotifier, listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../contracts.dart' show ExpressionValues;
import '../convert.dart';
import '../convert.dart' as convert show textAlign;
import '../node_tree.dart' show fireTrigger;
import '../recipe.dart';
import 'editable.dart';
import 'focus.dart' show ControlKeyResult;
import 'field_frame.dart';
import 'tokens.dart';

/// What the runtime does with a text field while it is shown: the `focus`
/// and `editText` actions find it, its form validates it.
abstract interface class TextFieldServices {
  /// [field], node [b]'s, is on screen (again: idempotent).
  void attachField(NodeBuilder b, RenderTextField field);

  /// It left the screen.
  void detachField(NodeBuilder b, RenderTextField field);

  /// Its text or the error it shows changed (its form publishes again).
  void fieldChanged(NodeBuilder b);
}

/// The trigger a tap on a decoration's prefix icon fires
/// (runtime/actions/wiring.dart's `iconTapPrefix`).
const fieldPrefixTap = 'prefixIconTap';

/// ... and on its suffix icon.
const fieldSuffixTap = 'suffixIconTap';

/// [text] as a design canvas shows it before bindings run: its formulas
/// (`${= ...}`) come out empty, its variables (`${name}`) stay as written.
String fieldPreviewText(String? text) {
  if (text == null || text.isEmpty) return '';
  if (!text.contains(r'${=')) return text;
  final out = StringBuffer();
  var i = 0;
  while (i < text.length) {
    if (text.startsWith(r'${=', i)) {
      var depth = 0, j = i + 1;
      for (; j < text.length; j++) {
        if (text[j] == '{') depth++;
        if (text[j] == '}' && --depth == 0) break;
      }
      i = j + 1;
    } else {
      out.write(text[i++]);
    }
  }
  final s = out.toString();
  return s.trim().isEmpty ? '' : s;
}

/// The recipe of `textField` (lib/src/widgets/controls.dart registers it,
/// with the runtime's [services]).
void textFieldRecipe(NodeBuilder b, Node n, List<RenderBox> chain, {TextFieldServices? services}) {
  final l = n.layout;
  chain.add(b.fitBox('fit', l.width.fit, l.height.fit, Size(l.width.value, l.height.value)));
  final interactive = b.tree.animates;
  final states = b.tree.statesOf(b.id, instance: b.instance);
  final patched = n.behaviors.states.patches.keys.toSet();
  final tokens = ControlTokens.of(b);
  final box = b.obtain<RenderTextField>('textField', RenderTextField.new);
  box
    ..builder = b
    ..services = interactive ? services : null
    ..interactive = interactive
    ..config = TextFieldConfig.of(n, tokens, inherited: b.slot.textDefault, interactive: interactive)
    ..autofillGroup = interactive ? FieldAutofillGroup.of(b) : null
    ..validation = interactive ? _validation(b, n) : null
    ..onStateChanged = interactive && patched.isNotEmpty
        ? (s, on) {
            if (patched.contains(s)) b.tree.setState(b.id, s, on, instance: b.instance);
          }
        : null
    ..onEvent = interactive ? (trigger, value) => fireTrigger(b, trigger, event: {'value': value}) : null
    ..onAffixTap = interactive ? (prefix) => fireTrigger(b, prefix ? fieldPrefixTap : fieldSuffixTap) : null;
  box.enabled = box.config.enabled && !states.contains(api.WidgetState.disabled);
  box.autofocus = interactive && box.config.autofocus;
  box.initialValue = interactive ? n.prop(TextFieldProps.initialValue) : fieldPreviewText(n.prop(TextFieldProps.initialValue));
  box.validateAlways();
  chain.add(box);
}

/// The validator of [n] at [b] and the modes it runs in (the field's and
/// its form's), or null without a validator.
FieldValidation? _validation(NodeBuilder b, Node n) {
  final validator = n.prop(TextFieldProps.validator);
  final modes = {n.prop(TextFieldProps.autovalidateMode), _formMode(b)};
  if (validator.trim().isEmpty) return FieldValidation(check: null, modes: modes);
  return FieldValidation(
    modes: modes,
    check: (text) {
      final values = b.tree.bindings?.valuesFor(b.source, b.id, b.instance);
      if (values is! ExpressionValues) return null;
      Object? result;
      try {
        result = values.evaluate(validator, {'value': text});
      } catch (_) {
        return null;
      }
      final message = result == null ? '' : '$result'.trim();
      return message.isEmpty ? null : message;
    },
  );
}

/// The id of the form node [b] is in (itself or its nearest ancestor with
/// a `form` behavior), or null.
String? fieldFormOf(NodeBuilder b) {
  for (String? at = b.id; at != null; at = b.source.parentOf(at)) {
    if (b.source.node(at)?.behaviors.form != null) return at;
  }
  return null;
}

api.AutovalidateMode _formMode(NodeBuilder b) {
  final form = fieldFormOf(b);
  return form == null ? api.AutovalidateMode.disabled : b.source.node(form)?.behaviors.form?.autovalidateMode ?? api.AutovalidateMode.disabled;
}

/// A field's validator (Flutter's `TextFormField.validator`) and when it
/// runs.
class FieldValidation {
  FieldValidation({required this.check, required this.modes});

  /// The error for a text (null: valid, or no validator).
  final String? Function(String text)? check;
  final Set<api.AutovalidateMode> modes;

  bool get validates => check != null;
}

/// The fields of one form that the platform fills together (a username and
/// its password): Flutter's `AutofillGroup`.
class FieldAutofillGroup with AutofillScopeMixin {
  FieldAutofillGroup._();

  final Map<String, AutofillClient> _clients = {};

  static final Expando<Map<String, FieldAutofillGroup>> _groups = Expando('FieldAutofillGroup');

  /// The group of the form [b] is in (null outside one).
  static FieldAutofillGroup? of(NodeBuilder b) {
    final form = fieldFormOf(b);
    if (form == null) return null;
    final byForm = _groups[b.tree] ??= {};
    return byForm['$form ${b.instance.hashCode}'] ??= FieldAutofillGroup._();
  }

  void register(AutofillClient c) => _clients[c.autofillId] = c;
  void unregister(AutofillClient c) => _clients.remove(c.autofillId);

  @override
  AutofillClient? getAutofillClient(String autofillId) => _clients[autofillId];

  @override
  Iterable<AutofillClient> get autofillClients =>
      _clients.values.where((c) => c.textInputConfiguration.autofillConfiguration.enabled);
}

/// A text field's props, resolved for drawing and editing.
class TextFieldConfig {
  TextFieldConfig._(this._props);

  final List<Object?> _props;

  late final api.InputDecoration decoration;
  late final ControlTokens tokens;
  late final TextStyle valueStyle;
  late final List<(int, int, TextStyle)> runs;
  late final TextAlign textAlign;
  late final TextAlignVertical? alignVertical;
  late final TextInputType keyboardType;
  late final TextInputAction? inputAction;
  late final TextCapitalization capitalization;
  late final bool autocorrect, autofocus, enableInteractiveSelection, enabled, obscureText, readOnly, selectAllOnFocus;
  late final String obscuringCharacter;
  late final bool? showCursor;
  late final Color cursorColor;
  late final double? cursorHeight;
  late final double cursorWidth;
  late final Radius cursorRadius;
  late final int? maxLength, maxLines, minLines;
  late final bool expands, oneLine;
  late final ui.BoxHeightStyle selectionHeightStyle;
  late final ui.BoxWidthStyle selectionWidthStyle;
  late final List<String> autofillHints;
  late final double focusRingWidth;
  late final Color? focusRingColor;
  late final List<TextInputFormatter> formatters;
  late final double hugWidth;

  /// [n]'s field in [tokens]; [inherited] is the default text style it is
  /// under.
  factory TextFieldConfig.of(Node n, ControlTokens tokens, {api.TextStyle? inherited, bool interactive = true}) {
    final p = <Object?>[
      n.props,
      n.layout.width.fit,
      n.layout.height.fit,
      n.layout.width.value,
      n.layout.height.value,
      n.behaviors.defaultTextStyle,
      inherited?.fontFamily,
      tokens.theme,
      tokens.dark,
      tokens.backdrop,
      interactive,
    ];
    final c = TextFieldConfig._(p);
    final hFit = n.layout.width.fit, vFit = n.layout.height.fit;
    final maxLinesProp = n.prop(TextFieldProps.maxLines);
    final minLinesProp = n.prop(TextFieldProps.minLines);
    final fillsHeight = vFit != SizeFit.hug;
    c.oneLine = maxLinesProp == 1 && (minLinesProp ?? 1) <= 1;
    c.expands = (fillsHeight && !c.oneLine) || (n.prop(TextFieldProps.expands) && !c.oneLine);
    var max = maxLinesProp >= 1 ? maxLinesProp : null;
    var min = minLinesProp != null && minLinesProp >= 1 ? minLinesProp : null;
    if (max != null && min != null && min > max) max = min;
    if (c.expands) max = min = null;
    c.maxLines = max;
    c.minLines = min;
    // The text's size follows the box's step of the scale (a fixed height).
    final scale = vFit == SizeFit.fixed && c.oneLine ? tokens.scaleFor(n.layout.height.value) : ControlScale.compact;
    final own = n.behaviors.defaultTextStyle;
    final inheritedStyle = TextStyle(fontFamily: inherited?.fontFamily);
    final ownDefault = own == null || own.isEmpty ? null : ownStyle(own);
    var base = FieldDecoration.valueStyleFor(tokens, scale, inherited: inheritedStyle);
    if (ownDefault != null) base = base.merge(ownDefault);
    final style = n.prop(TextFieldProps.style);
    c.valueStyle = style.isEmpty ? base : base.merge(ownStyle(style));
    c.runs = [
      for (final r in n.prop(TextFieldProps.runs))
        (r.start, r.end, ownStyle(own == null ? r.style : own.merge(r.style))),
    ];
    c.decoration = n.prop(TextFieldProps.decoration);
    c.tokens = tokens;
    c.textAlign = switch (n.prop(TextFieldProps.textAlign)) {
      api.TextAlign.start => TextAlign.left,
      final a => convert.textAlign(a),
    };
    c.alignVertical = switch (n.prop(TextFieldProps.textAlignVertical)) {
      null => null,
      api.TextAlignVertical.top => TextAlignVertical.top,
      api.TextAlignVertical.center => TextAlignVertical.center,
      api.TextAlignVertical.bottom => TextAlignVertical.bottom,
    };
    c.keyboardType = switch (n.prop(TextFieldProps.keyboardType)) {
      api.TextInputType.number => TextInputType.numberWithOptions(
          decimal: n.prop(TextFieldProps.keyboardDecimal), signed: n.prop(TextFieldProps.keyboardSigned)),
      api.TextInputType.text => c.oneLine ? TextInputType.text : TextInputType.multiline,
      api.TextInputType.multiline => TextInputType.multiline,
      api.TextInputType.phone => TextInputType.phone,
      api.TextInputType.datetime => TextInputType.datetime,
      api.TextInputType.emailAddress => TextInputType.emailAddress,
      api.TextInputType.url => TextInputType.url,
      api.TextInputType.visiblePassword => TextInputType.visiblePassword,
      api.TextInputType.name => TextInputType.name,
      api.TextInputType.streetAddress => TextInputType.streetAddress,
      api.TextInputType.none => TextInputType.none,
      api.TextInputType.webSearch => TextInputType.webSearch,
      api.TextInputType.twitter => TextInputType.twitter,
    };
    c.inputAction = switch (n.prop(TextFieldProps.textInputAction)) {
      null => null,
      final a => TextInputAction.values.byName(a.name),
    };
    c.capitalization = TextCapitalization.values.byName(n.prop(TextFieldProps.textCapitalization).name);
    c.autocorrect = n.prop(TextFieldProps.autocorrect);
    c.autofocus = n.prop(TextFieldProps.autofocus);
    c.enableInteractiveSelection = n.prop(TextFieldProps.enableInteractiveSelection);
    c.enabled = n.prop(TextFieldProps.enabled) && c.decoration.enabled;
    c.obscureText = n.prop(TextFieldProps.obscureText) && c.oneLine;
    final ch = n.prop(TextFieldProps.obscuringCharacter);
    c.obscuringCharacter = ch.isEmpty ? '•' : ch.characters1;
    c.readOnly = n.prop(TextFieldProps.readOnly);
    c.selectAllOnFocus = n.prop(TextFieldProps.selectAllOnFocus);
    c.showCursor = n.prop(TextFieldProps.showCursor);
    c.cursorColor = n.prop(TextFieldProps.cursorColor)?.flutter ?? tokens.primary;
    c.cursorHeight = n.prop(TextFieldProps.cursorHeight);
    // SSUI's caret is 1.5 wide with round ends; a node's own width wins.
    c.cursorWidth = n.props.has(TextFieldProps.cursorWidth) ? n.prop(TextFieldProps.cursorWidth) : 1.5;
    c.cursorRadius = Radius.circular(n.prop(TextFieldProps.cursorRadius) ?? 1);
    c.maxLength = n.prop(TextFieldProps.maxLength);
    c.selectionHeightStyle = ui.BoxHeightStyle.values.byName(n.prop(TextFieldProps.selectionHeightStyle).name);
    c.selectionWidthStyle = ui.BoxWidthStyle.values.byName(n.prop(TextFieldProps.selectionWidthStyle).name);
    c.autofillHints = n.prop(TextFieldProps.autofillHints);
    c.focusRingWidth = n.prop(TextFieldProps.focusRingWidth);
    c.focusRingColor = n.prop(TextFieldProps.focusRingColor)?.flutter;
    c.formatters = [
      if (n.prop(TextFieldProps.textCapitalization) == api.TextCapitalization.characters) const _UpperCaseFormatter(),
      ?_formatter(n.prop(TextFieldProps.inputFormatter)),
    ];
    c.hugWidth = hFit == SizeFit.hug && n.layout.width.value > 0 ? n.layout.width.value : kFieldHugWidth;
    return c;
  }

  @override
  bool operator ==(Object other) => other is TextFieldConfig && listEquals(other._props, _props);

  @override
  int get hashCode => Object.hashAll(_props);
}

extension on String {
  /// Its first character (a grapheme cluster of one code point at least).
  String get characters1 => runes.isEmpty ? this : String.fromCharCode(runes.first);
}

/// The input formatter [f] describes: a regex filter.
TextInputFormatter? _formatter(api.Json f) {
  final pattern = api.readString(f['pattern']);
  if (f['type'] != 'regex' || pattern == null || pattern.isEmpty) return null;
  final RegExp re;
  try {
    re = RegExp(pattern,
        unicode: f['unicode'] == true,
        caseSensitive: f['caseSensitive'] != false,
        multiLine: f['multiLine'] == true,
        dotAll: f['dotAll'] == true);
  } on FormatException {
    return null;
  }
  return FilteringTextInputFormatter(re, allow: f['allow'] != false, replacementString: api.readString(f['replacementString']) ?? '');
}

/// Turns typed text into capitals (`TextCapitalization.characters`).
class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final upper = newValue.text.toUpperCase();
    if (upper == newValue.text) return newValue;
    if (upper.length == newValue.text.length) return newValue.copyWith(text: upper);
    return TextEditingValue(text: upper, selection: TextSelection.collapsed(offset: upper.length));
  }
}

/// A text field: the frame around its editable text, its editing, focus,
/// validation and semantics.
class RenderTextField extends RenderFieldFrame implements FieldEditorHost {
  RenderTextField() {
    editor = FieldEditor(this);
    _editable = RenderEditable(
      text: const TextSpan(text: ''),
      textDirection: TextDirection.ltr,
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
      offset: _scroll,
      showCursor: _caretVisible,
      hasFocus: false,
      ignorePointer: true,
      paintCursorAboveText: true,
      textSelectionDelegate: editor,
      selection: const TextSelection.collapsed(offset: 0),
    );
    adoptChild(_editable);
    final focusChanged = focusNode.onFocusChange;
    focusNode
      ..onActivate = null
      ..onKeyResult = _key
      ..onFocusChange = (on) {
        focusChanged?.call(on);
        _focusChanged(on);
      };
    onPressed = _tapped;
    _tapAndPan = TapAndPanGestureRecognizer(debugOwner: this)
      ..onTapDown = _tapDown
      ..onTapUp = _tapUp
      ..onDragStart = _dragStart
      ..onDragUpdate = _dragUpdate;
    _longPress = LongPressGestureRecognizer(debugOwner: this)..onLongPressStart = _longPressStart;
    _affixTap = TapGestureRecognizer(debugOwner: this)..onTap = _affixTapped;
  }

  /// The field that has the keyboard focus now, of every root (someone is
  /// typing: letter shortcuts wait).
  static RenderTextField? focused;

  late final FieldEditor editor;
  late final RenderEditable _editable;
  final FieldScrollOffset _scroll = FieldScrollOffset();
  final ValueNotifier<bool> _caretVisible = ValueNotifier(false);
  late final CaretBlink _caret = CaretBlink(_caretVisible);
  late final TapAndPanGestureRecognizer _tapAndPan;
  late final LongPressGestureRecognizer _longPress;
  late final TapGestureRecognizer _affixTap;

  /// The laid-out text (Flutter's `RenderEditable`).
  @override
  RenderEditable get editable => _editable;

  @override
  List<RenderBox> get contentChildren => [_editable];

  /// Its node's builder (its trees and bindings) and the runtime's side.
  NodeBuilder? builder;
  TextFieldServices? _services;
  set services(TextFieldServices? v) {
    if (identical(v, _services)) return;
    if (attached && builder != null) _services?.detachField(builder!, this);
    _services = v;
    if (attached && builder != null) v?.attachField(builder!, this);
  }

  /// A trigger to fire on its node (`changed`, `submitted`, `focusGained`,
  /// `focusLost`, `editingComplete`) with the text.
  void Function(String trigger, String value)? onEvent;

  bool _interactive = false;

  /// Whether it edits (a running app); a design canvas draws it at rest.
  set interactive(bool v) {
    if (v == _interactive) return;
    _interactive = v;
    if (!v) focusNode.leave();
    markNeedsPaint();
  }

  bool get interactive => _interactive;

  FieldAutofillGroup? _autofillGroup;
  set autofillGroup(FieldAutofillGroup? g) {
    if (identical(g, _autofillGroup)) return;
    _autofillGroup?.unregister(editor);
    _autofillGroup = g;
    _syncAutofill();
  }

  void _syncAutofill() {
    final g = _autofillGroup;
    final on = g != null && _config != null && config.autofillHints.isNotEmpty;
    editor.autofillScope = on ? g : null;
    if (on && attached) {
      g.register(editor);
    } else {
      g?.unregister(editor);
    }
  }

  // --- configuration -----------------------------------------------------------------

  TextFieldConfig? _config;
  TextFieldConfig get config => _config!;
  set config(TextFieldConfig c) {
    if (c == _config) return;
    final old = _config;
    _config = c;
    hugWidth = c.hugWidth;
    alignVertical = c.alignVertical;
    hintAlign = c.textAlign;
    editor
      ..readOnly = c.readOnly
      ..obscureText = c.obscureText
      ..multiline = !c.oneLine
      ..enableInteractiveSelection = c.enableInteractiveSelection
      ..maxLength = c.maxLength
      ..formatters = c.formatters
      ..inputAction = c.inputAction;
    _editable
      ..textAlign = c.textAlign
      ..obscureText = c.obscureText
      ..obscuringCharacter = c.obscuringCharacter
      ..readOnly = c.readOnly
      ..maxLines = c.maxLines
      ..minLines = c.minLines
      ..expands = c.expands
      ..cursorColor = c.cursorColor
      ..backgroundCursorColor = c.tokens.secondaryText
      ..cursorWidth = c.cursorWidth
      ..cursorHeight = c.cursorHeight
      ..cursorRadius = c.cursorRadius
      ..selectionHeightStyle = c.selectionHeightStyle
      ..selectionWidthStyle = c.selectionWidthStyle
      ..enableInteractiveSelection = c.enableInteractiveSelection;
    _syncText();
    _rebuildDecoration();
    _syncAutofill();
    if (old != null) editor.updateConfiguration();
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  @override
  TextInputConfiguration get inputConfiguration {
    final c = config;
    final hints = c.autofillHints;
    return TextInputConfiguration(
      viewId: _viewId,
      inputType: c.keyboardType,
      readOnly: c.readOnly,
      obscureText: c.obscureText,
      autocorrect: c.obscureText ? false : c.autocorrect,
      enableSuggestions: !c.obscureText,
      enableInteractiveSelection: c.enableInteractiveSelection,
      inputAction: c.inputAction ?? (c.oneLine ? TextInputAction.done : TextInputAction.newline),
      textCapitalization: c.capitalization,
      keyboardAppearance: c.tokens.dark ? Brightness.dark : Brightness.light,
      autofillConfiguration: hints.isEmpty
          ? AutofillConfiguration.disabled
          : AutofillConfiguration(uniqueIdentifier: editor.autofillId, autofillHints: hints, currentEditingValue: editor.value),
    );
  }

  int? get _viewId {
    final owner = this.owner;
    if (owner == null) return null;
    RenderObject? at = this;
    while (at != null && at is! RenderView) {
      at = at.parent;
    }
    return at is RenderView ? at.flutterView.viewId : null;
  }

  // --- validation --------------------------------------------------------------------------

  FieldValidation? validation;

  String? _error;

  /// The error the validator shows now (null: none).
  String? get validationError => _error;

  /// The validator's error for the text now (null: valid or none).
  String? check() => validation?.check?.call(editor.text);

  /// Shows [error] under the field (Flutter's `FormFieldState.validate`
  /// result), or none.
  void showError(String? error) {
    if (error == _error) return;
    _error = error;
    _rebuildDecoration();
    final b = builder;
    if (b != null) _services?.fieldChanged(b);
  }

  /// With `autovalidateMode: always`, the error follows the text.
  void validateAlways() {
    final v = validation;
    if (v != null && v.validates && v.modes.contains(api.AutovalidateMode.always)) showError(check());
  }

  void _validateOnChange() {
    final v = validation;
    if (v != null && v.validates) {
      if (v.modes.contains(api.AutovalidateMode.always) ||
          v.modes.contains(api.AutovalidateMode.onUserInteraction) ||
          (v.modes.contains(api.AutovalidateMode.onUserInteractionIfError) && _error != null)) {
        showError(check());
      }
    }
    final b = builder;
    if (b != null) _services?.fieldChanged(b);
  }

  void _rebuildDecoration() {
    final c = _config;
    if (c == null) return;
    decoration = FieldDecoration.of(c.decoration, c.tokens,
        valueStyle: c.valueStyle,
        errorOverride: _error,
        focusRingWidth: c.focusRingWidth,
        focusRingColor: c.focusRingColor,
        text: _interactive ? null : fieldPreviewText);
  }

  // --- the value ------------------------------------------------------------------------------

  String? _initial;

  /// The texts it reported as changed, newest last: a bound initial value
  /// that comes back from them is an echo, not a new value.
  final List<String> _sent = [];

  /// The node's `initialValue`: the text when it first shows, and a new
  /// value when it changes from outside.
  set initialValue(String v) {
    if (v == _initial) return;
    final first = _initial == null;
    _initial = v;
    if (editor.text == v) return;
    if (first) {
      editor.value = TextEditingValue(text: v, selection: TextSelection.collapsed(offset: v.length));
      editor.history.reset(editor.value);
      return;
    }
    final echo = _sent.indexOf(v);
    if (echo >= 0) {
      _sent.removeRange(0, echo + 1);
      return;
    }
    _sent.clear();
    // A caret at the end stays at the end; elsewhere it stays where it is.
    final s = editor.selection;
    final atEnd = s.isCollapsed && s.baseOffset == editor.text.length;
    editor.value = TextEditingValue(
      text: v,
      selection: s.isValid && !atEnd
          ? TextSelection(baseOffset: s.baseOffset.clamp(0, v.length), extentOffset: s.extentOffset.clamp(0, v.length))
          : TextSelection.collapsed(offset: v.length),
    );
  }

  bool _edited = false;

  void _syncText() {
    final c = _config;
    if (c == null) return;
    final v = editor.value;
    // Hidden text is drawn as its obscuring character, one per code unit
    // (so the selection's offsets stay the text's): `RenderEditable` only
    // hides it from screen readers, as `EditableText` does the drawing.
    final shown = c.obscureText ? c.obscuringCharacter * v.text.length : v.text;
    _editable
      ..text = fieldTextSpan(shown, c.valueStyle,
          composing: focusNode.hasFocus ? v.composing : TextRange.empty, runs: c.obscureText ? const [] : c.runs)
      ..selection = v.selection;
  }

  @override
  void valueChanged(TextEditingValue old, {required bool userChanged, SelectionChangedCause? cause}) {
    _syncText();
    markNeedsLayout();
    if (focusNode.hasFocus) _caret.restart();
    markNeedsSemanticsUpdate();
    if (userChanged) {
      _edited = true;
      final t = editor.text;
      _sent.add(t);
      if (_sent.length > 64) _sent.removeAt(0);
      _validateOnChange();
      onEvent?.call('changed', t);
    } else if (old.text != editor.text) {
      validateAlways();
    }
  }

  @override
  void performAction(TextInputAction action) {
    switch (action) {
      case TextInputAction.newline:
        if (!config.oneLine) return;
      case TextInputAction.none || TextInputAction.unspecified:
        return;
      default:
    }
    final text = editor.text;
    if (editor.autofillScope != null) TextInput.finishAutofillContext();
    onEvent?.call('submitted', text);
    switch (action) {
      case TextInputAction.next:
        focusNode.scope?.next();
      case TextInputAction.previous:
        focusNode.scope?.next(backward: true);
      default:
        focusNode.unfocus();
    }
  }

  @override
  void inputClosed() => focusNode.unfocus();

  // --- focus -------------------------------------------------------------------------------------

  void _focusChanged(bool on) {
    if (on) {
      focused = this;
    } else if (identical(focused, this)) {
      focused = null;
    }
    _editable.hasFocus = on;
    if (on) {
      final v = editor.value;
      if (_config?.selectAllOnFocus ?? false) {
        editor.selection = TextSelection(baseOffset: 0, extentOffset: v.text.length);
      } else if (!v.selection.isValid) {
        editor.selection = TextSelection.collapsed(offset: v.text.length);
      }
      editor.openConnection();
      if (_showsCaret) _caret.start();
      _scheduleGeometry();
      _focusEvent('focusGained');
    } else {
      editor.closeConnection();
      _caret.stop();
      final v = validation;
      if (v != null && v.validates && v.modes.contains(api.AutovalidateMode.onUnfocus)) {
        showError(check());
      }
      _focusEvent('focusLost');
      if (_edited) {
        _edited = false;
        _focusEvent('editingComplete');
      }
    }
    _editable.selectionColor = on ? config.tokens.primary.withValues(alpha: .25) : null;
    _syncText();
    markNeedsLayout();
  }

  /// Fires a focus trigger once the focus has settled, unless the field
  /// left the screen meanwhile (a root that detaches drops its focus).
  void _focusEvent(String trigger) {
    final text = editor.text;
    scheduleMicrotask(() {
      if (attached) onEvent?.call(trigger, text);
    });
  }

  bool get _showsCaret => _config != null && (config.showCursor ?? !config.readOnly);

  ControlKeyResult _key(KeyEvent event) {
    if (!_interactive || !enabled) return ControlKeyResult.ignored;
    return editor.handleKey(event);
  }

  void _tapped() {
    if (!_interactive) return;
    focusNode.requestFocus();
    editor.showKeyboard();
  }

  /// Takes the focus (the `focus` action, a screen reader).
  bool requestFocus() => focusNode.requestFocus();

  // --- pointer -----------------------------------------------------------------------------------

  @override
  MouseCursor get cursor => _interactive && enabled ? SystemMouseCursors.text : MouseCursor.defer;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (!_interactive || !enabled || event is! PointerDownEvent) return;
    final part = partAt(entry.localPosition);
    if (part == FieldFramePart.prefixIcon || part == FieldFramePart.suffixIcon) {
      _affixPrefix = part == FieldFramePart.prefixIcon;
      _affixTap.addPointer(event);
      return;
    }
    _tapAndPan.addPointer(event);
    if (event.kind == PointerDeviceKind.touch) _longPress.addPointer(event);
  }

  bool _affixPrefix = true;
  void _affixTapped() => onAffixTap?.call(_affixPrefix);

  Offset? _dragFrom;

  void _tapDown(TapDragDownDetails d) {
    _dragFrom = d.globalPosition;
    if (!focusNode.hasFocus) focusNode.requestFocus();
    final count = d.consecutiveTapCount;
    final v = editor.value;
    if (count >= 3 || (count == 2 && config.obscureText)) {
      editor.selectAll(SelectionChangedCause.tap);
      return;
    }
    if (count == 2) {
      if (config.enableInteractiveSelection) _editable.selectWordsInRange(from: d.globalPosition, cause: SelectionChangedCause.doubleTap);
      return;
    }
    final pos = _editable.getPositionForPoint(d.globalPosition);
    if (HardwareKeyboard.instance.isShiftPressed && v.selection.isValid && config.enableInteractiveSelection) {
      editor.userUpdateTextEditingValue(
          v.copyWith(selection: TextSelection(baseOffset: v.selection.baseOffset, extentOffset: pos.offset)),
          SelectionChangedCause.tap);
    } else {
      editor.userUpdateTextEditingValue(
          v.copyWith(selection: TextSelection.fromPosition(pos), composing: TextRange.empty), SelectionChangedCause.tap);
    }
  }

  void _tapUp(TapDragUpDetails d) => editor.showKeyboard();

  void _dragStart(TapDragStartDetails d) {
    _dragFrom ??= d.globalPosition;
  }

  void _dragUpdate(TapDragUpdateDetails d) {
    final from = _dragFrom;
    if (from == null || !config.enableInteractiveSelection) return;
    if (d.consecutiveTapCount >= 2 && !config.obscureText) {
      _editable.selectWordsInRange(from: from, to: d.globalPosition, cause: SelectionChangedCause.drag);
    } else {
      _editable.selectPositionAt(from: from, to: d.globalPosition, cause: SelectionChangedCause.drag);
    }
  }

  void _longPressStart(LongPressStartDetails d) {
    if (!config.enableInteractiveSelection) return;
    if (config.obscureText) {
      editor.selectAll(SelectionChangedCause.longPress);
    } else {
      _editable.selectWordsInRange(from: d.globalPosition, cause: SelectionChangedCause.longPress);
    }
  }

  // --- the frame's content ---------------------------------------------------------------------

  @override
  double contentNaturalWidth() => _editable.getMaxIntrinsicWidth(double.infinity);

  @override
  double contentHeightFor(double width) => _editable.getMinIntrinsicHeight(width);

  @override
  double get contentLineHeight => _editable.preferredLineHeight;

  @override
  bool get contentMultiline => !(_config?.oneLine ?? true);

  @override
  bool get contentEmpty => editor.text.isEmpty;

  @override
  void layoutContent(Rect rect) {
    _editable.layout(BoxConstraints.tight(rect.size), parentUsesSize: true);
    (_editable.parentData! as BoxParentData).offset = rect.topLeft;
    if (focusNode.hasFocus) {
      _revealNow(editor.selection.isValid ? editor.selection.extent : TextPosition(offset: editor.text.length));
      _scheduleGeometry();
    }
  }

  @override
  void paintContent(PaintingContext context, Offset offset) {
    context.paintChild(_editable, offset + (_editable.parentData! as BoxParentData).offset);
  }

  @override
  void reveal(TextPosition position) => markNeedsLayout();

  void _revealNow(TextPosition position) {
    if (!_editable.hasSize) return;
    // Not getLocalRectForCaret: it snaps to the screen's pixels, which
    // can't be asked during layout.
    final end = _editable.getEndpointsForSelection(TextSelection.fromPosition(position)).first.point;
    final line = _editable.preferredLineHeight;
    final caret = Rect.fromLTWH(end.dx, end.dy - line, _editable.cursorWidth + 1, line);
    final view = Offset.zero & _editable.size;
    final multi = contentMultiline;
    final before = multi ? caret.top - view.top : caret.left - view.left;
    final after = multi ? caret.bottom - view.bottom : caret.right - view.right;
    if (after > 0) {
      _scroll.jumpTo(_scroll.pixels + after);
    } else if (before < 0) {
      _scroll.jumpTo(_scroll.pixels + before);
    }
  }

  bool _geometryScheduled = false;

  void _scheduleGeometry() {
    if (_geometryScheduled) return;
    _geometryScheduled = true;
    afterFrame(() {
      _geometryScheduled = false;
      if (attached && focusNode.hasFocus) editor.updateGeometry();
    });
  }

  @override
  void reportGeometry(TextInputConnection connection) {
    if (!attached || !_editable.hasSize) return;
    final c = config;
    connection
      ..setEditableSizeAndTransform(_editable.size, _editable.getTransformTo(null))
      ..updateStyle(TextInputStyle(
        fontFamily: c.valueStyle.fontFamily,
        fontSize: c.valueStyle.fontSize,
        fontWeight: c.valueStyle.fontWeight,
        textDirection: TextDirection.ltr,
        textAlign: c.textAlign,
        letterSpacing: c.valueStyle.letterSpacing,
      ));
    final v = editor.value;
    if (v.composing.isValid) {
      final r = _editable.getRectForComposingRange(v.composing);
      if (r != null) connection.setComposingRect(r);
    }
    if (v.selection.isValid) connection.setCaretRect(_editable.getLocalRectForCaret(v.selection.extent));
  }

  /// The frame's texts and the typed text (unless obscured), with their
  /// glyph boxes in the field's coordinates: what the label guard measures.
  @override
  List<({String text, String? fontFamily, List<Rect> glyphs})> get labels {
    final own = super.labels;
    final c = _config;
    if (c == null || c.obscureText || editor.text.trim().isEmpty || !_editable.hasSize) return own;
    final at = (_editable.parentData! as BoxParentData).offset;
    final view = Offset.zero & _editable.size;
    final glyphs = [
      for (final b in _editable.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: editor.text.length)))
        if (b.toRect().overlaps(view)) b.toRect().shift(at),
    ];
    return [...own, (text: editor.text, fontFamily: c.valueStyle.fontFamily, glyphs: glyphs)];
  }

  // --- semantics ------------------------------------------------------------------------------------

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    final c = _config;
    if (c == null) return;
    final v = editor.value;
    config
      ..isTextField = true
      ..isReadOnly = c.readOnly
      ..isObscured = c.obscureText
      ..isMultiline = !c.oneLine
      ..value = c.obscureText ? c.obscuringCharacter * v.text.length : v.text;
    if (c.maxLength != null) {
      config
        ..maxValueLength = c.maxLength
        ..currentValueLength = v.text.length;
    }
    if (!_interactive || !enabled) return;
    if (v.selection.isValid) config.textSelection = v.selection;
    config.onSetSelection = (s) => editor.userUpdateTextEditingValue(v.copyWith(selection: s), SelectionChangedCause.keyboard);
    if (!c.readOnly) {
      config.onSetText = (t) => editor.userUpdateTextEditingValue(
          TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length)), SelectionChangedCause.keyboard);
    }
    if (focusNode.hasFocus) {
      if (editor.copyEnabled && !v.selection.isCollapsed) config.onCopy = () => editor.copySelection(SelectionChangedCause.toolbar);
      if (editor.cutEnabled && !v.selection.isCollapsed) config.onCut = () => editor.cutSelection(SelectionChangedCause.toolbar);
      if (editor.pasteEnabled) config.onPaste = () => editor.pasteText(SelectionChangedCause.toolbar);
    }
  }

  // --- lifecycle ------------------------------------------------------------------------------------

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (!_interactive) focusNode.leave();
    final b = builder;
    if (b != null) _services?.attachField(b, this);
    _syncAutofill();
  }

  @override
  void detach() {
    final b = builder;
    if (b != null) _services?.detachField(b, this);
    _autofillGroup?.unregister(editor);
    editor.closeConnection();
    _caret.stop();
    super.detach();
  }

  @override
  void dispose() {
    _tapAndPan.dispose();
    _longPress.dispose();
    _affixTap.dispose();
    _caret.stop();
    _editable.dispose();
    _caretVisible.dispose();
    super.dispose();
  }

  /// The line of text the field shows, in the box (for tools and tests).
  Rect get textRect => (_editable.parentData! as BoxParentData).offset & _editable.size;

  /// Whether its caret is showing now.
  bool get caretVisible => _caretVisible.value && focusNode.hasFocus;

  /// The horizontal (one line) or vertical scroll of its text.
  double get scrollOffset => _scroll.pixels;
}

/// The field shown by node box [box], if any (for tests and tools).
RenderTextField? textFieldIn(RenderBox box) {
  RenderTextField? found;
  void visit(RenderObject o) {
    if (found != null) return;
    if (o is RenderTextField) {
      found = o;
      return;
    }
    o.visitChildren(visit);
  }

  visit(box);
  return found;
}
