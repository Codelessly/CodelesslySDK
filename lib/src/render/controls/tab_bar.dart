// Tab bars as render objects: `tabBar` (Flutter's `TabBar`: labels only)
// and `tabs` (a tab bar over its selected child), with no Material widget
// in their path. Unstyled, the bar is SSUI's Tabs (design_systems/ssui/
// components/Tabs.json):
//
// | Part | SSUI | Prop over it |
// |---|---|---|
// | bar | 36 high when it hugs (`sizes.panelHeader`), 12 px side padding, a 1 px `primaryBorder` hairline along the bottom | node padding, `dividerColor`, `dividerHeight` |
// | tabs | as wide as their label, 16 apart from the start | `tabAlignment` (fill, center, start, startOffset), `labelPadding`, `isScrollable` |
// | label | 12 px, weight 500, `secondaryText`; selected: weight 600, `primaryText`; hovered: `primaryText` | `labelStyle`, `unselectedLabelStyle`, `labelColor`, `unselectedLabelColor` |
// | indicator | a 2 px `primary` underline the label's width, rounded 1 px on top, over the hairline | `indicatorStyle` (underline, filled, border, none), `indicatorColor`, `indicatorWeight`, `indicatorSize`, `indicatorPadding`, `indicatorShape`, `indicatorRadius` |
//
// The indicator moves between tabs over SSUI's 150 ms ease (on a ticker of
// the bar's own); a bar whose tabs overflow its width scrolls (drag, mouse
// wheel, and to the tab the keyboard or a tap picks). Left and Right move
// the keyboard between tabs, Enter and Space pick one; each tab is a
// `SemanticsRole.tab` node with its selected state. Picking a tab fires the
// node's `changed` with its index (a bound `initialIndex` follows it).
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Json, Node, TabBarProps, TabsProps;
import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

import '../convert.dart';
import '../node_tree.dart' show NodeBox, Slot, SlotKind, fireTrigger;
import '../recipe.dart';
import 'kit.dart';
import 'kit_bars.dart';
import 'tokens.dart';

// --- recipes ------------------------------------------------------------------------

/// The recipe of `tabBar`: lib/src/widgets/controls.dart registers it.
void tabBarRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  final l = n.layout;
  chain.add(b.fitBox('fit', controlFit(l.width), controlFit(l.height), Size(l.width.value, l.height.value)));
  final tabs = n.prop(TabBarProps.tabs);
  final bar = b.obtain<RenderTabBar>('tabBar', RenderTabBar.new);
  _wire(b, bar, TabBarSpec.of(n, ControlTokens.of(b), inherited: b.slot.textDefault ?? n.behaviors.defaultTextStyle),
      tabs.isEmpty ? 0 : n.prop(TabBarProps.initialIndex).clamp(0, tabs.length - 1));
  chain.add(bar);
}

/// The recipe of `tabs`: a tab bar of its `titles` over its selected child
/// (lib/src/widgets/controls.dart registers it).
void tabsRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  final l = n.layout;
  chain.add(b.fitBox('fit', controlFit(l.width), controlFit(l.height), Size(l.width.value, l.height.value)));
  final titles = n.prop(TabsProps.titles);
  final count = math.min(titles.length, n.children.length);
  final tokens = ControlTokens.of(b);
  final box = b.obtain<RenderTabs>('tabs', RenderTabs.new);
  _wire(b, box.bar, TabBarSpec.titles(titles.take(count).toList(), tokens, inherited: b.slot.textDefault ?? n.behaviors.defaultTextStyle),
      count == 0 ? 0 : n.prop(TabsProps.initialIndex).clamp(0, count - 1));
  final shown = <String>[], tabOf = <int>[];
  for (var i = 0; i < count; i++) {
    final id = n.children[i];
    if (b.nodeOf(id) == null) continue;
    shown.add(id);
    tabOf.add(i);
  }
  box.tabOfChild = tabOf;
  b.syncChildren(box, shown, Slot(SlotKind.root, n));
  chain.add(box);
}

