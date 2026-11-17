// A keyed selection shared by lists and grids. The group owns one keyboard
// stop; its items remain individually named and selected in semantics.
import 'dart:ui' show SemanticsRole;
import 'package:codelessly_api/core.dart' show Node, SelectionListProps;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart' show RenderBox;

import '../render/controls/focus.dart';
import '../render/controls/root.dart';
import '../render/recipe.dart';

@immutable
class SelectionChoice {
  const SelectionChoice(this.key, this.label);
  final String key, label;
}

void selectionListRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  chain.add(
    b.fitBox(
      'fit',
      n.layout.width.fit,
      n.layout.height.fit,
      Size(n.layout.width.value, n.layout.height.value),
    ),
  );
  final variable = n.prop(SelectionListProps.variable);
  final values = b.tree.bindings?.valuesFor(b.source, b.id, b.instance);
  final items = [
    for (final raw in n.prop(SelectionListProps.items))
      if (raw['key'] is String && raw['label'] is String)
        SelectionChoice(raw['key'] as String, raw['label'] as String),
  ];
  chain.add(
    b.island(
      'selectionList',
      (_) => SelectionListControl(
        label: n.prop(SelectionListProps.label),
        items: items,
        columns: n.prop(SelectionListProps.columns),
        selected: () => [
          for (final v
              in (values?.read(variable) is List
                  ? values!.read(variable) as List
                  : const []))
            '$v',
        ],
        onChanged: (next) => values?.write(variable, next),
        listen: values?.watch(variable),
      ),
    ),
  );
}

/// A group with one Tab stop. Arrows move its active choice; Shift extends a
/// range; Ctrl/Cmd+A selects all. Touch taps toggle so a phone needs no modifier.
class SelectionListControl extends StatefulWidget {
  const SelectionListControl({
    super.key,
    required this.label,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.columns = 1,
    this.listen,
  });
  final String label;
  final List<SelectionChoice> items;
  final int columns;
  final List<String> Function() selected;
  final void Function(List<String>) onChanged;
  final Listenable? listen;

  @override
  State<SelectionListControl> createState() => _SelectionListControlState();
}

class _SelectionListControlState extends State<SelectionListControl> {
  final FocusNode _focus = FocusNode(debugLabel: 'selection group');
  int _active = 0, _anchor = 0;
  int _layoutColumns = 1;
  List<String>? _rangeBase;
  bool _keyboardFocus = false;
  List<String> _current = [];

  /// The group's stop in the page's own focus order (the controls' scope),
  /// when it is drawn in a page: Tab reaches it there as it reaches a slider,
  /// and its keys come from that scope. Outside one (a bare widget) the
  /// Flutter focus node below is the stop.
  ControlFocusNode? _stop;
  final GlobalKey _groupKey = GlobalKey();

  bool get _focused => _stop?.hasFocus ?? _focus.hasFocus;
  bool get _ringShown => _stop != null ? _stop!.showsHighlight : _focus.hasFocus && _keyboardFocus;

  void _redraw() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _syncStop() {
    if (!mounted) return;
    final owner = _groupKey.currentContext?.findRenderObject();
    final root = owner is RenderBox ? RenderControlRoot.of(owner) : null;
    if (owner is! RenderBox || root == null) {
      _stop?.leave();
      _stop = null;
      return;
    }
    if (identical(_stop?.owner, owner) && identical(_stop?.scope, root.focus)) return;
    _stop?.leave();
    _stop = ControlFocusNode(owner, onKey: (event) => _key(_focus, event) == KeyEventResult.handled, onFocusChange: (_) => _redraw())
      ..label = (() => widget.label)
      ..onHighlightChange = _redraw
      ..join(root.focus);
    _redraw();
  }

  @override
  void initState() {
    super.initState();
    _current = widget.selected();
    widget.listen?.addListener(_sync);
  }

