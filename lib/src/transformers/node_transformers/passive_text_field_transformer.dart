import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../codelessly_sdk.dart';
import '../utils/node_state_provider.dart';

/// Resolves a text field's line limits into values [TextField] accepts.
///
/// - A field that [expands] fills its height, so it has no line limits.
/// - A limit below 1 means no limit (null), as the editor's panel writes 0
///   for a cleared value.
/// - A null [maxLines] is unlimited: the field grows with its content,
///   starting at [minLines].
/// - [minLines] above [maxLines] raises [maxLines] to [minLines], as the
///   editor's panel does when min lines is set above max lines, so the field
///   is never shorter than its minimum.
(int? maxLines, int? minLines) resolveTextFieldLines({
  required int? maxLines,
  required int? minLines,
  bool expands = false,
}) {
  if (expands) return (null, null);
  int? max = maxLines != null && maxLines >= 1 ? maxLines : null;
  final int? min = minLines != null && minLines >= 1 ? minLines : null;
  if (max != null && min != null && min > max) max = min;
  return (max, min);
}

/// Turns everything typed or pasted into a text field into capitals, for a
/// field with [TextCapitalizationC.characters]: a booking reference typed
/// `mx4821` reads `MX4821`. The selection stays where it was (upper-casing
/// can change a text's length, e.g. `ß` to `SS`; the caret then goes to the
/// end).
class UpperCaseTextInputFormatter extends TextInputFormatter {
  /// Creates an [UpperCaseTextInputFormatter].
  const UpperCaseTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String upper = newValue.text.toUpperCase();
    if (upper == newValue.text) return newValue;
    if (upper.length == newValue.text.length) {
      return newValue.copyWith(text: upper);
    }
    return TextEditingValue(
      text: upper,
      selection: TextSelection.collapsed(offset: upper.length),
    );
  }
}

/// The Flutter [TextCapitalization] of [capitalization].
TextCapitalization flutterTextCapitalization(
  TextCapitalizationC capitalization,
) => switch (capitalization) {
  TextCapitalizationC.none => TextCapitalization.none,
  TextCapitalizationC.words => TextCapitalization.words,
  TextCapitalizationC.sentences => TextCapitalization.sentences,
  TextCapitalizationC.characters => TextCapitalization.characters,
};

class PassiveTextFieldTransformer extends NodeWidgetTransformer<TextFieldNode> {
  PassiveTextFieldTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    TextFieldNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return PassiveTextFieldWidget(
      key: ValueKey(node.id),
      node: node,
      settings: settings,
      onTap: (context, value) => onTap(context, node, value),
      onIconTap: (context, reactions, value) =>
          onIconTap(context, node, reactions, value),
      onChanged: (context, value) => onChanged(context, node, value),
      onSubmitted: (context, value) => onSubmitted(context, node, value),
      onEditingComplete: (context, value) =>
          onEditingComplete(context, node, value),
      onKeyDown: (context, reactions, result) =>
          FunctionsRepository.triggerAction(
            context,
            TriggerType.keyDown,
            reactions: reactions,
            result: result,
          ),
    );
  }

  Widget buildFromProps(
    BuildContext context, {
    required TextFieldProperties props,
    required double height,
    required double width,
    required WidgetBuildSettings settings,
  }) {
    final node = TextFieldNode(
      id: '',
      name: 'TextField',
      basicBoxLocal: NodeBox(0, 0, width, height),
      properties: props,
      edgePins: EdgePinsModel.standard,
    );
    return PassiveTextFieldWidget(node: node, settings: settings);
  }

  void onTap(BuildContext context, TextFieldNode node, String inputValue) {
    NodeStateProvider.setState(context, inputValue);
    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.changed,
      result: _result(context, inputValue),
    );
  }

  /// What the field's triggers read in `${result}`: the text with the word
  /// at the cursor and the selection (see [TextEdits.resultOf]).
  Map<String, Object> _result(BuildContext context, String inputValue) =>
      TextEdits.resultOf(
        PassiveTextFieldWidget.editingValueOf(context) ??
            TextEditingValue(text: inputValue),
      );

  void onChanged(BuildContext context, TextFieldNode node, String inputValue) {
    NodeStateProvider.setState(context, inputValue);
    FunctionsRepository.setNodeValue(
      context,
      node: node,
      property: 'inputValue',
      value: inputValue,
    );

    FunctionsRepository.setPropertyVariable(
      context,
      node: node,
      property: 'inputValue',
      value: inputValue,
    );

    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.changed,
      value: inputValue,
      result: _result(context, inputValue),
    );
  }

  void onSubmitted(
    BuildContext context,
    TextFieldNode node,
    String inputValue,
  ) {
    NodeStateProvider.setState(context, inputValue);
    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.submitted,
      value: inputValue,
    );
  }

  /// The field lost focus: its value is kept, and its "Editing Complete"
  /// actions run (not its "Submitted" ones, which wait for the keyboard's
  /// submit, so clicking elsewhere doesn't submit a form).
  void onEditingComplete(
    BuildContext context,
    TextFieldNode node,
    String inputValue,
  ) {
    NodeStateProvider.setState(context, inputValue);
    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.editingComplete,
      value: inputValue,
    );
  }

  void onIconTap(
    BuildContext context,
    TextFieldNode node,
    List<Reaction> reactions,
    String inputValue,
  ) {
    NodeStateProvider.setState(context, inputValue);
    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.click,
      value: inputValue,
      reactions: reactions,
    );
  }
}

class PassiveTextFieldWidget extends StatefulWidget {
  /// The key in [BaseNode.variables] that binds the colour of the typed
  /// text (`${pal.ink}`, `${= dark ? '#F4EFE6' : '#1F2B2E'}`).
  static const String inputColor = 'inputColor';

  /// The key in [BaseNode.variables] that binds the colour of the hint.
  static const String hintColor = 'hintColor';

  /// The key in [BaseNode.variables] that binds the colour of the cursor.
  static const String cursorColor = 'cursorColor';

  /// The visual density of a dense, unlabeled field with [contentPadding]
  /// under the [theme]'s density: the theme's, unless it would take more
  /// off the field than its vertical padding.
  static VisualDensity denseVisualDensity(
    VisualDensity theme,
    EdgeInsets contentPadding,
  ) {
    // Flutter's laid-out height of a dense, unlabeled field is
    // `max(padding + line + density, line)`, but its intrinsic height (which
    // sizes a field that hugs its height) drops the `line` floor: desktop's
    // compact density (-8 px) made a dense field with no content padding
    // 8 px shorter than its line (10 px for Inter 15). Keeping the density
    // from taking more than the vertical padding gives both the laid-out
    // height and line placement Flutter's layout gives.
    final double floor = -contentPadding.vertical / 4;
    if (theme.vertical >= floor) return theme;
    return VisualDensity(horizontal: theme.horizontal, vertical: floor);
  }

