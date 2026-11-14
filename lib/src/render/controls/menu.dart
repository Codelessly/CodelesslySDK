// Popups and menus as render objects: what Flutter's `showMenu`,
// `PopupMenuButton`'s route, `DropdownButton`'s menu route, `ModalBarrier`
// and `CompositedTransformFollower` do, in SSUI's look (soft_saas_ui's
// `SoftSaaSPopover` and `SoftSaaSMenuList`), with no widget.
//
// Two layers, so a dialog or a sheet can reuse the first without the second:
//
// | Piece | What it does | Flutter counterpart |
// |---|---|---|
// | [ControlPopup] | shows one render box in the root's overlay layer (render/controls/overlay.dart), placed by a [PopupPosition] against an anchor it keeps following; a barrier that takes every pointer outside the box and dismisses on a press; Escape dismisses; `onDismiss` lets the owner return the focus | `ModalRoute` + `ModalBarrier` + `CompositedTransformFollower` |
// | [RenderPopupLayer] | the overlay entry itself: full root size, the barrier, the box | `_ModalScope` |
// | [AnchoredPlacement] | under the anchor, flipping above when there is no room, at least the anchor's width, kept 8 px inside the root | `_DropdownMenuRouteLayout`, `SoftSaaSPopover`'s delegate |
// | [CenteredPlacement] | centred in the root (a dialog) | `Dialog`'s `Align` |
// | [RenderMenu] | SSUI's menu surface (radius 7, `level3` shadow, hairline border, 4 px inset) and its rows, scrolling when long, with the keyboard: arrows, Home/End, Page Up/Down, type-ahead, Enter/Space | `SoftSaaSMenuList`, `_DropdownMenu` |
// | [RenderMenuRow] | one row: label (optically centred), selected tint and check, hover, press, image | `SoftSaaSMenuRow`, `DropdownMenuItem` + `InkWell` |
//
// A dropdown (render/controls/dropdown.dart) opens a [RenderMenu] in a
// [ControlPopup] anchored to its field's box.
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' show Json;
import 'package:flutter/foundation.dart' show immutable, listEquals, mapEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../paint/icon_glyph.dart';
import 'kit.dart';
import 'kit_dropdown.dart';
import 'overlay.dart';
import 'root.dart';

// --- placement ------------------------------------------------------------------

/// Where a popup's box goes in the root: its constraints and its top left,
/// given the root's [area] and the anchor's rect in it.
abstract interface class PopupPosition {
  /// The constraints the box is laid out with.
  BoxConstraints constraintsFor(Size area, Rect anchor);

  /// The box's top left, after its layout at [box].
  Offset offsetFor(Size area, Rect anchor, Size box);
}

/// Under the anchor (above when [preferAbove]), flipping to the other side
/// when the box does not fit and fits there (or has more room there), at
/// least as wide as the anchor ([matchAnchorWidth]; [width] fixes it), kept
/// [margin] inside the root: SSUI's popover placement.
@immutable
class AnchoredPlacement implements PopupPosition {
  const AnchoredPlacement({
    this.gap = 4,
    this.margin = 8,
    this.preferAbove = false,
    this.matchAnchorWidth = true,
    this.width,
    this.minWidth = 0,
    this.maxHeight = double.infinity,
    this.alignEnd = false,
  });

  /// Between the anchor and the box.
  final double gap;

  /// Kept free at the root's edges.
  final double margin;
  final bool preferAbove;

  /// The box is the anchor's width (never under [minWidth]).
  final bool matchAnchorWidth;

  /// A fixed width (over [matchAnchorWidth]).
  final double? width;
  final double minWidth;

  /// The box's own cap (the room on its side caps it too).
  final double maxHeight;

  /// The box's right edge on the anchor's (when it is wider).
  final bool alignEnd;

  double _above(Rect a) => a.top - gap - margin;
  double _below(Size area, Rect a) => area.height - a.bottom - gap - margin;

