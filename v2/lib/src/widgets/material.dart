// Widget recipes: material. See lib/src/render/recipe.dart.
//
// Buttons, chips, app bars, navigation bars, list tiles and floating action
// buttons need ink and an element tree: they're islands hosting the real
// Material widgets (as SDK 8.x built them). A divider and a badge are only
// layout and paint: render objects. A modal shows its trigger in place.
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/codelessly_api.dart'
    show
        AppBarProps,
        BadgeProps,
        ButtonProps,
        ChipProps,
        DividerProps,
        FloatingActionButtonProps,
        IconButtonProps,
        Json,
        ListTileProps,
        NavigationBarProps,
        Node,
        SizeFit,
        readInt,
        readString;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../render/convert.dart';
import '../render/node_tree.dart';
import '../render/paint/icon_glyph.dart';
import '../render/recipe.dart';

/// Recipes for the material group, by node type.
final Map<String, WidgetRecipe> materialRecipes = {
  'elevatedButton': _button,
  'filledButton': _button,
  'textButton': _button,
  'outlinedButton': _button,
  'iconButton': _iconButton,
  'floatingActionButton': _fab,
  'chip': _chip,
  'actionChip': _chip,
  'choiceChip': _chip,
  'filterChip': _chip,
  'inputChip': _chip,
  'badge': _badge,
  'listTile': _listTile,
  'appBar': _appBar,
  'navigationBar': _navigationBar,
  'bottomNavigationBar': _navigationBar,
  'divider': _divider,
  'verticalDivider': _divider,
  'modal': _modal,
};

Size _design(Node n) => Size(n.layout.width.value, n.layout.height.value);

/// The node's box per its fits (SDK 8.x's AdaptiveNodeBox).
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

TextStyle? _textStyle(api.TextStyle s) => s.isEmpty ? null : textStyle(s);

void _pressed() {}

// --- buttons ------------------------------------------------------------------

void _button(NodeBuilder b, Node n, List<RenderBox> chain) {
  _fit(b, n, chain);
  chain.add(b.island('button', (context) => _buildButton(context, n)));
}