  /// [decoration] of a one-line field [height] tall, with its line placed
  /// in that height per [alignment] (the field's `textAlignVertical`).
  ///
  /// Flutter's InputDecorator is only as tall as its content (padding plus
  /// one line, or 48 px when not dense), whatever height it is given, so a
  /// dense 52 px field with no content padding showed its text at the top
  /// even when centered. The space left over goes into the content padding:
  /// above the line by the alignment's share (half for center), below it
  /// the rest, so the decorator fills the height and the line sits where
  /// `textAlignVertical` asks. A decoration with a label, helper, error or
  /// counter (which take their own room), or a non-dense field no taller
  /// than 48 px (which Flutter centers itself), is returned unchanged.
  static InputDecoration alignedVertically(
    BuildContext context,
    InputDecoration decoration, {
    required double height,
    required TextStyle inputStyle,
    required TextAlignVerticalEnum alignment,
  }) {
    final bool dense = decoration.isDense ?? false;
    if (!height.isFinite ||
        (decoration.isCollapsed ?? false) ||
        (!dense && height <= kMinInteractiveDimension) ||
        decoration.label != null ||
        decoration.labelText != null ||
        decoration.helperText != null ||
        decoration.helper != null ||
        decoration.error != null ||
        decoration.errorText != null ||
        decoration.counter != null ||
        (decoration.counterText?.isNotEmpty ?? false)) {
      return decoration;
    }
    final TextScaler scaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    double lineOf(TextStyle? style) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: ' ', style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      );
      final double line = painter.preferredLineHeight;
      painter.dispose();
      return line;
    }

    final double line = [
      lineOf(inputStyle),
      if (decoration.hintText != null) lineOf(decoration.hintStyle),
    ].reduce((a, b) => a > b ? a : b);
    final EdgeInsets padding =
        decoration.contentPadding?.resolve(Directionality.maybeOf(context)) ??
        EdgeInsets.zero;
    final double extra = height - padding.vertical - line;
    if (extra <= 0.5) return decoration;
    final double above = extra * (alignment.flutterTextAlignVertical.y + 1) / 2;
    return decoration.copyWith(
      contentPadding: padding.copyWith(
        top: padding.top + above,
        bottom: padding.bottom + extra - above,
      ),
    );
  }

  /// [padding] grown by the width of the border [decoration] draws in this
  /// state when it has `paddingIncludesBorder`, as a container's border adds
  /// to its padding: an outline on every side, an underline below. Disabled,
  /// then error (focused or not), then focused, then enabled.
  static EdgeInsets paddingWithBorder(
    EdgeInsets padding,
    InputDecorationModel decoration, {
    required bool error,
    required bool focused,
  }) {
    if (!decoration.paddingIncludesBorder) return padding;
    final InputBorderModel border = !decoration.enabled
        ? decoration.disabledBorder
        : error
        ? (focused ? decoration.focusedErrorBorder : decoration.errorBorder)
        : focused
        ? decoration.focusedBorder
        : decoration.enabledBorder;
    final double w = border.borderSide.width;
    if (border.borderType.isNone || w <= 0) return padding;
    if (border.borderType.isUnderline) {
      return padding.copyWith(bottom: padding.bottom + w);
    }
    return padding + EdgeInsets.all(w);
  }

  /// The colour that the binding [property] of [node] gives, evaluated with
  /// [scopedValues] (or a condition on it), or null when it is missing or
  /// isn't a colour.
  static Color? boundColor(
    TextFieldNode node,
    String property,
    ScopedValues scopedValues,
  ) {
    return PropertyValueDelegate.getPropertyValue<ColorRGBA>(
      node,
      property,
      scopedValues: scopedValues,
    )?.toFlutterColor();
  }

  final TextFieldNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;
  final Function(BuildContext context, String value)? onTap;
  final Function(BuildContext context, String value)? onChanged;
  final Function(BuildContext context, String value)? onSubmitted;

  /// Called when the field loses focus.
  final Function(BuildContext context, String value)? onEditingComplete;
  final Function(BuildContext context, List<Reaction> reactions, String value)?
  onIconTap;

  /// Runs the field's Key Down [reactions] that match a key pressed while it
  /// has focus, with the key, its modifiers and the cursor in [result].
  final Function(
    BuildContext context,
    List<Reaction> reactions,
    Map<String, Object> result,
  )?
  onKeyDown;
  final bool withAutofill;
  final AutovalidateMode? autovalidateMode;
  final FormFieldValidator<String>? validator;
  final bool? autofocus;

  /// The values the field's bound and initial text read, in place of the
  /// running app's: an editor's design canvas passes its variable defaults.
  final ScopedValues? scopedValues;

  PassiveTextFieldWidget({
    super.key,
    required this.node,
    required this.settings,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.withAutofill = true,
    this.onIconTap,
    this.onKeyDown,
    List<VariableData>? variables,
    this.autovalidateMode,
    this.validator,
    this.autofocus,
    this.scopedValues,
  }) : variablesOverrides = variables ?? [];

  @override
  State<PassiveTextFieldWidget> createState() => _PassiveTextFieldWidgetState();

  /// The text and selection of the field whose state's context is
  /// [context] (the context the field's callbacks get), if it is one.
  static TextEditingValue? editingValueOf(BuildContext context) =>
      switch (context) {
        StatefulElement(state: final _PassiveTextFieldWidgetState state) =>
          state.controller.value,
        _ => null,
      };
}

/// Moves the keyboard focus to the text field of a node (Focus action).
/// Returns whether that field is on screen.
///
/// In a list each item has its own copy of the field: the one in the same
/// item as [near] (the node that ran the action) is focused, else the
/// newest.
bool focusTextField(
  String nodeId, {
  bool selectAll = false,
  BuildContext? near,
}) => _PassiveTextFieldWidgetState.focus(
  nodeId,
  selectAll: selectAll,
  near: near,
);

/// Whether a text field of [nodeId] has the keyboard focus.
bool textFieldHasFocus(String nodeId) =>
    _PassiveTextFieldWidgetState.hasFocus(nodeId);

