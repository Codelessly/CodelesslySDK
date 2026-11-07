// Widget recipes: inputs. See lib/src/render/recipe.dart.
//
// Inputs are islands: real Flutter widgets (TextField, Checkbox, Slider...)
// built from the node's props, inside the box SDK 8.x gave them: a fit box
// for the ones that size to their node's fits, the design size for the ones
// that always took it (checkbox, radio, slider, signature), nothing for the
// pickers (their button's own size).
//
// The widgets keep their own state (typed text, a toggled checkbox) and, in a
// running app, report it as the node's `changed` (and `submitted`,
// `changeEnd`, focus) trigger: the runtime writes the value to the variable
// the input's value is bound to and runs the node's reactions.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:codelessly_api_v2/codelessly_api.dart' as api;
import 'package:codelessly_api_v2/codelessly_api.dart'
    show
        CheckboxProps,
        DatePickerProps,
        DateTimeInputMode,
        DateTimeInputProps,
        DropdownProps,
        Node,
        RadioProps,
        SegmentedButtonProps,
        SignatureProps,
        SizeFit,
        SliderProps,
        SwitchProps,
        TextFieldProps,
        TimePickerProps;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../render/convert.dart';
import '../render/node_tree.dart' show fireTrigger;
import '../runtime/actions/text_fields.dart';
import '../render/paint/icon_glyph.dart';
import '../render/recipe.dart';
import 'inputs_shapes.dart';

/// Recipes for the inputs group, by node type.
final Map<String, WidgetRecipe> inputsRecipes = {
  'textField': (b, n, chain) => _fitted(b, n, chain, (context) => _TextFieldIsland(node: n, interactive: _interactive(b))),
  'checkbox': (b, n, chain) => _sized(b, n, chain, (context) => _CheckboxIsland(node: n)),
  'switch': (b, n, chain) => _fitted(b, n, chain, (context) => _SwitchIsland(node: n)),
  'radio': (b, n, chain) => _sized(b, n, chain, (context) => _RadioIsland(node: n)),
  'slider': (b, n, chain) => _sized(b, n, chain, (context) => _SliderIsland(node: n)),
  'dropdown': (b, n, chain) => _fitted(b, n, chain, (context) => _DropdownIsland(node: n)),
  'datePicker': (b, n, chain) => chain.add(_island(b, (context) => _DatePickerIsland(node: n, interactive: _interactive(b)))),
  'timePicker': (b, n, chain) => chain.add(_island(b, (context) => _TimePickerIsland(node: n, interactive: _interactive(b)))),
  'dateTimeInput': (b, n, chain) =>
      chain.add(_island(b, (context) => _DateTimeInputIsland(node: n, interactive: _interactive(b)))),
  'segmentedButton': _segmentedButton,
  'signature': (b, n, chain) => _sized(b, n, chain, (context) => _SignatureIsland(node: n)),
};

bool _interactive(NodeBuilder b) => b.tree.islands.environment.interactive;

Size _designSize(Node n) => Size(n.layout.width.value, n.layout.height.value);

/// The input island of [b]'s node: [build] under what reports its events.
RenderBox _island(NodeBuilder b, WidgetBuilder build) =>
    b.island('input', (context) => _InputEvents(builder: b, child: build(context)));

/// Reports an input's events to its node's reactions ([fireTrigger]).
class _InputEvents extends StatelessWidget {
  const _InputEvents({required this.builder, required this.child});
  final NodeBuilder builder;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// The node builder of the input island [context] is in.
NodeBuilder? _builderOf(BuildContext context) => context.findAncestorWidgetOfExactType<_InputEvents>()?.builder;

/// Reports [trigger] of the input [context] is in, with its new [value].
void _fire(BuildContext context, String trigger, Object? value) {
  final b = _builderOf(context);
  if (b != null) fireTrigger(b, trigger, event: {'value': value});
}

/// The node's fit box (SDK 8.x's `AdaptiveNodeBox`) around [build].
void _fitted(NodeBuilder b, Node n, List<RenderBox> chain, WidgetBuilder build) {
  chain.add(b.fitBox('fit', n.layout.width.fit, n.layout.height.fit, _designSize(n)));
  chain.add(_island(b, build));
}

/// The node's design size (SDK 8.x's `SizedBox`, whatever its fits) around
/// [build].
void _sized(NodeBuilder b, Node n, List<RenderBox> chain, WidgetBuilder build) {
  final c = BoxConstraints.tight(_designSize(n));
  chain.add(b.obtain<RenderConstrainedBox>('sized', () => RenderConstrainedBox(additionalConstraints: c))
    ..additionalConstraints = c);
  chain.add(_island(b, build));
}

void _segmentedButton(NodeBuilder b, Node n, List<RenderBox> chain) {
  // SegmentedButton needs a segment: without one, only its box.
  if (n.prop(SegmentedButtonProps.segments).isEmpty) {
    chain.add(b.fitBox('fit', n.layout.width.fit, n.layout.height.fit, _designSize(n)));
    return;
  }
  _fitted(b, n, chain, (context) => _SegmentedButtonIsland(node: n));
}

// --- shared -------------------------------------------------------------------

/// [s] as Flutter's style, or null when unset (the theme's).
TextStyle? _styleOrNull(api.TextStyle s) => s.isEmpty ? null : textStyle(s);

/// [text] in [style], as SDK 8.x built a decoration's texts (a span in a
/// `Text.rich`).
Widget _text(String text, api.TextStyle style, {TextAlign? textAlign, int? maxLines, TextOverflow? overflow}) =>
    Text.rich(TextSpan(children: [TextSpan(text: text, style: _styleOrNull(style))]),
        textAlign: textAlign, maxLines: maxLines, overflow: overflow);

/// An input's icon: its glyph (or image) in a square of its size.
Widget? _icon(api.InputIcon? icon, {double? size, Color? color}) {
  if (icon == null || icon.icon.isEmpty || icon.icon['show'] == false) return null;
  final dimension = size ?? icon.size;
  final tint = icon.color?.flutter ?? color;
  final image = icon.icon['image'];
  if (image is String && image.isNotEmpty) {
    return SizedBox.square(
      dimension: dimension,
      child: Image.network(image,
          color: tint == null || tint.a == 0 ? null : tint,
          errorBuilder: (context, error, stack) => SizedBox.square(dimension: dimension)),
    );
  }
  return SizedBox.square(dimension: dimension, child: _Glyph(icon: icon.icon, color: tint));
}

/// A font icon's glyph filling its box, in [color] (else the icon theme's).
class _Glyph extends LeafRenderObjectWidget {
  const _Glyph({required this.icon, this.color});
  final api.Json icon;
  final Color? color;

  Color _color(BuildContext context) =>
      color ?? IconTheme.of(context).color ?? (Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white);

  @override
  RenderIconGlyph createRenderObject(BuildContext context) => RenderIconGlyph()
    ..icon = icon
    ..color = _color(context);

