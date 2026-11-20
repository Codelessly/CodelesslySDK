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
//
// Three behaviours every focusable shares live here, so no control writes
// its own:
//
// - [ControlFocusGroup]: a container that is one Tab stop; the arrows (and
//   Home, End, a typed letter) move the focus among its members. A menu
//   written from plain nodes uses it (`focusGroup` in the document); a tab
//   bar, a segmented button, a radio group, a toolbar or a tree can.
// - [ControlFocusLayer]: a modal overlay (a dialog, a sheet, a popover).
//   While it is the top one only the scopes in it take keys (Tab stays
//   inside), Escape asks it to close, and closing it gives the focus back
//   to what opened it.
// - [TypeAhead]: letters typed in quick succession find a label.
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Where a root's key events come from, and its bridge to the host's own
/// focus (an island's text field).
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

/// What a control did with a key ([ControlFocusNode.onKeyResult]):
/// Flutter's `KeyEventResult`.
enum ControlKeyResult {
  /// Its key: the scope does nothing more, the host never sees it.
  handled,

  /// Not its key: the scope goes on (Tab moves, Enter and Space press).
  ignored,

  /// Not its key and not the scope's either: nothing presses or moves, and
  /// the key goes back to the host unhandled, so the platform's text input
  /// gets it (a text field's Space and Enter, which an IME may compose with;
  /// Flutter's `KeyEventResult.skipRemainingHandlers`).
  passThrough,
}

/// A render object that takes what is under it out of the focus order while
/// it does not show it (a node's box while the node is hidden).
abstract interface class FocusGate {
  /// Whether the focus may be on what is under it now.
  bool get admitsFocus;
}

/// A control's place in its root's focus order (Flutter's `FocusNode`).
class ControlFocusNode {
  ControlFocusNode(this.owner, {this.onActivate, this.onKey, this.onKeyResult, this.onFocusChange});

  /// The control's render box: where it is on screen, for the order.
  final RenderBox owner;

  /// Enter, Numpad Enter or Space while focused (Flutter's `ActivateIntent`).
  VoidCallback? onActivate;

  /// The control's own keys while focused (a slider's arrows); true when
  /// handled. Asked before Tab, Enter and Space. [onKeyResult], when set,
  /// is asked instead.
  bool Function(KeyEvent event)? onKey;

  /// The control's own keys, with a [ControlKeyResult]: what [onKey] says,
  /// plus [ControlKeyResult.passThrough] for a key that must reach the
  /// platform untouched.
  ControlKeyResult Function(KeyEvent event)? onKeyResult;

  /// What the control does with [event].
  ControlKeyResult keyResult(KeyEvent event) {
    if (onKeyResult case final f?) return f(event);
    return (onKey?.call(event) ?? false) ? ControlKeyResult.handled : ControlKeyResult.ignored;
  }

  /// The focus came ([focused]) or went.
  void Function(bool focused)? onFocusChange;

  /// The focus stays here and how it shows changed ([showsHighlight]: a key
  /// pressed after a pointer brought the focus).
  VoidCallback? onHighlightChange;

  /// Whether Tab may stop here (a disabled control may not).
  bool canRequestFocus = true;

  /// Asked each time the focus would come here, beside [canRequestFocus]:
  /// a press target whose reaction's condition does not hold now is skipped.
  bool Function()? focusableWhen;

  /// What it is called: a group's type-ahead matches it, and an overlay it
  /// opened is named after it. Null: no name.
  String? Function()? label;

  /// Whether it is the chosen one of its group (the focus enters the group
  /// there).
  bool Function()? selected;

  /// A text field: an overlay that opens while it is typed in (suggestions
  /// under a search field) leaves the focus with it.
  bool isTextInput = false;

  /// Whether the focus may come here now.
  bool get canFocus => canRequestFocus && (focusableWhen?.call() ?? true);

  ControlFocusScope? _scope;

  /// The scope it is in (while its control is attached under a root).
  ControlFocusScope? get scope => _scope;

  bool _autofocus = false;

