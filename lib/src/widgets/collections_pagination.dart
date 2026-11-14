// The pagination node: page controls for a list's pagination, one render
// object in the node's fit box. Running, it shows and moves the controller
// its `controller` names (a list on the screen makes it); until one does,
// and on a design canvas, it shows its preview state (page 1 of 10, 200
// items), disabled.
import 'dart:math' as math;
import 'dart:ui' show BoxHeightStyle;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Node, PaginationProps, TriggerType;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../render/controls/kit.dart' show LabeledControl;
import '../render/controls/menu.dart';
import '../render/controls/tokens.dart';
import '../render/convert.dart';
import '../render/node_tree.dart';
import '../render/recipe.dart';
import '../render/surface_roles.dart' show onColor;
import '../runtime/lists/pagination.dart';
import 'collections_list_runtime.dart';

/// The pagination node: fit box → its controls.
void paginationRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  chain.add(b.fitBox('fit', n.layout.width.fit, n.layout.height.fit, Size(n.layout.width.value, n.layout.height.value)));
  final tokens = ControlTokens.of(b);
  final box = b.obtain<RenderPagination>('pagination', RenderPagination.new)
    ..node = n
    ..tokens = tokens
    ..fontFamily = b.tree.textDefault?.fontFamily ?? tokens.fontFamily;
  if (!b.tree.animates) {
    box.bind(null, '');
  } else {
    final runtime = ListRuntime(b, n);
    box
      ..summary = runtime.text
      ..onMoved = ((page) {
        if (b is NodeBox) fireTrigger(b, TriggerType.changed.name, event: {'value': page});
      })
      ..bind(PaginationRegistry.of(b.tree), runtime.text(n.prop(PaginationProps.controller)).trim());
  }
  chain.add(box);
}

/// What a pagination node shows: the controller's state, or the preview's.
class PaginationState {
  const PaginationState({
    this.page = 1,
    this.pageCount = 10,
    this.totalCount = 200,
    this.from = 1,
    this.to = 20,
    this.hasMore = true,
    this.pageSize = 20,
    this.pageSizeOptions = const [10, 20, 50, 100],
  });

  final int page;
  final int? pageCount, totalCount;
  final int from, to, pageSize;
  final bool hasMore;
  final List<int> pageSizeOptions;

  /// The preview (no controller).
  static const preview = PaginationState();

  /// What [c] shows.
  factory PaginationState.of(PaginationController c) => PaginationState(
        page: c.page,
        pageCount: c.pageCount,
        totalCount: c.totalCount,
        from: c.from,
        to: c.to,
        hasMore: c.hasMore,
        pageSize: c.pageSize,
        pageSizeOptions: c.model.pageSizeOptions,
      );
}

/// A move of a pagination controller (next, go to a page...).
typedef PaginationMove = Future<void> Function(PaginationController controller);

enum _Kind { text, button, gap, select }

/// One thing a pagination node draws: a text, a page button, the gap of an
/// ellipsis, or the page size select.
class PaginationPart {
  PaginationPart._(this._kind, this.label,
      {this.semantics, this.enabled = false, this.active = false, this.move, required this.group});

  final _Kind _kind;

  /// What it reads.
  final String label;

  /// What a screen reader says of a button ("Next page"); null for a text.
  final String? semantics;

  /// Whether a press moves the controller.
  final bool enabled;

  /// The current page's button.
  final bool active;
  final PaginationMove? move;

  /// 0 the summary, 1 the buttons, 2 the page size.
  final int group;

  bool get isButton => _kind == _Kind.button || _kind == _Kind.select;

  /// Where it is drawn, in the node's box.
  Rect rect = Rect.zero;
  TextPainter? _text;
}

/// A pagination node's controls: a summary, first/previous/page numbers/
/// next/last buttons and a page size select, wrapping when they do not fit.
/// The buttons are drawn here (the current page filled in the theme's
/// primary, the others outlined); the page size opens the controls' menu.
class RenderPagination extends RenderBox implements MouseTrackerAnnotation, LabeledControl {
  RenderPagination() {
    _tap = TapGestureRecognizer(debugOwner: this)..onTapUp = (d) => _pressAt(globalToLocal(d.globalPosition));
    _menu = RenderMenu()..onSelected = _chooseSize;
    _popup = ControlPopup(content: _menu);
  }

  late final TapGestureRecognizer _tap;
  late final RenderMenu _menu;
  late final ControlPopup _popup;

