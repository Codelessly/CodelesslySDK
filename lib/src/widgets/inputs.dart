// Widget recipes: inputs. See lib/src/render/recipe.dart.
//
// Every input but one is a render object (lib/src/render/controls). What is
// left here is the signature pad, the last input island: a Flutter widget at
// its node's design size that keeps its strokes and reports them as the
// node's `changed` trigger. The dropdown is listed so the catalog still
// counts it an input.
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

/// The node's design size around
/// [build].
void _sized(NodeBuilder b, Node n, List<RenderBox> chain, WidgetBuilder build) {
  final c = BoxConstraints.tight(_designSize(n));
  chain.add(b.obtain<RenderConstrainedBox>('sized', () => RenderConstrainedBox(additionalConstraints: c))
    ..additionalConstraints = c);
  chain.add(_island(b, build));
}

// --- shared -------------------------------------------------------------------

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

/// A [LayoutBuilder] that reports a zero intrinsic size instead of throwing,
/// so what is built with it can sit under intrinsic measurement.
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