  @override
  BoxConstraints constraintsFor(Size area, Rect anchor) {
    final maxWidth = math.max(0.0, area.width - 2 * margin);
    final room = math.max(0.0, math.max(_above(anchor), _below(area, anchor)));
    final maxH = math.min(room, maxHeight);
    final fixed = width ?? (matchAnchorWidth ? math.max(anchor.width, minWidth) : null);
    if (fixed != null) {
      final w = fixed.clamp(0.0, maxWidth).toDouble();
      return BoxConstraints(minWidth: w, maxWidth: w, maxHeight: maxH);
    }
    return BoxConstraints(minWidth: math.min(minWidth, maxWidth), maxWidth: maxWidth, maxHeight: maxH);
  }

  /// Whether a box of [height] opens above the anchor.
  bool opensAbove(Size area, Rect anchor, double height) {
    final above = _above(anchor), below = _below(area, anchor);
    final fitsAbove = height <= above, fitsBelow = height <= below;
    return preferAbove ? fitsAbove || (!fitsBelow && above >= below) : !fitsBelow && (fitsAbove || above > below);
  }

  @override
  Offset offsetFor(Size area, Rect anchor, Size box) {
    final up = opensAbove(area, anchor, box.height);
    final y = up ? anchor.top - gap - box.height : anchor.bottom + gap;
    final x = alignEnd ? anchor.right - box.width : anchor.left;
    final minX = margin, maxX = area.width - margin - box.width;
    final minY = margin, maxY = area.height - margin - box.height;
    return Offset(maxX < minX ? minX : x.clamp(minX, maxX), maxY < minY ? minY : y.clamp(minY, maxY));
  }

  @override
  bool operator ==(Object other) =>
      other is AnchoredPlacement &&
      other.gap == gap &&
      other.margin == margin &&
      other.preferAbove == preferAbove &&
      other.matchAnchorWidth == matchAnchorWidth &&
      other.width == width &&
      other.minWidth == minWidth &&
      other.maxHeight == maxHeight &&
      other.alignEnd == alignEnd;

  @override
  int get hashCode => Object.hash(gap, margin, preferAbove, matchAnchorWidth, width, minWidth, maxHeight, alignEnd);
}

/// Centred in the root, at most [maxWidth] wide and kept [margin] inside it
/// (a dialog; the anchor is ignored).
@immutable
class CenteredPlacement implements PopupPosition {
  const CenteredPlacement({this.margin = 16, this.maxWidth = double.infinity});
  final double margin;
  final double maxWidth;

  @override
  BoxConstraints constraintsFor(Size area, Rect anchor) => BoxConstraints(
        maxWidth: math.max(0.0, math.min(maxWidth, area.width - 2 * margin)),
        maxHeight: math.max(0.0, area.height - 2 * margin),
      );

  @override
  Offset offsetFor(Size area, Rect anchor, Size box) =>
      Offset((area.width - box.width) / 2, (area.height - box.height) / 2);
}

// --- the overlay entry and its barrier ------------------------------------------

/// A popup in the root's overlay layer: as big as the root, a barrier over
/// everything outside its box (painted in [barrierColor], taking every
/// pointer, dismissing on a press when [barrierDismissible]) and the box,
/// placed by [position] against [anchorRect] (root coordinates).
class RenderPopupLayer extends RenderOverlayEntry with RenderObjectWithChildMixin<RenderBox> {
  RenderPopupLayer({
    RenderBox? child,
    required PopupPosition position,
    Rect anchorRect = Rect.zero,
    this.barrierColor,
    this.barrierDismissible = true,
    this.onBarrierPress,
  })  : _position = position, // ignore: prefer_initializing_formals
        _anchorRect = anchorRect { // ignore: prefer_initializing_formals
    this.child = child;
  }

  PopupPosition _position;
  PopupPosition get position => _position;
  set position(PopupPosition v) {
    if (v == _position) return;
    _position = v;
    markNeedsLayout();
  }

  Rect _anchorRect;

  /// What it is placed against, in the root's coordinates.
  Rect get anchorRect => _anchorRect;
  set anchorRect(Rect v) {
    if (v == _anchorRect) return;
    _anchorRect = v;
    markNeedsLayout();
  }

  /// The barrier's colour (null: clear).
  Color? barrierColor;
  bool barrierDismissible;

  /// A press on the barrier (outside the box).
  VoidCallback? onBarrierPress;

  /// Where the box is, in the layer's (the root's) coordinates.
  Rect get boxRect {
    final c = child;
    if (c == null || !c.hasSize) return Rect.zero;
    return (c.parentData! as BoxParentData).offset & c.size;
  }