  /// Whether its autofocus has had its turn (it joined an active scope with
  /// autofocus on): as Flutter's `autofocus`, once, not again each time its
  /// control is attached (a page's render objects moved by the navigator as
  /// its route leaves would take the focus back from a field a Save blurred).
  bool _autofocused = false;

  /// Takes the focus as soon as it joins a scope (Flutter's `autofocus`).
  set autofocus(bool v) {
    if (v == _autofocus) return;
    _autofocus = v;
    _autofocused = false;
    if (v) _tryAutofocus();
  }

  void _tryAutofocus() {
    final s = _scope;
    if (s == null || _autofocused || !_autofocus) return;
    // An inactive scope (a page under a dialog) gives it its turn later.
    if (s.active) _autofocused = true;
    s._autofocus(this);
  }

  bool get hasFocus => _scope?.focused == this;

  /// Whether the focus came from the keyboard (Tab, autofocus, an action):
  /// the control shows its focus ring (Flutter's `FocusHighlightMode`).
  bool get showsHighlight => hasFocus && (_scope?._highlight ?? false);

  /// Takes the focus; false when not in a scope or it can't. [highlight]
  /// says how it shows: true as the keyboard brings it (the ring), false as
  /// a pointer does (none); null leaves the scope's mode as it is.
  bool requestFocus({bool? highlight}) {
    final scope = _scope;
    if (scope == null) return false;
    if (highlight != null && canFocus) scope._setHighlight(highlight);
    return scope._focus(this);
  }

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
    _tryAutofocus();
  }

  /// Leaves its scope (the control detached): it loses the focus.
  void leave() {
    _scope?._remove(this);
    _scope = null;
  }
}

/// Which arrow keys move the focus inside a [ControlFocusGroup].
enum ControlFocusAxis {
  /// Up and Down (a menu, a list, a sidebar).
  vertical,

  /// Left and Right (a tab bar, a toolbar, a segmented button).
  horizontal,

  /// All four, in reading order (a grid of tiles read as one line).
  both,
}

/// A container whose focusable descendants are one Tab stop (a roving
/// focus, as WAI-ARIA's composite widgets have): Tab enters at the member
/// that was focused last (else the selected one, else the first) and leaves
/// to the next stop outside; the arrows of its [axis] move the focus among
/// the members in reading order, Home and End jump to the ends, and with
/// [typeAhead] a typed letter jumps to the next member whose
/// [ControlFocusNode.label] starts with it.
///
/// Its members are the focus nodes whose box is inside [owner] (a nearer
/// group inside takes its own). A member's own keys come first (a slider in
/// a toolbar keeps its arrows).
class ControlFocusGroup {
  ControlFocusGroup(this.owner,
      {this.axis = ControlFocusAxis.vertical, this.wrap = true, this.typeAhead = false, this.rightToLeft = false});

  /// The container's render box.
  final RenderBox owner;

  ControlFocusAxis axis;

  /// Whether an arrow past the last member goes to the first (and back).
  bool wrap;

  /// Whether a typed character jumps to a member by its label.
  bool typeAhead;

  /// Right-to-left: Left moves forward and Right back on a horizontal
  /// [axis].
  bool rightToLeft;

  ControlFocusScope? _scope;
  ControlFocusNode? _last;
  final TypeAhead _typed = TypeAhead();

  /// Joins [scope] (the root's, when the container attaches).
  void join(ControlFocusScope scope) {
    if (identical(_scope, scope)) return;
    leave();
    _scope = scope;
    scope._groups[owner] = this;
  }

  /// Leaves its scope (the container detached).
  void leave() {
    _scope?._groups.remove(owner);
    _scope = null;
    _last = null;
  }
}

/// Letters typed in quick succession (within [timeout]) spell the start of
/// a label; one letter repeated cycles through the labels that start with
/// it. What a menu's, a list's and a focus group's type-ahead share.
class TypeAhead {
  TypeAhead({this.timeout = const Duration(milliseconds: 700)});

  final Duration timeout;
  String _typed = '';
  final Stopwatch _since = Stopwatch();

  /// Forgets what was typed.
  void reset() => _typed = '';