  @override
  void updateRenderObject(BuildContext context, RenderIconGlyph renderObject) => renderObject
    ..icon = icon
    ..color = _color(context);
}

BorderSide _side(api.BorderSide s) => BorderSide(
      color: s.color?.flutter ?? const Color(0xFF000000),
      width: s.width,
      style: s.style == api.BorderStyle.none ? BorderStyle.none : BorderStyle.solid,
      strokeAlign: s.strokeAlign.value,
    );

InputBorder? _inputBorder(api.InputBorder? b, {Color? color}) {
  if (b == null) return null;
  var side = _side(b.borderSide);
  if (color != null) side = side.copyWith(color: color);
  return switch (b.type) {
    api.InputBorderType.none => InputBorder.none,
    api.InputBorderType.outline =>
      OutlineInputBorder(borderRadius: b.borderRadius.flutter, borderSide: side, gapPadding: b.gapPadding),
    api.InputBorderType.underline => UnderlineInputBorder(borderRadius: b.borderRadius.flutter, borderSide: side),
  };
}

BoxConstraints? _constraintsOrNull(api.BoxConstraints c) => c.isEmpty ? null : c.flutter;

Color? _color(api.Color? c) => c?.flutter;

// --- textField ----------------------------------------------------------------

/// [text] as a design canvas shows it before bindings run: its formulas
/// (`${= ...}`) come out empty, its variables (`${name}`) stay as written; an
/// empty or blank result is no text.
String? previewText(String? text) {
  if (text == null || text.isEmpty) return null;
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
  return s.trim().isEmpty ? null : s;
}

/// [padding] grown by the width of the border [d] draws in this state when
/// it has `paddingIncludesBorder` (an outline on every side, an underline
/// below): disabled, then error (focused or not), then focused, then enabled
/// (SDK 8.x's `PassiveTextFieldWidget.paddingWithBorder`).
EdgeInsets paddingWithBorder(EdgeInsets padding, api.InputDecoration d, {bool error = false, bool focused = false}) {
  if (!d.paddingIncludesBorder) return padding;
  final border = !d.enabled
      ? d.disabledBorder
      : error
          ? (focused ? d.focusedErrorBorder : d.errorBorder)
          : focused
              ? d.focusedBorder
              : d.enabledBorder;
  if (border == null || border.type == api.InputBorderType.none) return padding;
  final w = border.borderSide.width;
  if (w <= 0) return padding;
  if (border.type == api.InputBorderType.underline) return padding.copyWith(bottom: padding.bottom + w);
  return padding + EdgeInsets.all(w);
}

/// An always-visible prefix or suffix text, beside its icon if it has one,
/// for an icon slot (SDK 8.x's `_affix`).
Widget _affix(Widget? icon, Widget text, {required bool before}) {
  final padded = Padding(
    padding: before
        ? const EdgeInsetsDirectional.only(start: 12, end: 4)
        : const EdgeInsetsDirectional.only(start: 4, end: 12),
    child: text,
  );
  if (icon == null) return padded;
  return Row(mainAxisSize: MainAxisSize.min, children: before ? [icon, padded] : [padded, icon]);
}

/// A text field's decoration; [padding] is the node's, the content padding
/// when the decoration sets none. [focused] and [error] pick the border a
/// padding that includes it grows by.
InputDecoration inputDecoration(api.InputDecoration d, api.EdgeInsets padding,
    {bool focused = false, bool? error}) {
  Widget? affixIcon(api.InputIcon? icon, api.EdgeInsets? iconPadding) {
    final glyph = _icon(icon);
    if (glyph == null) return null;
    final Widget aligned = Align(widthFactor: 1, heightFactor: 1, child: glyph);
    return iconPadding == null ? aligned : Padding(padding: iconPadding.flutter, child: aligned);
  }

  final label = previewText(d.labelText), errorText = previewText(d.errorText);
  final prefix = previewText(d.prefixText), suffix = previewText(d.suffixText);
  final counter = d.counterText == '' ? '' : previewText(d.counterText);
  // Units that show before anything is typed go in the icon slots, which
  // Flutter always shows.
  final always = d.affixesAlwaysVisible;
  final prefixWidget = prefix == null || prefix.isEmpty ? null : _text(prefix, d.prefixStyle);
  final suffixWidget = suffix == null || suffix.isEmpty ? null : _text(suffix, d.suffixStyle);
  final prefixIcon = affixIcon(d.prefixIcon, d.prefixIconPadding);
  final suffixIcon = affixIcon(d.suffixIcon, d.suffixIconPadding);
  // Unset constraints keep Flutter's 48 px icon slot, unless the icon has a
  // padding of its own or the slot holds only an always-visible text.
  BoxConstraints? iconConstraints(api.BoxConstraints c, api.EdgeInsets? iconPadding, Widget? text, Widget? icon) =>
      !c.isEmpty
          ? c.flutter
          : iconPadding != null || (always && text != null && icon == null)
              ? const BoxConstraints()
              : null;
  return InputDecoration(
    icon: _icon(d.icon),
    label: label == null || label.isEmpty ? null : _text(label, d.labelStyle),
    floatingLabelStyle: _styleOrNull(d.floatingLabelStyle),
    helperText: previewText(d.helperText),
    helperStyle: _styleOrNull(d.helperStyle),
    helperMaxLines: d.helperMaxLines,
    hintText: previewText(d.hintText),
    hintStyle: _styleOrNull(d.hintStyle),
    hintMaxLines: d.hintMaxLines,
    error: errorText == null || errorText.trim().isEmpty ? null : _text(errorText, d.errorStyle),
    errorStyle: _styleOrNull(d.errorStyle),
    errorMaxLines: d.errorMaxLines,
    floatingLabelBehavior: switch (d.floatingLabelBehavior) {
      null => null,
      final b => FloatingLabelBehavior.values.byName(b.name),
    },
    isCollapsed: d.isCollapsed,
    isDense: d.isDense,
    // A collapsed decoration is the bare input: a compact density must not
    // shrink its intrinsic height.
    visualDensity: d.isCollapsed ? VisualDensity.standard : null,
    contentPadding: paddingWithBorder((d.contentPadding ?? padding).flutter, d,
        error: error ?? (errorText != null && errorText.trim().isNotEmpty), focused: focused),
    prefixIcon: always && prefixWidget != null ? _affix(prefixIcon, prefixWidget, before: true) : prefixIcon,
    prefixIconConstraints: iconConstraints(d.prefixIconConstraints, d.prefixIconPadding, prefixWidget, prefixIcon),
    prefix: always ? null : prefixWidget,
    prefixStyle: _styleOrNull(d.prefixStyle),
    suffixIcon: always && suffixWidget != null ? _affix(suffixIcon, suffixWidget, before: false) : suffixIcon,
    suffixIconConstraints: iconConstraints(d.suffixIconConstraints, d.suffixIconPadding, suffixWidget, suffixIcon),
    suffix: always ? null : suffixWidget,
    suffixStyle: _styleOrNull(d.suffixStyle),
    counter: counter == null || counter.isEmpty ? null : _text(counter, d.counterStyle),
    counterText: counter != null && counter.isEmpty ? '' : null,
    counterStyle: _styleOrNull(d.counterStyle),
    filled: d.filled,
    fillColor: _color(d.fillColor),
    focusColor: _color(d.focusColor),
    hoverColor: _color(d.hoverColor),
    errorBorder: _inputBorder(d.errorBorder),
    focusedBorder: _inputBorder(d.focusedBorder),
    focusedErrorBorder: _inputBorder(d.focusedErrorBorder),
    disabledBorder: _inputBorder(d.disabledBorder),
    enabledBorder: _inputBorder(d.enabledBorder),
    border: _inputBorder(d.border),
    enabled: d.enabled,
    semanticCounterText: d.semanticCounterText,
    alignLabelWithHint: d.alignLabelWithHint,
    constraints: _constraintsOrNull(d.constraints),
  );
}

TextInputType _keyboardType(Node n) => switch (n.prop(TextFieldProps.keyboardType)) {
      api.TextInputType.number => TextInputType.numberWithOptions(
          decimal: n.prop(TextFieldProps.keyboardDecimal), signed: n.prop(TextFieldProps.keyboardSigned)),
      api.TextInputType.text => TextInputType.text,
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

/// A text field's line limits as [TextField] accepts them: none when it
/// expands; a limit below 1 is none; min lines above max lines raise max.
(int?, int?) textFieldLines({required int? maxLines, required int? minLines, bool expands = false}) {
  if (expands) return (null, null);
  var max = maxLines != null && maxLines >= 1 ? maxLines : null;
  final min = minLines != null && minLines >= 1 ? minLines : null;
  if (max != null && min != null && min > max) max = min;
  return (max, min);
}

/// The input formatter [f] describes: a regex filter
/// (`{"type": "regex", "pattern", "allow", "caseSensitive", ...}`). Currency
/// formatting needs the runtime's formulas.
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
  return FilteringTextInputFormatter(re,
      allow: f['allow'] != false, replacementString: api.readString(f['replacementString']) ?? '');
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

class _TextFieldIsland extends StatefulWidget {
  const _TextFieldIsland({required this.node, required this.interactive});
  final Node node;
  final bool interactive;

  @override
  State<_TextFieldIsland> createState() => _TextFieldIslandState();
}

class _TextFieldIslandState extends State<_TextFieldIsland> {
  late final TextEditingController controller = TextEditingController(text: widget.node.prop(TextFieldProps.initialValue));
  late final FocusNode focusNode = FocusNode()..addListener(_focusChanged);

  @override
  void didUpdateWidget(covariant _TextFieldIsland oldWidget) {
    super.didUpdateWidget(oldWidget);
    final initial = widget.node.prop(TextFieldProps.initialValue);
    if (initial != oldWidget.node.prop(TextFieldProps.initialValue) && controller.text != initial) {
      controller.text = initial;
    }
  }

  NodeBuilder? _builder;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final b = _builderOf(context);
    if (!identical(b, _builder)) {
      if (_builder != null) TextFieldHandle.unregister(_builder!, controller);
      _builder = b;
      if (b != null) TextFieldHandle.register(b, TextFieldHandle(controller, focusNode));
    }
  }

  void _focusChanged() {
    final n = widget.node;
    if (mounted) _fire(context, focusNode.hasFocus ? 'focusGained' : 'focusLost', controller.text);
    if (!focusNode.hasFocus && _edited && mounted) {
      _edited = false;
      _fire(context, 'editingComplete', controller.text);
    }
    // The focus ring follows focus, and so does a padding that includes the
    // (focused) border.
    if (n.prop(TextFieldProps.focusRingWidth) > 0 || n.prop(TextFieldProps.decoration).paddingIncludesBorder) {
      setState(() {});
    }
    if (focusNode.hasFocus && n.prop(TextFieldProps.selectAllOnFocus)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !focusNode.hasFocus) return;
        controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
      });
    }
  }

  bool _edited = false;

  @override
  void dispose() {
    if (_builder != null) TextFieldHandle.unregister(_builder!, controller);
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final hFit = n.layout.width.fit, vFit = n.layout.height.fit;
    final d = n.prop(TextFieldProps.decoration);
    final maxLinesProp = n.prop(TextFieldProps.maxLines);
    final minLinesProp = n.prop(TextFieldProps.minLines);
    // A one-line field stays one line even when it fills a fixed height; a
    // multi-line one that doesn't hug its height expands into it.
    final fillsHeight = vFit != SizeFit.hug;
    final oneLine = maxLinesProp == 1 && (minLinesProp ?? 1) <= 1;
    final expands = fillsHeight && !oneLine;
    final (maxLines, minLines) =
        textFieldLines(maxLines: maxLinesProp == 0 ? null : maxLinesProp, minLines: minLinesProp, expands: expands);
    final decoration = inputDecoration(d, n.layout.padding, focused: focusNode.hasFocus);
    final maxLength = n.prop(TextFieldProps.maxLength);
    final style = _styleOrNull(n.prop(TextFieldProps.style));
    final cursorRadius = n.prop(TextFieldProps.cursorRadius);

    Widget field(InputDecoration decoration) => TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: decoration,
          style: style,
          textAlign: switch (n.prop(TextFieldProps.textAlign)) {
            api.TextAlign.start => TextAlign.left,
            final a => textAlign(a),
          },
          textAlignVertical: switch (n.prop(TextFieldProps.textAlignVertical)) {
            null => null,
            api.TextAlignVertical.top => TextAlignVertical.top,
            api.TextAlignVertical.center => TextAlignVertical.center,
            api.TextAlignVertical.bottom => TextAlignVertical.bottom,
          },
          keyboardType: _keyboardType(n),
          textInputAction: switch (n.prop(TextFieldProps.textInputAction)) {
            null => null,
            final a => TextInputAction.values.byName(a.name),
          },
          textCapitalization: TextCapitalization.values.byName(n.prop(TextFieldProps.textCapitalization).name),
          autocorrect: n.prop(TextFieldProps.autocorrect),
          autofocus: widget.interactive && n.prop(TextFieldProps.autofocus),
          enableInteractiveSelection: n.prop(TextFieldProps.enableInteractiveSelection),
          enabled: n.prop(TextFieldProps.enabled),
          obscureText: n.prop(TextFieldProps.obscureText) && oneLine,
          obscuringCharacter: n.prop(TextFieldProps.obscuringCharacter).isEmpty ? '•' : n.prop(TextFieldProps.obscuringCharacter),
          readOnly: n.prop(TextFieldProps.readOnly),
          onChanged: (v) {
            _edited = true;
            _fire(context, 'changed', v);
          },
          onSubmitted: (v) => _fire(context, 'submitted', v),
          showCursor: n.prop(TextFieldProps.showCursor),
          cursorColor: _color(n.prop(TextFieldProps.cursorColor)),
          cursorHeight: n.prop(TextFieldProps.cursorHeight),
          cursorWidth: n.prop(TextFieldProps.cursorWidth),
          cursorRadius: cursorRadius == null ? null : Radius.circular(cursorRadius),
          maxLength: maxLength,
          maxLines: maxLines,
          minLines: minLines,
          expands: expands,
          selectionHeightStyle: ui.BoxHeightStyle.values.byName(n.prop(TextFieldProps.selectionHeightStyle).name),
          selectionWidthStyle: ui.BoxWidthStyle.values.byName(n.prop(TextFieldProps.selectionWidthStyle).name),
          autofillHints: widget.interactive && AutofillGroup.maybeOf(context) != null
              ? n.prop(TextFieldProps.autofillHints)
              : null,
          inputFormatters: [
            if (n.prop(TextFieldProps.textCapitalization) == api.TextCapitalization.characters) const _UpperCaseFormatter(),
            if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
            ?_formatter(n.prop(TextFieldProps.inputFormatter)),
          ],
        );

    // A one-line field filling its height takes that height as its
    // decoration's (a collapsed one, which has no box, is aligned instead).
    // A field that hugs its width is measured, so isn't built by layout.
    Widget result = fillsHeight && oneLine && hFit != SizeFit.hug
        ? IntrinsicSafeLayoutBuilder(builder: (context, constraints) {
            if (d.isCollapsed) {
              final y = switch (n.prop(TextFieldProps.textAlignVertical)) {
                api.TextAlignVertical.top => -1.0,
                api.TextAlignVertical.bottom => 1.0,
                api.TextAlignVertical.center => 0.0,
                null => -1.0,
              };
              return Align(alignment: Alignment(-1, y), child: field(decoration));
            }
            return field(constraints.hasBoundedHeight
                ? decoration.copyWith(constraints: BoxConstraints.tightFor(height: constraints.maxHeight))
                : decoration);
          })
        : field(decoration);
    if (hFit == SizeFit.hug) result = IntrinsicWidth(child: result);
    if (vFit == SizeFit.hug) result = IntrinsicHeight(child: result);

    // Always a DecoratedBox, empty without focus: a ring that came and went
    // as a wrapper would rebuild the field and drop its focus.
    final ring = n.prop(TextFieldProps.focusRingWidth);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _ringRadius(d),
        boxShadow: [
          if (ring > 0 && focusNode.hasFocus)
            BoxShadow(color: _color(n.prop(TextFieldProps.focusRingColor)) ?? Colors.transparent, spreadRadius: ring),
        ],
      ),
      child: result,
    );
  }

  /// The focused border's corners, else the resting border's.
  static BorderRadius _ringRadius(api.InputDecoration d) {
    for (final b in [d.focusedBorder, d.enabledBorder, d.border]) {
      if (b != null && b.type == api.InputBorderType.outline) return b.borderRadius.flutter;
    }
    return BorderRadius.zero;
  }
}

