// Widget recipes: material. See lib/src/render/recipe.dart.
//
// App bars, navigation bars and list tiles are still islands hosting
// the real Material widgets (Milestone 3 moves them to render objects:
// codelessly_api docs/design/11-no-widgets.md); buttons, chips and badges are
// render objects (render/controls/buttons.dart, chips.dart). A divider is only
// layout and paint: render objects. A modal shows its trigger in place.
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart'
    show
        DividerProps,
        ListTileProps,
        Node,
        SizeFit;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../render/control_theme.dart' show backdropOf, onColor, themeDataOf;
import '../render/convert.dart';
import '../render/node_tree.dart';
import '../render/recipe.dart';

/// Recipes for the material group, by node type.
final Map<String, WidgetRecipe> materialRecipes = {
  'listTile': _listTile,
  'divider': _divider,
  'verticalDivider': _divider,
  'modal': _modal,
};

Size _design(Node n) => Size(n.layout.width.value, n.layout.height.value);

/// The node's box per its fits.
void _fit(NodeBuilder b, Node n, List<RenderBox> chain) =>
    chain.add(b.fitBox('fit', n.layout.width.fit, n.layout.height.fit, _design(n)));

/// The node's box at its design size, whatever its fits (StrictNodeBox).
void _fixed(NodeBuilder b, Node n, List<RenderBox> chain) =>
    chain.add(b.fitBox('fit', SizeFit.fixed, SizeFit.fixed, _design(n)));

Color? _color(api.Color? c) => c?.flutter;

OutlinedBorder _shape(api.ShapeBorder s, {Color? sideColor}) {
  final side = s.side == null
      ? BorderSide.none
      : BorderSide(color: s.side!.color?.flutter ?? sideColor ?? const Color(0xFF000000), width: s.side!.width);
  final radius = s.borderRadius.flutter;
  return switch (s.type) {
    api.ShapeBorderType.roundedRectangle => RoundedRectangleBorder(borderRadius: radius, side: side),
    api.ShapeBorderType.circle => CircleBorder(side: side),
    api.ShapeBorderType.stadium => StadiumBorder(side: side),
    api.ShapeBorderType.continuousRectangle => ContinuousRectangleBorder(borderRadius: radius, side: side),
    api.ShapeBorderType.beveledRectangle => BeveledRectangleBorder(borderRadius: radius, side: side),
    api.ShapeBorderType.roundedSuperellipse => RoundedSuperellipseBorder(borderRadius: radius, side: side),
  };
}

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

// --- list tile ----------------------------------------------------------------

void _listTile(NodeBuilder b, Node n, List<RenderBox> chain) {
  _fixed(b, n, chain);
  chain.add(b.island('tile', (context) {
    Widget? slot(String name) {
      final id = n.slots[name];
      final child = id == null ? null : b.nodeOf(id);
      if (child == null) return null;
      return SizedBox(
        width: child.layout.width.value,
        height: child.layout.height.value,
        child: NodeChild(tree: b.tree, id: id!, instance: b.instance),
      );
    }

    final shape = n.prop(ListTileProps.shape);
    final density = n.prop(ListTileProps.visualDensity);
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: null,
        dense: n.prop(ListTileProps.dense),
        autofocus: n.prop(ListTileProps.autofocus),
        tileColor: _color(n.prop(ListTileProps.tileColor)),
        isThreeLine: n.prop(ListTileProps.isThreeLine),
        shape: shape == null ? null : _shape(shape),
        selected: n.prop(ListTileProps.selected),
        selectedTileColor: _color(n.prop(ListTileProps.selectedTileColor)),
        hoverColor: _color(n.prop(ListTileProps.hoverColor)),
        focusColor: _color(n.prop(ListTileProps.focusColor)),
        enabled: n.prop(ListTileProps.enabled),
        contentPadding: n.prop(ListTileProps.contentPadding)?.flutter,
        visualDensity: density == null ? null : VisualDensity(horizontal: density.horizontal, vertical: density.vertical),
        selectedColor: _color(n.prop(ListTileProps.selectedColor)),
        iconColor: _color(n.prop(ListTileProps.iconColor)),
        textColor: _color(n.prop(ListTileProps.textColor)),
        enableFeedback: n.prop(ListTileProps.enableFeedback),
        horizontalTitleGap: n.prop(ListTileProps.horizontalTitleGap),
        minVerticalPadding: n.prop(ListTileProps.minVerticalPadding),
        minLeadingWidth: n.prop(ListTileProps.minLeadingWidth),
        minTileHeight: n.prop(ListTileProps.minTileHeight),
        titleAlignment: switch (n.prop(ListTileProps.titleAlignment)) {
          null => null,
          final a => ListTileTitleAlignment.values.byName(a.name),
        },
        leading: slot('leading'),
        title: slot('title'),
        subtitle: slot('subtitle'),
        trailing: slot('trailing'),
      ),
    );
  }));
}

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