  /// [character] was typed: the index in [labels] to go to, from [current]
  /// (null: none is current), or null when no label matches. [labels] are
  /// the ones that can be gone to, in order.
  int? match(String character, List<String> labels, int? current) {
    if (!_since.isRunning || _since.elapsed > timeout) _typed = '';
    _since
      ..reset()
      ..start();
    _typed += character.toLowerCase();
    if (labels.isEmpty) return null;
    final cycling = _typed.length > 1 && _typed.split('').every((c) => c == _typed[0]);
    final needle = cycling ? _typed[0] : _typed;
    final start = current ?? -1;
    final from = (cycling || _typed.length == 1) ? start + 1 : (start < 0 ? 0 : start);
    for (var step = 0; step < labels.length; step++) {
      final i = (from + step) % labels.length;
      if (labels[i].trimLeft().toLowerCase().startsWith(needle)) return i;
    }
    return null;
  }
}

/// A modal overlay's hold on the keyboard (a dialog, a sheet, a popover, a
/// menu, a full-screen cover): Flutter's route `FocusScopeNode` and
/// `DismissIntent`, for the controls' scopes.
///
/// The host [open]s it when the overlay shows and [close]s it when the
/// overlay starts to go; the roots shown inside it set it as their scope's
/// [ControlFocusScope.layer]. While it is the [top] one:
///
/// - only its scopes take keys: Tab and Shift+Tab stay inside it;
/// - the focus is inside it: on the first focusable (in a group, the
///   selected member) when the keyboard opened it, else on the overlay
///   itself, nothing focused, until a key is pressed (so a pointer or touch
///   user sees no ring and no on-screen keyboard);
/// - Escape asks [onDismiss] to close it.
///
/// Closing it gives the focus back to what opened it (the control that was
/// activated, else the one that had the focus): with the ring when the
/// keyboard was used to open or to close it, else silently (the next Tab
/// starts there). When that control is gone, the focus goes to what opened
/// the overlay it was in, and so on down: nested overlays unwind.
class ControlFocusLayer {
  ControlFocusLayer({this.onDismiss, this.isCurrent});

  /// Escape while this is the top layer; true when the key was used (it
  /// closed, or told the document it was asked to). Null: Escape does
  /// nothing.
  bool Function()? onDismiss;

  /// Whether the overlay is the one the user is on (its route is the
  /// navigator's current one); null: while it is open.
  bool Function()? isCurrent;

  static final List<ControlFocusLayer> _open = [];

  /// The layer that holds the keyboard: the last one opened that is still
  /// open and current. Null: none (the page's own scopes take keys).
  static ControlFocusLayer? get top {
    for (var i = _open.length - 1; i >= 0; i--) {
      if (_open[i].isCurrent?.call() ?? true) return _open[i];
    }
    return null;
  }

  final Set<ControlFocusScope> _scopes = {};

  ControlFocusNode? _opener;
  ControlFocusLayer? _openerLayer;
  bool _keyboard = false;
  bool _pendingFocus = false;

  /// The control that opened it; null: none known.
  ControlFocusNode? get opener => _opener;

  /// Whether the keyboard opened it or was used in it.
  bool get usedKeyboard => _keyboard;

  bool get isOpen => _open.contains(this);

  /// What its opener calls itself (a menu is named after its button).
  String? get openerLabel => _opener?.label?.call();

  /// The overlay shows: it takes the keyboard from what is under it.
  void open() {
    if (isOpen) return;
    final activation = ControlFocusScope._takeActivation();
    final focused = ControlFocusScope._focusedScope?._focused;
    // Opened while a text field is typed in, by nothing that was pressed
    // (the suggestions under a search field): the field keeps the focus and
    // the overlay holds nothing.
    if (activation == null && focused != null && focused.isTextInput) return;
    _opener = activation?.node ?? focused;
    _keyboard = activation?.keyboard ?? (focused != null && (focused._scope?._highlight ?? false));
    _openerLayer = _opener?._scope?.layer;
    _open.add(this);
    _pendingFocus = _keyboard;
    final under = ControlFocusScope._focusedScope;
    if (under != null && !identical(under.layer, this)) under._focus(null);
  }