Widget _buildButton(BuildContext context, Node n) {
  final s = n.prop(ButtonProps.style);
  final padding = n.layout.padding.flutter;
  final shape = s.shape == null ? null : _shape(s.shape!);
  // An empty style is the base text style, as every v1 label had.
  final text = textStyle(s.textStyle);
  final elevation = s.elevation;
  final ButtonStyle style = switch (n.type) {
    'elevatedButton' => ElevatedButton.styleFrom(
        foregroundColor: _color(s.foregroundColor),
        backgroundColor: _color(s.backgroundColor),
        shadowColor: _color(s.shadowColor),
        elevation: elevation,
        iconColor: _color(s.iconColor),
        iconSize: s.iconSize,
        visualDensity: VisualDensity.standard,
        padding: padding,
        textStyle: text,
        minimumSize: Size.zero,
        shape: shape,
      ),
    'filledButton' => FilledButton.styleFrom(
        foregroundColor: _color(s.foregroundColor),
        backgroundColor: _color(s.backgroundColor),
        shadowColor: _color(s.shadowColor),
        elevation: elevation,
        iconColor: _color(s.iconColor),
        iconSize: s.iconSize,
        visualDensity: VisualDensity.standard,
        padding: padding,
        textStyle: text,
        minimumSize: Size.zero,
        shape: shape,
      ),
    'outlinedButton' => OutlinedButton.styleFrom(
        foregroundColor: _color(s.foregroundColor),
        backgroundColor: _color(s.backgroundColor),
        shadowColor: _color(s.shadowColor),
        elevation: elevation,
        iconColor: _color(s.iconColor),
        iconSize: s.iconSize,
        side: s.side == null ? null : BorderSide(color: _color(s.side!.color) ?? Colors.black, width: s.side!.width),
        visualDensity: VisualDensity.standard,
        padding: padding,
        textStyle: text,
        minimumSize: Size.zero,
        shape: shape,
      ),
    _ => TextButton.styleFrom(
        foregroundColor: _color(s.foregroundColor),
        backgroundColor: _color(s.backgroundColor),
        shadowColor: _color(s.shadowColor),
        elevation: elevation,
        iconColor: _color(s.iconColor),
        iconSize: s.iconSize,
        visualDensity: VisualDensity.standard,
        padding: padding,
        textStyle: text,
        minimumSize: Size.zero,
        shape: shape,
      ),
  };
  final effective = elevation == null ? style : style.copyWith(elevation: WidgetStatePropertyAll(elevation));
  final label = Text(n.prop(ButtonProps.label), textAlign: textAlign(n.prop(ButtonProps.textAlign)));
  final icon = _icon(n.prop(ButtonProps.icon), size: s.iconSize, color: _color(s.iconColor));
  Widget child = label;
  if (icon != null) {
    final gap = SizedBox(width: n.prop(ButtonProps.spacing));
    final end = n.prop(ButtonProps.iconAlignment) == api.IconAlignment.end;
    child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!end) ...[icon, gap],
        Flexible(child: label),
        if (end) ...[gap, icon],
      ],
    );
  }
  final onPressed = n.prop(ButtonProps.enabled) ? _pressed : null;
  return switch (n.type) {
    'elevatedButton' => ElevatedButton(onPressed: onPressed, style: effective, child: child),
    'filledButton' when n.prop(ButtonProps.tonal) =>
      FilledButton.tonal(onPressed: onPressed, style: effective, child: child),
    'filledButton' => FilledButton(onPressed: onPressed, style: effective, child: child),
    'outlinedButton' => OutlinedButton(onPressed: onPressed, style: effective, child: child),
    _ => TextButton(onPressed: onPressed, style: effective, child: child),
  };
}

void _iconButton(NodeBuilder b, Node n, List<RenderBox> chain) {
  _fit(b, n, chain);
  chain.add(b.island('button', (context) {
    final s = n.prop(IconButtonProps.style);
    final elevation = s.elevation;
    var style = TextButton.styleFrom(
      foregroundColor: _color(s.foregroundColor),
      backgroundColor: _color(s.backgroundColor),
      shadowColor: _color(s.shadowColor),
      elevation: elevation,
      visualDensity: VisualDensity.standard,
      padding: n.layout.padding.flutter,
      minimumSize: Size.zero,
      shape: s.shape == null ? null : _shape(s.shape!),
      textStyle: const TextStyle(),
    );
    if (elevation != null) style = style.copyWith(elevation: WidgetStatePropertyAll(elevation));
    return ElevatedButton(
      onPressed: n.prop(IconButtonProps.enabled) ? _pressed : null,
      style: style,
      child: _icon(n.prop(IconButtonProps.icon), size: s.iconSize, color: _color(s.iconColor)),
    );
  }));
}

