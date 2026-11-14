// Widget recipes: material. See lib/src/render/recipe.dart.
//
// Chips, app bars, navigation bars and list tiles are still islands hosting
// the real Material widgets (Milestone 3 moves them to render objects:
// codelessly_api docs/design/11-no-widgets.md); buttons are render objects
// (render/controls/buttons.dart). A divider and a badge are only
// layout and paint: render objects. A modal shows its trigger in place.
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart'
    show
        BadgeProps,
        ChipProps,
        ChipVariant,
        DividerProps,
        Json,
        ListTileProps,
        Node,
        SizeFit,
        readInt,
        readString;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../render/control_theme.dart' show backdropOf, onColor, themeDataOf, themeFont;
import '../render/convert.dart';
import '../render/node_tree.dart';
import '../render/paint/icon_glyph.dart';
import '../render/paint/icon_names.dart';
import '../render/recipe.dart';
import '../runtime/http_image_loader.dart';

/// Recipes for the material group, by node type.
final Map<String, WidgetRecipe> materialRecipes = {
  'chip': _chip,
  'actionChip': _chip,
  'choiceChip': _chip,
  'filterChip': _chip,
  'inputChip': _chip,
  'badge': _badge,
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

/// An icon glyph (or an image icon's box) at [size].
Widget? _icon(Json glyph, {double? size, Color? color}) {
  if (glyph.isEmpty || glyph['show'] == false) return null;
  final codepoint = readInt(glyph['codepoint']);
  if (codepoint != null && codepoint > 0) return _GlyphIcon(glyph, size: size, color: color);
  if (readString(glyph['image']) != null) return SizedBox.square(dimension: size ?? 24);
  // A Material icon given by name alone (`{"name": "circle"}`), as a glyph
  // bound by name is: drawn from its name.
  if (readString(glyph['name']) case final String name when name.isNotEmpty) {
    return _GlyphIcon(iconWithName(glyph, name), size: size, color: color);
  }
  return null;
}

/// A font icon glyph as `Icon` lays it out (a square of the icon theme's
/// size), painted by the tree's own glyph painter.
class _GlyphIcon extends StatelessWidget {
  const _GlyphIcon(this.glyph, {this.size, this.color});
  final Json glyph;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = this.size ?? theme.size ?? 24;
    return SizedBox.square(
      dimension: size,
      child: _Glyph(glyph, color ?? theme.color ?? const Color(0xFF000000)),
    );
  }
}

class _Glyph extends LeafRenderObjectWidget {
  const _Glyph(this.glyph, this.color);
  final Json glyph;
  final Color color;

  @override
  RenderIconGlyph createRenderObject(BuildContext context) => RenderIconGlyph()
    // Outside a tree with a loader of its own, its SVG is fetched as the SDK does.
    ..imageLoader = const HttpImageLoader()
    ..icon = glyph
    ..color = color;

  @override
  void updateRenderObject(BuildContext context, RenderIconGlyph renderObject) => renderObject
    ..icon = glyph
    ..color = color;
}

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

/// [b]'s island [key]: [build] under what reports its presses.
RenderBox _pressable(NodeBuilder b, String key, WidgetBuilder build) =>
    b.island(key, (context) => _Pressable(builder: b, child: Builder(builder: build)));