  /// The overlay goes: what opened it has the focus again.
  void close() {
    final at = _open.indexOf(this);
    if (at < 0) return;
    // Its own route is no longer current by now: the top one but for that.
    final wasTop = !_open.skip(at + 1).any((l) => l.isCurrent?.call() ?? true);
    _open.removeAt(at);
    _pendingFocus = false;
    for (final s in _scopes) {
      if (s._focused != null) s._focus(null);
    }
    if (!wasTop) return;
    final target = _restoreTarget();
    final scope = target?._scope;
    if (target == null || scope == null || !identical(scope.layer, top)) return;
    if (_keyboard) {
      target.requestFocus(highlight: true);
    } else {
      scope._resume = target;
    }
  }

  /// The opener, or when it is gone the opener of the overlay it was in.
  ControlFocusNode? _restoreTarget() {
    ControlFocusLayer? layer = this;
    for (var depth = 0; layer != null && depth < 32; depth++) {
      final n = layer._opener;
      if (n != null && n._scope != null && n.owner.attached && n.canFocus) return n;
      final below = layer._openerLayer;
      if (below == null || below.isOpen) return null;
      layer = below;
    }
    return null;
  }

  /// Escape: asks the host to close it.
  bool dismiss() {
    _keyboard = true;
    return onDismiss?.call() ?? false;
  }

  /// Whether a root of the controls is shown in it (an overlay built from
  /// the host's own widgets, the built-in confirm, has none).
  bool get hasScopes => _scopes.isNotEmpty;

  /// Whether one of its scopes has the focus.
  bool get hasFocus => _scopes.any((s) => s._focused != null);

  /// Puts the focus on its first focusable when the keyboard opened it and
  /// nothing in it has the focus yet (its content may arrive after it
  /// opens: the roots ask again after each layout). True when it did.
  bool takeFocus() {
    if (!_pendingFocus || !identical(top, this)) return false;
    if (hasFocus) {
      _pendingFocus = false;
      return false;
    }
    for (final s in _scopes) {
      final stops = s.stops;
      if (stops.isEmpty) continue;
      _pendingFocus = false;
      return stops.first.requestFocus(highlight: true);
    }
    return false;
  }

  /// Whether it still waits to put the focus inside ([takeFocus]).
  bool get wantsFocus => _pendingFocus && isOpen;
}

/// The focus order of one root (Flutter's `FocusScopeNode` with a
/// `ReadingOrderTraversalPolicy`).
class ControlFocusScope {
  ControlFocusScope({this.keyboard});

  /// The root's host input (its [ControlKeyboard.hostHasFocus] and
  /// [ControlKeyboard.yieldHostFocus] bridge the host's focus).
  ControlKeyboard? keyboard;

  final List<ControlFocusNode> _nodes = [];
  final Map<RenderObject, ControlFocusGroup> _groups = {};

  /// The scope whose control has the focus, of all roots; null: none.
  static ControlFocusScope? _focusedScope;

  /// The scope whose control has the focus, of all roots; null: none.
  static ControlFocusScope? get focusedScope => _focusedScope;

  ControlFocusNode? _focused;

  /// The focused control of this scope.
  ControlFocusNode? get focused => _focused;

  bool _highlight = false;

  /// Whether the keyboard is what moves the focus now (the ring shows).
  bool get highlight => _highlight;

  void _setHighlight(bool v) {
    if (v == _highlight) return;
    _highlight = v;
    final f = _focused;
    if (f == null) return;
    f.onHighlightChange?.call();
    onChange?.call();
  }

  ControlFocusLayer? _layer;

  /// The modal overlay this root is shown in; null: the page itself.
  ControlFocusLayer? get layer => _layer;
  set layer(ControlFocusLayer? value) {
    if (identical(value, _layer)) return;
    _layer?._scopes.remove(this);
    _layer = value;
    value?._scopes.add(this);
  }

  /// Whether this scope takes keys now: it is in the top overlay, or there
  /// is none and it is the page's.
  bool get active => identical(ControlFocusLayer.top, _layer);

  // Where the next Tab starts when nothing has the focus: what opened an
  // overlay a pointer closed.
  ControlFocusNode? _resume;