/// A [LayoutBuilder] that reports a zero intrinsic size instead of throwing,
/// so a field built with it can sit under intrinsic measurement.
class IntrinsicSafeLayoutBuilder extends ConstrainedLayoutBuilder<BoxConstraints> {
  const IntrinsicSafeLayoutBuilder({super.key, required super.builder});

  @override
  RenderAbstractLayoutBuilderMixin<BoxConstraints, RenderBox> createRenderObject(BuildContext context) =>
      _RenderIntrinsicSafeLayoutBuilder();
}

class _RenderIntrinsicSafeLayoutBuilder extends RenderBox
    with
        RenderObjectWithChildMixin<RenderBox>,
        RenderObjectWithLayoutCallbackMixin,
        RenderAbstractLayoutBuilderMixin<BoxConstraints, RenderBox> {
  @override
  double computeMinIntrinsicWidth(double height) => 0;
  @override
  double computeMaxIntrinsicWidth(double height) => 0;
  @override
  double computeMinIntrinsicHeight(double width) => 0;
  @override
  double computeMaxIntrinsicHeight(double width) => 0;
  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.smallest;
  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) => null;

  @override
  void performLayout() {
    runLayoutCallback();
    final child = this.child;
    if (child != null) {
      child.layout(constraints, parentUsesSize: true);
      size = constraints.constrain(child.size);
    } else {
      size = constraints.biggest;
    }
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      child?.getDistanceToActualBaseline(baseline) ?? super.computeDistanceToActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      child?.hitTest(result, position: position) ?? false;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) context.paintChild(child!, offset);
  }
}

