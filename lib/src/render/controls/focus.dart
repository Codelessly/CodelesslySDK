// Keyboard focus for render objects: what Flutter's FocusNode, FocusScope,
// FocusTraversalGroup and Shortcuts/Actions do for widgets, for the controls
// the SDK draws itself.
//
// A control owns a [ControlFocusNode]; the root it is under
// ([RenderControlRoot], render/controls/root.dart) owns the
// [ControlFocusScope] it joins while attached. The root is fed key events by
// its host ([ControlKeyboard]): the widget adapter feeds them from
// `FocusManager`'s early handlers (so a key a control handles never reaches
// Flutter's own traversal), a root attached to a view with no widget from
// `HardwareKeyboard`. Tab and Shift-Tab move in reading order (rows top to
// bottom, then left to right; wrapping), Enter, Numpad Enter and Space
// activate the focused control, Escape drops the focus.
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Where a root's key events come from, and its bridge to the host's own
/// focus (an island's text field during the migration).
abstract interface class ControlKeyboard {
  /// Starts sending key events to [handler] (true: handled).
  void attach(bool Function(KeyEvent event) handler);

  /// Stops sending them.
  void detach(bool Function(KeyEvent event) handler);

  /// Whether one of the host's own widgets has keyboard focus: Tab is then
  /// the host's.
  bool get hostHasFocus;

  /// A control took the focus: the host lets go of its own.
  void yieldHostFocus();
}

/// Key events from `HardwareKeyboard`: a root with no widget around it.
class HardwareKeyboardInput implements ControlKeyboard {
  const HardwareKeyboardInput();

  @override
  void attach(bool Function(KeyEvent event) handler) => HardwareKeyboard.instance.addHandler(handler);

  @override
  void detach(bool Function(KeyEvent event) handler) => HardwareKeyboard.instance.removeHandler(handler);

  @override
  bool get hostHasFocus => false;

  @override
  void yieldHostFocus() {}
}

/// A control's place in its root's focus order (Flutter's `FocusNode`).
class ControlFocusNode {
  ControlFocusNode(this.owner, {this.onActivate, this.onKey, this.onFocusChange});

  /// The control's render box: where it is on screen, for the order.
  final RenderBox owner;

  /// Enter, Numpad Enter or Space while focused (Flutter's `ActivateIntent`).
  VoidCallback? onActivate;

  /// The control's own keys while focused (a slider's arrows); true when
  /// handled. Asked before Tab, Enter and Space.
  bool Function(KeyEvent event)? onKey;

  /// The focus came ([focused]) or went.
  void Function(bool focused)? onFocusChange;

  /// Whether Tab may stop here (a disabled control may not).
  bool canRequestFocus = true;

  ControlFocusScope? _scope;

  /// The scope it is in (while its control is attached under a root).
  ControlFocusScope? get scope => _scope;

  bool _autofocus = false;

  /// Takes the focus as soon as it joins a scope (Flutter's `autofocus`).
  set autofocus(bool v) {
    if (v == _autofocus) return;
    _autofocus = v;
    if (v) _scope?._autofocus(this);
  }

  bool get hasFocus => _scope?.focused == this;

  /// Whether the focus came from the keyboard (Tab, autofocus, an action):
  /// the control shows its focus ring (Flutter's `FocusHighlightMode`).
  bool get showsHighlight => hasFocus && (_scope?._highlight ?? false);

  /// Takes the focus; false when not in a scope or it can't.
  bool requestFocus() => _scope?._focus(this) ?? false;

  /// Lets go of the focus (it goes nowhere).
  void unfocus() {
    if (hasFocus) _scope!._focus(null);
  }

  /// Joins [scope] (the root's, when the control attaches).
  void join(ControlFocusScope scope) {
    if (identical(_scope, scope)) return;
    _scope?._remove(this);
    _scope = scope;
    scope._nodes.add(this);
    if (_autofocus) scope._autofocus(this);
  }

  /// Leaves its scope (the control detached): it loses the focus.
  void leave() {
    _scope?._remove(this);
    _scope = null;
  }
}