class _Pressable extends StatelessWidget {
  const _Pressable({required this.builder, required this.child});
  final NodeBuilder builder;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Reports a press of the island [context] is in as its node's `click`.
VoidCallback _press(BuildContext context) => () {
      final b = context.findAncestorWidgetOfExactType<_Pressable>()?.builder;
      if (b != null) fireTrigger(b, 'click');
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

// --- chips --------------------------------------------------------------------

void _chip(NodeBuilder b, Node n, List<RenderBox> chain) {
  _fit(b, n, chain);
  chain.add(_pressable(
      b, 'chip', (context) => Material(type: MaterialType.transparency, child: _ContentWidth(child: _ChipIsland(node: n)))));
}

/// A chip at the width of its content (its check mark, avatar, label and
/// delete icon), never squeezed by a narrower node box: a selected chip's
/// check mark would cut its label. Centred in the box when it fits, from
/// the box's start when it is wider (drawn past the box's end; the node's
/// box keeps its size).
class _ContentWidth extends SingleChildRenderObjectWidget {
  const _ContentWidth({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderContentWidth(Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, _RenderContentWidth renderObject) =>
      renderObject.textDirection = Directionality.of(context);
}

class _RenderContentWidth extends RenderShiftedBox {
  _RenderContentWidth(this.textDirection) : super(null);
  TextDirection textDirection;

  @override
  void performLayout() {
    final c = constraints;
    final child = this.child;
    if (child == null) {
      size = c.smallest;
      return;
    }
    child.layout(BoxConstraints(minHeight: c.minHeight, maxHeight: c.maxHeight), parentUsesSize: true);
    size = c.constrain(child.size);
    final spare = size.width - child.size.width;
    final x = spare >= 0 ? spare / 2 : (textDirection == TextDirection.rtl ? spare : 0.0);
    (child.parentData! as BoxParentData).offset = Offset(x, (size.height - child.size.height) / 2);
  }

  @override
  double computeMinIntrinsicWidth(double height) => child?.getMinIntrinsicWidth(height) ?? 0;
  @override
  double computeMaxIntrinsicWidth(double height) => child?.getMaxIntrinsicWidth(height) ?? 0;
  @override
  double computeMinIntrinsicHeight(double width) => child?.getMinIntrinsicHeight(double.infinity) ?? 0;
  @override
  double computeMaxIntrinsicHeight(double width) => child?.getMaxIntrinsicHeight(double.infinity) ?? 0;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final s = child?.getDryLayout(BoxConstraints(minHeight: constraints.minHeight, maxHeight: constraints.maxHeight));
    return constraints.constrain(s ?? Size.zero);
  }
}

class _ChipIsland extends StatefulWidget {
  const _ChipIsland({required this.node});
  final Node node;

  @override
  State<_ChipIsland> createState() => _ChipIslandState();
}

class _ChipIslandState extends State<_ChipIsland> {
  late bool selected = widget.node.prop(ChipProps.selected);

  @override
  void didUpdateWidget(covariant _ChipIsland oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.node.prop(ChipProps.selected) != oldWidget.node.prop(ChipProps.selected) ||
        widget.node.type != oldWidget.node.type) {
      selected = widget.node.prop(ChipProps.selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final controlled = n.bind.containsKey('props.selected');
    return _buildChip(context, n, selection: controlled ? n.prop(ChipProps.selected) : selected,
        onSelected: (value) async {
      if (!controlled) setState(() => selected = value);
      final b = context.findAncestorWidgetOfExactType<_Pressable>()?.builder;
      if (b == null) return;
      // Native selection owns the pointer gesture. Report the proposed value
      // before its click so bindings and changed actions can update the model.
      await runTrigger(b, 'changed', event: {'value': value});
      if (mounted) await runTrigger(b, 'click', event: {'value': value});
    });
  }
}

Widget _buildChip(BuildContext context, Node n, {required bool selection, required ValueChanged<bool> onSelected}) {
  final label = Text(n.prop(ChipProps.label));
  // The label in the theme's font, in a color that reads on a fill the
  // node sets (else the theme's, made for what the chip sits on).
  final ownLabel = n.prop(ChipProps.labelStyle);
  var labelStyle = themeFont(context, textStyle(ownLabel, n.behaviors.defaultTextStyle))!;
  if (labelStyle.color == null) {
    // Flutter's chip drops its own label color for a style without one.
    final scheme = Theme.of(context).colorScheme;
    final fill = selection ? n.prop(ChipProps.selectedColor) ?? n.prop(ChipProps.backgroundColor) : n.prop(ChipProps.backgroundColor);
    labelStyle = labelStyle.copyWith(
      color: !n.prop(ChipProps.isEnabled)
          ? scheme.onSurface.withValues(alpha: .45)
          : labelColor(null, null, fill) ?? (selection ? scheme.onSecondaryContainer : scheme.onSurface),
    );
  }
  final avatarGlyph = n.prop(ChipProps.avatar);
  final image = readString(avatarGlyph['image']);
  final Widget? avatar = image != null && avatarGlyph['codepoint'] == null
      ? CircleAvatar(backgroundImage: NetworkImage(image), onBackgroundImageError: (_, _) {})
      : _icon(avatarGlyph, size: n.prop(ChipProps.avatarSize) ?? 18, color: _color(n.prop(ChipProps.avatarColor)));
  // A set avatar size is the avatar's box too: Material keeps an 18 px
  // slot otherwise, a gap beside a small dot.
  final avatarSize = n.prop(ChipProps.avatarSize);
  // The avatar's box; a selectable chip's checkmark is drawn in the same box
  // (75 % of it), so the size sets the checkmark's too.
  final avatarBox = avatarSize == null ? null : BoxConstraints.tight(Size.square(avatarSize));
  final sideModel = n.prop(ChipProps.side);
  final side = sideModel == null
      ? null
      : BorderSide(
          color: sideModel.color?.flutter ?? Theme.of(context).colorScheme.outlineVariant,
          width: sideModel.width,
        );
  final shapeModel = n.prop(ChipProps.shape);
  final shape = shapeModel == null ? null : _shape(shapeModel);
  final background = _color(n.prop(ChipProps.backgroundColor));
  final selectedColor = _color(n.prop(ChipProps.selectedColor));
  final elevation = n.prop(ChipProps.elevation);
  final shadow = _color(n.prop(ChipProps.shadowColor));
  final padding = n.prop(ChipProps.padding)?.flutter;
  final labelPadding = n.prop(ChipProps.labelPadding)?.flutter;
  final tooltip = n.prop(ChipProps.tooltip);
  final autofocus = n.prop(ChipProps.autofocus);
  final enabled = n.prop(ChipProps.isEnabled);
  final selected = selection;
  final showCheckmark = n.prop(ChipProps.showCheckmark);
  final checkmarkColor = _color(n.prop(ChipProps.checkmarkColor));
  // Material 3 chips paint their surface from `color` (by state), over
  // backgroundColor: give the set colours that way too, so a transparent
  // background really is transparent.
  final WidgetStateProperty<Color?>? color = background == null && selectedColor == null
      ? null
      : WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return selectedColor ?? background;
          return background;
        });
  if (n.prop(ChipProps.variant) == ChipVariant.plain) {
    return _plainChip(context, n,
        label: n.prop(ChipProps.label),
        labelStyle: labelStyle,
        avatar: avatarGlyph.isEmpty ? null : avatar,
        selected: selected,
        selectable: n.type == 'choiceChip' || n.type == 'filterChip' || n.type == 'inputChip',
        showCheckmark: showCheckmark,
        checkmarkColor: checkmarkColor,
        background: background,
        selectedColor: selectedColor,
        side: side,
        shape: shape,
        padding: padding,
        enabled: enabled,
        onSelected: onSelected);
  }
  final Widget chip = switch (n.type) {
    'actionChip' => ActionChip(
        label: label,
        avatar: avatar,
        avatarBoxConstraints: avatarBox,
        labelStyle: labelStyle,
        labelPadding: labelPadding,
        backgroundColor: background,
        color: color,
        side: side,
        shape: shape,
        elevation: elevation,
        shadowColor: shadow,
        padding: padding,
        tooltip: tooltip,
        autofocus: autofocus,
        onPressed: enabled ? _press(context) : null,
      ),
    'choiceChip' => ChoiceChip(
        label: label,
        avatar: avatar,
        avatarBoxConstraints: avatarBox,
        labelStyle: labelStyle,
        labelPadding: labelPadding,
        selected: selected,
        backgroundColor: background,
        color: color,
        selectedColor: selectedColor,
        showCheckmark: showCheckmark,
        checkmarkColor: checkmarkColor,
        side: side,
        shape: shape,
        elevation: elevation,
        shadowColor: shadow,
        padding: padding,
        tooltip: tooltip,
        autofocus: autofocus,
        onSelected: enabled ? onSelected : null,
      ),
    'filterChip' => FilterChip(
        label: label,
        avatar: avatar,
        avatarBoxConstraints: avatarBox,
        labelStyle: labelStyle,
        labelPadding: labelPadding,
        selected: selected,
        backgroundColor: background,
        color: color,
        selectedColor: selectedColor,
        showCheckmark: showCheckmark,
        checkmarkColor: checkmarkColor,
        side: side,
        shape: shape,
        elevation: elevation,
        shadowColor: shadow,
        padding: padding,
        tooltip: tooltip,
        autofocus: autofocus,
        onSelected: enabled ? onSelected : null,
      ),
    'inputChip' => InputChip(
        label: label,
        avatar: avatar,
        avatarBoxConstraints: avatarBox,
        labelStyle: labelStyle,
        labelPadding: labelPadding,
        deleteIcon: _icon(n.prop(ChipProps.deleteIcon), size: n.prop(ChipProps.deleteIconSize) ?? 18),
        deleteIconColor: _color(n.prop(ChipProps.deleteIconColor)),
        backgroundColor: background,
        color: color,
        side: side,
        shape: shape,
        elevation: elevation,
        shadowColor: shadow,
        padding: padding,
        tooltip: tooltip,
        autofocus: autofocus,
        isEnabled: enabled,
        onPressed: enabled ? _press(context) : null,
        onDeleted: enabled ? () {} : null,
      ),
    _ => Chip(
        label: label,
        avatar: avatar,
        avatarBoxConstraints: avatarBox,
        labelStyle: labelStyle,
        labelPadding: labelPadding,
        backgroundColor: background,
        color: color,
        side: side,
        shape: shape,
        elevation: elevation,
        shadowColor: shadow,
        padding: padding,
        autofocus: autofocus,
      ),
  };
  // A Material 3 chip sits on a canvas-type Material that paints the
  // theme's canvas colour under its own: with a background set (transparent
  // included), only the chip's colours show.
  if (background == null) return chip;
  return Theme(data: Theme.of(context).copyWith(canvasColor: Colors.transparent), child: chip);
}

/// [ChipVariant.plain]: exactly its padding around a check (selected), a
/// gap and the label, in its fill, side and shape; no Material spacing.
Widget _plainChip(
  BuildContext context,
  Node n, {
  required String label,
  required TextStyle labelStyle,
  required Widget? avatar,
  required bool selected,
  required bool selectable,
  required bool showCheckmark,
  required Color? checkmarkColor,
  required Color? background,
  required Color? selectedColor,
  required BorderSide? side,
  required ShapeBorder? shape,
  required EdgeInsetsGeometry? padding,
  required bool enabled,
  required ValueChanged<bool> onSelected,
}) {
  final on = selectable && selected;
  final checkSize = n.prop(ChipProps.avatarSize) ?? 13;
  final lead = on && showCheckmark
      ? Icon(Icons.check_rounded, size: checkSize, color: checkmarkColor ?? labelStyle.color)
      : avatar;
  final outline = shape is OutlinedBorder ? shape.copyWith(side: side ?? BorderSide.none) : shape;
  final Widget face = Container(
    padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: ShapeDecoration(
      color: on ? (selectedColor ?? background) : background,
      shape: outline ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: side ?? BorderSide.none),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (lead != null) ...[lead, SizedBox(width: n.prop(ChipProps.spacing))],
      Text(label, style: labelStyle),
    ]),
  );
  if (!enabled) return face;
  return Semantics(
    button: true,
    selected: selectable ? on : null,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selectable ? () => onSelected(!selected) : _press(context),
        child: face,
      ),
    ),
  );
}