// --- checkbox, switch, radio --------------------------------------------------

/// Flutter's own sizes the toggles are scaled from.
const double _checkboxSize = 40, _switchWidth = 59, _radioSize = 32;

class _CheckboxIsland extends StatefulWidget {
  const _CheckboxIsland({required this.node});
  final Node node;

  @override
  State<_CheckboxIsland> createState() => _CheckboxIslandState();
}

class _CheckboxIslandState extends State<_CheckboxIsland> {
  late bool? value = widget.node.prop(CheckboxProps.value);

  @override
  void didUpdateWidget(covariant _CheckboxIsland oldWidget) {
    super.didUpdateWidget(oldWidget);
    final v = widget.node.prop(CheckboxProps.value);
    if (v != oldWidget.node.prop(CheckboxProps.value)) value = v;
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final tristate = n.prop(CheckboxProps.tristate);
    final radius = n.prop(CheckboxProps.borderRadius);
    final side = n.prop(CheckboxProps.side);
    return Transform.scale(
      scale: n.layout.width.value / (n.prop(CheckboxProps.compact) ? Checkbox.width : _checkboxSize),
      child: Checkbox(
        value: tristate ? value : (value ?? false),
        tristate: tristate,
        autofocus: n.prop(CheckboxProps.autofocus),
        checkColor: _color(n.prop(CheckboxProps.checkColor)),
        activeColor: _color(n.prop(CheckboxProps.activeColor)),
        hoverColor: _color(n.prop(CheckboxProps.hoverColor)),
        focusColor: _color(n.prop(CheckboxProps.focusColor)),
        splashRadius: n.prop(CheckboxProps.splashRadius),
        visualDensity: VisualDensity.standard,
        shape: radius == null ? null : RoundedRectangleBorder(borderRadius: radius.flutter),
        side: side == null ? null : _side(side),
        onChanged: (v) {
          setState(() => value = v);
          _fire(context, 'changed', v);
        },
      ),
    );
  }
}

class _SwitchIsland extends StatefulWidget {
  const _SwitchIsland({required this.node});
  final Node node;

  @override
  State<_SwitchIsland> createState() => _SwitchIslandState();
}

class _SwitchIslandState extends State<_SwitchIsland> {
  late bool value = widget.node.prop(SwitchProps.value);

  @override
  void didUpdateWidget(covariant _SwitchIsland oldWidget) {
    super.didUpdateWidget(oldWidget);
    final v = widget.node.prop(SwitchProps.value);
    if (v != oldWidget.node.prop(SwitchProps.value)) value = v;
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final fillTrack = n.prop(SwitchProps.fillTrack);
    final active = _color(n.prop(SwitchProps.activeTrackOutlineColor));
    final inactive = _color(n.prop(SwitchProps.inactiveTrackOutlineColor));
    final outlineWidth = n.prop(SwitchProps.trackOutlineWidth);
    final toggle = Switch(
      // Where tickers are off (a design canvas) the toggle can't animate: a
      // new switch shows the current value.
      key: TickerMode.valuesOf(context).enabled ? null : ValueKey<bool>(value),
      value: value,
      onChanged: (v) {
        setState(() => value = v);
        _fire(context, 'changed', v);
      },
      autofocus: n.prop(SwitchProps.autofocus),
      activeTrackColor: _color(n.prop(SwitchProps.activeTrackColor)),
      inactiveTrackColor: _color(n.prop(SwitchProps.inactiveTrackColor)),
      activeThumbColor: _color(n.prop(SwitchProps.activeThumbColor)),
      inactiveThumbColor: _color(n.prop(SwitchProps.inactiveThumbColor)),
      hoverColor: _color(n.prop(SwitchProps.hoverColor)),
      focusColor: _color(n.prop(SwitchProps.focusColor)),
      splashRadius: n.prop(SwitchProps.splashRadius),
      trackOutlineColor: active == null && inactive == null
          ? null
          : WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? active : inactive),
      trackOutlineWidth: outlineWidth == null ? null : WidgetStatePropertyAll(outlineWidth),
      thumbIcon: n.prop(SwitchProps.uniformThumb) ? const WidgetStatePropertyAll<Icon?>(Icon(null)) : null,
      padding: fillTrack ? EdgeInsets.zero : null,
      materialTapTargetSize: fillTrack ? MaterialTapTargetSize.shrinkWrap : null,
    );
    if (fillTrack) {
      // The switch, cut to its track's box, stretched to the node's.
      final track = Theme.of(context).useMaterial3 ? const Size(52, 32) : const Size(33, 14);
      return FittedBox(
        fit: BoxFit.fill,
        child: SizedBox.fromSize(
          size: track,
          child: OverflowBox(
              minWidth: 0, minHeight: 0, maxWidth: double.infinity, maxHeight: double.infinity, child: toggle),
        ),
      );
    }
    return Transform.scale(scale: n.layout.width.value / _switchWidth, child: toggle);
  }
}

class _RadioIsland extends StatefulWidget {
  const _RadioIsland({required this.node});
  final Node node;

  @override
  State<_RadioIsland> createState() => _RadioIslandState();
}

class _RadioIslandState extends State<_RadioIsland> {
  late String? groupValue = widget.node.prop(RadioProps.groupValue);

  @override
  void didUpdateWidget(covariant _RadioIsland oldWidget) {
    super.didUpdateWidget(oldWidget);
    final v = widget.node.prop(RadioProps.groupValue);
    if (v != oldWidget.node.prop(RadioProps.groupValue)) groupValue = v;
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final side = n.prop(RadioProps.side);
    final inner = n.prop(RadioProps.innerRadius);
    final background = _color(n.prop(RadioProps.backgroundColor));
    final active = _color(n.prop(RadioProps.activeColor));
    final inactive = _color(n.prop(RadioProps.inactiveColor));
    return Transform.scale(
      scale: n.layout.width.value / _radioSize,
      child: RadioGroup<String>(
        groupValue: groupValue ?? '',
        onChanged: (v) {
          setState(() => groupValue = v);
          _fire(context, 'changed', v);
        },
        child: Radio<String>(
          value: n.prop(RadioProps.value),
          autofocus: n.prop(RadioProps.autofocus),
          activeColor: active,
          hoverColor: _color(n.prop(RadioProps.hoverColor)),
          focusColor: _color(n.prop(RadioProps.focusColor)),
          toggleable: n.prop(RadioProps.toggleable),
          splashRadius: n.prop(RadioProps.splashRadius),
          side: side == null ? null : _side(side),
          innerRadius: inner == null ? null : WidgetStatePropertyAll(inner),
          backgroundColor: background == null ? null : WidgetStatePropertyAll(background),
          fillColor: active == null && inactive == null
              ? null
              : WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? active : inactive),
        ),
      ),
    );
  }
}

// --- slider -------------------------------------------------------------------

/// [n]'s value indicator text: its label with `${value}` replaced.
String? sliderLabel(Node n, double value) {
  final label = n.prop(SliderProps.label);
  if (label == null || n.prop(SliderProps.showValueIndicator) == api.ShowValueIndicator.never) return null;
  final digits = n.prop(SliderProps.labelFractionDigits);
  return label.replaceAll(r'${value}', digits > 0 ? value.toStringAsFixed(digits) : value.round().toString());
}

