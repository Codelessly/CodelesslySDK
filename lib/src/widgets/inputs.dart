// Widget recipes: inputs. See lib/src/render/recipe.dart.
//
// Every input is a render object. Most are controls (lib/src/render/controls);
// here are the two the controls do not hold: the dropdown, listed so the
// catalog still counts it an input, and the signature pad, a box that keeps
// its strokes, draws them and reports them as the node's `changed` trigger.
import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Node, SignatureProps;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

import '../render/controls/dropdown.dart' show dropdownRecipe;
import '../render/convert.dart';
import '../render/node_tree.dart' show fireTrigger;
import '../render/paint/icon_glyph.dart';
import '../render/recipe.dart';
import '../render/surface_roles.dart';
import 'indicator_theme.dart';
import 'inputs_shapes.dart';

/// Recipes for the inputs group, by node type.
final Map<String, WidgetRecipe> inputsRecipes = {
  // A render object (render/controls/dropdown.dart; controls.dart registers
  // it too); listed here so the catalog still counts it an input (drawn
  // inside its node's shell when decorated).
  'dropdown': dropdownRecipe,
  'signature': _signature,
};

// --- signature ----------------------------------------------------------------

/// The signature pad at its node's design size.
void _signature(NodeBuilder b, Node node, List<RenderBox> chain) {
  final c = BoxConstraints.tight(Size(node.layout.width.value, node.layout.height.value));
  chain.add(b.obtain<RenderConstrainedBox>('sized', () => RenderConstrainedBox(additionalConstraints: c))
    ..additionalConstraints = c);
  // Its unset colors (ink, pad, border, placeholder) are the theme's, for
  // what it is drawn on; its texts are in the theme's font and ink.
  b.tree.dependOnTheme(b);
  final theme = b.tree.components?.theme ?? api.ThemeTokens.none;
  final roles = surfaceRoles(theme, surface: backdropOf(b.source.node, b.source.parentOf, b.id));
  final textDefault = api.TextStyle(
    fontFamily: b.tree.textDefault?.fontFamily ?? theme.fontFamily,
    color: api.Color(roles.onSurface.toARGB32()),
  ).merge(node.behaviors.defaultTextStyle);
  chain.add(b.obtain<RenderSignaturePad>('signature', RenderSignaturePad.new)
    ..configure(
      withThemeColors(node, roles),
      textDefault: textDefault,
      onChanged: (value) => fireTrigger(b, 'changed', event: {'value': value}),
    ));
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

/// A signature pad: its fill and border, the sign line with its mark, the
/// placeholder and caption, and the strokes drawn on it. A drag draws a
/// stroke (taken at once, so a scroll view around the pad does not scroll);
/// each finished stroke reports all of them.
class RenderSignaturePad extends RenderBox {
  RenderSignaturePad() {
    _pan = _EagerPanGestureRecognizer(debugOwner: this)
      ..dragStartBehavior = DragStartBehavior.down
      ..onStart = ((d) {
        _current = [_point(d.localPosition)];
        _repaint();
      })
      ..onUpdate = (d) {
        final stroke = _current;
        if (stroke == null) return;
        final p = _point(d.localPosition);
        if (stroke.isNotEmpty && stroke.last == p) return;
        stroke.add(p);
        _repaint();
      }
      ..onEnd = ((_) => _end())
      ..onCancel = _end;
  }

  late final _EagerPanGestureRecognizer _pan;
  Node? _node;
  api.TextStyle? _textDefault;
  void Function(List<List<List<double>>> value)? _onChanged;

  List<List<Offset>> _strokes = const [];
  List<Offset>? _current;
  SignaturePainter? _painter;

  /// What it draws with, as of the last paint: the strokes, the line and the
  /// texts (for tests and tools).
  SignaturePainter get painter => _painter ??= _makePainter();

  /// The icon drawn as the line's mark, when the node gives one.
  RenderIconGlyph? get markIcon => _mark;
  RenderIconGlyph? _mark;

  static List<List<Offset>> _strokesOf(Node n) => [
        for (final s in n.prop(SignatureProps.value)) [for (final p in s) Offset(p.dx, p.dy)],
      ];

  /// Sets what it draws: [node] with its themed colors filled in.
  void configure(Node node, {api.TextStyle? textDefault, void Function(List<List<List<double>>> value)? onChanged}) {
    final old = _node;
    _onChanged = onChanged;
    if (old == null || !api.jsonEquality.equals(node.prop(SignatureProps.value), old.prop(SignatureProps.value))) {
      // A value from outside (bound, or cleared) replaces what was drawn.
      _strokes = _strokesOf(node);
      _current = null;
    }
    _node = node;
    _textDefault = textDefault;
    _painter = null;
    final n = node;
    final iconJson = n.prop(SignatureProps.signMarkIcon);
    final hasIcon = iconJson != null && iconJson.isNotEmpty && iconJson['show'] != false;
    final shown = hasIcon && _showMark(n) && n.prop(SignatureProps.showSignLine);
    if (shown) {
      final mark = _mark ??= _adopt(RenderIconGlyph());
      mark
        ..icon = iconJson
        ..color = n.prop(SignatureProps.signMarkColor)?.flutter ?? n.prop(SignatureProps.signLineColor).flutter;
    } else if (_mark != null) {
      dropChild(_mark!);
      _mark = null;
    }
    markNeedsLayout();
    markNeedsPaint();
  }

  RenderIconGlyph _adopt(RenderIconGlyph glyph) {
    adoptChild(glyph);
    return glyph;
  }

  // showSignMark is an older name for signLineMark: either off hides it.
  static bool _showMark(Node n) => n.prop(SignatureProps.showSignMark) && n.prop(SignatureProps.signLineMark);

  bool get _draws {
    final n = _node;
    return n != null && n.prop(SignatureProps.enabled) && !n.prop(SignatureProps.readOnly);
  }

  Offset _point(Offset p) {
    if (_node!.prop(SignatureProps.normalized)) {
      return Offset(
          size.width <= 0 ? 0 : (p.dx / size.width).clamp(0.0, 1.0), size.height <= 0 ? 0 : (p.dy / size.height).clamp(0.0, 1.0));
    }
    return Offset((p.dx * 10).roundToDouble() / 10, (p.dy * 10).roundToDouble() / 10);
  }

  void _repaint() {
    _painter = null;
    markNeedsPaint();
  }

  void _end() {
    final stroke = _current;
    if (stroke == null) return;
    _strokes = [..._strokes, stroke];
    _current = null;
    _repaint();
    _onChanged?.call([
      for (final s in _strokes) [for (final p in s) [p.dx, p.dy]],
    ]);
  }

  SignaturePainter _makePainter() {
    final n = _node!;
    final lineColor = n.prop(SignatureProps.signLineColor).flutter;
    final iconJson = n.prop(SignatureProps.signMarkIcon);
    final hasIcon = iconJson != null && iconJson.isNotEmpty && iconJson['show'] != false;
    final placeholderFontSize = n.prop(SignatureProps.placeholderFontSize);
    final placeholderStyle = n.prop(SignatureProps.placeholderStyle);
    return SignaturePainter(
      strokes: [..._strokes, ?_current],
      inkColor: themedColor(n, SignatureProps.inkColor),
      inkWidth: n.prop(SignatureProps.inkWidth),
      placeholder: n.prop(SignatureProps.placeholder),
      placeholderColor: themedColor(n, SignatureProps.placeholderColor),
      placeholderFontSize: placeholderFontSize,
      placeholderStyle: placeholderStyle.isEmpty
          ? null
          : _signatureStyle(placeholderStyle,
              textDefault: _textDefault,
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
      showSignLine: n.prop(SignatureProps.showSignLine),
      signLineColor: lineColor,
      signLineWidth: n.prop(SignatureProps.signLineWidth),
      dashed: n.prop(SignatureProps.signLineStyle) == api.SignLineStyle.dashed,
      dash: n.prop(SignatureProps.signLineDash),
      gap: n.prop(SignatureProps.signLineGap),
      signLineOffset: n.prop(SignatureProps.signLineOffset),
      signLineBottom: n.prop(SignatureProps.signLineBottom),
      signLineInset: n.prop(SignatureProps.signLineInset),
      showMark: _showMark(n),
      markGlyph: !hasIcon,
      markSize: n.prop(SignatureProps.signMarkSize),
      markColor: n.prop(SignatureProps.signMarkColor)?.flutter ?? lineColor,
      leadingMark: n.prop(SignatureProps.signMarkPlacement) == api.SignMarkPlacement.leading,
      markGap: n.prop(SignatureProps.signMarkGap),
      caption: n.prop(SignatureProps.caption),
      captionStyle: _signatureStyle(n.prop(SignatureProps.captionStyle), color: lineColor, fontSize: 11, textDefault: _textDefault),
      captionGap: n.prop(SignatureProps.captionGap),
      captionAlign: textAlign(n.prop(SignatureProps.captionAlign)),
      textDirection: TextDirection.ltr,
      normalized: n.prop(SignatureProps.normalized),
    );
  }

  // --- children: the mark's icon ---

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _mark?.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    _mark?.detach();
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    if (_mark != null) visitor(_mark!);
  }

  @override
  void redepthChildren() {
    if (_mark != null) redepthChild(_mark!);
  }

  // --- layout: the box it is given; nothing of its own ---

  @override
  double computeMinIntrinsicWidth(double height) => 0;
  @override
  double computeMaxIntrinsicWidth(double height) => 0;
  @override
  double computeMinIntrinsicHeight(double width) => 0;
  @override
  double computeMaxIntrinsicHeight(double width) => 0;
  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest.isFinite ? constraints.biggest : constraints.smallest;

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
    _mark?.layout(BoxConstraints.tight(Size.square(painter.markSize)));
  }

  // --- pointer ---

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent && _draws) _pan.addPointer(event);
  }

  @override
  void dispose() {
    _pan.dispose();
    super.dispose();
  }

  // --- paint ---

  @override
  void paint(PaintingContext context, Offset offset) {
    final n = _node;
    if (n == null) return;
    final error = n.prop(SignatureProps.error);
    final radius = n.prop(SignatureProps.borderRadius).flutter;
    final borderWidth = error ? n.prop(SignatureProps.errorBorderWidth) : n.prop(SignatureProps.borderWidth);
    final rect = offset & size;
    final outer = radius.toRRect(rect);
    final canvas = context.canvas;
    canvas.drawRRect(outer, Paint()..color = themedColor(n, SignatureProps.backgroundColor));
    if (borderWidth > 0) {
      canvas.drawRRect(
          outer.deflate(borderWidth / 2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = borderWidth
            ..color = themedColor(n, error ? SignatureProps.errorBorderColor : SignatureProps.borderColor));
    }
    final p = painter;
    context.pushClipRRect(needsCompositing, offset, Offset.zero & size, radius.toRRect(Offset.zero & size), (context, offset) {
      context.canvas
        ..save()
        ..translate(offset.dx, offset.dy);
      p.paint(context.canvas, size);
      context.canvas.restore();
      final mark = _mark;
      if (mark != null) {
        final g = p.geometry();
        // Not drawn where the line has no room.
        if (g.fits(size)) context.paintChild(mark, offset + g.markOrigin(size));
      }
    });
  }
}

/// Takes a drag at once, so a scroll view around the pad doesn't.
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  _EagerPanGestureRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolvePointer(event.pointer, GestureDisposition.accepted);
  }
}