  @override
  bool get hitTestable => true;

  @override
  Offset placeIn(RenderControlRoot root, Size rootSize) => Offset.zero;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  @override
  void performLayout() {
    size = constraints.biggest.isFinite ? constraints.biggest : constraints.smallest;
    final c = child;
    if (c == null) return;
    c.layout(_position.constraintsFor(size, _anchorRect), parentUsesSize: true);
    (c.parentData! as BoxParentData).offset = _position.offsetFor(size, _anchorRect, c.size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final color = barrierColor;
    if (color != null && color.a > 0) context.canvas.drawRect(offset & size, Paint()..color = color);
    final c = child;
    if (c != null) context.paintChild(c, offset + (c.parentData! as BoxParentData).offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    if (hitTestChildren(result, position: position)) return true;
    // The barrier: nothing under it takes the pointer.
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null) return false;
    final o = (c.parentData! as BoxParentData).offset;
    return result.addWithPaintOffset(offset: o, position: position, hitTest: (r, p) => c.hitTest(r, position: p));
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerDownEvent && barrierDismissible) onBarrierPress?.call();
  }
}

/// A popup an owner opens and closes: [content] in a [RenderPopupLayer] of
/// the root over the anchor, following the anchor while it is open (its
/// rect is measured after every frame), dismissed by a press on the
/// barrier, by Escape (the owner forwards its keys to [handleKey]) or when
/// the anchor goes away. Dialogs and sheets reuse it with a
/// [CenteredPlacement] (or their own [PopupPosition]) and a [barrierColor].
class ControlPopup {
  ControlPopup({
    required this.content,
    this.position = const AnchoredPlacement(),
    this.barrierColor,
    this.dismissible = true,
    this.onDismiss,
  });

  /// What it shows (adopted by the layer while open, dropped on close).
  final RenderBox content;
  PopupPosition position;
  Color? barrierColor;

  /// Whether a press outside and Escape close it.
  bool dismissible;

  /// Told after it closed by itself (barrier, Escape, anchor gone), not
  /// after [close]: the owner returns the focus.
  VoidCallback? onDismiss;

  RenderPopupLayer? _layer;
  RenderControlRoot? _root;
  RenderBox? _anchor;
  Rect Function()? _area;

  bool get isOpen => _layer != null;

  /// The overlay entry while open.
  RenderPopupLayer? get layer => _layer;

  /// Opens over [anchor] ([area]: the part of it to place against, in its
  /// own coordinates; null its whole box). False when [anchor] is not under
  /// a root.
  bool open(RenderBox anchor, {Rect Function()? area}) {
    if (isOpen) return true;
    final root = RenderControlRoot.of(anchor);
    if (root == null || !anchor.attached || !anchor.hasSize) return false;
    _anchor = anchor;
    _area = area;
    _root = root;
    final layer = RenderPopupLayer(
      child: content,
      position: position,
      anchorRect: _measure() ?? Rect.zero,
      barrierColor: barrierColor,
      barrierDismissible: dismissible,
      onBarrierPress: dismiss,
    );
    _layer = layer;
    root.showOverlay(layer);
    _follow();
    return true;
  }

  /// The anchor's rect in the root now (null: it is gone).
  Rect? _measure() {
    final a = _anchor, root = _root;
    if (a == null || root == null || !a.attached || !a.hasSize) return null;
    final local = _area?.call() ?? Offset.zero & a.size;
    return MatrixUtils.transformRect(a.getTransformTo(root), local);
  }

  /// Follows the anchor: measured after each frame while open.
  void _follow() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final layer = _layer;
      if (layer == null) return;
      final r = _measure();
      if (r == null) {
        dismiss();
        return;
      }
      layer.anchorRect = r;
      _follow();
    });
  }

  /// Closes it (the owner's choice: [onDismiss] is not told).
  void close() {
    final layer = _layer;
    if (layer == null) return;
    _layer = null;
    // A root going away (detached, disposed) keeps its entries.
    final root = _root;
    if (root != null && root.attached) {
      root.hideOverlay(layer);
      layer.child = null;
    }
    _root = null;
    _anchor = null;
    _area = null;
  }

  /// Closes it as the user asked (a press outside, Escape): [onDismiss]
  /// is told.
  void dismiss() {
    if (!isOpen) return;
    close();
    onDismiss?.call();
  }

  /// A key event while open; true when handled (Escape).
  bool handleKey(KeyEvent event) {
    if (!isOpen || event is KeyUpEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (dismissible) dismiss();
      return true;
    }
    return false;
  }
}