void _wire(NodeBuilder b, RenderTabBar bar, TabBarSpec spec, int index) {
  final interactive = b.tree.animates;
  bar
    ..interactive = interactive
    ..spec = spec
    ..propIndex = index
    ..onSelected = interactive ? (i) => fireTrigger(b, 'changed', event: {'value': i}) : null;
  if (interactive && b is NodeBox) {
    final node = b;
    node.outsideHitTest = (result, position) {
      if (!bar.hitTestTarget(result, node.localToGlobal(position))) return false;
      result.add(BoxHitTestEntry(node, position));
      return true;
    };
  }
}

// --- what a tab bar shows ---------------------------------------------------------------

const _deep = DeepCollectionEquality();

/// A tab bar resolved from its node and tokens: everything but its state.
@immutable
class TabBarSpec {
  const TabBarSpec({
    required this.tokens,
    required this.labels,
    this.icons = const [],
    this.content = api.TabContent.labelAndIcon,
    this.iconAbove = false,
    this.gap,
    this.scrollable = false,
    this.alignment,
    this.padding,
    this.labelPadding = EdgeInsets.zero,
    this.indicatorStyle = api.TabIndicatorStyle.underline,
    this.indicatorColor,
    this.indicatorWeight = 2,
    this.indicatorToTab = false,
    this.indicatorPadding = EdgeInsets.zero,
    this.indicatorShape = 'roundedRectangle',
    this.indicatorRadius,
    this.labelColor,
    this.unselectedLabelColor,
    this.labelStyle = const TextStyle(),
    this.unselectedLabelStyle = const TextStyle(),
    this.overlayColor,
    this.dividerColor,
    this.dividerHeight,
  });

  final ControlTokens tokens;
  final List<String> labels;

  /// One per tab (empty: none).
  final List<Json> icons;
  final api.TabContent content;

  /// The icon above the label (`iconDirection: vertical`).
  final bool iconAbove;

  /// Between a tab's icon and label (null: SSUI's 6).
  final double? gap;
  final bool scrollable;

  /// Null: SSUI's (from the start, 16 apart).
  final api.TabAlignment? alignment;

  /// The node's padding (null: SSUI's 12 at the sides).
  final EdgeInsets? padding;
  final EdgeInsets labelPadding;
  final api.TabIndicatorStyle indicatorStyle;
  final Color? indicatorColor;
  final double indicatorWeight;

  /// The indicator spans the tab (`indicatorSize: tab`), else its label.
  final bool indicatorToTab;
  final EdgeInsets indicatorPadding;
  final String indicatorShape;

  /// Null: SSUI's (an underline rounded 1 px on top; square otherwise).
  final BorderRadius? indicatorRadius;
  final Color? labelColor, unselectedLabelColor;
  final TextStyle labelStyle, unselectedLabelStyle;
  final Color? overlayColor;
  final Color? dividerColor;
  final double? dividerHeight;

  /// [n]'s tab bar, drawn with [tokens]; [inherited] is the default text
  /// style it is under.
  factory TabBarSpec.of(Node n, ControlTokens tokens, {api.TextStyle? inherited}) {
    final tabs = n.prop(TabBarProps.tabs);
    final padding = n.layout.padding;
    return TabBarSpec(
      tokens: tokens,
      labels: [for (final t in tabs) t['label'] is String ? t['label'] as String : ''],
      icons: [for (final t in tabs) barGlyph(t['icon'])],
      content: n.prop(TabBarProps.content),
      iconAbove: n.prop(TabBarProps.iconDirection) == api.Axis.vertical,
      gap: n.props.has(TabBarProps.gap) ? n.prop(TabBarProps.gap) : null,
      scrollable: n.prop(TabBarProps.isScrollable),
      alignment: n.prop(TabBarProps.tabAlignment),
      padding: padding == api.EdgeInsets.zero ? null : padding.flutter,
      labelPadding: n.prop(TabBarProps.labelPadding).flutter,
      indicatorStyle: n.prop(TabBarProps.indicatorStyle),
      indicatorColor: n.prop(TabBarProps.indicatorColor)?.flutter,
      indicatorWeight: n.prop(TabBarProps.indicatorWeight),
      indicatorToTab: n.prop(TabBarProps.indicatorSize) == api.TabBarIndicatorSize.tab,
      indicatorPadding: n.prop(TabBarProps.indicatorPadding).flutter,
      indicatorShape: n.prop(TabBarProps.indicatorShape),
      indicatorRadius: n.props.has(TabBarProps.indicatorRadius) ? n.prop(TabBarProps.indicatorRadius).flutter : null,
      labelColor: n.prop(TabBarProps.labelColor)?.flutter,
      unselectedLabelColor: n.prop(TabBarProps.unselectedLabelColor)?.flutter,
      labelStyle: barTextStyle(n.prop(TabBarProps.labelStyle), inherited),
      unselectedLabelStyle: barTextStyle(n.prop(TabBarProps.unselectedLabelStyle)),
      overlayColor: n.prop(TabBarProps.overlayColor)?.flutter,
      dividerColor: n.prop(TabBarProps.dividerColor)?.flutter,
      dividerHeight: n.prop(TabBarProps.dividerHeight),
    );
  }

