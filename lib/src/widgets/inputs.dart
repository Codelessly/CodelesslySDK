// Widget recipes: inputs. See lib/src/render/recipe.dart.
//
// Inputs are islands: real Flutter widgets (TextField, Checkbox, Slider...)
// built from the node's props, inside their box: a fit box
// for the ones that size to their node's fits, the design size for the ones
// that always take it (checkbox, radio, signature, and non-fill sliders), nothing for the
// pickers (their button's own size).
//
// The widgets keep their own state (typed text, a toggled checkbox) and, in a
// running app, report it as the node's `changed` (and `submitted`,
// `changeEnd`, focus) trigger: the runtime writes the value to the variable
// the input's value is bound to and runs the node's reactions.

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart'
    show
        Node,
        SignatureProps;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../render/controls/dropdown.dart' show dropdownRecipe;
import '../render/control_theme.dart' show rolesOfScheme;
import '../render/convert.dart';
import '../render/node_tree.dart' show fireTrigger;
import '../render/paint/icon_glyph.dart';
import '../render/recipe.dart';
import 'indicator_theme.dart';
import 'inputs_shapes.dart';
import '../runtime/http_image_loader.dart';

/// What an input's texts inherit: the node's default text style, over the
/// theme's font (the project's: a label that names no family isn't in the
/// platform's) and ink.
api.TextStyle? _textDefault(BuildContext context, Node n) {
  final own = n.behaviors.defaultTextStyle;
  final theme = Theme.of(context);
  final family = theme.textTheme.bodyMedium?.fontFamily;
  // A style that names no color is in the theme's ink for what the input
  // sits on (Flutter would draw it white: a style of its own replaces the
  // field's).
  final ink = api.Color(theme.colorScheme.onSurface.toARGB32());
  return api.TextStyle(fontFamily: family, color: ink).merge(own);
}