  // What was pressed last, and how: an overlay that opens next was opened
  // by it.
  static WeakReference<ControlFocusNode>? _activated;
  static bool _activatedByKeyboard = false;

  /// [node] was pressed ([keyboard]: by Enter or Space, else by a pointer
  /// or a screen reader): an overlay that opens next was opened by it, and
  /// gives it the focus back when it closes.
  static void noteActivation(ControlFocusNode node, {required bool keyboard}) {
    _activated = WeakReference(node);
    _activatedByKeyboard = keyboard;
    _sinceActivated
      ..reset()
      ..start();
  }

  static final Stopwatch _sinceActivated = Stopwatch();

  /// How long after a press an overlay still counts as opened by it (its
  /// reactions may wait for an answer first). After that the control with
  /// the focus is the opener.
  static const activationWindow = Duration(seconds: 2);

  static ({ControlFocusNode node, bool keyboard})? _takeActivation() {
    final node = _activated?.target;
    _activated = null;
    if (_sinceActivated.elapsed > activationWindow) return null;
    if (node == null || node._scope == null) return null;
    return (node: node, keyboard: _activatedByKeyboard);
  }

  /// Called after the focus changed (the root repaints what it shows).
  VoidCallback? onChange;

  /// Every node, focusable or not.
  Iterable<ControlFocusNode> get nodes => _nodes;

  void _remove(ControlFocusNode n) {
    _nodes.remove(n);
    if (identical(_resume, n)) _resume = null;
    if (identical(_focused, n)) _focus(null);
  }

  void _autofocus(ControlFocusNode n) {
    if (_focused == null && _focusedScope == null && n.canFocus && active) {
      _highlight = true;
      _focus(n);
    }
  }