  /// A bar of [titles] with nothing else set (a `tabs` node's).
  factory TabBarSpec.titles(List<String> titles, ControlTokens tokens, {api.TextStyle? inherited}) => TabBarSpec(
        tokens: tokens,
        labels: titles,
        labelStyle: inherited == null ? const TextStyle() : barTextStyle(api.TextStyle.empty, inherited),
      );

  int get length => labels.length;

  bool showsIcon(int i) => content != api.TabContent.label && i < icons.length && icons[i].isNotEmpty;
  bool showsLabel(int i) => content != api.TabContent.icon || !showsIcon(i);

  List<Object?> get _fields => [
        tokens.theme, tokens.dark, tokens.backdrop, labels, icons, content, iconAbove, gap, scrollable, alignment, //
        padding, labelPadding, indicatorStyle, indicatorColor, indicatorWeight, indicatorToTab, indicatorPadding,
        indicatorShape, indicatorRadius, labelColor, unselectedLabelColor, labelStyle, unselectedLabelStyle,
        overlayColor, dividerColor, dividerHeight,
      ];

  @override
  bool operator ==(Object other) => other is TabBarSpec && _deep.equals(other._fields, _fields);

  @override
  int get hashCode => Object.hash(length, content, alignment, labelColor);
}

// --- the tab bar ------------------------------------------------------------------------

/// A tab bar: its tabs, the selection indicator and the hairline below, in
/// the states [RenderItemBar] resolves.
class RenderTabBar extends RenderItemBar implements LabeledControl {
  RenderTabBar();

  final List<ControlLabel> _labels = [];