class _SliderIsland extends StatefulWidget {
  const _SliderIsland({required this.node});
  final Node node;

  @override
  State<_SliderIsland> createState() => _SliderIslandState();
}

class _SliderIslandState extends State<_SliderIsland> {
  late double value = widget.node.prop(SliderProps.value);

  @override
  void didUpdateWidget(covariant _SliderIsland oldWidget) {
    super.didUpdateWidget(oldWidget);
    final v = widget.node.prop(SliderProps.value);
    if (v != oldWidget.node.prop(SliderProps.value)) value = v;
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final min = n.prop(SliderProps.min);
    final max = math.max(min, n.prop(SliderProps.max));
    final vertical = n.prop(SliderProps.orientation) == api.Axis.vertical;
    final range = max - min;
    final marker = n.prop(SliderProps.markerValue);
    final markerFraction = marker == null || range == 0 ? null : ((marker - min) / range).clamp(0.0, 1.0);
    final trackHeight = n.prop(SliderProps.trackHeight);
    final trackShapeKind = n.prop(SliderProps.trackShape);
    final showThumb = n.prop(SliderProps.showThumb);
    final startOpacity = n.prop(SliderProps.activeTrackStartOpacity);
    final fillFromEnd = n.prop(SliderProps.fillFromEnd);
    final SliderTrackShape? baseTrack = switch (trackShapeKind) {
      null => null,
      api.SliderTrackShape.rectangle => const RectangularSliderTrackShape(),
      api.SliderTrackShape.roundedRectangle => const RoundedRectSliderTrackShape(),
      api.SliderTrackShape.gapped => const GappedSliderTrackShape(),
    };
    final trackShape = fillFromEnd || markerFraction != null || startOpacity < 1
        ? MarkedSliderTrackShape(
            fillFromEnd: fillFromEnd,
            activeStartOpacity: startOpacity,
            markerFraction: markerFraction,
            markerColor: n.prop(SliderProps.markerColor).flutter,
            markerWidth: n.prop(SliderProps.markerWidth),
            markerHeight: n.prop(SliderProps.markerHeight),
            radius: trackShapeKind == api.SliderTrackShape.rectangle ? 0 : (trackHeight ?? 4) / 2,
          )
        : baseTrack;
    final thumbSize = n.prop(SliderProps.thumbSize);
    final thumbRadius = n.prop(SliderProps.thumbCornerRadius);
    final w = !showThumb ? 0.0 : (vertical ? thumbSize.dy : thumbSize.dx);
    final h = !showThumb ? 0.0 : (vertical ? thumbSize.dx : thumbSize.dy);
    final SliderComponentShape baseThumb = switch (n.prop(SliderProps.thumbShape)) {
      api.SliderThumbShape.rectangle => RectSliderThumbShape(
          width: w,
          height: h,
          radius: thumbRadius,
          borderColor: _color(n.prop(SliderProps.thumbBorderColor)) ?? Colors.transparent,
          borderWidth: n.prop(SliderProps.thumbBorderWidth),
          gripColor: _color(n.prop(SliderProps.thumbGripColor)) ?? Colors.transparent,
        ),
      api.SliderThumbShape.roundedRect => RoundedRectSliderThumbShape(
          size: Size(w, h),
          cornerRadius: thumbRadius,
          strokeColor: _color(n.prop(SliderProps.thumbStrokeColor)),
          strokeWidth: n.prop(SliderProps.thumbStrokeWidth),
        ),
      api.SliderThumbShape.circle => StrokedSliderThumbShape(
          enabledThumbRadius: showThumb ? n.prop(SliderProps.thumbRadius) : 0,
          strokeColor: _color(n.prop(SliderProps.thumbStrokeColor)),
          strokeWidth: n.prop(SliderProps.thumbStrokeWidth),
        ),
    };
    final glow = _color(n.prop(SliderProps.thumbGlowColor));
    final thumbShape = showThumb && glow != null && glow.a > 0
        ? GlowSliderThumbShape(
            thumb: baseThumb,
            color: glow,
            blur: n.prop(SliderProps.thumbGlowBlur),
            spread: n.prop(SliderProps.thumbGlowSpread),
            cornerRadius: n.prop(SliderProps.thumbShape) == api.SliderThumbShape.circle ? null : thumbRadius,
          )
        : baseThumb;
    final divisions = n.prop(SliderProps.divisions);
    final indicator = n.prop(SliderProps.showValueIndicator);
    final overlayRadius = n.prop(SliderProps.overlayRadius);
    final indicatorStyle = n.prop(SliderProps.valueIndicatorTextStyle);
    final selectableMin = n.prop(SliderProps.selectableMin), selectableMax = n.prop(SliderProps.selectableMax);
    double selectable(double v) {
      final lo = (selectableMin ?? min).clamp(min, max);
      final hi = (selectableMax ?? max).clamp(lo, max);
      return v.clamp(lo, hi);
    }

    final shown = selectable(value.clamp(min, max));
    final design = _designSize(n);
    final Widget slider = SizedBox(
      width: vertical ? design.height : design.width,
      height: vertical ? design.width : design.height,
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: trackHeight,
          overlayColor: !showThumb ? Colors.transparent : _color(n.prop(SliderProps.overlayColor)),
          activeTrackColor: _color(n.prop(SliderProps.activeTrackColor)),
          inactiveTrackColor: _color(n.prop(SliderProps.inactiveTrackColor)),
          secondaryActiveTrackColor: _color(n.prop(SliderProps.secondaryActiveTrackColor)),
          thumbColor: _color(n.prop(SliderProps.thumbColor)),
          thumbShape: thumbShape,
          trackShape: trackShape,
          // GappedSliderTrackShape needs a gap; 6 is Material 3's.
          trackGap: trackShapeKind == api.SliderTrackShape.gapped ? 6 : null,
          tickMarkShape: divisions == null
              ? null
              : n.prop(SliderProps.tickMarkStyle) == api.SliderTickMarkStyle.notch
                  ? NotchSliderTickMarkShape(
                      divisions: divisions,
                      every: n.prop(SliderProps.notchEvery),
                      color: _color(n.prop(SliderProps.inactiveTickMarkColor)) ?? Colors.grey,
                    )
                  : switch (n.prop(SliderProps.tickMarkRadius)) {
                      null => null,
                      final r => RoundSliderTickMarkShape(tickMarkRadius: r),
                    },
          showValueIndicator: indicator == null ? null : ShowValueIndicator.values.byName(indicator.name),
          activeTickMarkColor: _color(n.prop(SliderProps.activeTickMarkColor)),
          inactiveTickMarkColor: _color(n.prop(SliderProps.inactiveTickMarkColor)),
          valueIndicatorColor: _color(n.prop(SliderProps.valueIndicatorColor)),
          valueIndicatorTextStyle: indicatorStyle.isEmpty
              ? null
              : TextStyle(color: _color(indicatorStyle.color), fontSize: indicatorStyle.fontSize),
          valueIndicatorShape: switch (n.prop(SliderProps.valueIndicatorShape)) {
            null => null,
            api.SliderValueIndicatorShape.rectangle => const RectangularSliderValueIndicatorShape(),
            api.SliderValueIndicatorShape.paddle => const PaddleSliderValueIndicatorShape(),
            api.SliderValueIndicatorShape.drop => const DropSliderValueIndicatorShape(),
            api.SliderValueIndicatorShape.roundedRectangle => const RoundedRectSliderValueIndicatorShape(),
          },
          overlayShape: overlayRadius == null && showThumb
              ? null
              : RoundSliderOverlayShape(overlayRadius: showThumb ? overlayRadius! : 0),
        ),
        child: Slider(
          value: shown,
          onChanged: (v) {
            final kept = selectable(v);
            if (kept == value) return;
            setState(() => value = kept);
            _fire(context, 'changed', kept);
          },
          onChangeEnd: (_) => _fire(context, 'changeEnd', value),
          autofocus: n.prop(SliderProps.autofocus),
          min: min,
          max: max,
          divisions: divisions,
          label: sliderLabel(n, value),
          secondaryTrackValue: n.prop(SliderProps.secondaryTrackValue)?.clamp(min, max),
          padding: n.prop(SliderProps.padding)?.flutter,
        ),
      ),
    );
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final flipped = direction == TextDirection.ltr ? TextDirection.rtl : TextDirection.ltr;
    // Vertical: a horizontal slider turned a quarter counterclockwise (min
    // at the bottom); inverted runs the other way.
    final directed = n.prop(SliderProps.inverted) ? Directionality(textDirection: flipped, child: slider) : slider;
    if (!vertical) return directed;
    return SizedBox(width: design.width, height: design.height, child: RotatedBox(quarterTurns: 3, child: directed));
  }
}