// --- badge --------------------------------------------------------------------

/// The neutral colors (no theme reaches a render object) for what [b]'s
/// node is drawn on.
ColorScheme _neutral(NodeBuilder b) =>
    themeDataOf(api.ThemeTokens.none, surface: backdropOf(b.source.node, b.source.parentOf, b.id)).colorScheme;

void _badge(NodeBuilder b, Node n, List<RenderBox> chain) {
  _fit(b, n, chain);
  final count = n.prop(BadgeProps.count);
  final maxCount = n.prop(BadgeProps.maxCount);
  final label = count != null ? (count > maxCount ? '$maxCount+' : '$count') : n.prop(BadgeProps.label);
  final style = textStyle(n.prop(BadgeProps.textStyle), n.behaviors.defaultTextStyle);
  final badge = b.obtain<RenderBadge>('badge', RenderBadge.new)
    ..label = label
    ..isLabelVisible = n.prop(BadgeProps.isLabelVisible)
    ..backgroundColor = _color(n.prop(BadgeProps.backgroundColor)) ?? _neutral(b).error
    // Flutter applies textColor over the style's color.
    ..textStyle = style.copyWith(color: _color(n.prop(BadgeProps.textColor)) ?? style.color ?? const Color(0xFFFFFFFF))
    ..smallSize = n.prop(BadgeProps.smallSize)
    ..largeSize = n.prop(BadgeProps.largeSize)
    ..padding = n.prop(BadgeProps.padding).flutter
    ..badgeAlignment = n.prop(BadgeProps.alignment).flutter
    ..offset = Offset(n.prop(BadgeProps.offset).dx, n.prop(BadgeProps.offset).dy);
  final child = n.slots['child'];
  b.syncChildren(badge, [?child], Slot(SlotKind.root, n));
  chain.add(badge);
}