  TabBarSpec? _spec;
  TabBarSpec get spec => _spec!;
  set spec(TabBarSpec v) {
    if (v == _spec) return;
    _spec = v;
    while (_labels.length > v.length) {
      _labels.removeLast().dispose();
    }
    while (_labels.length < v.length) {
      _labels.add(ControlLabel());
    }
    syncGlyphs([for (var i = 0; i < v.length; i++) v.showsIcon(i) ? v.icons[i] : const <String, Object?>{}]);
    motion.duration = Duration(milliseconds: v.tokens.controlMs);
    if (selectedIndex >= v.length) selectedIndex = math.max(0, v.length - 1);
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  int? _propIndex;

  /// The index the node gives (`initialIndex`, perhaps bound): the bar
  /// selects it whenever it changes, and keeps the user's pick otherwise.
  set propIndex(int v) {
    if (v == _propIndex) return;
    _propIndex = v;
    selectedIndex = v;
  }

  @override
  int get itemCount => _spec?.length ?? 0;

  @override
  String itemLabel(int i) => spec.labels[i];

  @override
  SemanticsRole? get itemRole => SemanticsRole.tab;

  @override
  void selectionChanged() {
    super.selectionChanged();
    // A selected label is heavier: the tabs are measured again.
    markNeedsLayout();
  }

  @override
  void updateGlyphColors() {
    final s = _spec;
    if (s == null) return;
    for (var i = 0; i < s.length && i < glyphs.glyphs.length; i++) {
      if (!s.showsIcon(i)) continue;
      final own = s.icons[i]['color'];
      glyphs.color(i, (own is String || own is int ? api.Color.fromJson(own)?.flutter : null) ?? labelColorOf(i));
    }
  }

  // --- geometry --------------------------------------------------------------------

  static const _ssuiSpacing = 16.0;
  static const _ssuiSidePadding = 12.0;
  static const _startOffset = 52.0;

  ControlTokens get _t => spec.tokens;
  double get _hugHeight => _t.theme.sizes['panelHeader'] ?? 36;
  EdgeInsets get _padding => spec.padding ?? const EdgeInsets.symmetric(horizontal: _ssuiSidePadding);
  double get _spacing => spec.alignment == api.TabAlignment.fill ? 0 : _ssuiSpacing;
  double get _gap => spec.gap ?? 6;
  double _iconSize(int i) => (spec.icons[i]['size'] is num) ? (spec.icons[i]['size'] as num).toDouble() : (spec.iconAbove ? 18 : 16);

  TextStyle get _base => TextStyle(
        fontFamily: _t.fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.2,
        letterSpacing: 0,
      );

  /// Tab [i]'s label style (selected or not), in [color].
  TextStyle _style(int i, Color color) {
    final selected = i == selectedIndex;
    final own = selected ? spec.labelStyle : spec.labelStyle.merge(spec.unselectedLabelStyle);
    final base = selected ? _base.copyWith(fontWeight: FontWeight.w600) : _base;
    return base.merge(own).copyWith(color: color, leadingDistribution: TextLeadingDistribution.even);
  }

  /// Tab [i]'s label color now.
  Color labelColorOf(int i) {
    final s = spec;
    if (i == selectedIndex) return s.labelStyle.color ?? s.labelColor ?? _t.onSurface;
    final own = s.unselectedLabelStyle.color ?? s.unselectedLabelColor;
    if (own != null) return own;
    return i == hoveredIndex || i == focusedIndex ? _t.onSurface : _t.secondaryText;
  }

  double _lineHeight(int i) {
    final st = _style(i, const Color(0xFF000000));
    return (st.fontSize ?? 12) * (st.height ?? 1.2);
  }

  double get _contentHeight {
    var h = 0.0;
    for (var i = 0; i < itemCount; i++) {
      final label = spec.showsLabel(i) ? _lineHeight(i) : 0.0;
      final icon = spec.showsIcon(i) ? _iconSize(i) : 0.0;
      final c = spec.iconAbove && label > 0 && icon > 0 ? icon + _gap + label : math.max(icon, label);
      h = math.max(h, c);
    }
    return h;
  }

  double get _naturalHeight => math.max(_hugHeight, _contentHeight + 16 + _padding.vertical + spec.labelPadding.vertical);

  /// Tab [i]'s content (icon and label) width.
  double _contentWidth(int i) {
    final label = spec.showsLabel(i) ? _measure(i) : 0.0;
    if (!spec.showsIcon(i)) return label;
    final icon = _iconSize(i);
    if (label == 0) return icon;
    return spec.iconAbove ? math.max(icon, label) : icon + _gap + label;
  }

  double _measure(int i) {
    _labels[i].update(spec.labels[i], _style(i, const Color(0xFF000000)));
    return _labels[i].intrinsicWidth;
  }

  double get _offsetStart => spec.alignment == api.TabAlignment.startOffset ? _startOffset : 0;

  double get _naturalWidth {
    var total = 0.0;
    for (var i = 0; i < itemCount; i++) {
      total += _contentWidth(i) + spec.labelPadding.horizontal;
    }
    if (itemCount > 1) total += _spacing * (itemCount - 1);
    return _padding.horizontal + _offsetStart + total;
  }

  @override
  double computeMinIntrinsicWidth(double height) => _naturalWidth;
  @override
  double computeMaxIntrinsicWidth(double height) => _naturalWidth;
  @override
  double computeMinIntrinsicHeight(double width) => _naturalHeight;
  @override
  double computeMaxIntrinsicHeight(double width) => _naturalHeight;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => constraints.constrain(Size(_naturalWidth, _naturalHeight));

  List<Rect> _tabs = const [], _contents = const [];
  List<double> _labelLefts = const [];
  bool _scrolls = false;
  double _scroll = 0, _maxScroll = 0;

  /// Whether its tabs scroll (they overflow it, or `isScrollable`).
  bool get scrolls => _scrolls;

  /// How far it is scrolled.
  double get scrollOffset => _scroll;

  @override
  void performLayout() {
    final c = constraints;
    final natural = _naturalWidth;
    final width = c.hasTightWidth ? c.maxWidth : c.constrainWidth(natural);
    final height = c.hasTightHeight ? c.maxHeight : c.constrainHeight(_naturalHeight);
    size = Size(width, height);
    final pad = _padding;
    final lp = spec.labelPadding;
    final n = itemCount;
    final widths = [for (var i = 0; i < n; i++) _contentWidth(i)];
    final inner = math.max(0.0, width - pad.horizontal);
    final total = natural - pad.horizontal;
    _scrolls = n > 0 && (spec.scrollable || total > inner + .5);
    _maxScroll = _scrolls ? math.max(0.0, natural - width) : 0;
    _scroll = _scroll.clamp(0, _maxScroll);
    final top = pad.top, bottom = height - pad.bottom;
    var x = pad.left;
    final tabs = <Rect>[];
    if (_scrolls) {
      x += _offsetStart;
      for (var i = 0; i < n; i++) {
        final w = widths[i] + lp.horizontal;
        tabs.add(Rect.fromLTRB(x, top, x + w, bottom));
        x += w + _spacing;
      }
    } else if (spec.alignment == api.TabAlignment.fill && n > 0) {
      final w = inner / n;
      for (var i = 0; i < n; i++) {
        tabs.add(Rect.fromLTRB(pad.left + w * i, top, pad.left + w * (i + 1), bottom));
      }
    } else {
      if (spec.alignment == api.TabAlignment.center) x += math.max(0, (inner - total) / 2);
      if (spec.alignment == api.TabAlignment.startOffset) x += _startOffset;
      for (var i = 0; i < n; i++) {
        final w = widths[i] + lp.horizontal;
        tabs.add(Rect.fromLTRB(x, top, x + w, bottom));
        x += w + _spacing;
      }
    }
    _tabs = tabs;
    final contents = <Rect>[], lefts = <double>[];
    for (var i = 0; i < n; i++) {
      final t = tabs[i];
      final area = Rect.fromLTRB(t.left + lp.left, t.top + lp.top, t.right - lp.right, t.bottom - lp.bottom);
      final w = math.min(widths[i], math.max(0.0, area.width));
      final content = Rect.fromCenter(center: area.center, width: w, height: area.height);
      contents.add(content);
      final showIcon = spec.showsIcon(i), showLabel = spec.showsLabel(i);
      final iconSize = showIcon ? _iconSize(i) : 0.0;
      var labelLeft = content.left;
      if (showLabel) {
        final labelRoom = showIcon && !spec.iconAbove ? math.max(0.0, w - iconSize - _gap) : w;
        _labels[i].update(spec.labels[i], _style(i, const Color(0xFF000000)));
        _labels[i].layout(labelRoom);
        labelLeft = spec.iconAbove || !showIcon ? content.center.dx - _labels[i].size.width / 2 : content.left + iconSize + _gap;
      }
      lefts.add(labelLeft);
      if (showIcon) {
        final Rect r;
        if (spec.iconAbove && showLabel) {
          final stack = iconSize + _gap + _lineHeight(i);
          r = Rect.fromLTWH(content.center.dx - iconSize / 2, content.center.dy - stack / 2, iconSize, iconSize);
        } else if (showLabel) {
          r = Rect.fromLTWH(content.left, content.center.dy - iconSize / 2, iconSize, iconSize);
        } else {
          r = Rect.fromCenter(center: content.center, width: iconSize, height: iconSize);
        }
        glyphs.place(i, r);
      }
    }
    _contents = contents;
    _labelLefts = lefts;
  }

  /// The vertical center of tab [i]'s label line.
  double _labelCenter(int i) {
    final c = _contents[i];
    if (spec.iconAbove && spec.showsIcon(i)) {
      final stack = _iconSize(i) + _gap + _lineHeight(i);
      return c.center.dy - stack / 2 + _iconSize(i) + _gap + _lineHeight(i) / 2;
    }
    return c.center.dy;
  }

  Offset get _shift => Offset(-_scroll, 0);

  @override
  Offset get glyphPaintShift => _shift;

  @override
  List<Rect> get itemRects => [for (final t in _tabs) t.shift(_shift)];

  /// The label boxes ([LabeledControl]: the guard measures them).
  @override
  List<({String text, String? fontFamily, List<Rect> glyphs})> get labels => !hasSize
      ? const []
      : [
          for (var i = 0; i < itemCount && i < _contents.length; i++)
            if (spec.showsLabel(i) && spec.labels[i].isNotEmpty)
              (
                text: spec.labels[i],
                fontFamily: _labels[i].fontFamily,
                glyphs: _labels[i].glyphBoxes(_labelLefts[i] - _scroll, _labelCenter(i)),
              ),
        ];

  // --- the indicator ------------------------------------------------------------------

  Color get indicatorColor => spec.indicatorColor ?? _t.primary;

  /// Where the indicator of tab [i] sits (unscrolled).
  Rect _indicatorFor(int i) {
    final tab = _tabs[i];
    final base = spec.indicatorToTab ? tab : Rect.fromLTRB(_contents[i].left, tab.top, _contents[i].right, tab.bottom);
    final r = spec.indicatorPadding.deflateRect(base);
    if (spec.indicatorStyle == api.TabIndicatorStyle.underline) {
      return Rect.fromLTRB(r.left, r.bottom - spec.indicatorWeight, r.right, r.bottom);
    }
    return r;
  }

  /// Where the selected tab's indicator is drawn now (scrolled), mid-move
  /// included; null: none.
  Rect? get indicatorRect {
    if (!hasSize || spec.indicatorStyle == api.TabIndicatorStyle.none) return null;
    final i = selectedIndex;
    if (i < 0 || i >= _tabs.length) return null;
    return motion.at(_indicatorFor(i)).shift(_shift);
  }

  @override
  Rect? get indicatorRectNow => indicatorRect?.shift(-_shift);

  BorderRadius get _indicatorRadius =>
      spec.indicatorRadius ??
      (spec.indicatorStyle == api.TabIndicatorStyle.underline
          ? const BorderRadius.vertical(top: Radius.circular(1))
          : BorderRadius.circular(_t.radiusFor(ControlScale.compact)));

  ShapeBorder _indicatorShape({BorderSide side = BorderSide.none}) {
    final radius = _indicatorRadius;
    return switch (spec.indicatorShape) {
      'circle' => CircleBorder(side: side),
      'stadium' => StadiumBorder(side: side),
      'beveledRectangle' => BeveledRectangleBorder(borderRadius: radius, side: side),
      'continuousRectangle' => ContinuousRectangleBorder(borderRadius: radius, side: side),
      _ => RoundedRectangleBorder(borderRadius: radius, side: side),
    };
  }

  // --- scrolling ------------------------------------------------------------------------

  /// Scrolls by [delta] (clamped).
  void scrollBy(double delta) {
    final to = (_scroll + delta).clamp(0.0, _maxScroll);
    if (to == _scroll) return;
    _scroll = to;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void revealItem(int i) {
    if (!_scrolls || i < 0 || i >= _tabs.length || !hasSize) return;
    final t = _tabs[i];
    final pad = _padding;
    if (t.left - _scroll < pad.left) scrollBy(t.left - pad.left - _scroll);
    if (t.right - _scroll > size.width - pad.right) scrollBy(t.right - (size.width - pad.right) - _scroll);
  }

  @override
  void describeScrollSemantics(SemanticsConfiguration config) {
    if (!_scrolls) return;
    if (_scroll > 0) config.onScrollRight = () => scrollBy(-size.width / 2);
    if (_scroll < _maxScroll) config.onScrollLeft = () => scrollBy(size.width / 2);
  }

  HorizontalDragGestureRecognizer? _drag;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    super.handleEvent(event, entry);
    if (!interactive || !_scrolls) return;
    if (event is PointerDownEvent) {
      (_drag ??= HorizontalDragGestureRecognizer(debugOwner: this)..onUpdate = (d) => scrollBy(-d.delta.dx)).addPointer(event);
    }
    if (event is PointerScrollEvent) {
      GestureBinding.instance.pointerSignalResolver.register(event, (e) {
        final s = e as PointerScrollEvent;
        scrollBy(s.scrollDelta.dx != 0 ? s.scrollDelta.dx : s.scrollDelta.dy);
      });
    }
  }

  // --- paint -----------------------------------------------------------------------------

  @override
  bool get isRepaintBoundary => false;

  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();

  /// The hairline along the bottom (null: none).
  ({Color color, double height})? get divider {
    final h = spec.dividerHeight ?? 1;
    if (h <= 0) return null;
    return (color: spec.dividerColor ?? _t.primaryBorder, height: h);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final d = divider;
    if (d != null) canvas.drawRect(Rect.fromLTWH(offset.dx, offset.dy + size.height - d.height, size.width, d.height), Paint()..color = d.color);
    if (_scrolls) {
      _clip.layer = context.pushClipRect(needsCompositing, offset, Offset.zero & size, _paintTabs, oldLayer: _clip.layer);
    } else {
      _clip.layer = null;
      _paintTabs(context, offset);
    }
  }

  void _paintTabs(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final s = spec;
    final shift = offset + _shift;
    // State layers (only when the node sets an overlay: SSUI's tabs change
    // their ink instead).
    if (s.overlayColor case final Color overlay when overlay.a > 0) {
      for (final i in {hoveredIndex, pressedIndex}) {
        if (i >= 0 && i < _tabs.length) canvas.drawRect(_tabs[i].shift(shift), Paint()..color = overlay);
      }
    }
    final ind = indicatorRect;
    if (ind != null) {
      final r = ind.shift(offset);
      final color = indicatorColor;
      switch (s.indicatorStyle) {
        case api.TabIndicatorStyle.underline:
          canvas.drawRRect(_indicatorRadius.toRRect(r), Paint()..color = color);
        case api.TabIndicatorStyle.filled:
          canvas.drawPath(_indicatorShape().getOuterPath(r), Paint()..color = color);
        case api.TabIndicatorStyle.border:
          _indicatorShape(side: BorderSide(color: color, width: s.indicatorWeight, strokeAlign: BorderSide.strokeAlignInside))
              .paint(canvas, r);
        case api.TabIndicatorStyle.none:
          break;
      }
    }
    for (var i = 0; i < itemCount && i < _contents.length; i++) {
      final color = labelColorOf(i);
      if (s.showsLabel(i)) {
        _labels[i].update(s.labels[i], _style(i, color));
        _labels[i].layout(_labels[i].size.width < 1 ? double.infinity : _laidOut(i));
        _labels[i].paint(canvas, shift.dx + _labelLefts[i], offset.dy + _labelCenter(i));
      }
    }
    glyphs.paint(context, offset, shift: _shift);
    final f = focusedIndex;
    if (focusHighlight && f >= 0 && f < _tabs.length) {
      final t = _tabs[f].shift(shift);
      final ring = Rect.fromLTRB(_contents[f].left + shift.dx - 6, t.top + 4, _contents[f].right + shift.dx + 6, t.bottom - 4);
      paintItemFocusRing(canvas, ring, _t.focusBorder, _t.radius('inner', 5));
    }
  }

  double _laidOut(int i) {
    final c = _contents[i];
    final iconW = spec.showsIcon(i) && !spec.iconAbove ? _iconSize(i) + _gap : 0.0;
    return math.max(0, c.width - iconW);
  }

  @override
  void dispose() {
    for (final l in _labels) {
      l.dispose();
    }
    _drag?.dispose();
    _clip.layer = null;
    super.dispose();
  }
}

// --- tabs: a bar over the selected child ---------------------------------------------------

/// A [RenderTabs] child's parent data.
class TabsParentData extends ContainerBoxParentData<RenderBox> {}

/// `tabs`: its [bar] across the top at the bar's own height, the child of
/// the selected tab below it in the rest (the others are kept, not shown).
class RenderTabs extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, ContainerBoxParentData<RenderBox>>, RenderBoxContainerDefaultsMixin<RenderBox, ContainerBoxParentData<RenderBox>> {
  RenderTabs() {
    adoptChild(bar);
  }