// --- the menu ---------------------------------------------------------------------

/// One row of a menu.
@immutable
class MenuItem {
  const MenuItem({required this.label, this.enabled = true, this.selected = false, this.image = const {}, this.imageSize = 0});

  final String label;
  final bool enabled;

  /// The current value (a select's): tinted, its check shown.
  final bool selected;

  /// A glyph or image before the label (an icon prop: `{"source": "image",
  /// "image": url}`), [imageSize] square; empty: none.
  final Json image;
  final double imageSize;

  @override
  bool operator ==(Object other) =>
      other is MenuItem &&
      other.label == label &&
      other.enabled == enabled &&
      other.selected == selected &&
      mapEquals(other.image, image) &&
      other.imageSize == imageSize;

  @override
  int get hashCode => Object.hash(label, enabled, selected, imageSize);
}

/// How a menu looks: its surface and its rows. [MenuLook.new]'s defaults
/// are SSUI's (soft_saas_ui's `SoftSaaSMenuList` in a `SoftSaaSPopover`)
/// but for the colours and text, which come from tokens.
@immutable
class MenuLook {
  const MenuLook({
    required this.fill,
    required this.textStyle,
    required this.selectedTextStyle,
    this.radius = 7,
    this.border,
    this.shadows = const [],
    this.padding = const EdgeInsets.all(4),
    this.maxHeight = 240,
    this.minWidth = 0,
    this.gap = 4,
    this.itemHeight = 28,
    this.itemPadding = const EdgeInsets.symmetric(horizontal: 8),
    this.rowRadius = 5,
    this.hoverFill,
    this.pressedFill,
    this.selectedFill,
    this.showCheck = true,
    this.checkLeading = false,
    this.checkSize = 14,
    this.checkColor,
    this.alignX = -1,
    this.imageGap = 10,
  });

  final Color fill;
  final double radius;

  /// The hairline around the surface (null: none), drawn inside it.
  final BorderSide? border;
  final List<BoxShadow> shadows;

  /// Between the surface's edge and the rows.
  final EdgeInsets padding;
  final double maxHeight;
  final double minWidth;

  /// Between the anchor and the surface.
  final double gap;
  final double itemHeight;
  final EdgeInsets itemPadding;
  final double rowRadius;

  /// A row under the pointer or the keyboard; pressed; the selected one.
  final Color? hoverFill, pressedFill, selectedFill;

  /// The rows' text (resolved), the selected row's.
  final TextStyle textStyle, selectedTextStyle;

  /// The selected row's check mark: shown, before the label, its size and
  /// colour (null: the selected text's).
  final bool showCheck;
  final bool checkLeading;
  final double checkSize;
  final Color? checkColor;

  /// The label's place in its row: -1 start, 0 centre, 1 end.
  final double alignX;

  /// Between a row's image and its label.
  final double imageGap;

  List<Object?> get _fields => [
        fill, radius, border, shadows, padding, maxHeight, minWidth, gap, itemHeight, itemPadding, rowRadius, //
        hoverFill, pressedFill, selectedFill, textStyle, selectedTextStyle, showCheck, checkLeading, checkSize,
        checkColor, alignX, imageGap,
      ];

  @override
  bool operator ==(Object other) => other is MenuLook && listEquals(_flat(other._fields), _flat(_fields));

  static List<Object?> _flat(List<Object?> f) => [for (final v in f) if (v is List) ...v else v];

  @override
  int get hashCode => Object.hashAll(_flat(_fields));
}

class MenuRowParentData extends ContainerBoxParentData<RenderMenuRow> {}

