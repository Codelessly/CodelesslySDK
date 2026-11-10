// Islands of the collections group: tabs, tab bars, accordions and
// expansion tiles are material controls, built with Flutter's widgets as
// SDK 8.x built them. Their child nodes go back in as NodeChild boxes.
import 'dart:math' as math;

import 'package:codelessly_api_v2/codelessly_api.dart' as api;
import 'package:codelessly_api_v2/codelessly_api.dart'
    show Json, Node, SizeFit, TabsProps, TabBarProps, AccordionProps, ExpansionTileProps, readDouble;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../render/convert.dart';
import '../render/paint/icon_glyph.dart';
import '../render/recipe.dart';

Size _designSize(Node n) => Size(n.layout.width.value, n.layout.height.value);

/// SDK 8.x's AdaptiveNodeBox: the node's fits at its design size.
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
    final color = n.prop(TabBarProps.indicatorColor).flutter;
    final radius = n.prop(TabBarProps.indicatorRadius);
    final weight = n.prop(TabBarProps.indicatorWeight);
    final style = n.prop(TabBarProps.indicatorStyle);
    ShapeBorder shape({double borderWidth = 0}) => _shape(
      n.prop(TabBarProps.indicatorShape),
      radius.flutter,
      side: borderWidth > 0 ? BorderSide(color: color, width: borderWidth) : BorderSide.none,
    );
    return switch (style) {
      api.TabIndicatorStyle.underline =>
        radius.isZero
            ? null
            : UnderlineTabIndicator(
                borderRadius: radius.flutter,
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
      indicatorColor: n.prop(TabBarProps.indicatorColor).flutter,
      indicatorPadding: n.prop(TabBarProps.indicatorPadding).flutter,
      indicatorSize: TabBarIndicatorSize.values.byName(n.prop(TabBarProps.indicatorSize).name),
      isScrollable: isScrollable,
      indicatorWeight: indicator != null ? 0 : n.prop(TabBarProps.indicatorWeight),
      labelStyle: textStyle(n.prop(TabBarProps.labelStyle)),
      unselectedLabelStyle: textStyle(n.prop(TabBarProps.unselectedLabelStyle)),
      indicator: indicator,
      splashBorderRadius: n.prop(TabBarProps.indicatorRadius).flutter,
      splashFactory: NoSplash.splashFactory,
      labelColor: n.prop(TabBarProps.labelColor)?.flutter,
      unselectedLabelColor: n.prop(TabBarProps.unselectedLabelColor)?.flutter,
      labelPadding: n.prop(TabBarProps.labelPadding).flutter,
      tabs: [for (final t in n.prop(TabBarProps.tabs)) _tab(n, t)],
    );
  }
}

/// A shape by its v1 name (`CShapeBorder`), rounded by [radius].
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
    ..icon = icon
    ..color = _color;

  @override
  void updateRenderObject(BuildContext context, RenderIconGlyph renderObject) => renderObject
    ..icon = icon
    ..color = _color;
}

// --- accordion --------------------------------------------------------------

/// The header (first child) with a toggle button over its end, and the
/// content (second child) below it while expanded.
void accordionRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  _adaptiveBox(b, n, chain);
  String? at(int i) {
    final id = n.children.elementAtOrNull(i);
    return id != null && b.nodeOf(id) != null ? id : null;
  }

  final top = at(0), bottom = at(1);
  chain.add(
    b.island(
      'accordion',
      (context) => _Accordion(
        expanded: n.prop(AccordionProps.expanded),
        interactive: b.tree.islands.environment.interactive,
        mainAxisAlignment: mainAxisAlignment(n.prop(AccordionProps.mainAxisAlignment)),
        crossAxisAlignment: crossAxisAlignment(n.prop(AccordionProps.crossAxisAlignment)),
        top: top == null ? const SizedBox.shrink() : _child(b, top),
        bottom: bottom == null ? const SizedBox.shrink() : _child(b, bottom),
      ),
    ),
  );
}

class _Accordion extends StatefulWidget {
  const _Accordion({
    required this.expanded,
    required this.interactive,
    required this.mainAxisAlignment,
    required this.crossAxisAlignment,
    required this.top,
    required this.bottom,
  });
  final bool expanded, interactive;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final Widget top, bottom;

  @override
  State<_Accordion> createState() => _AccordionState();
}

class _AccordionState extends State<_Accordion> {
  late bool expanded = widget.expanded;

  @override
  void didUpdateWidget(covariant _Accordion old) {
    super.didUpdateWidget(old);
    if (old.expanded != widget.expanded) expanded = widget.expanded;
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: widget.mainAxisAlignment,
    crossAxisAlignment: widget.crossAxisAlignment,
    children: [
      Stack(
        children: [
          widget.top,
          Positioned(
            right: 8,
            top: 8,
            bottom: 8,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: TextButton(
                  onPressed: () {
                    if (widget.interactive) setState(() => expanded = !expanded);
                  },
                  child: Icon(expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up),
                ),
              ),
            ),
          ),
        ],
      ),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) => SizeTransition(sizeFactor: animation, child: child),
        child: expanded ? Center(child: widget.bottom) : const SizedBox(),
      ),
    ],
  );
}