/// Recipes for the inputs group, by node type.
final Map<String, WidgetRecipe> inputsRecipes = {
  // A render object now (render/controls/dropdown.dart; controls.dart
  // registers it too); listed here so the catalog still counts it an input
  // (drawn inside its node's shell when decorated).
  'dropdown': dropdownRecipe,
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

/// The node's fit box around [build].
void _fitted(NodeBuilder b, Node n, List<RenderBox> chain, WidgetBuilder build) {
  chain.add(b.fitBox('fit', n.layout.width.fit, n.layout.height.fit, _designSize(n)));
  chain.add(_island(b, build));
}

/// The node's design size around
/// [build].
void _sized(NodeBuilder b, Node n, List<RenderBox> chain, WidgetBuilder build) {
  final c = BoxConstraints.tight(_designSize(n));
  chain.add(b.obtain<RenderConstrainedBox>('sized', () => RenderConstrainedBox(additionalConstraints: c))
    ..additionalConstraints = c);
  chain.add(_island(b, build));
}

// --- shared -------------------------------------------------------------------

/// [s] as Flutter's style, or null when unset (the theme's).
TextStyle? _styleOrNull(api.TextStyle s, [api.TextStyle? inherited]) => s.isEmpty ? null : textStyle(s, inherited);

/// [text] in [style], as a decoration's texts are built (a span in a
/// `Text.rich`).
Widget _text(String text, api.TextStyle style,
        {TextAlign? textAlign, int? maxLines, TextOverflow? overflow, api.TextStyle? textDefault}) =>
    Text.rich(TextSpan(children: [TextSpan(text: text, style: _styleOrNull(style, textDefault))]),
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
    // Outside a tree with a loader of its own, its SVG is fetched as the SDK does.
    ..imageLoader = const HttpImageLoader()
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

/// The content padding of a field whose decoration and node set none:
/// Flutter's `InputDecorator` default for an outlined or filled field (12 px
/// at the sides, so the text and label clear the border), else the node's
/// [padding] (an unfilled underline field has no side padding in Flutter
/// either).
api.EdgeInsets defaultContentPadding(api.InputDecoration d, api.EdgeInsets padding) {
  if (d.isCollapsed || padding != api.EdgeInsets.zero) return padding;
  final borders = [d.border, d.enabledBorder, d.focusedBorder, d.errorBorder, d.focusedErrorBorder, d.disabledBorder];
  final outlined = borders.any((b) => b?.type == api.InputBorderType.outline);
  final dense = d.isDense ?? false;
  // No border of its own: the theme's outline, the label inside as a hint
  // (it never floats), so the same padding all round.
  if (borders.every((b) => b == null) && !(d.filled ?? false)) {
    return dense ? const api.EdgeInsets.fromLTRB(12, 8, 12, 8) : const api.EdgeInsets.fromLTRB(12, 12, 12, 12);
  }
  if (outlined) return dense ? const api.EdgeInsets.fromLTRB(12, 16, 12, 8) : const api.EdgeInsets.fromLTRB(12, 20, 12, 12);
  if (d.filled ?? false) return dense ? const api.EdgeInsets.fromLTRB(12, 4, 12, 4) : const api.EdgeInsets.fromLTRB(12, 8, 12, 8);
  return padding;
}

/// [padding] grown by the width of the border [d] draws in this state when
/// it has `paddingIncludesBorder` (an outline on every side, an underline
/// below): disabled, then error (focused or not), then focused, then enabled.
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
/// for an icon slot.
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
    {bool focused = false,
    bool? error,
    void Function(bool prefix)? onIconTap,
    api.TextStyle? textDefault,
    bool labelAbove = false}) {
  Widget? affixIcon(api.InputIcon? icon, api.EdgeInsets? iconPadding) {
    var glyph = _icon(icon);
    if (glyph == null) return null;
    // An icon with reactions (a clear "×") runs them when tapped.
    if (onIconTap != null && icon!.actions.isNotEmpty) {
      final prefix = identical(icon, d.prefixIcon);
      glyph = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onIconTap(prefix), child: glyph),
      );
    }
    final Widget aligned = Align(widthFactor: 1, heightFactor: 1, child: glyph);
    return iconPadding == null ? aligned : Padding(padding: iconPadding.flutter, child: aligned);
  }

  var label = previewText(d.labelText);
  final errorText = previewText(d.errorText);
  var hint = previewText(d.hintText);
  var hintStyle = d.hintStyle;
  // No border and no label behavior of its own: the theme's outlined field,
  // whose label never floats. It is the placeholder (as Flutter shows a
  // label that never floats, over the hint): the line stays centered
  // whether the field is empty or not.
  final themed = d.floatingLabelBehavior == null &&
      [d.border, d.enabledBorder, d.focusedBorder, d.errorBorder, d.focusedErrorBorder, d.disabledBorder]
          .every((b) => b == null);
  // With [labelAbove] the caller draws the label above the field
  // ([labelAboveField]); otherwise it is the placeholder.
  if (themed && label != null && label.isNotEmpty) {
    if (!labelAbove) {
      hint = label;
      if (!d.labelStyle.isEmpty) hintStyle = d.labelStyle;
    }
    label = null;
  }
  final prefix = previewText(d.prefixText), suffix = previewText(d.suffixText);
  final counter = d.counterText == '' ? '' : previewText(d.counterText);
  // Units that show before anything is typed go in the icon slots, which
  // Flutter always shows.
  final always = d.affixesAlwaysVisible;
  final prefixWidget = prefix == null || prefix.isEmpty ? null : _text(prefix, d.prefixStyle, textDefault: textDefault);
  final suffixWidget = suffix == null || suffix.isEmpty ? null : _text(suffix, d.suffixStyle, textDefault: textDefault);
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
    label: label == null || label.isEmpty ? null : _text(label, d.labelStyle, textDefault: textDefault),
    floatingLabelStyle: _styleOrNull(d.floatingLabelStyle, textDefault),
    helperText: previewText(d.helperText),
    helperStyle: _styleOrNull(d.helperStyle, textDefault),
    helperMaxLines: d.helperMaxLines,
    hintText: hint,
    hintStyle: _styleOrNull(hintStyle, textDefault),
    hintMaxLines: d.hintMaxLines,
    // In error without a message (an error text bound to `true`): the
    // error border, nothing under the field.
    error: errorText == api.kErrorWithoutMessage
        ? const SizedBox.shrink()
        : (errorText == null || errorText.trim().isEmpty ? null : _text(errorText, d.errorStyle, textDefault: textDefault)),
    errorStyle: _styleOrNull(d.errorStyle, textDefault),
    errorMaxLines: d.errorMaxLines,
    // Unset, a field with a border of its own floats its label as Flutter's
    // does; one without takes the theme's (the label never floats).
    floatingLabelBehavior: switch (d.floatingLabelBehavior) {
      null => [d.border, d.enabledBorder, d.focusedBorder].any((b) => b != null) ? FloatingLabelBehavior.auto : null,
      final b => FloatingLabelBehavior.values.byName(b.name),
    },
    isCollapsed: d.isCollapsed,
    isDense: d.isDense,
    // A collapsed decoration is the bare input, and a set content padding is
    // the designed one: a platform's compact density (desktop) must not
    // shrink either, or the field is ~8px shorter on desktop than designed.
    visualDensity: d.isCollapsed || d.contentPadding != null ? VisualDensity.standard : null,
    contentPadding: paddingWithBorder((d.contentPadding ?? defaultContentPadding(d, padding)).flutter, d,
        error: error ?? (errorText == api.kErrorWithoutMessage || (errorText != null && errorText.trim().isNotEmpty)),
        focused: focused),
    prefixIcon: always && prefixWidget != null ? _affix(prefixIcon, prefixWidget, before: true) : prefixIcon,
    prefixIconConstraints: iconConstraints(d.prefixIconConstraints, d.prefixIconPadding, prefixWidget, prefixIcon),
    prefix: always ? null : prefixWidget,
    prefixStyle: _styleOrNull(d.prefixStyle, textDefault),
    suffixIcon: always && suffixWidget != null ? _affix(suffixIcon, suffixWidget, before: false) : suffixIcon,
    suffixIconConstraints: iconConstraints(d.suffixIconConstraints, d.suffixIconPadding, suffixWidget, suffixIcon),
    suffix: always ? null : suffixWidget,
    suffixStyle: _styleOrNull(d.suffixStyle, textDefault),
    counter: counter == null || counter.isEmpty ? null : _text(counter, d.counterStyle, textDefault: textDefault),
    counterText: counter != null && counter.isEmpty ? '' : null,
    counterStyle: _styleOrNull(d.counterStyle, textDefault),
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