/// Flutter's `Badge`: [label] in a stadium (or, without a label, a dot)
/// over its child at [alignment] + [offset]; without a child, the badge
/// alone, aligned in the box.
class RenderBadge extends RenderStack {
  RenderBadge() : super(alignment: AlignmentDirectional.topStart, textDirection: TextDirection.ltr, clipBehavior: Clip.none);

  String? _label;
  set label(String? v) {
    if (v == _label) return;
    _label = v;
    _painter = null;
    markNeedsLayout();
  }

  bool _isLabelVisible = true;
  set isLabelVisible(bool v) {
    if (v == _isLabelVisible) return;
    _isLabelVisible = v;
    markNeedsLayout();
  }

  Color _backgroundColor = const Color(0xFFC4302B);
  set backgroundColor(Color v) {
    if (v == _backgroundColor) return;
    _backgroundColor = v;
    markNeedsPaint();
  }

  TextStyle _textStyle = const TextStyle();
  set textStyle(TextStyle v) {
    if (v == _textStyle) return;
    _textStyle = v;
    _painter = null;
    markNeedsLayout();
  }

  double _smallSize = 6, _largeSize = 16;
  set smallSize(double v) {
    if (v == _smallSize) return;
    _smallSize = v;
    markNeedsLayout();
  }