void _fab(NodeBuilder b, Node n, List<RenderBox> chain) {
  _fixed(b, n, chain);
  chain.add(b.island('fab', (context) {
    final type = n.prop(FloatingActionButtonProps.type);
    final shape = n.prop(FloatingActionButtonProps.shape);
    final icon = _icon(n.prop(FloatingActionButtonProps.icon), color: _color(n.prop(FloatingActionButtonProps.foregroundColor)));
    final background = _color(n.prop(FloatingActionButtonProps.backgroundColor));
    final foreground = _color(n.prop(FloatingActionButtonProps.foregroundColor));
    final elevation = n.prop(FloatingActionButtonProps.elevation);
    final focusElevation = n.prop(FloatingActionButtonProps.focusElevation);
    final hoverElevation = n.prop(FloatingActionButtonProps.hoverElevation);
    final highlightElevation = n.prop(FloatingActionButtonProps.highlightElevation);
    final focusColor = _color(n.prop(FloatingActionButtonProps.focusColor));
    final hoverColor = _color(n.prop(FloatingActionButtonProps.hoverColor));
    final splashColor = _color(n.prop(FloatingActionButtonProps.splashColor));
    final s = shape == null ? null : _shape(shape);
    return switch (type) {
      api.FloatingActionButtonType.extended => FloatingActionButton.extended(
          heroTag: null,
          onPressed: _pressed,
          extendedPadding: n.prop(FloatingActionButtonProps.extendedPadding)?.flutter,
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: elevation,
          focusElevation: focusElevation,
          hoverElevation: hoverElevation,
          highlightElevation: highlightElevation,
          focusColor: focusColor,
          hoverColor: hoverColor,
          splashColor: splashColor,
          extendedIconLabelSpacing: n.prop(FloatingActionButtonProps.extendedIconLabelSpacing),
          extendedTextStyle: _textStyle(n.prop(FloatingActionButtonProps.extendedTextStyle)),
          shape: s,
          icon: icon,
          label: Text(n.prop(FloatingActionButtonProps.label)),
        ),
      api.FloatingActionButtonType.small => FloatingActionButton.small(
          heroTag: null,
          onPressed: _pressed,
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: elevation,
          focusElevation: focusElevation,
          hoverElevation: hoverElevation,
          highlightElevation: highlightElevation,
          focusColor: focusColor,
          hoverColor: hoverColor,
          splashColor: splashColor,
          shape: s,
          child: icon,
        ),
      api.FloatingActionButtonType.large => FloatingActionButton.large(
          heroTag: null,
          onPressed: _pressed,
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: elevation,
          focusElevation: focusElevation,
          hoverElevation: hoverElevation,
          highlightElevation: highlightElevation,
          focusColor: focusColor,
          hoverColor: hoverColor,
          splashColor: splashColor,
          shape: s,
          child: icon,
        ),
      api.FloatingActionButtonType.regular => FloatingActionButton(
          heroTag: null,
          onPressed: _pressed,
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: elevation,
          focusElevation: focusElevation,
          hoverElevation: hoverElevation,
          highlightElevation: highlightElevation,
          focusColor: focusColor,
          hoverColor: hoverColor,
          splashColor: splashColor,
          shape: s,
          child: icon,
        ),
    };
  }));
}

// --- chips --------------------------------------------------------------------

void _chip(NodeBuilder b, Node n, List<RenderBox> chain) {
  _fit(b, n, chain);
  chain.add(b.island('chip', (context) => Material(type: MaterialType.transparency, child: _buildChip(context, n))));
}

Widget _buildChip(BuildContext context, Node n) {
  final label = Text(n.prop(ChipProps.label));
  final labelStyle = textStyle(n.prop(ChipProps.labelStyle));
  final avatarGlyph = n.prop(ChipProps.avatar);
  final image = readString(avatarGlyph['image']);
  final Widget? avatar = image != null && avatarGlyph['codepoint'] == null
      ? CircleAvatar(backgroundImage: NetworkImage(image), onBackgroundImageError: (_, _) {})
      : _icon(avatarGlyph, size: n.prop(ChipProps.avatarSize) ?? 18, color: _color(n.prop(ChipProps.avatarColor)));
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
  final selected = n.prop(ChipProps.selected);
  final showCheckmark = n.prop(ChipProps.showCheckmark);
  final checkmarkColor = _color(n.prop(ChipProps.checkmarkColor));
  void onSelected(bool _) {}
  return switch (n.type) {
    'actionChip' => ActionChip(
        label: label,
        avatar: avatar,
        labelStyle: labelStyle,
        labelPadding: labelPadding,
        backgroundColor: background,
        side: side,
        shape: shape,
        elevation: elevation,
        shadowColor: shadow,
        padding: padding,
        tooltip: tooltip,
        autofocus: autofocus,
        onPressed: enabled ? _pressed : null,
      ),
    'choiceChip' => ChoiceChip(
        label: label,
        avatar: avatar,
        labelStyle: labelStyle,
        labelPadding: labelPadding,
        selected: selected,
        backgroundColor: background,
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
        labelStyle: labelStyle,
        labelPadding: labelPadding,
        selected: selected,
        backgroundColor: background,
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
        labelStyle: labelStyle,
        labelPadding: labelPadding,
        deleteIcon: _icon(n.prop(ChipProps.deleteIcon), size: n.prop(ChipProps.deleteIconSize) ?? 18),
        deleteIconColor: _color(n.prop(ChipProps.deleteIconColor)),
        backgroundColor: background,
        side: side,
        shape: shape,
        elevation: elevation,
        shadowColor: shadow,
        padding: padding,
        tooltip: tooltip,
        autofocus: autofocus,
        isEnabled: enabled,
        onPressed: enabled ? _pressed : null,
        onDeleted: enabled ? _pressed : null,
      ),
    _ => Chip(
        label: label,
        avatar: avatar,
        labelStyle: labelStyle,
        labelPadding: labelPadding,
        backgroundColor: background,
        side: side,
        shape: shape,
        elevation: elevation,
        shadowColor: shadow,
        padding: padding,
        autofocus: autofocus,
      ),
  };
}