  Node? _node;
  set node(Node v) {
    if (identical(v, _node)) return;
    _node = v;
    _changed();
  }

  ControlTokens? _tokens;
  set tokens(ControlTokens v) {
    _tokens = v;
    _changed();
  }

  String? _fontFamily;
  set fontFamily(String? v) {
    if (v == _fontFamily) return;
    _fontFamily = v;
    _changed();
  }

  /// Reads the `${...}` of the summary.
  String Function(String text)? summary;

  /// Told the page after a press moved the controller.
  void Function(int page)? onMoved;

  PaginationRegistry? _registry;
  String _name = '';
  PaginationController? _controller;

  /// Follows the controller named [name] in [registry] (null: the preview).
  void bind(PaginationRegistry? registry, String name) {
    if (identical(registry, _registry) && name == _name) return;
    if (attached) _registry?.removeListener(_lookUp);
    _registry = registry;
    _name = name;
    if (attached) {
      _registry?.addListener(_lookUp);
      _lookUp();
    }
  }

  void _lookUp() {
    final next = _registry?[_name];
    if (identical(next, _controller)) return;
    _controller?.removeListener(_changed);
    _controller = next;
    _controller?.addListener(_changed);
    _changed();
  }

  void _changed() {
    _parts = null;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _registry?.addListener(_lookUp);
    _lookUp();
  }

  @override
  void detach() {
    _popup.close();
    _registry?.removeListener(_lookUp);
    _controller?.removeListener(_changed);
    _controller = null;
    super.detach();
  }

  @override
  void dispose() {
    _tap.dispose();
    for (final p in _parts ?? const <PaginationPart>[]) {
      p._text?.dispose();
    }
    super.dispose();
  }

  // --- what it shows ---

  /// The state shown: the controller's, else the preview.
  PaginationState get state => _controller == null ? PaginationState.preview : PaginationState.of(_controller!);

  List<PaginationPart>? _parts;

  /// What it draws, in order (for tests and tools).
  List<PaginationPart> get parts => _parts ??= _makeParts();