  /// The tab bar.
  final RenderTabBar bar = RenderTabBar();

  List<int> _tabOfChild = const [];

  /// The tab each child (in order) belongs to.
  set tabOfChild(List<int> v) {
    if (_listEq(v, _tabOfChild)) return;
    _tabOfChild = v;
    markNeedsLayout();
  }

  static bool _listEq(List<int> a, List<int> b) => a.length == b.length && Iterable.generate(a.length).every((i) => a[i] == b[i]);

  /// The child shown (null: none).
  RenderBox? get shown {
    var i = 0;
    for (RenderBox? c = firstChild; c != null; c = childAfter(c), i++) {
      if (i < _tabOfChild.length && _tabOfChild[i] == bar.selectedIndex) return c;
    }
    return null;
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! ContainerBoxParentData<RenderBox>) child.parentData = TabsParentData();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    bar.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    bar.detach();
  }

  @override
  void redepthChildren() {
    super.redepthChildren();
    redepthChild(bar);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    visitor(bar);
    super.visitChildren(visitor);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    visitor(bar);
    final s = shown;
    if (s != null) visitor(s);
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(bar.getMinIntrinsicWidth(height), shown?.getMinIntrinsicWidth(double.infinity) ?? 0);
  @override
  double computeMaxIntrinsicWidth(double height) => math.max(bar.getMaxIntrinsicWidth(height), shown?.getMaxIntrinsicWidth(double.infinity) ?? 0);
  @override
  double computeMinIntrinsicHeight(double width) => bar.getMinIntrinsicHeight(width) + (shown?.getMinIntrinsicHeight(width) ?? 0);
  @override
  double computeMaxIntrinsicHeight(double width) => bar.getMaxIntrinsicHeight(width) + (shown?.getMaxIntrinsicHeight(width) ?? 0);

  @override
  void performLayout() {
    final c = constraints;
    final barWidth = c.hasBoundedWidth ? c.maxWidth : bar.getMaxIntrinsicWidth(double.infinity);
    bar.layout(BoxConstraints(minWidth: barWidth, maxWidth: barWidth, maxHeight: c.maxHeight), parentUsesSize: true);
    (bar.parentData! as BoxParentData).offset = Offset.zero;
    final top = bar.size.height;
    final child = shown;
    var height = top;
    if (child != null) {
      final rest = math.max(0.0, c.maxHeight - top);
      child.layout(
          c.hasBoundedHeight
              ? BoxConstraints(minWidth: barWidth, maxWidth: barWidth, minHeight: rest, maxHeight: rest)
              : BoxConstraints(minWidth: barWidth, maxWidth: barWidth),
          parentUsesSize: true);
      (child.parentData! as BoxParentData).offset = Offset(0, top);
      height += child.size.height;
    }
    size = c.constrain(Size(barWidth, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = shown;
    if (child != null) context.paintChild(child, offset + (child.parentData! as BoxParentData).offset);
    context.paintChild(bar, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (bar.hitTest(result, position: position)) return true;
    final child = shown;
    if (child == null) return false;
    final o = (child.parentData! as BoxParentData).offset;
    return result.addWithPaintOffset(offset: o, position: position, hitTest: (r, p) => child.hitTest(r, position: p));
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    final o = (child.parentData! as BoxParentData).offset;
    transform.translateByDouble(o.dx, o.dy, 0, 1);
  }
}