/// A menu: [items] as rows on SSUI's surface ([look]), [active] the row the
/// pointer or keyboard is on, scrolling when taller than its constraints
/// or [MenuLook.maxHeight]. A row chosen (a tap, Enter, Space) is reported
/// to [onSelected]; the owner closes the menu.
class RenderMenu extends RenderBox
    with ContainerRenderObjectMixin<RenderMenuRow, MenuRowParentData>, RenderBoxContainerDefaultsMixin<RenderMenuRow, MenuRowParentData> {
  RenderMenu({List<MenuItem> items = const [], MenuLook? look}) {
    if (look != null) this.look = look;
    this.items = items;
    _drag = VerticalDragGestureRecognizer(debugOwner: this)..onUpdate = (d) => scrollBy(-d.delta.dy);
  }

  late final VerticalDragGestureRecognizer _drag;

  List<MenuItem> _items = const [];
  List<MenuItem> get items => _items;
  set items(List<MenuItem> v) {
    if (listEquals(v, _items)) return;
    _items = List.unmodifiable(v);
    _syncRows();
    if (_active != null && (_active! >= v.length || !v[_active!].enabled)) _active = null;
    markNeedsLayout();
  }

  MenuLook? _look;
  MenuLook get look => _look!;
  set look(MenuLook v) {
    if (v == _look) return;
    _look = v;
    for (final r in _rows) {
      r.markNeedsLayout();
    }
    markNeedsLayout();
  }

  /// A row chosen.
  ValueChanged<int>? onSelected;

  final List<RenderMenuRow> _rows = [];

  /// The rows, first to last.
  List<RenderMenuRow> get rows => List.unmodifiable(_rows);

  void _syncRows() {
    while (_rows.length > _items.length) {
      final r = _rows.removeLast();
      remove(r);
    }
    while (_rows.length < _items.length) {
      final r = RenderMenuRow(_rows.length);
      _rows.add(r);
      add(r);
    }
    for (var i = 0; i < _rows.length; i++) {
      _rows[i].item = _items[i];
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! MenuRowParentData) child.parentData = MenuRowParentData();
  }

  // --- the active row and the keyboard -------------------------------------------

  int? _active;

  /// The row the pointer or keyboard is on (null: none).
  int? get active => _active;
  set active(int? v) {
    if (v == _active) return;
    _active = v;
    for (final r in _rows) {
      r.markNeedsPaint();
    }
    markNeedsSemanticsUpdate();
  }

  List<int> get _enabled => [for (var i = 0; i < _items.length; i++) if (_items[i].enabled) i];

  void _activate(int i, {bool center = false}) {
    active = i;
    reveal(i, center: center);
  }

  void _move(int delta) {
    final enabled = _enabled;
    if (enabled.isEmpty) return;
    final at = _active == null ? -1 : enabled.indexOf(_active!);
    final next = at == -1 ? (delta > 0 ? enabled.first : enabled.last) : enabled[(at + delta) % enabled.length];
    _activate(next);
  }

  /// The rows a page holds.
  int get _page => math.max(1, ((size.height - look.padding.vertical) / look.itemHeight).floor());

  void _pageBy(int pages) {
    final enabled = _enabled;
    if (enabled.isEmpty) return;
    final from = _active ?? (pages > 0 ? enabled.first : enabled.last);
    final target = (from + pages * _page).clamp(0, _items.length - 1);
    // The enabled row nearest the target, in the direction of travel first.
    final pick = pages > 0
        ? enabled.lastWhere((i) => i <= target, orElse: () => enabled.first)
        : enabled.firstWhere((i) => i >= target, orElse: () => enabled.last);
    _activate(pick);
  }

  String _typed = '';
  final Stopwatch _sinceTyped = Stopwatch();

  /// Jumps to the next row whose label starts with what was typed in the
  /// last 700 ms (a repeated letter cycles through the rows it starts).
  void typeAhead(String character) {
    if (!_sinceTyped.isRunning || _sinceTyped.elapsedMilliseconds > 700) _typed = '';
    _sinceTyped
      ..reset()
      ..start();
    _typed += character.toLowerCase();
    final enabled = _enabled;
    if (enabled.isEmpty) return;
    final cycling = _typed.length > 1 && _typed.split('').every((c) => c == _typed[0]);
    final needle = cycling ? _typed[0] : _typed;
    final start = _active == null ? -1 : enabled.indexOf(_active!);
    final from = (cycling || _typed.length == 1) ? start + 1 : math.max(0, start);
    for (var step = 0; step < enabled.length; step++) {
      final i = enabled[(from + step) % enabled.length];
      if (_items[i].label.toLowerCase().startsWith(needle)) {
        _activate(i);
        return;
      }
    }
  }

  /// Chooses row [i] (an enabled one).
  void choose(int i) {
    if (i < 0 || i >= _items.length || !_items[i].enabled) return;
    onSelected?.call(i);
  }

  /// A key while the menu is open; true when handled: arrows move, Home
  /// and End jump, Page Up and Down move a page, Enter and Space choose,
  /// a character jumps to a row (type-ahead). Escape and Tab are the
  /// owner's.
  bool handleKey(KeyEvent event) {
    if (event is KeyUpEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
    } else if (key == LogicalKeyboardKey.home) {
      if (_enabled.isNotEmpty) _activate(_enabled.first);
    } else if (key == LogicalKeyboardKey.end) {
      if (_enabled.isNotEmpty) _activate(_enabled.last);
    } else if (key == LogicalKeyboardKey.pageDown) {
      _pageBy(1);
    } else if (key == LogicalKeyboardKey.pageUp) {
      _pageBy(-1);
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent && _active != null) choose(_active!);
    } else {
      final c = event.character;
      final modified = HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed ||
          HardwareKeyboard.instance.isAltPressed;
      if (modified || c == null || c.length != 1 || c.codeUnitAt(0) <= 32) return false;
      typeAhead(c);
    }
    return true;
  }

  // --- scroll ---------------------------------------------------------------------

  double _scroll = 0;
  double _maxScroll = 0;

  /// How far the rows are scrolled.
  double get scrollOffset => _scroll;

  /// The furthest they scroll (0: they all fit).
  double get maxScrollOffset => _maxScroll;

  /// Scrolls the rows by [delta] (positive: down the list).
  void scrollBy(double delta) => _scrollTo(_scroll + delta);

  void _scrollTo(double v) {
    final c = v.clamp(0.0, _maxScroll).toDouble();
    if (c == _scroll) return;
    _scroll = c;
    _placeRows();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  int? _reveal;
  bool _revealCentred = false;

  /// Scrolls row [i] into view (to the middle when [center]); done at the
  /// next layout when the menu has none yet.
  void reveal(int i, {bool center = false}) {
    if (!hasSize || debugNeedsLayout) {
      _reveal = i;
      _revealCentred = center;
      markNeedsLayout();
      return;
    }
    _revealNow(i, center);
  }

  void _revealNow(int i, bool center) {
    final l = look;
    final top = l.padding.top + i * l.itemHeight, bottom = top + l.itemHeight;
    final view = size.height;
    if (center) {
      _scrollTo(top + l.itemHeight / 2 - view / 2);
    } else if (top - _scroll < l.padding.top) {
      _scrollTo(top - l.padding.top);
    } else if (bottom - _scroll > view - l.padding.bottom) {
      _scrollTo(bottom - view + l.padding.bottom);
    }
  }

  // --- layout -----------------------------------------------------------------------

  double get _contentHeight => look.padding.vertical + _items.length * look.itemHeight;

  @override
  double computeMinIntrinsicWidth(double height) => computeMaxIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) {
    var w = look.minWidth;
    for (final r in _rows) {
      w = math.max(w, look.padding.horizontal + r.getMaxIntrinsicWidth(look.itemHeight));
    }
    return w;
  }

  @override
  double computeMinIntrinsicHeight(double width) => math.min(_contentHeight, look.maxHeight);

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => _sizeFor(constraints);

  Size _sizeFor(BoxConstraints c) {
    final w = c.hasBoundedWidth && c.minWidth == c.maxWidth ? c.maxWidth : c.constrainWidth(computeMaxIntrinsicWidth(double.infinity));
    return Size(w, c.constrainHeight(math.min(_contentHeight, look.maxHeight)));
  }

  @override
  void performLayout() {
    size = _sizeFor(constraints);
    final l = look;
    final rowWidth = math.max(0.0, size.width - l.padding.horizontal);
    for (final r in _rows) {
      r.layout(BoxConstraints.tight(Size(rowWidth, l.itemHeight)));
    }
    _maxScroll = math.max(0.0, _contentHeight - size.height);
    _scroll = _scroll.clamp(0.0, _maxScroll).toDouble();
    final pending = _reveal;
    _reveal = null;
    if (pending != null && pending >= 0 && pending < _items.length) _revealNow(pending, _revealCentred);
    _placeRows();
  }

  void _placeRows() {
    final l = look;
    for (var i = 0; i < _rows.length; i++) {
      (_rows[i].parentData! as MenuRowParentData).offset = Offset(l.padding.left, l.padding.top + i * l.itemHeight - _scroll);
    }
  }

  // --- paint ------------------------------------------------------------------------

  final LayerHandle<ClipRRectLayer> _clip = LayerHandle<ClipRRectLayer>();

  RRect _shape(Offset offset) => RRect.fromRectAndRadius(offset & size, Radius.circular(look.radius));

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final l = look;
    final shape = _shape(offset);
    for (final s in l.shadows) {
      canvas.drawRRect(shape.shift(s.offset).inflate(s.spreadRadius), s.toPaint());
    }
    canvas.drawRRect(shape, Paint()..color = l.fill);
    _clip.layer = context.pushClipRRect(needsCompositing, offset, Offset.zero & size, _shape(Offset.zero), (context, offset) {
      for (final r in _rows) {
        final o = (r.parentData! as MenuRowParentData).offset;
        if (o.dy + r.size.height < 0 || o.dy > size.height) continue;
        context.paintChild(r, offset + o);
      }
    }, oldLayer: _clip.layer);
    final b = l.border;
    if (b != null && b.width > 0 && b.color.a > 0) {
      context.canvas.drawRRect(
          shape.deflate(b.width / 2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = b.width
            ..color = b.color);
    }
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => Offset.zero & size;

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (!(Offset.zero & size).contains(position)) return false;
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerScrollEvent) {
      GestureBinding.instance.pointerSignalResolver.register(event, (e) => scrollBy((e as PointerScrollEvent).scrollDelta.dy));
    } else if (event is PointerDownEvent && _maxScroll > 0) {
      _drag.addPointer(event);
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..explicitChildNodes = true;
    if (_maxScroll > 0) {
      config
        ..hasImplicitScrolling = true
        ..scrollPosition = _scroll
        ..scrollExtentMax = _maxScroll
        ..scrollExtentMin = 0;
      if (_scroll < _maxScroll) config.onScrollUp = () => scrollBy(size.height / 2);
      if (_scroll > 0) config.onScrollDown = () => scrollBy(-size.height / 2);
    }
  }

  @override
  void dispose() {
    _drag.dispose();
    _clip.layer = null;
    super.dispose();
  }
}