/// A [LayoutBuilder] that reports a zero intrinsic size instead of throwing,
/// so a field built with it can sit under intrinsic measurement.
/// A one-line input [height] tall. InputDecorator doesn't stretch its
/// container (fill, border) to a height: a dense 50 px field painted a 20 px
/// box at its top. So a box paints them at full height and a borderless
/// decorator of that height sits in it, its line centered (as a Container
/// around a TextField would). Its icons center in the whole height too, and
/// one with no icon gets an empty suffix as wide as its end padding and as
/// tall as the field, so small text centers as well (the decorator's own
/// container is otherwise 48 px).
Widget fullHeightField(
  BuildContext context,
  InputDecoration decoration,
  double height,
  Widget Function(InputDecoration borderless) build, {
  bool focused = false,
}) {
  final error = decoration.errorText != null || decoration.error != null;
  final own = (error ? (focused ? decoration.focusedErrorBorder : null) ?? decoration.errorBorder : null) ??
      (focused ? decoration.focusedBorder : null) ??
      decoration.enabledBorder ??
      decoration.border;
  // No border of its own: the theme's field shape, its side by state as
  // Flutter's InputDecorator draws it.
  final InputBorder border = own ?? themeFieldBorder(context, error: error, focused: focused, enabled: decoration.enabled);
  final fill = decoration.filled == true ? (decoration.fillColor ?? Colors.transparent) : Colors.transparent;
  final padEnd = (decoration.contentPadding ?? EdgeInsets.zero).resolve(Directionality.of(context)).right;
  // Without a floating label, the line is centered in the box at its own
  // (dense) height, whatever the box's height: a 28 px field is not laid out
  // for Material's 48 px and cut.
  final center = decoration.label == null && decoration.labelText == null;
  final spacer = decoration.prefixIcon == null && decoration.suffixIcon == null;
  return DecoratedBox(
    decoration: ShapeDecoration(color: fill, shape: border),
    child: _centered(center, build(
      decoration.copyWith(
        contentPadding: centeredPadding(context, decoration),
        isDense: center ? true : null,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        constraints: center ? null : BoxConstraints.tightFor(height: height),
        prefixIconConstraints:
            decoration.prefixIcon == null ? null : _tallIcon(decoration.prefixIconConstraints, height),
        suffixIcon: spacer ? SizedBox(width: padEnd, height: height) : decoration.suffixIcon,
        suffixIconConstraints: spacer
            ? BoxConstraints.tightFor(width: padEnd, height: height)
            : decoration.suffixIcon == null
                ? null
                : _tallIcon(decoration.suffixIconConstraints, height),
      ),
    )),
  );
}