  TextStyle get _style {
    final n = _node!;
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: n.prop(PaginationProps.fontSize),
      fontWeight: FontWeight.values[(n.prop(PaginationProps.fontWeight) ~/ 100 - 1).clamp(0, 8)],
      color: n.prop(PaginationProps.textColor)?.flutter ?? _tokens?.onSurface ?? const Color(0xFF111827),
    );
  }

  Color get _activeFill => _node!.prop(PaginationProps.activeColor)?.flutter ?? _tokens?.primary ?? const Color(0xFF2563EB);

  List<PaginationPart> _makeParts() {
    for (final p in _parts ?? const <PaginationPart>[]) {
      p._text?.dispose();
    }
    final n = _node;
    if (n == null) return [];
    final s = state;
    final enabled = _controller != null && n.prop(PaginationProps.enabled);
    final pageCount = s.pageCount;
    final out = <PaginationPart>[];
    PaginationPart button(String label, {required bool canPress, bool active = false, String? semantics, PaginationMove? move}) =>
        PaginationPart._(_Kind.button, label,
            semantics: semantics ?? label, enabled: enabled && canPress, active: active, move: move, group: 1);
    if (n.prop(PaginationProps.showSummary)) {
      final text = n
          .prop(PaginationProps.summaryText)
          .replaceAll('{from}', '${s.from}')
          .replaceAll('{to}', '${s.to}')
          .replaceAll('{total}', s.totalCount == null ? 'many' : '${s.totalCount}')
          .replaceAll('{page}', '${s.page}')
          .replaceAll('{pageCount}', pageCount == null ? '?' : '$pageCount');
      out.add(PaginationPart._(_Kind.text, summary?.call(text) ?? text, group: 0));
    }
    if (n.prop(PaginationProps.showFirstLast)) {
      out.add(button(n.prop(PaginationProps.firstLabel), semantics: 'First page', canPress: s.page > 1, move: (c) => c.first()));
    }
    if (n.prop(PaginationProps.showPrevNext)) {
      out.add(button(n.prop(PaginationProps.previousLabel), semantics: 'Previous page', canPress: s.page > 1, move: (c) => c.previous()));
    }
    if (n.prop(PaginationProps.showPageNumbers)) {
      for (final number in PaginationProps.pageItems(
        page: s.page,
        pageCount: pageCount ?? s.page + (s.hasMore ? 1 : 0),
        siblingCount: n.prop(PaginationProps.siblingCount),
        boundaryCount: n.prop(PaginationProps.boundaryCount),
      )) {
        out.add(number == null
            ? PaginationPart._(_Kind.gap, '…', group: 1)
            : button('$number',
                semantics: 'Page $number', active: number == s.page, canPress: number != s.page, move: (c) => c.goTo(number)));
      }
    }
    if (n.prop(PaginationProps.showPrevNext)) {
      out.add(button(n.prop(PaginationProps.nextLabel), semantics: 'Next page', canPress: s.hasMore, move: (c) => c.next()));
    }
    if (n.prop(PaginationProps.showFirstLast)) {
      out.add(button(n.prop(PaginationProps.lastLabel),
          semantics: 'Last page', canPress: pageCount != null && s.page < pageCount, move: (c) => c.last()));
    }
    if (n.prop(PaginationProps.showPageSize)) {
      out
        ..add(PaginationPart._(_Kind.text, n.prop(PaginationProps.pageSizeLabel), group: 2))
        ..add(PaginationPart._(_Kind.select, '${s.pageSize}', semantics: n.prop(PaginationProps.pageSizeLabel), enabled: enabled, group: 2));
    }
    final style = _style;
    for (final p in out) {
      final own = p.active
          ? style.copyWith(
              color: n.prop(PaginationProps.activeTextColor)?.flutter ??
                  onColor(_activeFill, preferred: [if (_activeFill == _tokens?.primary) _tokens?.onPrimary]),
              fontWeight: FontWeight.w600)
          : style;
      p._text = TextPainter(text: TextSpan(text: p.label, style: own), textDirection: TextDirection.ltr)..layout();
    }
    return out;
  }

  // --- layout ---

  static const double _chevron = 14;

  Size _sizeOf(PaginationPart p) {
    final n = _node!;
    final t = p._text!;
    final size = n.prop(PaginationProps.buttonSize);
    return switch (p._kind) {
      _Kind.text => t.size,
      _Kind.gap => Size(size * 0.75, t.height),
      _Kind.button => Size(math.max(size, t.width + 16), math.max(size, t.height)),
      _Kind.select => Size(t.width + 4 + _chevron, math.max(t.height, 20)),
    };
  }

  /// Rows of [sizes] no wider than [maxWidth], [gap] apart and [runGap]
  /// between rows, each centered down its row: where each goes, and the
  /// whole's size.
  static (List<Offset>, Size, List<(int, int, double)>) _wrap(List<Size> sizes, double maxWidth, double gap, double runGap) {
    final at = List<Offset>.filled(sizes.length, Offset.zero);
    final runs = <(int, int, double)>[];
    var y = 0.0, widest = 0.0, i = 0;
    while (i < sizes.length) {
      var x = 0.0, tall = 0.0, j = i;
      while (j < sizes.length && (j == i || x + gap + sizes[j].width <= maxWidth + precisionErrorTolerance)) {
        if (j > i) x += gap;
        x += sizes[j].width;
        tall = math.max(tall, sizes[j].height);
        j++;
      }
      var left = 0.0;
      for (var k = i; k < j; k++) {
        at[k] = Offset(left, y + (tall - sizes[k].height) / 2);
        left += sizes[k].width + gap;
      }
      runs.add((i, j, x));
      widest = math.max(widest, x);
      y += tall + runGap;
      i = j;
    }
    return (at, Size(widest, sizes.isEmpty ? 0 : y - runGap), runs);
  }

  Size _layOut(BoxConstraints constraints, {required bool place}) {
    final n = _node;
    if (n == null) return constraints.smallest;
    final padding = n.layout.padding.flutter;
    final spacing = n.prop(PaginationProps.spacing);
    final all = parts;
    final maxInner = constraints.maxWidth.isFinite ? math.max(0.0, constraints.maxWidth - padding.horizontal) : double.infinity;
    // Three groups, each a block: the summary, the buttons (which wrap among
    // themselves) and the page size.
    final blocks = <(List<PaginationPart>, List<Offset>, Size)>[];
    for (var g = 0; g < 3; g++) {
      final members = [for (final p in all) if (p.group == g) p];
      if (members.isEmpty) continue;
      final sizes = [for (final p in members) _sizeOf(p)];
      final (at, size, _) = _wrap(sizes, maxInner, g == 2 ? spacing * 2 : spacing, spacing);
      blocks.add((members, at, size));
    }
    final (blockAt, content, runs) = _wrap([for (final b in blocks) b.$3], maxInner, spacing * 3, spacing);
    final hugs = n.layout.width.fit == api.SizeFit.hug || !constraints.maxWidth.isFinite;
    final width = hugs ? content.width + padding.horizontal : constraints.maxWidth;
    final size = constraints.constrain(Size(width, content.height + padding.vertical));
    if (!place) return size;
    final inner = size.width - padding.horizontal;
    // Centered down the node's box (a 48 px node and 32 px buttons).
    final top = padding.top + math.max(0.0, (size.height - padding.vertical - content.height) / 2);
    final align = n.prop(PaginationProps.alignment);
    for (final (from, to, used) in runs) {
      final free = math.max(0.0, inner - used);
      final count = to - from;
      final (lead, between) = switch (align) {
        api.WrapAlignment.end => (free, 0.0),
        api.WrapAlignment.center => (free / 2, 0.0),
        api.WrapAlignment.spaceBetween => (0.0, count > 1 ? free / (count - 1) : 0.0),
        api.WrapAlignment.spaceAround => (free / count / 2, free / count),
        api.WrapAlignment.spaceEvenly => (free / (count + 1), free / (count + 1)),
        _ => (0.0, 0.0),
      };
      for (var k = from; k < to; k++) {
        final origin = Offset(padding.left + lead + between * (k - from), top) + blockAt[k];
        final (members, at, _) = blocks[k];
        for (var m = 0; m < members.length; m++) {
          members[m].rect = (origin + at[m]) & _sizeOf(members[m]);
        }
      }
    }
    return size;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _layOut(constraints, place: false);

  @override
  double computeMinIntrinsicWidth(double height) => 0;
  @override
  double computeMaxIntrinsicWidth(double height) => _layOut(const BoxConstraints(), place: false).width;
  @override
  double computeMinIntrinsicHeight(double width) => _layOut(BoxConstraints(maxWidth: width), place: false).height;
  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  void performLayout() {
    size = _layOut(constraints, place: true);
  }

  // --- pointer ---

  PaginationPart? _hovered;

  PaginationPart? _partAt(Offset p) {
    for (final part in parts) {
      if (part.isButton && part.rect.contains(p)) return part;
    }
    return null;
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) _tap.addPointer(event);
    if (event is PointerHoverEvent) _hover(_partAt(event.localPosition));
  }

  void _hover(PaginationPart? part) {
    if (identical(part, _hovered)) return;
    _hovered = part;
    markNeedsPaint();
  }

  @override
  PointerEnterEventListener? get onEnter => null;
  @override
  PointerExitEventListener? get onExit => (_) => _hover(null);
  @override
  MouseCursor get cursor => (_hovered?.enabled ?? false) ? SystemMouseCursors.click : MouseCursor.defer;
  @override
  bool get validForMouseTracker => attached;

  void _pressAt(Offset p) {
    final part = _partAt(p);
    if (part != null) press(part);
  }

  /// Presses [part] as a tap on it does: a button moves the controller, the
  /// page size opens its menu. Nothing when it is disabled.
  Future<void> press(PaginationPart part) async {
    final controller = _controller;
    if (!part.enabled || controller == null) return;
    if (part._kind == _Kind.select) return _openSizes(part);
    final move = part.move;
    if (move == null) return;
    await move(controller);
    onMoved?.call(controller.page);
  }

  /// The page size menu, while open.
  RenderMenu? get sizeMenu => _popup.isOpen ? _menu : null;

  void _openSizes(PaginationPart part) {
    final t = _tokens;
    if (t == null) return;
    final s = state;
    final options = {...s.pageSizeOptions, s.pageSize}.toList()..sort();
    _sizes = options;
    final style = _style;
    _menu
      ..look = MenuLook(
        fill: t.raisedBackground,
        radius: t.radius('control', 7),
        border: BorderSide(color: t.primaryBorder),
        hoverFill: t.hoverOverlay,
        pressedFill: t.pressedOverlay,
        selectedFill: t.activeTint,
        checkColor: t.primary,
        textStyle: style,
        selectedTextStyle: style.copyWith(fontWeight: FontWeight.w600),
      )
      ..items = [for (final o in options) MenuItem(label: '$o', selected: o == s.pageSize)];
    _popup
      ..position = const AnchoredPlacement(gap: 4, minWidth: 72)
      ..open(this, area: () => part.rect);
  }

  List<int> _sizes = const [];

  void _chooseSize(int index) {
    _popup.close();
    final controller = _controller;
    if (controller == null || index < 0 || index >= _sizes.length) return;
    final size = _sizes[index];
    controller.setPageSize(size).then((_) => onMoved?.call(controller.page));
  }

  /// Chooses the page size at [index] of the open menu, as a tap on its row.
  void chooseSize(int index) => _chooseSize(index);

  /// Where [p]'s text is drawn, in the node's box.
  Offset _textAt(PaginationPart p) {
    final t = p._text!;
    final rect = p.rect;
    return rect.topLeft + Offset(p._kind == _Kind.select ? 0 : (rect.width - t.width) / 2, (rect.height - t.height) / 2);
  }

  /// Its words (not the arrows and the ellipsis) with their glyph boxes.
  @override
  List<({String text, String? fontFamily, List<Rect> glyphs})> get labels => [
        for (final p in parts)
          if (hasSize && RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(p.label))
            (
              text: p.label,
              fontFamily: _fontFamily,
              glyphs: [
                for (final b in p._text!.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: p.label.length),
                    boxHeightStyle: BoxHeightStyle.tight))
                  b.toRect().shift(_textAt(p)),
              ],
            ),
      ];

  // --- paint ---

  @override
  void paint(PaintingContext context, Offset offset) {
    final n = _node;
    if (n == null) return;
    final canvas = context.canvas;
    final radius = Radius.circular(n.prop(PaginationProps.cornerRadius));
    final borderColor = n.prop(PaginationProps.borderColor)?.flutter ?? _tokens?.primaryBorder ?? const Color(0xFFE5E7EB);
    final borderWidth = n.prop(PaginationProps.borderWidth);
    final fill = n.prop(PaginationProps.buttonColor)?.flutter;
    final dim = n.prop(PaginationProps.disabledOpacity);
    for (final p in parts) {
      final rect = p.rect.shift(offset);
      final t = p._text!;
      final faded = p.isButton && !(p.enabled || p.active) && dim < 1;
      if (faded) canvas.saveLayer(rect.inflate(1), Paint()..color = Color.fromRGBO(0, 0, 0, dim.clamp(0.0, 1.0)));
      if (p._kind == _Kind.button) {
        final box = RRect.fromRectAndRadius(rect, radius);
        final background = p.active ? _activeFill : fill;
        if (background != null) canvas.drawRRect(box, Paint()..color = background);
        if (!p.active && borderColor.a > 0 && borderWidth > 0) {
          canvas.drawRRect(
              box.deflate(borderWidth / 2),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = borderWidth
                ..color = borderColor);
        }
        if (identical(p, _hovered) && p.enabled) {
          canvas.drawRRect(box, Paint()..color = _tokens?.hoverOverlay ?? const Color(0x0A000000));
        }
        t.paint(canvas, offset + _textAt(p));
      } else if (p._kind == _Kind.select) {
        t.paint(canvas, offset + _textAt(p));
        // A chevron after the size.
        final c = Offset(rect.right - _chevron / 2, rect.center.dy);
        canvas.drawPath(
            Path()
              ..moveTo(c.dx - 3.5, c.dy - 1.75)
              ..lineTo(c.dx, c.dy + 1.75)
              ..lineTo(c.dx + 3.5, c.dy - 1.75),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..color = _style.color ?? const Color(0xFF111827));
      } else {
        t.paint(canvas, offset + _textAt(p));
      }
      if (faded) canvas.restore();
    }
  }

  // --- semantics: each button is its own node ---

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
  }

  final List<SemanticsNode> _semantics = [];

  @override
  void assembleSemanticsNode(SemanticsNode node, SemanticsConfiguration config, Iterable<SemanticsNode> children) {
    final all = parts;
    while (_semantics.length < all.length) {
      _semantics.add(SemanticsNode());
    }
    final shown = <SemanticsNode>[];
    for (var i = 0; i < all.length; i++) {
      final p = all[i];
      if (p._kind == _Kind.gap) continue;
      final c = SemanticsConfiguration()..textDirection = TextDirection.ltr;
      if (p.isButton) {
        c
          ..isButton = true
          ..label = p.semantics ?? p.label
          ..isEnabled = p.enabled
          ..isSelected = p.active;
        if (p.enabled) c.onTap = () => press(p);
        if (p._kind == _Kind.select) c.value = p.label;
      } else {
        c.label = p.label;
      }
      shown.add(_semantics[i]
        ..rect = p.rect
        ..updateWith(config: c));
    }
    node.updateWith(config: config, childrenInInversePaintOrder: shown);
  }

  @override
  void clearSemantics() {
    super.clearSemantics();
    _semantics.clear();
  }
}
