// The keyboard in tests: press Tab, the arrows, Enter, Space, Escape or a
// letter on what is shown, and read back where the focus is and what a
// screen reader is told about it. For any control or design-system block
// under test (docs/BEHAVIOR_CHECKLIST.md):
//
//   final keys = Keyboard(tester);
//   await keys.tab();
//   expect(keys.focusedId, 'save');
//   expect(keys.ringShown, isTrue);
//   expect(keys.semantics!.isButton, isTrue);
//   await keys.enter();
//
// The focus is the SDK's own (render/controls/focus.dart): a control, a
// text field or a node with a click reaction, in the page or in the top
// overlay.
import 'dart:ui' show Tristate;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/focus.dart';
import 'package:codelessly_sdk/src/render/controls/kit.dart' show firstTextUnder;
import 'package:codelessly_sdk/src/render/controls/root.dart' show RenderControlRoot;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// What assistive technology is told about the focused node.
class FocusSemantics {
  FocusSemantics(this.data);

  final SemanticsData data;

  String get label => data.label;
  String get value => data.value;
  bool get isButton => data.flagsCollection.isButton;
  bool get isTextField => data.flagsCollection.isTextField;
  bool get isFocused => data.flagsCollection.isFocused == Tristate.isTrue;
  bool get isFocusable => data.flagsCollection.isFocused != Tristate.none;
  bool get isSelected => data.flagsCollection.isSelected == Tristate.isTrue;
  bool get isEnabled => data.flagsCollection.isEnabled != Tristate.isFalse;
  bool get canTap => data.hasAction(SemanticsAction.tap);

  @override
  String toString() => 'FocusSemantics("$label"${isButton ? ', button' : ''}${isFocused ? ', focused' : ''}'
      '${isSelected ? ', selected' : ''}${isEnabled ? '' : ', disabled'})';
}

/// Presses keys and reads the focus back.
class Keyboard {
  Keyboard(this.tester);

  final WidgetTester tester;

  /// How long each key is given to take effect (a route's transition, a
  /// state style's microtask).
  Duration settle = const Duration(milliseconds: 400);

  Future<void> _settle() async {
    await tester.pump();
    await tester.pump(settle);
  }

  /// Presses [key] (with Shift held when [shift]).
  Future<void> press(LogicalKeyboardKey key, {bool shift = false, String? character}) async {
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(key, character: character);
    await tester.sendKeyUpEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _settle();
  }

  Future<void> tab({bool shift = false}) => press(LogicalKeyboardKey.tab, shift: shift);
  Future<void> shiftTab() => tab(shift: true);
  Future<void> enter() => press(LogicalKeyboardKey.enter);
  Future<void> space() => press(LogicalKeyboardKey.space, character: ' ');
  Future<void> escape() => press(LogicalKeyboardKey.escape);
  Future<void> up() => press(LogicalKeyboardKey.arrowUp);
  Future<void> down() => press(LogicalKeyboardKey.arrowDown);
  Future<void> left() => press(LogicalKeyboardKey.arrowLeft);
  Future<void> right() => press(LogicalKeyboardKey.arrowRight);
  Future<void> home() => press(LogicalKeyboardKey.home);
  Future<void> end() => press(LogicalKeyboardKey.end);

  /// Types one letter or digit (a menu's type-ahead).
  Future<void> letter(String character) {
    final c = character.toLowerCase();
    final key = LogicalKeyboardKey.findKeyByKeyId(c.codeUnitAt(0)) ?? LogicalKeyboardKey(c.codeUnitAt(0));
    return press(key, character: character);
  }

  /// The focus node that has the keyboard, of every root; null: none.
  ControlFocusNode? get focused => ControlFocusScope.focusedScope?.focused;

  /// The node box around what has the focus.
  NodeBox? get focusedBox {
    for (RenderObject? p = focused?.owner; p != null; p = p.parent) {
      if (p is NodeBox) return p;
    }
    return null;
  }

  /// The id of the node that has the focus; null: nothing has it.
  String? get focusedId => focusedBox?.id;

  /// The first text the focused node shows (a row's title, a button's
  /// label).
  String? get focusedText {
    final n = focused;
    if (n == null) return null;
    return n.label?.call() ?? firstTextUnder(n.owner);
  }

  /// Whether the focus ring shows (the keyboard brought the focus).
  bool get ringShown => focused?.showsHighlight ?? false;

  /// Whether the focus is inside a modal overlay (a dialog, a menu).
  bool get inOverlay => ControlFocusScope.focusedScope?.layer != null;

  /// The open modal overlays' hold on the keyboard: the top one, or null.
  ControlFocusLayer? get topOverlay => ControlFocusLayer.top;

  /// What a screen reader is told about the focused node (semantics must be
  /// on: `tester.ensureSemantics()`).
  FocusSemantics? get semantics {
    final n = focused;
    return n == null ? null : semanticsOf(n.owner);
  }

  /// What a screen reader is told about [box] (the nearest semantics node
  /// at or around it).
  FocusSemantics? semanticsOf(RenderObject box) {
    for (RenderObject? p = box; p != null; p = p.parent) {
      final s = p.debugSemantics;
      if (s != null) return FocusSemantics(s.getSemanticsData());
    }
    return null;
  }

  /// The ids of the Tab stops of the root that has the focus (or of [tree]'s
  /// first root), in order.
  List<String?> stopIds(RenderObject anyBoxOfTheRoot) {
    ControlFocusScope? scope;
    for (RenderObject? p = anyBoxOfTheRoot; p != null; p = p.parent) {
      if (p is RenderControlRoot) scope = p.focus;
    }
    return [
      for (final n in scope?.stops ?? const <ControlFocusNode>[])
        () {
          for (RenderObject? p = n.owner; p != null; p = p.parent) {
            if (p is NodeBox) return p.id;
          }
          return null;
        }(),
    ];
  }

  /// The name the open route announces (the innermost `namesRoute` label).
  String? get routeName {
    String? name;
    void visit(SemanticsNode node) {
      final d = node.getSemanticsData();
      if (d.flagsCollection.namesRoute && d.label.isNotEmpty) name = d.label;
      node.visitChildren((c) {
        visit(c);
        return true;
      });
    }

    final root = tester.binding.renderViews.single.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
    return name;
  }
}