// --- badge --------------------------------------------------------------------

void _badge(NodeBuilder b, Node n, List<RenderBox> chain) {
  _fit(b, n, chain);
  final count = n.prop(BadgeProps.count);
  final maxCount = n.prop(BadgeProps.maxCount);
  final label = count != null ? (count > maxCount ? '$maxCount+' : '$count') : n.prop(BadgeProps.label);
  final style = textStyle(n.prop(BadgeProps.textStyle));
  final badge = b.obtain<RenderBadge>('badge', RenderBadge.new)
    ..label = label
    ..isLabelVisible = n.prop(BadgeProps.isLabelVisible)
    ..backgroundColor = _color(n.prop(BadgeProps.backgroundColor)) ?? const Color(0xFFB3261E)
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

  Color _backgroundColor = const Color(0xFFB3261E);
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
    // Flutter's _RenderBadge: the dot's corner (the label's centre line)
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

// --- app bar ------------------------------------------------------------------

void _appBar(NodeBuilder b, Node n, List<RenderBox> chain) {
  _fit(b, n, chain);
  chain.add(b.island('appBar', (context) {
    final leading = n.prop(AppBarProps.leading);
    final leadingIcon = leading == null ? null : _icon(leading.icon, size: leading.size, color: _color(leading.color));
    final title = n.prop(AppBarProps.title);
    return AppBar(
      toolbarHeight: n.layout.height.value,
      centerTitle: n.prop(AppBarProps.centerTitle),
      leadingWidth: n.prop(AppBarProps.leadingWidth),
      leading: leadingIcon == null ? null : Center(child: leadingIcon),
      titleTextStyle: _textStyle(n.prop(AppBarProps.titleTextStyle)),
      surfaceTintColor: _color(n.prop(AppBarProps.surfaceTintColor)),
      backgroundColor: _color(n.prop(AppBarProps.backgroundColor)),
      elevation: n.prop(AppBarProps.elevation),
      automaticallyImplyLeading: n.prop(AppBarProps.automaticallyImplyLeading),
      title: title.trim().isEmpty ? null : Text(title),
      foregroundColor: _color(n.prop(AppBarProps.foregroundColor)),
      scrolledUnderElevation: n.prop(AppBarProps.scrolledUnderElevation),
      titleSpacing: n.prop(AppBarProps.titleSpacing),
      shadowColor: _color(n.prop(AppBarProps.shadowColor)),
      actions: [
        for (final a in n.prop(AppBarProps.actions))
          _icon(a.icon, size: a.size, color: _color(a.color)) ?? const SizedBox.shrink(),
      ],
    );
  }));
}

// --- navigation bars ----------------------------------------------------------

void _navigationBar(NodeBuilder b, Node n, List<RenderBox> chain) {
  _fixed(b, n, chain);
  chain.add(b.island('navigationBar', (context) {
    final w = n.layout.width, h = n.layout.height;
    double? extent(api.AxisSize s) => switch (s.fit) {
          SizeFit.hug => null,
          SizeFit.fill => double.infinity,
          _ => s.value,
        };
    // Flutter's bars need two destinations; fewer (bad or partial data) is
    // an empty bar of the node's size, never an error.
    Widget bar = n.prop(NavigationBarProps.destinations).length < 2
        ? const SizedBox.expand()
        : n.type == 'bottomNavigationBar'
            ? _bottomNavigationBar(context, n)
            : _materialNavigationBar(context, n);
    if (n.prop(NavigationBarProps.notched)) {
      bar = BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: n.prop(NavigationBarProps.notchMargin),
        clipBehavior: Clip.antiAlias,
        elevation: n.prop(NavigationBarProps.elevation),
        color: _color(n.prop(NavigationBarProps.backgroundColor)),
        child: bar,
      );
    }
    // A bottom app bar needs a Scaffold, as on SDK 8.x's design canvas.
    return Scaffold(body: SizedBox(width: extent(w), height: extent(h), child: bar));
  }));
}