/// Takes the focus from the text field of [nodeId], or from any field.
void unfocusTextField([String? nodeId]) =>
    _PassiveTextFieldWidgetState.unfocus(nodeId);

class _PassiveTextFieldWidgetState extends State<PassiveTextFieldWidget>
    implements EditableTextField {
  late final MarkdownTextEditingController controller =
      MarkdownTextEditingController(
        text: _lastBound =
            boundValue() ?? getInitialText(widget.node.initialText),
        markdown: widget.node.properties.markdown,
      );

  /// The selection while the field last had focus. Tapping a toolbar button
  /// can take the focus (and, on the web, the selection) away before the
  /// button's Edit Text action runs.
  TextSelection? _lastSelection;

  @override
  int lastFocused = 0;

  bool _listening = false;

  @override
  ModalRoute<Object?>? route;

  /// Whether the field runs in an app (it has handlers), so Edit Text
  /// actions can reach it. A design canvas's fields don't register.
  bool get _editable => widget.onChanged != null && widget.node.id.isNotEmpty;

  /// The bound value the field last showed. The field takes the binding's
  /// value only when it changes, so typing into a field whose binding can't
  /// be set (a computed variable, a formula) isn't undone on every rebuild.
  String? _lastBound;

  /// The current value of the variable this field is bound to, if any. A
  /// variable set before the field first builds (by a canvas load action
  /// that prefills a form) shows up in the field.
  String? boundValue() {
    if (widget.node.variables['inputValue'] == null) return null;
    return PropertyValueDelegate.getPropertyValue<String>(
      widget.node,
      'inputValue',
      scopedValues: _scopedValues,
    );
  }

  late final FocusNode focusNode = FocusNode(onKeyEvent: _onKeyEvent);

  /// The text fields on screen by node id, newest last, so a Focus action
  /// can reach a field by its node.
  static final Map<String, List<_PassiveTextFieldWidgetState>> _mounted = {};

  /// Focuses the newest field of [nodeId] on screen (and selects its text
  /// when [selectAll]); returns whether there was one.
  static bool focus(
    String nodeId, {
    bool selectAll = false,
    BuildContext? near,
  }) {
    final List<_PassiveTextFieldWidgetState> fields = [
      for (final state in _mounted[nodeId] ?? const [])
        if (state.mounted) state,
    ];
    Element? itemOf(BuildContext context) =>
        context.getElementForInheritedWidgetOfExactType<IndexedItemProvider>();
    final Element? item = near != null && near.mounted ? itemOf(near) : null;
    _PassiveTextFieldWidgetState? state;
    if (item != null) {
      for (final field in fields.reversed) {
        if (itemOf(field.context) == item) {
          state = field;
          break;
        }
      }
    }
    state ??= fields.lastOrNull;
    if (state == null) return false;
    state.focusNode.requestFocus();
    if (selectAll) {
      state.controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: state.controller.text.length,
      );
    }
    return true;
  }

  /// Whether a field of [nodeId] has the focus.
  static bool hasFocus(String nodeId) =>
      [...?_mounted[nodeId]]
          .any((state) => state.mounted && state.focusNode.hasFocus);

  /// Unfocuses the field of [nodeId] (any field when null).
  static void unfocus([String? nodeId]) {
    if (nodeId == null) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    for (final _PassiveTextFieldWidgetState state in [...?_mounted[nodeId]]) {
      state.focusNode.unfocus();
    }
  }

  /// The values the field's bindings read: those it was given, else on the
  /// design canvas (no reactions) the editor's preview values, else the
  /// live ones.
  ScopedValues get _scopedValues =>
      widget.scopedValues ??
      (widget.settings.withReactions
          ? null
          : VariablePreview.scopeOf(widget.node, context: context)) ??
      ScopedValues.of(context);

  String getInitialText(String text) {
    return PropertyValueDelegate.substituteVariables(
      text,
      nullSubstitutionMode: widget.settings.nullSubstitutionMode,
      scopedValues: _scopedValues,
    );
  }

  @override
  void initState() {
    super.initState();
    focusNode.addListener(onFocusChanged);
    (_mounted[widget.node.id] ??= []).add(this);
    if (_editable) TextFieldRegistry.register(widget.node.id, this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    route = ModalRoute.of(context);
    // The controller reads the bound value, so it is made here, not in
    // initState.
    if (!_listening) {
      _listening = true;
      controller.addListener(_rememberSelection);
    }

    NodeStateProvider.setState(context, controller.text, byUser: false);
  }

  @override
  void didUpdateWidget(covariant PassiveTextFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    controller.markdown = widget.node.properties.markdown;
    if (oldWidget.node.id != widget.node.id) {
      // Registered under the old id, it would be kept there after dispose.
      _mounted[oldWidget.node.id]?.remove(this);
      if (_mounted[oldWidget.node.id]?.isEmpty ?? false) {
        _mounted.remove(oldWidget.node.id);
      }
      (_mounted[widget.node.id] ??= []).add(this);
    }
    if (oldWidget.node.id != widget.node.id ||
        (oldWidget.onChanged != null) != (widget.onChanged != null)) {
      TextFieldRegistry.unregister(oldWidget.node.id, this);
      if (_editable) TextFieldRegistry.register(widget.node.id, this);
    }

    // Update controller text if this text field is bound to a variable.
    final ScopedValues scopedValues = _scopedValues;

    // Get the value of bound variable and update the controller text if it's
    // different from the current controller text.
    // widget.node.variables['inputValue'] only works when a sync variable is specified. If it is not then
    // we rely on initial text to be able to see if controller text needs to be updated.
    final String? boundPath = widget.node.variables['inputValue'];
    String? currentPropertyValue = boundPath != null
        ? PropertyValueDelegate.getPropertyValue<String>(
                widget.node,
                'inputValue',
                scopedValues: scopedValues,
              ) ??
              // An empty text variable reads as null; a field bound to one
              // still clears, e.g. after a comment is sent.
              (_isExistingVariable(boundPath, scopedValues) ? '' : null)
        : findIndexedValueIfApplied(scopedValues) ??
              PropertyValueDelegate.getPropertyValueFromNodeValues<String>(
                widget.node,
                'inputValue',
                scopedValues: scopedValues,
              );
    if (currentPropertyValue != null) {
      currentPropertyValue = PropertyValueDelegate.substituteVariables(
        currentPropertyValue,
        scopedValues: scopedValues,
        nullSubstitutionMode: widget.settings.nullSubstitutionMode,
      );
    }

    if (currentPropertyValue != null &&
        currentPropertyValue != _lastBound &&
        controller.text != currentPropertyValue) {
      controller.text = currentPropertyValue;
    }
    if (currentPropertyValue != null) _lastBound = currentPropertyValue;
  }

  bool _isExistingVariable(String path, ScopedValues scopedValues) {
    final VariableMatch? match = VariableMatch.parse(
      path.wrapWithVariableSyntax(),
    );
    if (match == null || match.hasPath || match.isPredefinedVariable) {
      return false;
    }
    return scopedValues.variables.values.findByNameOrNull(match.name) != null;
  }

  /// The purpose of this function is to find the indexed value of the variable
  /// 'item' if it is applied to the initial text. This is used to determine if
  /// the controller text needs to be updated when the variable 'inputValue' is
  /// not specified.
  String? findIndexedValueIfApplied(ScopedValues scopedValues) {
    if (scopedValues.indexedItem == null) return null;
    if (widget.node.initialText.isEmpty) return null;
    if (widget.node.variables['inputValue'] != null) return null;
    final match = VariableMatch.parseAll(widget.node.initialText);
    if (!match.any((match) => match.name == 'item')) return null;

    return widget.node.initialText;
  }

  @override
  void dispose() {
    _mounted[widget.node.id]?.remove(this);
    if (_mounted[widget.node.id]?.isEmpty ?? false) {
      _mounted.remove(widget.node.id);
    }
    TextFieldRegistry.unregister(widget.node.id, this);
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void onFocusChanged() {
    if (focusNode.hasFocus) {
      lastFocused = TextFieldRegistry.tick();
    } else {
      widget.onEditingComplete?.call(context, controller.text);
    }
    if (!mounted) return;
    // The focus ring follows focus (its width may be bound), and so does a
    // padding that includes the (focused) border.
    if (widget.node.properties.focusRingWidth > 0 ||
        widget.node.variables.containsKey('focusRingWidth') ||
        widget.node.properties.decoration.paddingIncludesBorder) {
      setState(() {});
    }
    if (focusNode.hasFocus && widget.node.properties.selectAllOnFocus) {
      // After the tap that focused it places the caret.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !focusNode.hasFocus) return;
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      });
    }
    FunctionsRepository.triggerAction(
      context,
      node: widget.node,
      focusNode.hasFocus ? TriggerType.focusGained : TriggerType.focusLost,
      value: controller.text,
    );
  }

  /// The field's "Key Down" reactions: keys pressed while it has focus.
  /// A reaction for a specific key takes it (↑ ↓ don't move the caret);
  /// one for any key lets typing through.
  KeyEventResult onKey(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final String key = keyTriggerLabel(event.logicalKey);
    final List<Reaction> reactions = [
      for (final Reaction reaction in widget.node.reactions)
        if (reaction.trigger.type == TriggerType.keyDown &&
            reaction.action.enabled &&
            (reaction.trigger.key == null ||
                reaction.trigger.key!.isEmpty ||
                normalizeKeyLabel(reaction.trigger.key!) ==
                    normalizeKeyLabel(key)))
          reaction,
    ];
    if (reactions.isEmpty) return KeyEventResult.ignored;
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    FunctionsRepository.triggerAction(
      context,
      TriggerType.keyDown,
      reactions: reactions,
      value: controller.text,
      result: {
        'key': key,
        'shift': keyboard.isShiftPressed,
        'alt': keyboard.isAltPressed,
        'meta': keyboard.isMetaPressed || keyboard.isControlPressed,
      },
    );
    return reactions.any((r) => r.trigger.key?.isNotEmpty ?? false)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  void _rememberSelection() {
    if (focusNode.hasFocus && controller.selection.isValid) {
      _lastSelection = controller.selection;
    }
  }

  /// The field's text with the selection to edit at: the current one while
  /// focused, else the one it had when it last had focus.
  TextEditingValue get _editingValue {
    final TextSelection? last = _lastSelection;
    final TextSelection selection =
        !focusNode.hasFocus &&
            last != null &&
            last.end <= controller.text.length
        ? last
        : controller.selection;
    return controller.value.copyWith(
      selection: selection,
      composing: TextRange.empty,
    );
  }

  @override
  bool editText(
    EditTextOperation operation, {
    String text = '',
    String before = '',
    String? after,
    bool numbered = false,
  }) {
    if (!mounted) return false;
    final TextEditingValue current = _editingValue;
    final TextEditingValue? next = TextEdits.apply(
      current,
      operation,
      text: text,
      before: before,
      after: after,
      numbered: numbered,
    );
    if (next != null) _setValue(next);
    if (operation != EditTextOperation.clear &&
        operation != EditTextOperation.setText) {
      _focusKeeping(next?.selection ?? TextEdits.selectionOf(current));
    }
    return true;
  }

  /// Shows [value] and, when its text differs, updates the bound variable
  /// and runs the Changed reactions, as typing does.
  void _setValue(TextEditingValue value) {
    final bool changed = value.text != controller.text;
    controller.value = value;
    if (value.selection.isValid) _lastSelection = value.selection;
    if (changed) widget.onChanged?.call(context, value.text);
  }

  /// Focuses the field with [selection]. A one-line field selects all when
  /// it gains focus on the web and desktop, so the selection is put back
  /// once the focus has moved.
  void _focusKeeping(TextSelection selection) {
    if (focusNode.hasFocus) return;
    focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || controller.selection == selection) return;
      if (selection.end <= controller.text.length) {
        controller.selection = selection;
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Runs the field's Key Down reactions for [event], before the field's own
  /// editing keys. A reaction for a specific key (or combination) whose
  /// `when` holds takes the key; others let it through. Enter that no
  /// reaction took continues a Markdown list.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || isModifierKey(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    final List<Reaction> reactions = [
      for (final Reaction reaction in widget.node.reactions)
        if (reaction.trigger.type == TriggerType.keyDown &&
            reaction.action.enabled)
          reaction,
    ];
    if (reactions.isNotEmpty && widget.onKeyDown != null) {
      final ScopedValues scopedValues = ScopedValues.of(context);
      final List<Reaction> matched = [
        for (final Reaction reaction in reactions)
          if (keyTriggerMatches(reaction.trigger, event.logicalKey) &&
              triggerWhenHolds(reaction.trigger, scopedValues))
            reaction,
      ];
      if (matched.isNotEmpty) {
        widget.onKeyDown!(context, matched, {
          ...TextEdits.resultOf(controller.value),
          ...keyTriggerResult(event.logicalKey),
        });
        if (matched.any((reaction) => reaction.trigger.keyCombo != null)) {
          return KeyEventResult.handled;
        }
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        controller.markdown != null &&
        widget.node.properties.maxLines != 1 &&
        !widget.node.properties.readOnly) {
      final HardwareKeyboard keyboard = HardwareKeyboard.instance;
      if (keyboard.isShiftPressed ||
          keyboard.isMetaPressed ||
          keyboard.isControlPressed ||
          keyboard.isAltPressed) {
        return KeyEventResult.ignored;
      }
      final TextEditingValue? next = TextEdits.continueList(controller.value);
      if (next != null) {
        _setValue(next);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final TextFieldNode node = widget.node;
    final TextFieldProperties properties = node.properties;

    final ScopedValues scopedValues = _scopedValues;
    // Colour bindings read the canvas's defaults on a design canvas.
    final ScopedValues styleScope = widget.scopedValues ?? scopedValues;
    final Color? inputColor = PassiveTextFieldWidget.boundColor(
      node,
      PassiveTextFieldWidget.inputColor,
      styleScope,
    );
    final Color? cursorColor = PassiveTextFieldWidget.boundColor(
      node,
      PassiveTextFieldWidget.cursorColor,
      styleScope,
    );
    final bool upperCase =
        properties.textCapitalization == TextCapitalizationC.characters;

    // Resolve variable bindings as well as values set by actions.
    bool flag(String property, bool fallback) =>
        context.getNodeValue(node.id, property) ??
        PropertyValueDelegate.getPropertyValue<bool>(
          node,
          property,
          scopedValues: scopedValues,
        ) ??
        fallback;
    final bool enabled = flag('enabled', properties.enabled);
    final bool obscureText = flag('obscureText', properties.obscureText);
    final bool readOnly = flag('readOnly', properties.readOnly);
    final bool showCursor =
        context.getNodeValue(node.id, 'showCursor') ?? properties.showCursor;
    final int? maxLength =
        context.getNodeValue(node.id, 'maxLength') ?? properties.maxLength;

    final TextInputType keyboardType =
        properties.keyboardType == TextInputTypeEnum.number
        ? TextInputType.numberWithOptions(
            decimal: properties.showDecimalKey,
            signed: properties.showSignKey,
          )
        : properties.keyboardType.toFlutter();

    final TextInputValidatorModel validatorModel = properties.validator;
    final FormFieldValidator<String> validator =
        widget.validator ?? validatorModel.validate;

    final bool autofocus =
        !widget.settings.isPreview &&
        (widget.autofocus ?? properties.autoFocus);

    // Keep a one-line field one line even when it fills a fixed height.
    final bool fillsHeight = !widget.node.isVerticalWrap;
    final bool oneLine =
        properties.maxLines == 1 && (properties.minLines ?? 1) <= 1;
    final bool obscure = obscureText && oneLine;
    final bool expands = fillsHeight && !oneLine;
    final (int? maxLines, int? minLines) = resolveTextFieldLines(
      maxLines: properties.maxLines,
      minLines: properties.minLines,
      expands: expands,
    );
    final InputDecoration decoration = getDecoration(
      context,
      node,
      properties.decoration,
      widget.settings,
      scopedValues,
    );

    Widget buildField(InputDecoration decoration) => TextFormField(
      focusNode: focusNode,
      autocorrect: properties.autoCorrect,
      autofocus: autofocus,
      enableInteractiveSelection: properties.enableInteractiveSelection,
      enabled: enabled,
      controller: controller,
      obscureText: obscure,
      textCapitalization: switch (node.properties.textCapitalization) {
        TextCapitalizationC.none => TextCapitalization.none,
        TextCapitalizationC.words => TextCapitalization.words,
        TextCapitalizationC.sentences => TextCapitalization.sentences,
        TextCapitalizationC.characters => TextCapitalization.characters,
      },
      readOnly: readOnly,
      showCursor: showCursor,
      keyboardType: keyboardType,
      textInputAction:
          widget.node.properties.textInputAction.flutterTextInputAction,
      selectionHeightStyle: properties.selectionHeightStyle.toFlutter(),
      selectionWidthStyle: properties.selectionWidthStyle.toFlutter(),
      textAlign: properties.textAlign.toFlutter(),
      textAlignVertical: properties.textAlignVertical.flutterTextAlignVertical,
      cursorColor:
          cursorColor ?? properties.cursorColor.toFlutterColor(opacity: 1),
      cursorHeight: properties.cursorHeight,
      cursorWidth: properties.cursorWidth,
      cursorRadius: Radius.circular(properties.cursorRadius),
      maxLength: maxLength,
      validator: validator,
      autovalidateMode:
          widget.autovalidateMode ??
          widget.node.properties.autovalidateMode.flutterAutovalidateMode,
      autofillHints:
          AutofillGroup.maybeOf(context) != null && !widget.settings.isPreview
          ? widget.node.properties.autofillHints.map((hint) => hint.code)
          : null,
      inputFormatters: [
        if (upperCase) const UpperCaseTextInputFormatter(),
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
        ?properties.formatter.toFlutterFormatter(
          resolve: (value) => PropertyValueDelegate.substituteVariables(
            value,
            nullSubstitutionMode: widget.settings.nullSubstitutionMode,
            scopedValues: widget.scopedValues ?? ScopedValues.of(context),
          ),
        ),
      ],
      maxLines: maxLines,
      minLines: minLines,
      expands: expands,
      obscuringCharacter: widget.node.properties.obscuringCharacter,
      style: TextUtils.retrieveTextStyleFromProp(
        widget.node.properties.inputStyle,
      ).copyWith(color: inputColor),
      onTap: () => widget.onTap?.call(context, controller.text),
      onChanged: (value) => widget.onChanged?.call(context, value),
      onEditingComplete: () {},
      // The keyboard's submit (Enter on a one-line field) runs the
      // "Submitted" actions; the field keeps its focus, as a form expects.
      onFieldSubmitted: (value) => widget.onSubmitted?.call(context, value),
      decoration: decoration,
    );

    // A field that hugs its width is measured by [IntrinsicWidth] below, so
    // it can't be sized by a layout builder.
    Widget field = fillsHeight && oneLine && !node.isHorizontalWrap
        ? IntrinsicSafeLayoutBuilder(
            builder: (context, constraints) {
              // A collapsed decoration has no box of its own to fill, so the
              // line would sit at the top: place it by the field's vertical
              // alignment instead.
              if (decoration.isCollapsed ?? false) {
                return Align(
                  alignment: Alignment(
                    -1,
                    properties.textAlignVertical.flutterTextAlignVertical.y,
                  ),
                  child: buildField(decoration),
                );
              }
              // The node's box sets the height here, so the theme's density
              // must not change it: desktop's compact density took 8 px off
              // the outline, leaving a strip of the box's background below
              // the border.
              if (!constraints.hasBoundedHeight) return buildField(decoration);
              return buildField(
                PassiveTextFieldWidget.alignedVertically(
                  context,
                  decoration.copyWith(
                    constraints: BoxConstraints.tightFor(
                      height: constraints.maxHeight,
                    ),
                    visualDensity: VisualDensity.standard,
                  ),
                  height: constraints.maxHeight,
                  inputStyle: TextUtils.retrieveTextStyleFromProp(
                    properties.inputStyle,
                  ),
                  alignment: properties.textAlignVertical,
                ),
              );
            },
          )
        : buildField(decoration);

    if (node.isHorizontalWrap) {
      field = IntrinsicWidth(child: field);
    }
    if (node.isVerticalWrap) {
      field = IntrinsicHeight(child: field);
    }

    if (node.reactions.any((r) => r.trigger.type == TriggerType.keyDown)) {
      field = Focus(onKeyEvent: onKey, skipTraversal: true, child: field);
    }

    // Always a DecoratedBox, empty without focus: a ring that came and went
    // as a wrapper would rebuild the field and drop its focus.
    // Both bindable: `focusRingWidth` (e.g. 0 while the input is invalid)
    // and `focusRingColor`.
    final double ring =
        (node.variables.containsKey('focusRingWidth')
                ? PropertyValueDelegate.getPropertyValue<num>(
                    node,
                    'focusRingWidth',
                    scopedValues: scopedValues,
                  )
                : null)
            ?.toDouble() ??
        properties.focusRingWidth;
    final Color ringColor =
        (node.variables.containsKey('focusRingColor')
            ? PropertyValueDelegate.getPropertyValue<ColorRGBA>(
                node,
                'focusRingColor',
                scopedValues: scopedValues,
              )?.toFlutterColor()
            : null) ??
        properties.focusRingColor.toFlutterColor();
    field = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _ringRadius(properties.decoration),
        boxShadow: [
          if (ring > 0 && focusNode.hasFocus)
            BoxShadow(color: ringColor, spreadRadius: ring),
        ],
      ),
      child: field,
    );

    field = AdaptiveNodeBox(node: node, child: field);

    return field;
  }

  /// The corner radius the focus ring follows: the field's focused border's,
  /// else its resting border's.
  BorderRadius _ringRadius(InputDecorationModel decoration) {
    for (final InputBorderModel? border in [
      decoration.focusedBorder,
      decoration.enabledBorder,
      decoration.border,
    ]) {
      if (border != null && border.borderType == BorderTypeEnum.outline) {
        return border.cornerRadius.borderRadius;
      }
    }
    return BorderRadius.zero;
  }

  /// A border color bound in the node's variables under [key]
  /// (`decoration.borderColor`, `decoration.focusedBorderColor`), e.g. red
  /// while the input is invalid: `${= error != '' ? '#FF5A5F' : '#E6E4F2'}`.
  Color? _boundBorderColor(String key, ScopedValues scopedValues) {
    if (!widget.node.variables.containsKey(key)) return null;
    return PropertyValueDelegate.getPropertyValue<ColorRGBA>(
      widget.node,
      key,
      scopedValues: scopedValues,
    )?.toFlutterColor();
  }

  InputDecoration getDecoration(
    BuildContext context,
    TextFieldNode node,
    InputDecorationModel decoration,
    WidgetBuildSettings settings,
    ScopedValues scopedValues,
  ) {
    final Color? borderColor = _boundBorderColor(
      'decoration.borderColor',
      scopedValues,
    );
    final Color? focusedBorderColor =
        _boundBorderColor('decoration.focusedBorderColor', scopedValues) ??
        borderColor;
    final bool isCollapsed =
        context.getNodeValue(node.id, 'isCollapsed') ?? decoration.isCollapsed;
    final bool isDense =
        context.getNodeValue(node.id, 'isDense') ?? decoration.isDense;
    final Widget? labelText = buildText(
      context,
      node,
      property: 'labelText',
      defaultValue: decoration.labelText,
      scopedValues: scopedValues,
      settings: settings,
      variablesOverrides: widget.variablesOverrides,
      color: decoration.labelStyle.fills.first.toFlutterColor(),
      fontSize: decoration.labelStyle.fontSize,
      letterSpacing: decoration.labelStyle.letterSpacing,
      lineHeight: decoration.labelStyle.lineHeight,
      fontName: decoration.labelStyle.fontName,
      textDecoration: decoration.labelStyle.textDecoration,
    );
    final String? hintText = getText(
      context,
      node,
      property: 'hintText',
      defaultValue: decoration.hintText,
      scopedValues: scopedValues,
      settings: settings,
    );
    final String? helperText = getText(
      context,
      node,
      property: 'helperText',
      defaultValue: decoration.helperText,
      scopedValues: scopedValues,
      settings: settings,
    );
    // The error text is worked out first: a template such as
    // `${= invalid ? 'Required' : ''}` that comes out empty (or blank) is
    // no error, so the field keeps its normal border and has no error row.
    // InputDecoration uses errorBorder/focusedErrorBorder only with an error.
    // The template is the errorText property, or a binding of it in the
    // node's variables; a set-value action's value wins over both.
    final String? errorTemplate =
        node.variables['errorText'] ?? decoration.errorText;
    final String? errorMessage = getText(
      context,
      node,
      property: 'errorText',
      defaultValue: errorTemplate,
      scopedValues: scopedValues,
      settings: settings,
    );
    final bool hasError =
        errorMessage != null && errorMessage.trim().isNotEmpty;
    // A true `error` binding shows the error borders without a message, for
    // forms that show their errors elsewhere.
    final bool errorFlag =
        PropertyValueDelegate.getPropertyValue<bool>(
          node,
          'error',
          scopedValues: scopedValues,
        ) ??
        false;
    final Widget? errorText = !hasError
        ? null
        : buildText(
            context,
            node,
            property: 'errorText',
            defaultValue: errorTemplate,
            scopedValues: scopedValues,
            settings: settings,
            variablesOverrides: widget.variablesOverrides,
            color: decoration.errorStyle.fills.first.toFlutterColor(),
            fontSize: decoration.errorStyle.fontSize,
            letterSpacing: decoration.errorStyle.letterSpacing,
            lineHeight: decoration.errorStyle.lineHeight,
            fontName: decoration.errorStyle.fontName,
            textDecoration: decoration.errorStyle.textDecoration,
          );
    final Widget? prefixText = buildText(
      context,
      node,
      property: 'prefixText',
      defaultValue: decoration.prefixText,
      scopedValues: scopedValues,
      settings: settings,
      variablesOverrides: widget.variablesOverrides,
      color: decoration.prefixStyle.fills.first.toFlutterColor(),
      fontSize: decoration.prefixStyle.fontSize,
      letterSpacing: decoration.prefixStyle.letterSpacing,
      lineHeight: decoration.prefixStyle.lineHeight,
      fontName: decoration.prefixStyle.fontName,
      textDecoration: decoration.prefixStyle.textDecoration,
    );
    final Widget? suffixText = buildText(
      context,
      node,
      property: 'suffixText',
      defaultValue: decoration.suffixText,
      scopedValues: scopedValues,
      settings: settings,
      variablesOverrides: widget.variablesOverrides,
      color: decoration.suffixStyle.fills.first.toFlutterColor(),
      fontSize: decoration.suffixStyle.fontSize,
      letterSpacing: decoration.suffixStyle.letterSpacing,
      lineHeight: decoration.suffixStyle.lineHeight,
      fontName: decoration.suffixStyle.fontName,
      textDecoration: decoration.suffixStyle.textDecoration,
    );
    // Units like "kWh" that show even before anything is typed: the texts
    // go in the icon slots, which Flutter always shows, instead of the
    // prefix/suffix, which it shows only once the field is focused or has
    // text.
    final bool alwaysAffixes = decoration.affixesAlwaysVisible;
    final Widget? prefixIconWidget =
        !decoration.prefixIcon.icon.show || decoration.prefixIcon.icon.isEmpty
        ? null
        : _ReactiveIcon(
            onTap: () => widget.onIconTap?.call(
              context,
              decoration.prefixIcon.reactions,
              controller.text,
            ),
            iconModel: decoration.prefixIcon,
            padding: decoration.prefixIconPadding?.flutterEdgeInsets,
          );
    final Widget? suffixIconWidget =
        !decoration.suffixIcon.icon.show || decoration.suffixIcon.icon.isEmpty
        ? null
        : _ReactiveIcon(
            onTap: () => widget.onIconTap?.call(
              context,
              decoration.suffixIcon.reactions,
              controller.text,
            ),
            iconModel: decoration.suffixIcon,
            padding: decoration.suffixIconPadding?.flutterEdgeInsets,
          );
    final Widget? counterText = buildText(
      context,
      node,
      property: 'counterText',
      defaultValue: decoration.counterText,
      scopedValues: scopedValues,
      settings: settings,
      variablesOverrides: widget.variablesOverrides,
      color: decoration.counterStyle.fills.first.toFlutterColor(),
      fontSize: decoration.counterStyle.fontSize,
      letterSpacing: decoration.counterStyle.letterSpacing,
      lineHeight: decoration.counterStyle.lineHeight,
      fontName: decoration.counterStyle.fontName,
      textDecoration: decoration.counterStyle.textDecoration,
    );

    return InputDecoration(
      icon: !decoration.icon.show || decoration.icon.isEmpty
          ? null
          : retrieveIconWidget(decoration.icon, null),
      label: labelText,
      floatingLabelStyle: TextUtils.retrieveTextStyleFromProp(
        decoration.floatingLabelStyle,
      ),
      helperText: helperText,
      helperStyle: TextUtils.retrieveTextStyleFromProp(decoration.helperStyle),
      helperMaxLines: decoration.helperMaxLines,
      hintText: hintText,
      hintStyle: TextUtils.retrieveTextStyleFromProp(decoration.hintStyle)
          .copyWith(
            color: PassiveTextFieldWidget.boundColor(
              node,
              PassiveTextFieldWidget.hintColor,
              widget.scopedValues ?? scopedValues,
            ),
          ),
      hintMaxLines: decoration.hintMaxLines,
      error: errorText,
      errorStyle: TextUtils.retrieveTextStyleFromProp(decoration.errorStyle),
      errorMaxLines: decoration.errorMaxLines,
      floatingLabelBehavior: decoration.floatingLabelBehavior.toFlutter(),
      isCollapsed: isCollapsed,
      isDense: isDense,
      // A design is the same on every platform, so desktop's compact
      // density (the default on desktop and the web) must not shrink a
      // field: it took 8 px off a field that hugs its height (a 44 px field
      // drew 36 on the web and on the editor's canvas), and from the
      // intrinsic height of a collapsed multi-line one.
      visualDensity: VisualDensity.standard,
      // The decoration's own content padding wins over the node's padding,
      // which defaults to 12 x 16 for text fields: zero makes a bare input.
      contentPadding: PassiveTextFieldWidget.paddingWithBorder(
        (decoration.contentPadding ?? node.padding).flutterEdgeInsets,
        decoration,
        error: hasError || errorFlag,
        focused: focusNode.hasFocus,
      ),
      prefixIcon: alwaysAffixes && prefixText != null
          ? _affix(prefixIconWidget, prefixText, before: true)
          : prefixIconWidget,
      // Unset constraints keep Flutter's 48 px icon slot (an always-visible
      // text with no icon takes only its own width).
      prefixIconConstraints: decoration.prefixIconConstraints.isEmpty
          ? (decoration.prefixIconPadding != null ||
                    (alwaysAffixes &&
                        prefixText != null &&
                        prefixIconWidget == null)
                ? const BoxConstraints()
                : null)
          : decoration.prefixIconConstraints.flutterConstraints,
      prefix: alwaysAffixes ? null : prefixText,
      prefixStyle: TextUtils.retrieveTextStyleFromProp(decoration.prefixStyle),
      suffixIcon: alwaysAffixes && suffixText != null
          ? _affix(suffixIconWidget, suffixText, before: false)
          : suffixIconWidget,
      suffix: alwaysAffixes ? null : suffixText,
      suffixStyle: TextUtils.retrieveTextStyleFromProp(decoration.suffixStyle),
      // Unset constraints keep Flutter's 48 px icon slot.
      // With a padding of its own the icon sits at that inset, so unset
      // constraints drop the 48 px minimum instead of centring it in one.
      suffixIconConstraints: decoration.suffixIconConstraints.isEmpty
          ? (decoration.suffixIconPadding != null ||
                    (alwaysAffixes &&
                        suffixText != null &&
                        suffixIconWidget == null)
                ? const BoxConstraints()
                : null)
          : decoration.suffixIconConstraints.flutterConstraints,
      counter: decoration.showCounter
          ? decoration.counterText?.isNotEmpty == true
                ? counterText
                : null
          : null,
      counterText: decoration.showCounter ? null : '',
      // counterText: decoration.showCounter
      //     ? decoration.counterText?.isNotEmpty == true
      //         ? decoration.counterText
      //         : null
      //     : '',
      counterStyle: TextUtils.retrieveTextStyleFromProp(
        decoration.counterStyle,
      ),
      filled: decoration.filled,
      fillColor: decoration.fillColor.toFlutterColor(),
      focusColor: decoration.focusColor.toFlutterColor(),
      hoverColor: decoration.hoverColor.toFlutterColor(),
      errorBorder: getInputBorder(decoration.errorBorder),
      // An error (flag or message) wins over bound border colours: a field
      // in error stays red when focused.
      focusedBorder: getInputBorder(
        errorFlag && !hasError
            ? decoration.focusedErrorBorder
            : decoration.focusedBorder,
        color: errorFlag || hasError ? null : focusedBorderColor,
      ),
      focusedErrorBorder: getInputBorder(decoration.focusedErrorBorder),
      disabledBorder: getInputBorder(decoration.disabledBorder),
      enabledBorder: getInputBorder(
        errorFlag && !hasError
            ? decoration.errorBorder
            : decoration.enabledBorder,
        color: errorFlag || hasError ? null : borderColor,
      ),
      border: getInputBorder(decoration.border, color: borderColor),
      enabled: decoration.enabled,
      semanticCounterText: decoration.semanticCounterText,
      alignLabelWithHint: decoration.alignLabelWithHint,
      constraints: decoration.constraints.flutterConstraints,
    );
  }

  /// [inputBorder] as a Flutter border, its line in [color] when given (a
  /// bound border color).
  InputBorder? getInputBorder(InputBorderModel? inputBorder, {Color? color}) {
    if (inputBorder == null) return null;
    BorderSide side() {
      final BorderSide base = inputBorder.borderSide.toFlutter();
      return color == null ? base : base.copyWith(color: color);
    }

    switch (inputBorder.borderType) {
      case BorderTypeEnum.none:
        return InputBorder.none;
      case BorderTypeEnum.outline:
        return OutlineInputBorder(
          borderRadius: inputBorder.cornerRadius.borderRadius,
          borderSide: side(),
          gapPadding: inputBorder.gapPadding,
        );
      case BorderTypeEnum.underline:
        return UnderlineInputBorder(
          borderRadius: inputBorder.cornerRadius.borderRadius,
          borderSide: side(),
        );
    }
  }

  String? getText(
    BuildContext context,
    BaseNode node, {
    required String property,
    required String? defaultValue,
    required ScopedValues scopedValues,
    required WidgetBuildSettings settings,
  }) {
    // A value set at runtime wins, then a binding of the property in the
    // node's variables (e.g. a hint that follows a form's mode), then the
    // design's own text.
    final String? value =
        context.getNodeValue(node.id, property) ??
        node.variables[property] ??
        defaultValue;
    if (value == null || value.isEmpty) return null;
    final newValue = PropertyValueDelegate.substituteVariables(
      value,
      scopedValues: scopedValues,
      nullSubstitutionMode: settings.nullSubstitutionMode,
    );
    if (newValue.isEmpty) return null;
    return newValue;
  }

  Widget? buildText(
    BuildContext context,
    BaseNode node, {
    required List<VariableData> variablesOverrides,
    required String property,
    required String? defaultValue,
    required ScopedValues scopedValues,
    required WidgetBuildSettings settings,
    Color? color,
    double? fontSize,
    LetterSpacing? letterSpacing,
    LineHeight? lineHeight,
    FontName? fontName,
    TextDecorationEnum? textDecoration,
    List<Effect>? effects,
    TextAlignHorizontalEnum? textAlignHorizontal,
    int? maxLines,
  }) {
    // A value set at runtime wins, then a binding of the property in the
    // node's variables (e.g. a hint that follows a form's mode), then the
    // design's own text.
    final String? value =
        context.getNodeValue(node.id, property) ??
        node.variables[property] ??
        defaultValue;
    if (value == null || value.isEmpty) return null;
    // A text that is only variables, like an error message from a formula,
    // shows nothing when they come out empty: an empty error text would
    // still put the field in its error state.
    if (!settings.replaceVariablesWithSymbols &&
        value.contains(r'${') &&
        PropertyValueDelegate.substituteVariables(
          value,
          scopedValues: scopedValues,
          nullSubstitutionMode: settings.nullSubstitutionMode,
        ).trim().isEmpty) {
      return null;
    }
    return TextUtils.buildText(
      context,
      value,
      node: node,
      variablesOverrides: variablesOverrides,
      nullSubstitutionMode: settings.nullSubstitutionMode,
      replaceVariablesWithSymbol: settings.replaceVariablesWithSymbols,
      color: color,
      fontSize: fontSize,
      letterSpacing: letterSpacing,
      lineHeight: lineHeight,
      fontName: fontName,
      textDecoration: textDecoration,
      effects: effects,
      textAlignHorizontal: textAlignHorizontal,
      maxLines: maxLines,
    );
  }
}

class _ReactiveIcon extends StatelessWidget {
  final VoidCallback onTap;
  final ReactiveIconModel iconModel;

  /// Space round the icon in its slot (the decoration's icon padding).
  final EdgeInsets? padding;

  const _ReactiveIcon({
    required this.onTap,
    required this.iconModel,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget icon = Align(
      widthFactor: 1,
      heightFactor: 1,
      child: retrieveIconWidget(iconModel.icon, null)!,
    );
    if (padding case final EdgeInsets padding) {
      icon = Padding(padding: padding, child: icon);
    }

    if (iconModel.reactions.isEmpty) return icon;

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: icon),
    );
  }
}

/// An always-visible prefix or suffix text, beside its icon if it has one,
/// for the icon slot of an [InputDecoration].
Widget _affix(Widget? icon, Widget text, {required bool before}) {
  final Widget padded = Padding(
    padding: before
        ? const EdgeInsetsDirectional.only(start: 12, end: 4)
        : const EdgeInsetsDirectional.only(start: 4, end: 12),
    child: text,
  );
  if (icon == null) return padded;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: before ? [icon, padded] : [padded, icon],
  );
}
