// Islands of the collections group: tabs, tab bars, accordions and
// expansion tiles are material controls, built with Flutter's widgets. Their child nodes go back in as NodeChild boxes.
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart'
    show Json, Node, SizeFit, TabsProps, TabBarProps, readDouble;
import 'package:flutter/material.dart';

import '../render/control_theme.dart' show themeFont;
import '../render/convert.dart';
import '../render/paint/icon_glyph.dart';
import '../render/recipe.dart';
import '../runtime/http_image_loader.dart';

Size _designSize(Node n) => Size(n.layout.width.value, n.layout.height.value);

/// The node's fits at its design size.
void _adaptiveBox(NodeBuilder b, Node n, List<RenderBox> chain) =>
    chain.add(b.fitBox('box', n.layout.width.fit, n.layout.height.fit, _designSize(n)));

/// A child node's box inside an island, in the node's scope.
Widget _child(NodeBuilder b, String id) => NodeChild(tree: b.tree, id: id, instance: b.instance);

// --- tabs -------------------------------------------------------------------

/// A `TabBar` of the titles over the selected child.
void tabsRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  _adaptiveBox(b, n, chain);
  final titles = n.prop(TabsProps.titles);
  final kids = [
    for (final c in n.children)
      if (b.nodeOf(c) != null) c,
  ];
  final count = math.min(titles.length, n.children.length);
  final initial = count == 0 ? 0 : n.prop(TabsProps.initialIndex).clamp(0, count - 1);
  chain.add(
    b.island(
      'tabs',
      (context) => _Tabs(
        titles: titles.take(count).toList(),
        children: n.children.take(count).toList(),
        initial: initial,
        build: (id) => kids.contains(id) ? _child(b, id) : null,
      ),
    ),
  );
}

class _Tabs extends StatefulWidget {
  const _Tabs({required this.titles, required this.children, required this.initial, required this.build});
  final List<String> titles;
  final List<String> children;
  final int initial;
  final Widget? Function(String id) build;

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  late int selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final count = widget.titles.length;
    final index = count == 0 ? 0 : selected.clamp(0, count - 1);
    final child = count == 0 ? null : widget.build(widget.children[index]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (count > 0)
          DefaultTabController(
            key: ValueKey(index),
            length: count,
            initialIndex: index,
            child: TabBar(
              isScrollable: false,
              tabs: [for (final t in widget.titles) Tab(text: t)],
              onTap: (i) => setState(() => selected = i),
            ),
          ),
        if (child != null) Expanded(child: child),
      ],
    );
  }
}

// --- tab bar ----------------------------------------------------------------

/// A Flutter `TabBar` at the node's design size (an expanding or hugging
/// axis takes the bar's own extent).
void tabBarRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  final w = n.layout.width, h = n.layout.height;
  final width = w.fit == SizeFit.fill || w.fit == SizeFit.hug ? null : w.value;
  final height = h.fit == SizeFit.fill || h.fit == SizeFit.hug ? null : h.value;
  chain.add(
    b.island(
      'tabBar',
      (context) => SizedBox(
        width: width,
        height: height,
        child: _TabBarIsland(node: n),
      ),
    ),
  );
}

class _TabBarIsland extends StatefulWidget {
  const _TabBarIsland({required this.node});
  final Node node;

  @override
  State<_TabBarIsland> createState() => _TabBarIslandState();
}

class _TabBarIslandState extends State<_TabBarIsland> with TickerProviderStateMixin {
  late TabController controller = _create();

  int get _length => widget.node.prop(TabBarProps.tabs).length;
  int get _initial => _length == 0 ? 0 : widget.node.prop(TabBarProps.initialIndex).clamp(0, _length - 1);

  TabController _create() => TabController(length: _length, vsync: this, initialIndex: _initial);