Widget _navIcon(Json glyph, Color? color) => _icon(glyph, color: color) ?? const SizedBox.shrink();

Widget _materialNavigationBar(BuildContext context, Node n) {
  final notched = n.prop(NavigationBarProps.notched);
  final background = notched ? Colors.transparent : _color(n.prop(NavigationBarProps.backgroundColor));
  final behavior = switch (n.prop(NavigationBarProps.labelBehavior)) {
    api.NavigationDestinationLabelBehavior.alwaysShow => NavigationDestinationLabelBehavior.alwaysShow,
    api.NavigationDestinationLabelBehavior.alwaysHide => NavigationDestinationLabelBehavior.alwaysHide,
    api.NavigationDestinationLabelBehavior.onlyShowSelected => NavigationDestinationLabelBehavior.onlyShowSelected,
    // NavigationBar can't show only the unselected labels.
    api.NavigationDestinationLabelBehavior.onlyShowUnselected => NavigationDestinationLabelBehavior.alwaysShow,
  };
  final iconColor = _color(n.prop(NavigationBarProps.iconColor));
  final selectedIconColor = _color(n.prop(NavigationBarProps.selectedIconColor));
  final label = textStyle(n.prop(NavigationBarProps.labelTextStyle));
  final selectedLabel = textStyle(n.prop(NavigationBarProps.selectedLabelTextStyle));
  final destinations = n.prop(NavigationBarProps.destinations);
  return NavigationBarTheme(
    data: NavigationBarThemeData(
      backgroundColor: background,
      indicatorColor: _color(n.prop(NavigationBarProps.indicatorColor)),
      iconTheme: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected)
          ? IconThemeData(color: selectedIconColor, size: n.prop(NavigationBarProps.selectedIconSize))
          : IconThemeData(color: iconColor, size: n.prop(NavigationBarProps.iconSize))),
      labelBehavior: behavior,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? selectedLabel : label),
    ),
    child: NavigationBar(
      selectedIndex: destinations.isEmpty ? 0 : n.prop(NavigationBarProps.selectedIndex).clamp(0, destinations.length - 1),
      onDestinationSelected: (_) {},
      backgroundColor: background,
      elevation: notched ? 0 : n.prop(NavigationBarProps.elevation),
      height: n.layout.height.value,
      labelBehavior: behavior,
      destinations: [
        for (final d in destinations)
          NavigationDestination(
            icon: _navIcon(d.icon, _color(d.iconColor)),
            selectedIcon: d.selectedIcon == null ? null : _navIcon(d.selectedIcon!, _color(d.selectedIconColor)),
            label: d.label,
            tooltip: d.tooltip,
          ),
      ],
    ),
  );
}