/// The focus order of one root (Flutter's `FocusScopeNode` with a
/// `ReadingOrderTraversalPolicy`).
class ControlFocusScope {
  ControlFocusScope({this.keyboard});

  /// The root's host input (its [ControlKeyboard.hostHasFocus] and
  /// [ControlKeyboard.yieldHostFocus] bridge the host's focus).
  ControlKeyboard? keyboard;

  final List<ControlFocusNode> _nodes = [];

  /// The scope whose control has the focus, of all roots; null: none.
  static ControlFocusScope? _focusedScope;

  ControlFocusNode? _focused;

  /// The focused control of this scope.
  ControlFocusNode? get focused => _focused;

  bool _highlight = false;

  /// Called after the focus changed (the root repaints what it shows).
  VoidCallback? onChange;

  /// Every node, focusable or not.
  Iterable<ControlFocusNode> get nodes => _nodes;

  void _remove(ControlFocusNode n) {
    _nodes.remove(n);
    if (identical(_focused, n)) _focus(null);
  }

  void _autofocus(ControlFocusNode n) {
    if (_focused == null && _focusedScope == null && n.canRequestFocus) {
      _highlight = true;
      _focus(n);
    }
  }

  bool _focus(ControlFocusNode? n) {
    if (n != null && !n.canRequestFocus) return false;
    final old = _focused;
    if (identical(old, n)) return n != null;
    _focused = n;
    if (n != null) {
      if (!identical(_focusedScope, this)) {
        final other = _focusedScope;
        _focusedScope = this;
        other?._focus(null);
      }
      keyboard?.yieldHostFocus();
    } else if (identical(_focusedScope, this)) {
      _focusedScope = null;
    }
    old?.onFocusChange?.call(false);
    n?.onFocusChange?.call(true);
    onChange?.call();
    return n != null;
  }

  /// The host focused one of its own widgets: this scope lets go.
  void hostTookFocus() => _focus(null);

  /// The nodes Tab stops at, in reading order: rows from the top (boxes
  /// that overlap vertically are a row), left to right in a row.
  List<ControlFocusNode> get order {
    final placed = <(ControlFocusNode, Rect)>[
      for (final n in _nodes)
        if (n.canRequestFocus && n.owner.attached && n.owner.hasSize)
          (n, MatrixUtils.transformRect(n.owner.getTransformTo(null), Offset.zero & n.owner.size)),
    ];
    placed.sort((a, b) {
      final ra = a.$2, rb = b.$2;
      final sameRow = ra.center.dy >= rb.top && ra.center.dy <= rb.bottom || rb.center.dy >= ra.top && rb.center.dy <= ra.bottom;
      if (!sameRow) return ra.top.compareTo(rb.top);
      return ra.left.compareTo(rb.left);
    });
    return [for (final p in placed) p.$1];
  }

  /// Moves the focus to the next node in [order] (the previous one when
  /// [backward]), wrapping; from nowhere to the first (the last).
  bool next({bool backward = false}) {
    final o = order;
    if (o.isEmpty) return false;
    final at = _focused == null ? -1 : o.indexOf(_focused!);
    final i = at < 0 ? (backward ? o.length - 1 : 0) : (at + (backward ? -1 : 1)) % o.length;
    _highlight = true;
    return _focus(o[i]);
  }

  /// A key event for this scope's root; true when handled. Tab from
  /// nowhere is taken by the first scope with somewhere to go, unless the
  /// host's own focus has it.
  bool handleKeyEvent(KeyEvent event) {
    if (event is KeyUpEvent) return false;
    final key = event.logicalKey;
    final focused = _focused;
    if (focused == null) {
      if (key != LogicalKeyboardKey.tab || _focusedScope != null) return false;
      if (keyboard?.hostHasFocus ?? false) return false;
      return next(backward: HardwareKeyboard.instance.isShiftPressed);
    }
    if (focused.onKey?.call(event) ?? false) return true;
    if (key == LogicalKeyboardKey.tab) return next(backward: HardwareKeyboard.instance.isShiftPressed);
    if (key == LogicalKeyboardKey.escape) {
      _focus(null);
      return true;
    }
    if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.space)) {
      _highlight = true;
      focused.onActivate?.call();
      return true;
    }
    return false;
  }
}