  set largeSize(double v) {
    if (v == _largeSize) return;
    _largeSize = v;
    markNeedsLayout();
  }

  EdgeInsets _padding = const EdgeInsets.symmetric(horizontal: 4);
  set padding(EdgeInsets v) {
    if (v == _padding) return;
    _padding = v;
    markNeedsLayout();
  }

  Alignment _alignment = Alignment.topRight;
  set badgeAlignment(Alignment v) {
    if (v == _alignment) return;
    _alignment = v;
    markNeedsLayout();
  }

  Offset _offset = const Offset(4, -4);
  set offset(Offset v) {
    if (v == _offset) return;
    _offset = v;
    markNeedsLayout();
  }

  TextPainter? _painter;
  TextPainter get _text => _painter ??= TextPainter(
        text: TextSpan(text: _label ?? '', style: _textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

  /// The badge's own size (zero when hidden).
  Size get _badgeSize {
    if (!_isLabelVisible) return Size.zero;
    if (_label == null) return Size.square(_smallSize);
    final t = _text;
    final height = math.max(_largeSize, t.height + _padding.vertical);
    return Size(math.max(t.width + _padding.horizontal, height), height);
  }

  Rect _badgeRect = Rect.zero;

  @override
  void performLayout() {
    final badge = _badgeSize;
    if (firstChild == null) {
      size = constraints.constrain(badge);
      _badgeRect = _alignment.alongOffset(Offset(size.width - badge.width, size.height - badge.height)) & badge;
      return;
    }
    super.performLayout();
    // Flutter's _RenderBadge: the dot's corner (the label's center line)
    // at the alignment point, less the badge's width offset.
    final hasLabel = _label != null;
    var at = (hasLabel ? _offset + const Offset(0, 8) : Offset.zero) +
        _alignment.alongOffset(Offset(size.width - (hasLabel ? _largeSize : _smallSize), size.height));
    if (hasLabel) at -= Offset(0, badge.height / 2);
    _badgeRect = at & badge;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      firstChild == null ? constraints.constrain(_badgeSize) : super.computeDryLayout(constraints);

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!_isLabelVisible) return;
    final r = _badgeRect.shift(offset);
    context.canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide / 2)), Paint()..color = _backgroundColor);
    if (_label != null) {
      final t = _text;
      t.paint(context.canvas, r.center - Offset(t.width / 2, t.height / 2));
    }
  }
}

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