Widget _bottomNavigationBar(BuildContext context, Node n) {
  final notched = n.prop(NavigationBarProps.notched);
  final label = n.prop(NavigationBarProps.labelTextStyle);
  final selectedLabel = n.prop(NavigationBarProps.selectedLabelTextStyle);
  // The label colors are the items' colors; the styles go without them.
  api.TextStyle uncolored(api.TextStyle s) =>
      api.TextStyle.fromJson({...s.toJson()}..remove('color'));
  final behavior = n.prop(NavigationBarProps.labelBehavior);
  final type = n.prop(NavigationBarProps.type);
  final background = _color(n.prop(NavigationBarProps.backgroundColor));
  final destinations = n.prop(NavigationBarProps.destinations);
  final iconSize = n.prop(NavigationBarProps.iconSize);
  return MediaQuery(
    data: MediaQuery.of(context).copyWith(padding: EdgeInsets.zero),
    child: BottomNavigationBar(
      currentIndex: destinations.isEmpty ? 0 : n.prop(NavigationBarProps.selectedIndex).clamp(0, destinations.length - 1),
      onTap: (_) {},
      type: type == api.BottomNavigationBarType.shifting ? BottomNavigationBarType.shifting : BottomNavigationBarType.fixed,
      landscapeLayout: BottomNavigationBarLandscapeLayout.values.byName(n.prop(NavigationBarProps.landscapeLayout).name),
      backgroundColor: background,
      selectedItemColor: _color(selectedLabel.color),
      unselectedItemColor: _color(label.color),
      selectedLabelStyle: textStyle(uncolored(selectedLabel)),
      unselectedLabelStyle: textStyle(uncolored(label)),
      selectedIconTheme: IconThemeData(
        color: _color(n.prop(NavigationBarProps.selectedIconColor)),
        size: n.prop(NavigationBarProps.selectedIconSize),
      ),
      unselectedIconTheme: IconThemeData(color: _color(n.prop(NavigationBarProps.iconColor)), size: iconSize),
      elevation: notched ? 0 : n.prop(NavigationBarProps.elevation),
      showSelectedLabels: behavior == api.NavigationDestinationLabelBehavior.alwaysShow ||
          behavior == api.NavigationDestinationLabelBehavior.onlyShowSelected,
      showUnselectedLabels: behavior == api.NavigationDestinationLabelBehavior.alwaysShow ||
          behavior == api.NavigationDestinationLabelBehavior.onlyShowUnselected,
      iconSize: iconSize,
      items: [
        for (final d in destinations)
          BottomNavigationBarItem(
            icon: _navIcon(d.icon, _color(d.iconColor)),
            activeIcon: d.selectedIcon == null ? null : _navIcon(d.selectedIcon!, _color(d.selectedIconColor)),
            backgroundColor:
                _color(d.backgroundColor) ?? (type == api.BottomNavigationBarType.shifting ? background : null),
            label: d.label,
            tooltip: d.tooltip,
          ),
      ],
    ),
  );
}

// --- divider ------------------------------------------------------------------

void _divider(NodeBuilder b, Node n, List<RenderBox> chain) {
  _fit(b, n, chain);
  final vertical = n.type == 'verticalDivider';
  chain.add(b.obtain<RenderDivider>('divider', RenderDivider.new)
    ..vertical = vertical
    ..extent = vertical ? n.layout.width.value : n.layout.height.value
    ..thickness = n.prop(DividerProps.thickness)
    ..color = _color(n.prop(DividerProps.color)) ?? const Color(0xFFCAC4D0)
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

  Color _color = const Color(0xFFCAC4D0);
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
          // The trigger gets the modal's own constraints, as SDK 8.x built
          // it in the modal's place.
          fit: StackFit.passthrough));
  final trigger = n.slots['trigger'];
  b.syncChildren(stack, [?trigger], Slot(SlotKind.root, n));
  chain.add(stack);
}