// --- dropdown -----------------------------------------------------------------

class _DropdownIsland extends StatefulWidget {
  const _DropdownIsland({required this.node});
  final Node node;

  @override
  State<_DropdownIsland> createState() => _DropdownIslandState();
}

class _DropdownIslandState extends State<_DropdownIsland> {
  late Object? selected = widget.node.prop(DropdownProps.value);

  @override
  void didUpdateWidget(covariant _DropdownIsland oldWidget) {
    super.didUpdateWidget(oldWidget);
    final v = widget.node.prop(DropdownProps.value);
    if (!api.jsonEquality.equals(v, oldWidget.node.prop(DropdownProps.value))) selected = v;
  }

  Node get n => widget.node;

  // Data source items are bound at runtime.
  List<Object?> get items => n.prop(DropdownProps.useDataSource) ? const [] : n.prop(DropdownProps.items);

  String labelOf(Object? value) => n.prop(DropdownProps.useDataSource) ? n.prop(DropdownProps.itemLabel) : '$value';

  Widget? image() {
    final url = n.prop(DropdownProps.itemImage).trim();
    if (url.isEmpty) return null;
    final size = n.prop(DropdownProps.itemImageSize);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 10),
      child: SizedBox.square(
        dimension: size,
        child: url.contains(r'${')
            ? null
            : ClipRRect(
                borderRadius: BorderRadius.circular(n.prop(DropdownProps.itemImageRadius)),
                child: Image.network(url,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => SizedBox.square(dimension: size)),
              ),
      ),
    );
  }

  Widget content(Object? value, TextStyle? style) {
    final label = Text(labelOf(value), style: style, overflow: TextOverflow.ellipsis);
    final img = image();
    if (img == null) return label;
    return Row(mainAxisSize: MainAxisSize.min, children: [img, Flexible(child: label)]);
  }

  @override
  Widget build(BuildContext context) {
    final items = this.items;
    // The selected item is the one equal to the value by content.
    final matches = [for (final item in items) if (api.jsonEquality.equals(item, selected)) item];
    final value = matches.length == 1 ? matches.single : null;
    final itemAlignment = n.prop(DropdownProps.itemAlignment).flutter;
    final itemStyle = _styleOrNull(n.prop(DropdownProps.style));
    final selectedStyle = _styleOrNull(n.prop(DropdownProps.selectedItemStyle));
    final hint = n.prop(DropdownProps.hint);
    final iconSize = n.prop(DropdownProps.iconSize);
    final enabled = n.prop(DropdownProps.enabled);
    final radius = n.prop(DropdownProps.borderRadius);
    final button = DropdownButton<Object>(
      value: value,
      isDense: n.prop(DropdownProps.isDense),
      isExpanded: n.prop(DropdownProps.isExpanded),
      autofocus: n.prop(DropdownProps.autofocus),
      enableFeedback: n.prop(DropdownProps.enableFeedback),
      alignment: n.prop(DropdownProps.alignment).flutter,
      hint: hint == null || hint.isEmpty
          ? null
          : Text(hint, style: _styleOrNull(n.prop(DropdownProps.hintStyle)), overflow: TextOverflow.ellipsis),
      iconDisabledColor: _color(n.prop(DropdownProps.iconDisabledColor)),
      iconEnabledColor: _color(n.prop(DropdownProps.iconEnabledColor)),
      iconSize: iconSize,
      icon: _icon(n.prop(DropdownProps.icon), size: iconSize),
      dropdownColor: _color(n.prop(DropdownProps.dropdownColor)),
      focusColor: _color(n.prop(DropdownProps.focusColor)),
      elevation: n.prop(DropdownProps.elevation),
      borderRadius: radius?.flutter,
      padding: n.layout.padding.flutter,
      onChanged: enabled
          ? (v) {
              setState(() => selected = v);
              _fire(context, 'changed', v);
            }
          : null,
      underline: n.prop(DropdownProps.underline) ? null : const SizedBox.shrink(),
      items: [
        for (final item in items)
          DropdownMenuItem<Object>(value: item, alignment: itemAlignment, child: content(item, itemStyle)),
      ],
      selectedItemBuilder: (context) => [
        for (final item in items)
          DropdownMenuItem<Object>(
            value: item,
            alignment: itemAlignment,
            child: Container(
              // An expanded dropdown gives the value the field's width; the
              // design width only caps one that sizes to its value.
              constraints: n.prop(DropdownProps.isExpanded)
                  ? null
                  : BoxConstraints(maxWidth: math.max(0, n.layout.width.value - iconSize)),
              child: content(item, selectedStyle),
            ),
          ),
      ],
    );
    final menuStyle = n.prop(DropdownProps.menuStyle);
    Widget field = button;
    if (menuStyle != null) {
      field = _AnchoredMenu(
        node: n,
        style: menuStyle,
        items: items,
        value: value,
        enabled: enabled,
        labelOf: labelOf,
        image: image,
        onPick: (v) {
          setState(() => selected = v);
          _fire(context, 'changed', v);
        },
        child: button,
      );
    }
    if (n.layout.width.fit == SizeFit.hug) field = IntrinsicWidth(child: field);
    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: _color(n.prop(DropdownProps.hoverColor)),
        splashColor: _color(n.prop(DropdownProps.splashColor)),
      ),
      child: field,
    );
  }
}

/// A dropdown whose menu is a card anchored under (or over) the button.
class _AnchoredMenu extends StatefulWidget {
  const _AnchoredMenu({
    required this.node,
    required this.style,
    required this.items,
    required this.value,
    required this.enabled,
    required this.labelOf,
    required this.image,
    required this.onPick,
    required this.child,
  });

  final Node node;
  final api.Json style;
  final List<Object?> items;
  final Object? value;
  final bool enabled;
  final String Function(Object?) labelOf;
  final Widget? Function() image;
  final ValueChanged<Object?> onPick;
  final Widget child;

  @override
  State<_AnchoredMenu> createState() => _AnchoredMenuState();
}

class _AnchoredMenuState extends State<_AnchoredMenu> {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  Size _fieldSize = Size.zero;
  bool _below = true;

  double _num(String key, double fallback) => api.readDouble(widget.style[key]) ?? fallback;
  Color? _hex(String key) => api.Color.fromJson(widget.style[key])?.flutter;
  EdgeInsets? _insets(String key) =>
      widget.style[key] == null ? null : api.EdgeInsets.fromJson(widget.style[key]).flutter;

  void _open() {
    if (!widget.enabled || _portal.isShowing) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final screen = MediaQuery.sizeOf(context).height;
    final bottom = box.localToGlobal(Offset.zero).dy + box.size.height;
    setState(() {
      _fieldSize = box.size;
      _below = bottom + _num('offset', 6) + _num('maxHeight', 320) <= screen || bottom < screen / 2;
    });
    _portal.show();
  }

