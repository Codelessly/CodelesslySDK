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
        AppBarProps,
        DividerProps,
        Json,
        ListTileProps,
        NavigationBarProps,
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
  'listTile': _listTile,
  'appBar': _appBar,
  'navigationBar': _navigationBar,
  'bottomNavigationBar': _navigationBar,
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

TextStyle? _textStyle(api.TextStyle s, [api.TextStyle? inherited]) => s.isEmpty ? null : textStyle(s, inherited);

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
      titleTextStyle: themeFont(context, _textStyle(n.prop(AppBarProps.titleTextStyle), n.behaviors.defaultTextStyle)),
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
    // A bottom app bar needs a Scaffold, on the design canvas too.
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
  // Labels without a color in the theme's (Flutter's bar drops its own for
  // a style without one).
  final scheme = Theme.of(context).colorScheme;
  TextStyle label0(TextStyle s, Color c) => s.color == null ? s.copyWith(color: c) : s;
  final label = label0(
      themeFont(context, textStyle(n.prop(NavigationBarProps.labelTextStyle), n.behaviors.defaultTextStyle))!,
      scheme.onSurfaceVariant);
  final selectedLabel = label0(
      themeFont(context, textStyle(n.prop(NavigationBarProps.selectedLabelTextStyle), n.behaviors.defaultTextStyle))!,
      scheme.onSurface);
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
      selectedLabelStyle: themeFont(context, textStyle(uncolored(selectedLabel), n.behaviors.defaultTextStyle)),
      unselectedLabelStyle: themeFont(context, textStyle(uncolored(label), n.behaviors.defaultTextStyle)),
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