  @override
  void didUpdateWidget(SelectionListControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listen != widget.listen) {
      oldWidget.listen?.removeListener(_sync);
      widget.listen?.addListener(_sync);
    }
    _sync();
  }

  void _sync() {
    final next = widget.selected();
    if (!listEquals(next, _current) && mounted) {
      _rangeBase = null;
      setState(() => _current = next);
    }
  }

  @override
  void dispose() {
    widget.listen?.removeListener(_sync);
    _stop?.leave();
    _focus.dispose();
    super.dispose();
  }

  void _write(Iterable<String> keys) {
    final allowed = {for (final i in widget.items) i.key};
    final next = keys.toSet().where(allowed.contains).toList();
    setState(() => _current = next);
    widget.onChanged(next);
  }

  void _choose(int at, {bool range = false}) {
    if (widget.items.isEmpty) return;
    at = at.clamp(0, widget.items.length - 1);
    final key = widget.items[at].key;
    if (range) {
      _rangeBase ??= [..._current];
      final first = _anchor < at ? _anchor : at,
          last = _anchor > at ? _anchor : at;
      _write([
        ..._rangeBase!,
        for (var i = first; i <= last; i++) widget.items[i].key,
      ]);
    } else {
      _rangeBase = null;
      final next = [..._current];
      next.contains(key) ? next.remove(key) : next.add(key);
      _write(next);
      _anchor = at;
    }
    setState(() => _active = at);
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || widget.items.isEmpty)
      return KeyEventResult.ignored;
    final k = event.logicalKey, hw = HardwareKeyboard.instance;
    final mod = hw.isControlPressed || hw.isMetaPressed;
    if (mod && k == LogicalKeyboardKey.keyA) {
      _rangeBase = null;
      _write([for (final item in widget.items) item.key]);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.space) {
      _choose(_active, range: hw.isShiftPressed);
      return KeyEventResult.handled;
    }
    // Escape clears a selection; with none it is left to what is around the
    // group (an overlay it is in closes).
    if (k == LogicalKeyboardKey.escape) {
      if (_current.isEmpty) return KeyEventResult.ignored;
      _rangeBase = null;
      _write(const []);
      return KeyEventResult.handled;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final cols = _layoutColumns;
    final step = switch (k) {
      LogicalKeyboardKey.arrowDown => cols,
      LogicalKeyboardKey.arrowUp => -cols,
      LogicalKeyboardKey.arrowRight => rtl ? -1 : 1,
      LogicalKeyboardKey.arrowLeft => rtl ? 1 : -1,
      _ => 0,
    };
    final to = k == LogicalKeyboardKey.home
        ? 0
        : k == LogicalKeyboardKey.end
        ? widget.items.length - 1
        : _active + step;
    if (step == 0 &&
        k != LogicalKeyboardKey.home &&
        k != LogicalKeyboardKey.end)
      return KeyEventResult.ignored;
    final target = to.clamp(0, widget.items.length - 1);
    if (hw.isShiftPressed) {
      _rangeBase ??= [..._current];
      final first = _anchor < target ? _anchor : target,
          last = _anchor > target ? _anchor : target;
      _write([
        ..._rangeBase!,
        for (var i = first; i <= last; i++) widget.items[i].key,
      ]);
    } else {
      _rangeBase = null;
      _anchor = target;
    }
    setState(() {
      _active = target;
      _keyboardFocus = true;
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final count = _current.length;
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncStop());
    return ListenableBuilder(
      listenable: widget.listen ?? _never,
      builder: (context, _) {
        final width = MediaQuery.sizeOf(context).width;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: '${widget.label}, multi-select, $count selected',
              container: true,
              child: Text(
                '${widget.label} · $count selected',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              role: SemanticsRole.list,
              label: '${widget.label}, multi-select, $count selected',
              container: true,
              explicitChildNodes: true,
              child: Focus(
                key: _groupKey,
                focusNode: _focus,
                // In a page the stop is the page's own (above): this node
                // would be a second one.
                canRequestFocus: _stop == null,
                skipTraversal: _stop != null,
                onKeyEvent: _key,
                onFocusChange: (on) => setState(() {
                  _keyboardFocus =
                      on &&
                      FocusManager.instance.highlightMode ==
                          FocusHighlightMode.traditional;
                }),
                child: LayoutBuilder(
                  builder: (context, limits) {
                    final w = limits.maxWidth.isFinite
                        ? limits.maxWidth
                        : width;
                    final cols = _layoutColumns = w < 600
                        ? 1
                        : widget.columns.clamp(
                            1,
                            widget.items.isEmpty ? 1 : widget.items.length,
                          );
                    final cell = (w - (cols - 1) * 8) / cols;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _ringShown ? colors.primary : colors.outlineVariant,
                          width: _ringShown ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < widget.items.length; i++)
                              SizedBox(
                                width: cell - 6,
                                child: Semantics(
                                  button: true,
                                  selected: _current.contains(
                                    widget.items[i].key,
                                  ),
                                  focused: _focused && _active == i,
                                  label: widget.items[i].label,
                                  onTap: () => _choose(i),
                                  child: ExcludeSemantics(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        if (_stop case final stop?) {
                                          ControlFocusScope.noteActivation(stop, keyboard: false);
                                          stop.requestFocus(highlight: false);
                                        } else {
                                          _focus.requestFocus();
                                        }
                                        _keyboardFocus = false;
                                        _choose(
                                          i,
                                          range: HardwareKeyboard
                                              .instance
                                              .isShiftPressed,
                                        );
                                      },
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minHeight: 44,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              _current.contains(
                                                widget.items[i].key,
                                              )
                                              ? colors.primaryContainer
                                              : colors.surface,
                                          border: Border.all(
                                            color:
                                                _active == i && _focused
                                                ? colors.primary
                                                : colors.outlineVariant,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              _current.contains(
                                                    widget.items[i].key,
                                                  )
                                                  ? Icons.check_box
                                                  : Icons
                                                        .check_box_outline_blank,
                                              size: 20,
                                              color: colors.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                widget.items[i].label,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () =>
                    _write([for (final item in widget.items) item.key]),
                child: const Text('Select all'),
              ),
            ),
          ],
        );
      },
    );
  }
}

final _never = ChangeNotifier();