  void _close() {
    if (_portal.isShowing) setState(_portal.hide);
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _menu,
        child: CompositedTransformTarget(
          link: _link,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _open,
            // The button only draws the field; the menu is this one.
            child: IgnorePointer(child: ExcludeFocus(child: widget.child)),
          ),
        ),
      );

  Widget _menu(BuildContext context) {
    final n = widget.node;
    final s = widget.style;
    final radius = api.readDouble(s['radius']) ?? n.prop(DropdownProps.borderRadius)?.topLeft ?? 0;
    final border = api.BorderSide.fromJson(s['border']);
    final side = border == null ? BorderSide.none : _side(border);
    final shadows = s['shadows'] != null
        ? [for (final e in api.Effect.listFromJson(s['shadows'])) if (e.visible && e.type == api.EffectType.dropShadow) boxShadow(e)]
        : kElevationToShadow[n.prop(DropdownProps.elevation).clamp(0, 24)] ?? kElevationToShadow[8]!;
    final itemStyle = _styleOrNull(n.prop(DropdownProps.style)) ?? const TextStyle();
    final selectedStyle = itemStyle.merge(_styleOrNull(api.TextStyle.fromJson(s['selectedTextStyle'])));
    final hover = _hex('hoverItemColor') ?? _color(n.prop(DropdownProps.hoverColor));
    final itemPadding = _insets('itemPadding') ?? const EdgeInsets.symmetric(horizontal: 14);
    final showCheck = s['showCheck'] == true;
    final leadingCheck = s['checkPosition'] == 'leading';
    final minWidth = _num('minWidth', 0);
    final menu = Container(
      width: _fieldSize.width < minWidth ? minWidth : _fieldSize.width,
      constraints: BoxConstraints(maxHeight: _num('maxHeight', 320)),
      decoration: BoxDecoration(
        color: _hex('color') ?? _color(n.prop(DropdownProps.dropdownColor)),
        borderRadius: BorderRadius.circular(radius),
        border: side == BorderSide.none ? null : Border.fromBorderSide(side),
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(math.max(0, radius - side.width)),
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            padding: _insets('padding') ?? const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in widget.items)
                  Builder(builder: (context) {
                    final selected = item == widget.value;
                    final style = selected ? selectedStyle : itemStyle;
                    Widget check() => Icon(Icons.check, size: _num('checkSize', 18), color: _hex('checkColor') ?? style.color);
                    return Material(
                      color: selected ? _hex('selectedItemColor') ?? Colors.transparent : Colors.transparent,
                      child: InkWell(
                        hoverColor: hover,
                        splashColor: _color(n.prop(DropdownProps.splashColor)),
                        onTap: () {
                          _close();
                          widget.onPick(item);
                        },
                        child: Container(
                          height: _num('itemHeight', 40),
                          padding: itemPadding,
                          alignment: n.prop(DropdownProps.itemAlignment).flutter,
                          child: Row(children: [
                            if (selected && showCheck && leadingCheck)
                              Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: check()),
                            ?widget.image(),
                            Expanded(child: Text(widget.labelOf(item), style: style, overflow: TextOverflow.ellipsis)),
                            if (selected && showCheck && !leadingCheck)
                              Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: check()),
                          ]),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
    final offset = _num('offset', 6);
    return Stack(children: [
      Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _close)),
      CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: _below ? Alignment.bottomLeft : Alignment.topLeft,
        followerAnchor: _below ? Alignment.topLeft : Alignment.bottomLeft,
        offset: Offset(0, _below ? offset : -offset),
        child: Align(alignment: _below ? Alignment.topLeft : Alignment.bottomLeft, child: menu),
      ),
    ]);
  }
}

// --- date and time ------------------------------------------------------------

/// [value] as a date (`yyyy-MM-dd...`), or null.
DateTime? _date(String? value) {
  if (value == null || value.length < 10) return null;
  return DateTime.tryParse('${value.substring(0, 10)}T00:00:00');
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _clock(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay? _time(String value) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
  if (m == null) return null;
  final h = int.parse(m[1]!), min = int.parse(m[2]!);
  return h < 24 && min < 60 ? TimeOfDay(hour: h, minute: min) : null;
}

class _DatePickerIsland extends StatefulWidget {
  const _DatePickerIsland({required this.node, required this.interactive});
  final Node node;
  final bool interactive;

  @override
  State<_DatePickerIsland> createState() => _DatePickerIslandState();
}

class _DatePickerIslandState extends State<_DatePickerIsland> {
  String? picked;

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final first = _date(n.prop(DatePickerProps.firstDate)) ?? DateTime(1);
    final last = _date(n.prop(DatePickerProps.lastDate)) ?? DateTime(9999, 12, 31);
    var initial = _date(picked ?? n.prop(DatePickerProps.value)) ?? DateTime.now();
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    return OutlinedButton(
      onPressed: !n.prop(DatePickerProps.enabled) || !widget.interactive
          ? null
          : () async {
              final date = await showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last);
              if (date == null || !mounted) return;
              setState(() => picked = _isoDate(date));
              if (context.mounted) _fire(context, 'changed', picked);
            },
      child: Text(_isoDate(initial)),
    );
  }
}

class _TimePickerIsland extends StatefulWidget {
  const _TimePickerIsland({required this.node, required this.interactive});
  final Node node;
  final bool interactive;

  @override
  State<_TimePickerIsland> createState() => _TimePickerIslandState();
}

class _TimePickerIslandState extends State<_TimePickerIsland> {
  String? picked;

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final time = _time(picked ?? n.prop(TimePickerProps.value)) ?? const TimeOfDay(hour: 0, minute: 0);
    return OutlinedButton(
      onPressed: !n.prop(TimePickerProps.enabled) || !widget.interactive
          ? null
          : () async {
              final t = await showTimePicker(context: context, initialTime: time);
              if (t == null || !mounted) return;
              setState(() => picked = _clock(t));
              if (context.mounted) _fire(context, 'changed', picked);
            },
      child: Text(_clock(time)),
    );
  }
}

class _DateTimeInputIsland extends StatefulWidget {
  const _DateTimeInputIsland({required this.node, required this.interactive});
  final Node node;
  final bool interactive;

  @override
  State<_DateTimeInputIsland> createState() => _DateTimeInputIslandState();
}

class _DateTimeInputIslandState extends State<_DateTimeInputIsland> {
  String? picked;

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final mode = n.prop(DateTimeInputProps.mode);
    final String raw = picked ?? n.prop(DateTimeInputProps.value);
    final min = n.prop(DateTimeInputProps.min), max = n.prop(DateTimeInputProps.max);
    var first = _date(n.prop(DateTimeInputProps.firstDate)) ?? DateTime(1);
    var last = _date(n.prop(DateTimeInputProps.lastDate)) ?? DateTime(9999, 12, 31);
    if (mode != DateTimeInputMode.time) {
      final lower = _date(min), upper = _date(max);
      if (lower != null && lower.isAfter(first)) first = lower;
      if (upper != null && upper.isBefore(last)) last = upper;
    }
    final date = mode == DateTimeInputMode.time ? null : _date(raw);
    final time = switch (mode) {
      DateTimeInputMode.date => null,
      DateTimeInputMode.time => _time(raw),
      DateTimeInputMode.dateTime => switch (DateTime.tryParse(raw)) {
          null => null,
          final d => TimeOfDay.fromDateTime(d),
        },
    };
    final localizations = MaterialLocalizations.of(context);
    final display = switch (mode) {
      DateTimeInputMode.date => date == null ? '' : localizations.formatMediumDate(date),
      DateTimeInputMode.time => time == null ? '' : time.format(context),
      DateTimeInputMode.dateTime =>
        date == null || time == null ? '' : '${localizations.formatMediumDate(date)} · ${time.format(context)}',
    };
    final enabled = n.prop(DateTimeInputProps.enabled);
    final label = n.prop(DateTimeInputProps.labelText);
    final initial = date == null || date.isBefore(first) || date.isAfter(last)
        ? (DateTime.now().isBefore(first) ? first : (DateTime.now().isAfter(last) ? last : DateTime.now()))
        : date;
    return InkWell(
      onTap: !enabled || !widget.interactive || first.isAfter(last)
          ? null
          : () async {
              var chosen = initial;
              if (mode != DateTimeInputMode.time) {
                final d = await showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last);
                if (d == null || !context.mounted) return;
                chosen = d;
              }
              TimeOfDay? t;
              if (mode != DateTimeInputMode.date) {
                t = await showTimePicker(context: context, initialTime: time ?? TimeOfDay.now());
                if (t == null || !context.mounted) return;
              }
              setState(() => picked = switch (mode) {
                    DateTimeInputMode.date => _isoDate(chosen),
                    DateTimeInputMode.time => _clock(t!),
                    DateTimeInputMode.dateTime =>
                      DateTime.utc(chosen.year, chosen.month, chosen.day, t!.hour, t.minute).toIso8601String(),
                  });
              if (context.mounted) _fire(context, 'changed', picked);
            },
      child: InputDecorator(
        isEmpty: display.isEmpty,
        decoration: InputDecoration(
          labelText: label,
          hintText: label == null || label.isEmpty
              ? 'Select ${switch (mode) {
                  DateTimeInputMode.date => 'date',
                  DateTimeInputMode.time => 'time',
                  DateTimeInputMode.dateTime => 'date and time',
                }}'
              : null,
          suffixIcon: Icon(mode == DateTimeInputMode.time ? Icons.access_time : Icons.calendar_today),
          enabled: enabled,
          border: const OutlineInputBorder(),
        ),
        child: Text(display.isEmpty ? ' ' : display),
      ),
    );
  }
}