  @override
  void didUpdateWidget(covariant _TabBarIsland old) {
    super.didUpdateWidget(old);
    if (old.node.prop(TabBarProps.tabs).length != _length ||
        old.node.prop(TabBarProps.initialIndex) != widget.node.prop(TabBarProps.initialIndex)) {
      controller.dispose();
      controller = _create();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Decoration? _indicator(Node n) {
    final color = n.prop(TabBarProps.indicatorColor)?.flutter ??
        Theme.of(context).tabBarTheme.indicatorColor ??
        Theme.of(context).colorScheme.primary;
    final radius = n.prop(TabBarProps.indicatorRadius);
    final weight = n.prop(TabBarProps.indicatorWeight);
    final style = n.prop(TabBarProps.indicatorStyle);
    ShapeBorder shape({double borderWidth = 0}) => _shape(
      n.prop(TabBarProps.indicatorShape),
      radius.flutter,
      side: borderWidth > 0 ? BorderSide(color: color, width: borderWidth) : BorderSide.none,
    );
    return switch (style) {
      // Square ends unless a radius is set (not Material's rounded pill).
      api.TabIndicatorStyle.underline => UnderlineTabIndicator(
          borderRadius: radius.isZero ? null : radius.flutter,
          borderSide: BorderSide(color: color, width: weight),
        ),
      api.TabIndicatorStyle.filled => ShapeDecoration(color: color, shape: shape()),
      api.TabIndicatorStyle.border => ShapeDecoration(shape: shape(borderWidth: weight)),
      api.TabIndicatorStyle.none => const BoxDecoration(),
    };
  }

  Widget _tab(Node n, Json tab) {
    final label = tab['label'] is String ? tab['label'] as String : '';
    final content = n.prop(TabBarProps.content);
    final icon = tab['icon'] is Map ? (tab['icon'] as Map).cast<String, Object?>() : const <String, Object?>{};
    final iconSize = math.min(readDouble(icon['size']) ?? 24, n.layout.height.value);
    final showIcon = content != api.TabContent.label && icon.isNotEmpty && icon['show'] != false;
    final glyph = showIcon
        ? SizedBox(
            width: iconSize,
            height: iconSize,
            child: _Glyph(icon: icon),
          )
        : null;
    if (glyph == null) return Tab(text: label);
    if (content == api.TabContent.icon) return Tab(icon: glyph);
    final gap = n.prop(TabBarProps.gap);
    if (n.prop(TabBarProps.iconDirection) == api.Axis.vertical) {
      return Tab(
        text: label,
        icon: glyph,
        iconMargin: EdgeInsets.only(bottom: gap),
      );
    }
    return Tab(
      height: n.layout.height.value,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          glyph,
          SizedBox(width: gap),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final indicator = _indicator(n);
    final overlay = n.prop(TabBarProps.overlayColor)?.flutter;
    final isScrollable = n.prop(TabBarProps.isScrollable);
    return TabBar(
      controller: controller,
      padding: n.layout.padding.flutter,
      overlayColor: WidgetStateProperty.all(overlay),
      dividerColor: n.prop(TabBarProps.dividerColor)?.flutter,
      dividerHeight: n.prop(TabBarProps.dividerHeight),
      tabAlignment: switch (n.prop(TabBarProps.tabAlignment)) {
        null => null,
        api.TabAlignment.start || api.TabAlignment.startOffset when !isScrollable => TabAlignment.fill,
        final a => TabAlignment.values.byName(a.name),
      },
      indicatorColor: n.prop(TabBarProps.indicatorColor)?.flutter,
      indicatorPadding: n.prop(TabBarProps.indicatorPadding).flutter,
      indicatorSize: TabBarIndicatorSize.values.byName(n.prop(TabBarProps.indicatorSize).name),
      isScrollable: isScrollable,
      indicatorWeight: indicator != null && n.prop(TabBarProps.indicatorStyle) != api.TabIndicatorStyle.underline
          ? 0
          : n.prop(TabBarProps.indicatorWeight),
      labelStyle: themeFont(context, textStyle(n.prop(TabBarProps.labelStyle), n.behaviors.defaultTextStyle)),
      unselectedLabelStyle: themeFont(context, textStyle(n.prop(TabBarProps.unselectedLabelStyle), n.behaviors.defaultTextStyle)),
      indicator: indicator,
      splashBorderRadius: n.prop(TabBarProps.indicatorRadius).flutter,
      splashFactory: NoSplash.splashFactory,
      labelColor: n.prop(TabBarProps.labelColor)?.flutter,
      unselectedLabelColor: n.prop(TabBarProps.unselectedLabelColor)?.flutter,
      // The bar keeps the indicator's weight free under the labels; as much
      // above centres them in the bar.
      labelPadding: n.prop(TabBarProps.labelPadding).flutter +
          EdgeInsets.only(
              top: n.prop(TabBarProps.indicatorStyle) == api.TabIndicatorStyle.underline ? n.prop(TabBarProps.indicatorWeight) : 0),
      tabs: [for (final t in n.prop(TabBarProps.tabs)) _tab(n, t)],
    );
  }
}

/// A shape by its stored name (`CShapeBorder`), rounded by [radius].
ShapeBorder _shape(String name, BorderRadius radius, {BorderSide side = BorderSide.none}) => switch (name) {
  'circle' => CircleBorder(side: side),
  'stadium' => StadiumBorder(side: side),
  'beveledRectangle' => BeveledRectangleBorder(borderRadius: radius, side: side),
  'continuousRectangle' => ContinuousRectangleBorder(borderRadius: radius, side: side),
  _ => RoundedRectangleBorder(borderRadius: radius, side: side),
};

/// An icon glyph (IconProps.icon JSON) filling its box.
class _Glyph extends LeafRenderObjectWidget {
  const _Glyph({required this.icon});
  final Json icon;

  Color? get _color => api.Color.fromJson(icon['color'])?.flutter;

  @override
  RenderIconGlyph createRenderObject(BuildContext context) => RenderIconGlyph()
    // Outside a tree with a loader of its own, its SVG is fetched as the SDK does.
    ..imageLoader = const HttpImageLoader()
    ..icon = icon
    ..color = _color;

  @override
  void updateRenderObject(BuildContext context, RenderIconGlyph renderObject) => renderObject
    ..icon = icon
    ..color = _color;
}