/// [decoration]'s content padding for a field of a set height whose line
/// is centered (TextAlignVertical.center): its horizontal padding only, so a
/// 28 or 32 px field is not laid out for a taller line box and its text and
/// hint sit on its center. A field whose label floats keeps its padding (the
/// label needs the room above the line).
EdgeInsetsGeometry? centeredPadding(BuildContext context, InputDecoration decoration) {
  final p = decoration.contentPadding;
  if (p == null || decoration.label != null || decoration.labelText != null) return p;
  final r = p.resolve(Directionality.of(context));
  return EdgeInsets.fromLTRB(r.left, 0, r.right, 0);
}

/// The border of a field that sets none: the theme's field shape (an
/// outline of the control radius; an underline under a theme without one)
/// with the side Flutter's InputDecorator gives it in this state.
InputBorder themeFieldBorder(BuildContext context, {bool error = false, bool focused = false, bool enabled = true}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final shape = theme.inputDecorationTheme.border ?? const UnderlineInputBorder();
  final color = !enabled
      ? scheme.onSurface.withValues(alpha: .12)
      : error
          ? scheme.error
          : focused
              ? scheme.primary
              : scheme.outline;
  return shape.copyWith(borderSide: BorderSide(color: color, width: focused && enabled ? 2 : 1));
}

Widget _centered(bool center, Widget field) => center ? Center(child: field) : field;