// --- segmentedButton ----------------------------------------------------------

class _SegmentedButtonIsland extends StatefulWidget {
  const _SegmentedButtonIsland({required this.node});
  final Node node;

  @override
  State<_SegmentedButtonIsland> createState() => _SegmentedButtonIslandState();
}

class _SegmentedButtonIslandState extends State<_SegmentedButtonIsland> {
  late Set<String> selected = widget.node.prop(SegmentedButtonProps.selected).toSet();

  @override
  void didUpdateWidget(covariant _SegmentedButtonIsland oldWidget) {
    super.didUpdateWidget(oldWidget);
    final v = widget.node.prop(SegmentedButtonProps.selected);
    if (!api.jsonEquality.equals(v, oldWidget.node.prop(SegmentedButtonProps.selected))) selected = v.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final segments = [
      for (final s in n.prop(SegmentedButtonProps.segments))
        () {
          final icon = _icon(s.icon);
          return ButtonSegment<String>(
            value: s.value,
            icon: icon,
            // A segment needs a label or an icon.
            label: s.label.isNotEmpty || icon == null ? Text(s.label.isNotEmpty ? s.label : s.value) : null,
            tooltip: s.tooltip == null || s.tooltip!.isEmpty ? null : s.tooltip,
            enabled: s.enabled,
          );
        }(),
    ];
    // Keep the selection within what SegmentedButton accepts.
    final values = {for (final s in segments) s.value};
    var selection = selected.where(values.contains).toSet();
    final multi = n.prop(SegmentedButtonProps.multiSelectionEnabled);
    if (!multi && selection.length > 1) selection = {selection.first};
    final side = n.prop(SegmentedButtonProps.side);
    final radius = n.prop(SegmentedButtonProps.borderRadius);
    final selectedIcon = _icon(n.prop(SegmentedButtonProps.selectedIcon));
    return SegmentedButton<String>(
      segments: segments,
      selected: selection,
      onSelectionChanged:
          n.prop(SegmentedButtonProps.enabled)
              ? (s) {
                  setState(() => selected = s);
                  _fire(context, 'changed', s.toList());
                }
              : null,
      multiSelectionEnabled: multi,
      emptySelectionAllowed: n.prop(SegmentedButtonProps.emptySelectionAllowed) || selection.isEmpty,
      showSelectedIcon: n.prop(SegmentedButtonProps.showSelectedIcon),
      selectedIcon: selectedIcon,
      direction: n.prop(SegmentedButtonProps.direction) == api.Axis.vertical ? Axis.vertical : Axis.horizontal,
      style: SegmentedButton.styleFrom(
        backgroundColor: _color(n.prop(SegmentedButtonProps.backgroundColor)),
        selectedBackgroundColor: _color(n.prop(SegmentedButtonProps.selectedBackgroundColor)),
        foregroundColor: _color(n.prop(SegmentedButtonProps.foregroundColor)),
        selectedForegroundColor: _color(n.prop(SegmentedButtonProps.selectedForegroundColor)),
        side: side == null ? null : _side(side),
        shape: radius == null ? null : RoundedRectangleBorder(borderRadius: radius.flutter),
      ),
    );
  }
}

// --- signature ----------------------------------------------------------------

class _SignatureIsland extends StatefulWidget {
  const _SignatureIsland({required this.node});
  final Node node;

  @override
  State<_SignatureIsland> createState() => _SignatureIslandState();
}

class _SignatureIslandState extends State<_SignatureIsland> {
  late List<List<Offset>> strokes = _strokesOf(widget.node);
  List<Offset>? current;

  static List<List<Offset>> _strokesOf(Node n) => [
        for (final s in n.prop(SignatureProps.value)) [for (final p in s) Offset(p.dx, p.dy)],
      ];

  @override
  void didUpdateWidget(covariant _SignatureIsland oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!api.jsonEquality.equals(widget.node.prop(SignatureProps.value), oldWidget.node.prop(SignatureProps.value))) {
      strokes = _strokesOf(widget.node);
      current = null;
    }
  }

  Offset _point(Offset p, Size size) {
    if (widget.node.prop(SignatureProps.normalized)) {
      return Offset(
          size.width <= 0 ? 0 : (p.dx / size.width).clamp(0.0, 1.0), size.height <= 0 ? 0 : (p.dy / size.height).clamp(0.0, 1.0));
    }
    return Offset((p.dx * 10).roundToDouble() / 10, (p.dy * 10).roundToDouble() / 10);
  }

  void _end([Object? _]) {
    final stroke = current;
    if (stroke == null) return;
    setState(() {
      strokes = [...strokes, stroke];
      current = null;
    });
    _fire(context, 'changed', [
      for (final s in strokes) [for (final p in s) [p.dx, p.dy]],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final error = n.prop(SignatureProps.error);
    final radius = n.prop(SignatureProps.borderRadius).flutter;
    final borderWidth = error ? n.prop(SignatureProps.errorBorderWidth) : n.prop(SignatureProps.borderWidth);
    final pad = DecoratedBox(
      decoration: BoxDecoration(
        color: n.prop(SignatureProps.backgroundColor).flutter,
        borderRadius: radius,
        border: borderWidth <= 0
            ? null
            : Border.all(
                color: (error ? n.prop(SignatureProps.errorBorderColor) : n.prop(SignatureProps.borderColor)).flutter,
                width: borderWidth,
              ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: CustomPaint(
          painter: SignaturePainter(
            strokes: [...strokes, ?current],
            inkColor: n.prop(SignatureProps.inkColor).flutter,
            inkWidth: n.prop(SignatureProps.inkWidth),
            placeholder: n.prop(SignatureProps.placeholder),
            placeholderColor: n.prop(SignatureProps.placeholderColor).flutter,
            placeholderFontSize: n.prop(SignatureProps.placeholderFontSize),
            showSignLine: n.prop(SignatureProps.showSignLine),
            signLineColor: n.prop(SignatureProps.signLineColor).flutter,
            textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
            normalized: n.prop(SignatureProps.normalized),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
    if (!n.prop(SignatureProps.enabled) || n.prop(SignatureProps.readOnly)) return pad;
    return IntrinsicSafeLayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            _EagerPanGestureRecognizer: GestureRecognizerFactoryWithHandlers<_EagerPanGestureRecognizer>(
              _EagerPanGestureRecognizer.new,
              (r) => r
                ..dragStartBehavior = DragStartBehavior.down
                ..onStart = ((d) => setState(() => current = [_point(d.localPosition, size)]))
                ..onUpdate = (d) {
                  final stroke = current;
                  if (stroke == null) return;
                  final p = _point(d.localPosition, size);
                  if (stroke.isNotEmpty && stroke.last == p) return;
                  setState(() => stroke.add(p));
                }
                ..onEnd = _end
                ..onCancel = _end,
            ),
          },
          child: pad,
        );
      },
    );
  }
}

/// Takes a drag at once, so a scroll view around the pad doesn't.
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolvePointer(event.pointer, GestureDisposition.accepted);
  }
}