// --- expansion tile ---------------------------------------------------------

/// On a design canvas (not interactive), SDK 8.x's placeholder at the
/// node's design size; running, a Flutter `ExpansionTile` whose header is
/// the `tile` slot's list tile parts.
void expansionTileRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  if (!b.tree.islands.environment.interactive) {
    final size = _designSize(n);
    chain.add(
      b.obtain<RenderConstrainedBox>(
        'strict',
        () => RenderConstrainedBox(additionalConstraints: BoxConstraints.tight(size)),
      )..additionalConstraints = BoxConstraints.tight(size),
    );
    chain.add(
      b.obtain<RenderCustomPaint>('placeholder', RenderCustomPaint.new)
        ..painter = _PlaceholderPainter(label: 'Expansion Tile'),
    );
    return;
  }
  _adaptiveBox(b, n, chain);
  final tile = b.nodeOf(n.slots['tile'] ?? '');
  Widget? part(String slot) {
    final id = tile?.slots[slot];
    if (id == null || b.nodeOf(id) == null) return null;
    final node = b.nodeOf(id)!;
    return SizedBox(width: node.layout.width.value, height: node.layout.height.value, child: _child(b, id));
  }

  final p = n.props;
  final affinity = n.prop(ExpansionTileProps.controlAffinity) == api.ListTileControlAffinity.leading
      ? ListTileControlAffinity.leading
      : ListTileControlAffinity.trailing;
  final radius = n.prop(ExpansionTileProps.radius).flutter;
  final density = n.prop(ExpansionTileProps.visualDensity);
  final align = n.prop(ExpansionTileProps.expandedAlignment);
  final cross = n.prop(ExpansionTileProps.expandedCrossAxisAlignment);
  chain.add(
    b.island('expansionTile', (context) {
      final theme = Theme.of(context);
      return Theme(
        data: theme.copyWith(
          visualDensity: density == null ? null : VisualDensity(horizontal: density.dx, vertical: density.dy),
          dividerColor: p.get(ExpansionTileProps.showDividers) ? null : Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: p.get(ExpansionTileProps.initiallyExpanded),
          maintainState: p.get(ExpansionTileProps.maintainState),
          showTrailingIcon: p.get(ExpansionTileProps.showTrailingIcon),
          shape: switch (p.get(ExpansionTileProps.shape)) {
            final String s => _shape(s, radius),
            null => null,
          },
          collapsedShape: switch (p.get(ExpansionTileProps.collapsedShape)) {
            final String s => _shape(s, radius),
            null => null,
          },
          tilePadding: p.get(ExpansionTileProps.tilePadding)?.flutter,
          childrenPadding: p.get(ExpansionTileProps.childrenPadding)?.flutter,
          expandedAlignment: align?.flutter,
          expandedCrossAxisAlignment: cross == null ? null : crossAxisAlignment(cross),
          backgroundColor: p.get(ExpansionTileProps.backgroundColor)?.flutter,
          collapsedBackgroundColor: p.get(ExpansionTileProps.collapsedBackgroundColor)?.flutter,
          iconColor: p.get(ExpansionTileProps.iconColor)?.flutter,
          collapsedIconColor: p.get(ExpansionTileProps.collapsedIconColor)?.flutter,
          textColor: p.get(ExpansionTileProps.textColor)?.flutter,
          collapsedTextColor: p.get(ExpansionTileProps.collapsedTextColor)?.flutter,
          controlAffinity: affinity,
          leading: part('leading'),
          title: part('title') ?? const SizedBox.shrink(),
          subtitle: part('subtitle'),
          trailing: part('trailing'),
          children: [
            for (final c in n.children)
              if (b.nodeOf(c) != null) _child(b, c),
          ],
        ),
      );
    }),
  );
}

/// SDK 8.x's preview placeholder: a tinted box, a dashed inner outline and
/// the type's name.
class _PlaceholderPainter extends CustomPainter {
  _PlaceholderPainter({required this.label});
  final String label;

  static const _bg = Color(0x265C69E5);
  static const _dash = Color(0xFFADB3F1);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = _bg;
    var outerW = size.width - 4, outerH = size.height - 4;
    var outerL = 2.0, outerT = 2.0;
    if (outerW <= 1) (outerW, outerT) = (size.width, 0);
    if (outerH <= 1) (outerH, outerL) = (size.height, 0);
    canvas.drawRect(Rect.fromLTWH(outerL, outerT, outerW, outerH), bg);
    final inner = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    canvas.drawRect(inner, bg);
    final dash = Paint()
      ..color = _dash
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()..addRect(inner);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 12) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 6, metric.length)), dash);
      }
    }
    final maxW = size.width - 8, maxH = size.height - 8;
    final text = TextPainter(
      text: TextSpan(text: label, style: const TextStyle(fontSize: 14)),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxW < 100 ? 100 : double.infinity);
    final scale = math.min(1.0, math.min(maxW / text.width, maxH / text.height));
    if (!scale.isFinite || scale <= 0) return;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlaceholderPainter old) => old.label != label;
}
