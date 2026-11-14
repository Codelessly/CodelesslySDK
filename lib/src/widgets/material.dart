// Widget recipes: material. See lib/src/render/recipe.dart.
//
// Buttons, chips, badges, bars and tiles are render objects
// (render/controls; codelessly_api docs/design/11-no-widgets.md). A divider
// is only layout and paint: a render object. A modal shows its trigger in
// place.
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show DividerProps, Node;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../render/control_theme.dart' show backdropOf, onColor, themeDataOf;
import '../render/convert.dart';
import '../render/node_tree.dart';
import '../render/recipe.dart';

/// Recipes for the material group, by node type.
final Map<String, WidgetRecipe> materialRecipes = {
  'divider': _divider,
  'verticalDivider': _divider,
  'modal': _modal,
};

Size _design(Node n) => Size(n.layout.width.value, n.layout.height.value);

/// The node's box per its fits.
void _fit(NodeBuilder b, Node n, List<RenderBox> chain) =>
    chain.add(b.fitBox('fit', n.layout.width.fit, n.layout.height.fit, _design(n)));

Color? _color(api.Color? c) => c?.flutter;

/// The types whose island takes a tap itself and reports it as the node's
/// `click` (the node's own tap layer leaves it to them).
const Set<String> selfTappedTypes = {
  'elevatedButton', 'filledButton', 'textButton', 'outlinedButton', 'iconButton', 'floatingActionButton', //
  'chip', 'actionChip', 'choiceChip', 'filterChip', 'inputChip',
};

// --- buttons ------------------------------------------------------------------
//
// Buttons are render objects: render/controls/buttons.dart.

/// A control's label color when its node sets none: its own text style's,
/// else one that reads on its own [background] when it has one; null
/// leaves it to the theme, made for what the control is drawn on.
Color? labelColor(api.Color? foreground, api.TextStyle? label, api.Color? background) {
  final own = _color(foreground) ?? label?.color?.flutter;
  if (own != null) return own;
  final fill = _color(background);
  return fill != null && fill.a > .9 ? onColor(fill) : null;
}

// --- badge --------------------------------------------------------------------
//
// Badges are render objects: render/controls/chips.dart.

/// The neutral colors (no theme reaches a render object) for what [b]'s
/// node is drawn on.
ColorScheme _neutral(NodeBuilder b) =>
    themeDataOf(api.ThemeTokens.none, surface: backdropOf(b.source.node, b.source.parentOf, b.id)).colorScheme;

// --- divider ------------------------------------------------------------------

void _divider(NodeBuilder b, Node n, List<RenderBox> chain) {
  _fit(b, n, chain);
  final vertical = n.type == 'verticalDivider';
  chain.add(b.obtain<RenderDivider>('divider', RenderDivider.new)
    ..vertical = vertical
    ..extent = vertical ? n.layout.width.value : n.layout.height.value
    ..thickness = n.prop(DividerProps.thickness)
    // Unset: the theme's faint outline over what it's drawn on.
    ..color = _color(n.prop(DividerProps.color)) ?? _neutral(b).outlineVariant
    ..indent = n.prop(DividerProps.indent)
    ..endIndent = n.prop(DividerProps.endIndent));
}

/// Flutter's `Divider` / `VerticalDivider`: [extent] across, as long as
/// allowed, with a [thickness] line through its middle.
class RenderDivider extends RenderBox {
  bool _vertical = false;
  set vertical(bool v) {
    if (v == _vertical) return;
    _vertical = v;
    markNeedsLayout();
  }

  double _extent = 16;
  set extent(double v) {
    if (v == _extent) return;
    _extent = v;
    markNeedsLayout();
  }

  double _thickness = 1;
  set thickness(double v) {
    if (v == _thickness) return;
    _thickness = v;
    markNeedsPaint();
  }

  Color _color = const Color(0xFFD1D1D1);
  set color(Color v) {
    if (v == _color) return;
    _color = v;
    markNeedsPaint();
  }

  double _indent = 0, _endIndent = 0;
  set indent(double v) {
    if (v == _indent) return;
    _indent = v;
    markNeedsLayout();
  }

  set endIndent(double v) {
    if (v == _endIndent) return;
    _endIndent = v;
    markNeedsLayout();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    // SizedBox(extent) around a Center: as long as the constraints allow.
    final along = _vertical ? constraints.maxHeight : constraints.maxWidth;
    final length = along.isFinite ? along : _indent + _endIndent;
    return _vertical
        ? constraints.constrain(Size(_extent, length))
        : constraints.constrain(Size(length, _extent));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_thickness <= 0) return;
    final paint = Paint()..color = _color;
    final Rect r;
    if (_vertical) {
      final x = (size.width - _thickness) / 2;
      r = Rect.fromLTRB(x, _indent, x + _thickness, math.max(_indent, size.height - _endIndent));
    } else {
      final y = (size.height - _thickness) / 2;
      r = Rect.fromLTRB(_indent, y, math.max(_indent, size.width - _endIndent), y + _thickness);
    }
    context.canvas.drawRect(r.shift(offset), paint);
  }
}

// --- modal --------------------------------------------------------------------

/// A modal shows its trigger in place (the content opens in a dialog at
/// runtime).
void _modal(NodeBuilder b, Node n, List<RenderBox> chain) {
  final stack = b.obtain<RenderStack>('trigger',
      () => RenderStack(
          alignment: AlignmentDirectional.topStart,
          textDirection: TextDirection.ltr,
          clipBehavior: Clip.none,
          // The trigger gets the modal's own constraints, built
          // in the modal's place.
          fit: StackFit.passthrough));
  final trigger = n.slots['trigger'];
  b.syncChildren(stack, [?trigger], Slot(SlotKind.root, n));
  chain.add(stack);
}