/// An icon box as tall as a fixed-height field.
BoxConstraints _tallIcon(BoxConstraints? c, double height) =>
    (c ?? const BoxConstraints(minWidth: kMinInteractiveDimension)).copyWith(minHeight: height, maxHeight: height);

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
    // Its unset colors (ink, pad, border, placeholder) are the theme's.
    final n = withThemeColors(widget.node, rolesOfScheme(Theme.of(context).colorScheme));
    final error = n.prop(SignatureProps.error);
    final radius = n.prop(SignatureProps.borderRadius).flutter;
    final borderWidth = error ? n.prop(SignatureProps.errorBorderWidth) : n.prop(SignatureProps.borderWidth);
    final lineColor = n.prop(SignatureProps.signLineColor).flutter;
    final markColor = n.prop(SignatureProps.signMarkColor)?.flutter ?? lineColor;
    final markSize = n.prop(SignatureProps.signMarkSize);
    final showSignLine = n.prop(SignatureProps.showSignLine);
    // showSignMark is an older name for signLineMark: either off hides it.
    final showMark = n.prop(SignatureProps.showSignMark) && n.prop(SignatureProps.signLineMark);
    final iconJson = n.prop(SignatureProps.signMarkIcon);
    final hasIcon = iconJson != null && iconJson.isNotEmpty && iconJson['show'] != false;
    final placeholderFontSize = n.prop(SignatureProps.placeholderFontSize);
    final placeholderStyle = n.prop(SignatureProps.placeholderStyle);
    final captionStyle = n.prop(SignatureProps.captionStyle);
    final painter = SignaturePainter(
      strokes: [...strokes, ?current],
      inkColor: themedColor(n, SignatureProps.inkColor),
      inkWidth: n.prop(SignatureProps.inkWidth),
      placeholder: n.prop(SignatureProps.placeholder),
      placeholderColor: themedColor(n, SignatureProps.placeholderColor),
      placeholderFontSize: placeholderFontSize,
      placeholderStyle: placeholderStyle.isEmpty
          ? null
          : _signatureStyle(placeholderStyle,
              textDefault: _textDefault(context, n),
              color: themedColor(n, SignatureProps.placeholderColor),
              fontSize: placeholderFontSize,
              fontWeight: FontWeight.values[((n.prop(SignatureProps.placeholderFontWeight) ~/ 100) - 1).clamp(0, 8)],
              letterSpacing: n.prop(SignatureProps.placeholderLetterSpacing) ??
                  (placeholderStyle.fontSize ?? placeholderFontSize) * 0.12),
      placeholderFontWeight: n.prop(SignatureProps.placeholderFontWeight),
      placeholderLetterSpacing: n.prop(SignatureProps.placeholderLetterSpacing),
      smooth: n.prop(SignatureProps.smooth),
      placeholderBelowLine: n.prop(SignatureProps.placeholderPosition) == api.SignaturePlaceholderPosition.belowLine,
      placeholderAlignment: n.prop(SignatureProps.placeholderAlignment).flutter,
      placeholderOffset: Offset(n.prop(SignatureProps.placeholderOffset).dx, n.prop(SignatureProps.placeholderOffset).dy),
      showSignLine: showSignLine,
      signLineColor: lineColor,
      signLineWidth: n.prop(SignatureProps.signLineWidth),
      dashed: n.prop(SignatureProps.signLineStyle) == api.SignLineStyle.dashed,
      dash: n.prop(SignatureProps.signLineDash),
      gap: n.prop(SignatureProps.signLineGap),
      signLineOffset: n.prop(SignatureProps.signLineOffset),
      signLineBottom: n.prop(SignatureProps.signLineBottom),
      signLineInset: n.prop(SignatureProps.signLineInset),
      showMark: showMark,
      markGlyph: !hasIcon,
      markSize: markSize,
      markColor: markColor,
      leadingMark: n.prop(SignatureProps.signMarkPlacement) == api.SignMarkPlacement.leading,
      markGap: n.prop(SignatureProps.signMarkGap),
      caption: n.prop(SignatureProps.caption),
      captionStyle: _signatureStyle(captionStyle, color: lineColor, fontSize: 11, textDefault: _textDefault(context, n)),
      captionGap: n.prop(SignatureProps.captionGap),
      captionAlign: textAlign(n.prop(SignatureProps.captionAlign)),
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      normalized: n.prop(SignatureProps.normalized),
    );
    final paint = CustomPaint(painter: painter, child: const SizedBox.expand());
    final markIcon = hasIcon && showMark && showSignLine
        ? _icon(api.InputIcon(icon: iconJson, size: markSize, color: n.prop(SignatureProps.signMarkColor) ?? n.prop(SignatureProps.signLineColor)))
        : null;
    final pad = DecoratedBox(
      decoration: BoxDecoration(
        color: themedColor(n, SignatureProps.backgroundColor),
        borderRadius: radius,
        border: borderWidth <= 0
            ? null
            : Border.all(
                color: themedColor(n, error ? SignatureProps.errorBorderColor : SignatureProps.borderColor),
                width: borderWidth,
              ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: markIcon == null
            ? paint
            : Stack(fit: StackFit.expand, children: [
                paint,
                CustomSingleChildLayout(delegate: _SignMarkLayout(painter), child: markIcon),
              ]),
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

/// [style] over a signature pad's fallbacks for what it leaves unset.
TextStyle _signatureStyle(api.TextStyle style,
    {required Color color, required double fontSize, FontWeight? fontWeight, double? letterSpacing, api.TextStyle? textDefault}) {
  final converted = textStyle(style, textDefault);
  return converted.copyWith(
    color: style.color == null && style.foreground == null ? color : converted.color,
    fontSize: style.fontSize ?? fontSize,
    fontWeight: style.fontWeight == null ? fontWeight ?? converted.fontWeight : converted.fontWeight,
    letterSpacing: style.letterSpacing ?? letterSpacing ?? converted.letterSpacing,
  );
}

/// Lays a signature pad's icon mark where its painter puts the mark.
class _SignMarkLayout extends SingleChildLayoutDelegate {
  _SignMarkLayout(this.painter);
  final SignaturePainter painter;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.tight(Size.square(painter.markSize));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final g = painter.geometry();
    // Off the pad where the line has no room (it isn't drawn).
    return g.fits(size) ? g.markOrigin(size) : Offset(-childSize.width - size.width, 0);
  }

  @override
  bool shouldRelayout(_SignMarkLayout old) =>
      old.painter.markSize != painter.markSize ||
      old.painter.signLineOffset != painter.signLineOffset ||
      old.painter.signLineInset != painter.signLineInset ||
      old.painter.leadingMark != painter.leadingMark ||
      old.painter.markGap != painter.markGap;
}

/// Takes a drag at once, so a scroll view around the pad doesn't.
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolvePointer(event.pointer, GestureDisposition.accepted);
  }
}