/// One row of a [RenderMenu].
class RenderMenuRow extends RenderBox
    with RenderObjectWithChildMixin<RenderIconGlyph>
    implements MouseTrackerAnnotation, LabelledControl {
  RenderMenuRow(this.index) {
    _tap = TapGestureRecognizer(debugOwner: this)
      ..onTapDown = ((_) => _setPressed(true))
      ..onTapUp = ((_) => _setPressed(false))
      ..onTapCancel = (() => _setPressed(false))
      ..onTap = () => _menu?.choose(index);
  }

  /// Its place in the menu.
  final int index;
  late final TapGestureRecognizer _tap;

  RenderMenu? get _menu => parent is RenderMenu ? parent! as RenderMenu : null;
  MenuLook get _look => _menu!.look;

  MenuItem _item = const MenuItem(label: '');
  MenuItem get item => _item;
  set item(MenuItem v) {
    if (v == _item) return;
    _item = v;
    if (v.image.isEmpty) {
      child = null;
    } else {
      (child ??= RenderIconGlyph()).icon = v.image;
    }
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  /// Whether the pointer or the keyboard is on it.
  bool get active => _menu?.active == index;

  bool _pressed = false;
  void _setPressed(bool v) {
    if (v == _pressed) return;
    _pressed = v;
    markNeedsPaint();
  }

  final ControlLabel _label = ControlLabel();

  TextStyle get _style => _item.selected ? _look.selectedTextStyle : _look.textStyle;

  double get _checkSpace => _item.selected && _look.showCheck ? _look.checkSize + 8 : 0;
  double get _imageSpace => _item.image.isEmpty ? 0 : _item.imageSize + _look.imageGap;

  @override
  double computeMaxIntrinsicWidth(double height) {
    final l = _look;
    _label.update(_item.label, _style, align: TextAlign.left);
    // The check's room is kept on every row, so choosing never widens it.
    final check = l.showCheck ? l.checkSize + 8 : 0;
    return l.itemPadding.horizontal + _imageSpace + _label.intrinsicWidth + check;
  }

  @override
  double computeMinIntrinsicWidth(double height) => computeMaxIntrinsicWidth(height);

  Rect _imageRect = Rect.zero, _checkRect = Rect.zero;
  double _labelLeft = 0;

  @override
  void performLayout() {
    size = constraints.biggest;
    final l = _look;
    var left = l.itemPadding.left, right = size.width - l.itemPadding.right;
    final check = _checkSpace;
    if (check > 0) {
      if (l.checkLeading) {
        _checkRect = Rect.fromLTWH(left, (size.height - l.checkSize) / 2, l.checkSize, l.checkSize);
        left += check;
      } else {
        _checkRect = Rect.fromLTWH(right - l.checkSize, (size.height - l.checkSize) / 2, l.checkSize, l.checkSize);
        right -= check;
      }
    } else {
      _checkRect = Rect.zero;
    }
    final img = child;
    if (img != null) {
      final s = _item.imageSize;
      _imageRect = Rect.fromLTWH(left, (size.height - s) / 2, s, s);
      img.layout(BoxConstraints.tight(Size.square(s)));
      left += _imageSpace;
    }
    final width = math.max(0.0, right - left);
    _label
      ..update(_item.label, _style, align: TextAlign.left)
      ..layout(width);
    final free = math.max(0.0, width - _label.size.width);
    _labelLeft = left + free * (l.alignX.clamp(-1.0, 1.0) + 1) / 2;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final l = _look;
    final canvas = context.canvas;
    final shape = RRect.fromRectAndRadius(offset & size, Radius.circular(l.rowRadius));
    final enabled = _item.enabled;
    Color? fill;
    if (_item.selected) fill = l.selectedFill;
    if (enabled && active && !_item.selected) fill = l.hoverFill;
    if (fill != null && fill.a > 0) canvas.drawRRect(shape, Paint()..color = fill);
    if (enabled && active && _item.selected && l.hoverFill != null) canvas.drawRRect(shape, Paint()..color = l.hoverFill!);
    if (enabled && _pressed && l.pressedFill != null) canvas.drawRRect(shape, Paint()..color = l.pressedFill!);
    void content(PaintingContext context, Offset offset) {
      final img = child;
      if (img != null) context.paintChild(img, offset + _imageRect.topLeft);
      _label.paint(context.canvas, offset.dx + _labelLeft, offset.dy + size.height / 2);
      if (_checkRect != Rect.zero) {
        StrokeGlyph.check.paint(context.canvas, _checkRect.shift(offset), l.checkColor ?? _style.color ?? const Color(0xFF000000));
      }
    }

    if (enabled) {
      content(context, offset);
    } else {
      // A disabled row at SSUI's 50 %.
      context.pushOpacity(offset, 128, (context, o) => content(context, o));
    }
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) =>
      transform.translateByDouble(_imageRect.left, _imageRect.top, 0, 1);

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerDownEvent && _item.enabled) _tap.addPointer(event);
  }

  // --- hover --------------------------------------------------------------------------

  @override
  MouseCursor get cursor => _item.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic;

  @override
  PointerEnterEventListener? get onEnter => (_) {
        if (_item.enabled) _menu?.active = index;
      };

  @override
  PointerExitEventListener? get onExit => null;

  @override
  bool get validForMouseTracker => attached;

  // --- what the guard and screen readers read --------------------------------------

  @override
  List<({String text, String? fontFamily, List<Rect> glyphs})> get labels => !hasSize || _item.label.isEmpty
      ? const []
      : [(text: _item.label, fontFamily: _label.fontFamily, glyphs: _label.glyphBoxes(_labelLeft, size.height / 2))];

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..isButton = true
      ..label = _item.label
      ..isEnabled = _item.enabled
      ..isSelected = _item.selected
      ..textDirection = TextDirection.ltr;
    if (_item.enabled) config.onTap = () => _menu?.choose(index);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {}

  @override
  void dispose() {
    _tap.dispose();
    _label.dispose();
    super.dispose();
  }
}