  bool _focus(ControlFocusNode? n) {
    if (n != null && !n.canFocus) return false;
    final old = _focused;
    if (identical(old, n)) return n != null;
    _focused = n;
    if (n != null) {
      _resume = null;
      groupOf(n)?._last = n;
      _layer?._pendingFocus = false;
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

  /// True while the root is detaching and drops the focus: its controls are
  /// leaving the screen, so they let go without asking for a new layout
  /// (the framework may be in the middle of one: a LayoutBuilder rebuilding
  /// the subtree that held the preview).
  bool get detaching => _detaching;
  bool _detaching = false;

  /// Drops the focus as the root leaves the screen ([detaching] meanwhile).
  void releaseOnDetach() {
    _detaching = true;
    try {
      _focus(null);
    } finally {
      _detaching = false;
    }
  }

  /// Whether what is around [box] lets a user reach it: nothing above it
  /// ignores the pointer (the document's `ignorePointer`: a checkbox the
  /// row around it toggles), is hidden ([FocusGate]: `visible: false`),
  /// offstage or drawn fully transparent.
  static bool reachable(RenderObject box) {
    for (RenderObject? p = box.parent; p != null; p = p.parent) {
      if (p case FocusGate(admitsFocus: false)) return false;
      if (p is RenderIgnorePointer && p.ignoring) return false;
      if (p is RenderAbsorbPointer && p.absorbing) return false;
      if (p is RenderOffstage && p.offstage) return false;
      // (Not an animated opacity: an overlay fading in is at 0 on the frame
      // the focus moves into it.)
      if (p is RenderOpacity && p.opacity == 0) return false;
    }
    return true;
  }

  /// The nodes the focus can be on, in the order of the tree (the order of
  /// the document's lines, as a web page's Tab follows its DOM): a box
  /// around another comes before it; a sidebar's stops all come before the
  /// main column's beside it. (By position on screen, as before, the order
  /// went from a lane's header to the sidebar beside it and back, and
  /// changed with the window's size: test 9, admin 5 and kanban 5.) A
  /// group's members are all here ([stops] has one of them).
  List<ControlFocusNode> get order {
    final placed = <ControlFocusNode>[
      for (final n in _nodes)
        if (n.owner.attached && n.owner.hasSize && n.canFocus && reachable(n.owner)) n,
    ];
    if (placed.length < 2) return placed;
    // Each node's ancestors, the root first.
    final chains = <ControlFocusNode, List<RenderObject>>{
      for (final n in placed)
        n: [
          for (RenderObject? p = n.owner; p != null; p = p.parent) p,
        ].reversed.toList(),
    };
    // The place of each child among its parent's, as the parent visits them.
    final places = <RenderObject, Map<RenderObject, int>>{};
    int placeOf(RenderObject parent, RenderObject child) {
      final map = places.putIfAbsent(parent, () {
        final m = <RenderObject, int>{};
        parent.visitChildren((c) => m[c] = m.length);
        return m;
      });
      return map[child] ?? 0;
    }

    int compare(ControlFocusNode a, ControlFocusNode b) {
      final ca = chains[a]!, cb = chains[b]!;
      var i = 0;
      while (i < ca.length && i < cb.length && identical(ca[i], cb[i])) {
        i++;
      }
      if (i == ca.length) return i == cb.length ? 0 : -1; // a is around b
      if (i == cb.length) return 1;
      if (i == 0) return 0; // two roots
      return placeOf(ca[i - 1], ca[i]).compareTo(placeOf(cb[i - 1], cb[i]));
    }

    return placed..sort(compare);
  }

  /// The group [node] is a member of (the nearest one around it).
  ControlFocusGroup? groupOf(ControlFocusNode node) {
    if (_groups.isEmpty) return null;
    for (RenderObject? p = node.owner; p != null; p = p.parent) {
      final g = _groups[p];
      if (g != null) return g;
    }
    return null;
  }

  /// The members of [group] the focus can be on, in reading order.
  List<ControlFocusNode> membersOf(ControlFocusGroup group) =>
      [for (final n in order) if (identical(groupOf(n), group)) n];

  /// Where Tab stops, in order: every node of [order] outside a group, and
  /// of each group one member: the one focused last, else its selected one,
  /// else its first.
  List<ControlFocusNode> get stops => _stopsOf(order);

  List<ControlFocusNode> _stopsOf(List<ControlFocusNode> order) {
    if (_groups.isEmpty) return order;
    final groups = <ControlFocusNode, ControlFocusGroup?>{for (final n in order) n: groupOf(n)};
    final chosen = <ControlFocusGroup, ControlFocusNode>{};
    for (final n in order) {
      final g = groups[n];
      if (g == null) continue;
      final has = chosen[g];
      if (identical(n, g._last)) {
        chosen[g] = n;
      } else if (has == null) {
        chosen[g] = n;
      } else if (!identical(has, g._last) && !(has.selected?.call() ?? false) && (n.selected?.call() ?? false)) {
        chosen[g] = n;
      }
    }
    return [
      for (final n in order)
        if (groups[n] == null || identical(chosen[groups[n]], n)) n,
    ];
  }

  void _show(ControlFocusNode n) {
    if (n.owner.attached) n.owner.showOnScreen(duration: const Duration(milliseconds: 150));
  }

  /// Moves the focus to the next stop in [stops] (the previous one when
  /// [backward]), wrapping; from nowhere to the first (the last), or to
  /// what opened the overlay that just closed.
  bool next({bool backward = false}) {
    final o = stops;
    if (o.isEmpty) return false;
    _setHighlight(true);
    final resume = _resume;
    if (_focused == null && resume != null && resume.owner.attached && resume.canFocus) {
      if (_focus(resume)) {
        _show(resume);
        return true;
      }
    }
    final at = _focused == null ? -1 : o.indexOf(_focused!);
    final i = at < 0 ? (backward ? o.length - 1 : 0) : (at + (backward ? -1 : 1)) % o.length;
    final moved = _focus(o[i]);
    if (moved) _show(o[i]);
    return moved;
  }

  /// A group's keys while [focused], one of its members, has the focus.
  bool _groupKey(ControlFocusGroup g, ControlFocusNode focused, KeyEvent event) {
    final key = event.logicalKey;
    final vertical = g.axis != ControlFocusAxis.horizontal, horizontal = g.axis != ControlFocusAxis.vertical;
    final forwardH = g.rightToLeft ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight;
    final backH = g.rightToLeft ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft;
    int? step;
    if (vertical && key == LogicalKeyboardKey.arrowDown || horizontal && key == forwardH) step = 1;
    if (vertical && key == LogicalKeyboardKey.arrowUp || horizontal && key == backH) step = -1;
    final home = key == LogicalKeyboardKey.home, end = key == LogicalKeyboardKey.end;
    String? typed;
    if (step == null && !home && !end) {
      if (!g.typeAhead) return false;
      final c = event.character;
      final keys = HardwareKeyboard.instance;
      if (keys.isControlPressed || keys.isMetaPressed || keys.isAltPressed) return false;
      if (c == null || c.length != 1 || c.codeUnitAt(0) <= 32) return false;
      typed = c;
    }
    final members = membersOf(g);
    if (members.isEmpty) return false;
    final at = members.indexOf(focused);
    int to;
    if (typed != null) {
      final found = g._typed.match(typed, [for (final m in members) m.label?.call() ?? ''], at < 0 ? null : at);
      if (found == null) return true;
      to = found;
    } else if (home) {
      to = 0;
    } else if (end) {
      to = members.length - 1;
    } else {
      to = at + step!;
      if (g.wrap) {
        to = (to + members.length) % members.length;
      } else {
        to = to.clamp(0, members.length - 1);
      }
    }
    _setHighlight(true);
    _layer?._keyboard = true;
    if (_focus(members[to])) _show(members[to]);
    return true;
  }

  /// A key event for this scope's root; true when handled. Tab from
  /// nowhere is taken by the first scope with somewhere to go, unless the
  /// host's own focus has it. A scope under the top overlay takes none.
  bool handleKeyEvent(KeyEvent event) {
    if (event is KeyUpEvent) return false;
    if (!active) return false;
    final key = event.logicalKey;
    final layer = _layer;
    final focused = _focused;
    if (focused == null) {
      if (_focusedScope != null && _focusedScope!.active) return false;
      if (keyboard?.hostHasFocus ?? false) return false;
      if (key == LogicalKeyboardKey.tab) {
        layer?._keyboard = true;
        final moved = next(backward: HardwareKeyboard.instance.isShiftPressed);
        // An overlay with nothing to stop at keeps Tab all the same.
        return moved || layer != null;
      }
      // In an overlay nothing has the focus until a key is pressed (a
      // pointer opened it): an arrow, Home or End starts in its group.
      if (layer != null) return _enterGroup(key);
      return false;
    }
    switch (focused.keyResult(event)) {
      case ControlKeyResult.handled:
        return true;
      case ControlKeyResult.passThrough:
        return false;
      case ControlKeyResult.ignored:
        break;
    }
    if (key == LogicalKeyboardKey.tab) {
      layer?._keyboard = true;
      next(backward: HardwareKeyboard.instance.isShiftPressed);
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      // In an overlay Escape closes it (when nothing in it has the focus
      // the overlay's host takes the key itself).
      if (layer != null) return event is KeyDownEvent && layer.dismiss();
      _focus(null);
      return true;
    }
    if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.space)) {
      _setHighlight(true);
      layer?._keyboard = true;
      noteActivation(focused, keyboard: true);
      focused.onActivate?.call();
      return true;
    }
    if (groupOf(focused) case final g?) return _groupKey(g, focused, event);
    return false;
  }

  bool _enterGroup(LogicalKeyboardKey key) {
    final forward = key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.home;
    final back = key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.end;
    if (!forward && !back) return false;
    final o = stops;
    if (o.isEmpty) return false;
    final g = groupOf(o.first);
    if (g == null) return false;
    final vertical = key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp;
    final horizontal = key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight;
    if (vertical && g.axis == ControlFocusAxis.horizontal || horizontal && g.axis == ControlFocusAxis.vertical) return false;
    final members = membersOf(g);
    if (members.isEmpty) return false;
    // Down (or Home) starts where Tab would; Up (or End) at the last.
    final to = forward ? (key == LogicalKeyboardKey.home ? members.first : o.first) : members.last;
    _setHighlight(true);
    _layer?._keyboard = true;
    if (_focus(to)) _show(to);
    return true;
  }
}
