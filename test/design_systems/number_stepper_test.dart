import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/node_tree.dart';
import 'package:codelessly_sdk/src/render/controls/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keyboard.dart';

Future<UiSession> showNumber(WidgetTester tester, String control, {Size size = const Size(1280, 800), bool dark = false}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final problems = <String>[];
  final ds = await tester.runAsync(() => api.DesignSystem.load((ref) async {
    final file = File('design_systems/cards/$ref');
    return file.existsSync() ? file.readAsStringSync() : null;
  }, problems: problems));
  expect(problems, isEmpty);
  final session = UiSession(designSystem: ds);
  addTearDown(session.dispose);
  await tester.pumpWidget(MaterialApp(themeMode: dark ? ThemeMode.dark : ThemeMode.light, home: Scaffold(body: CodelesslyView(session: session))));
  final result = await session.applyNotation(Stream.value('''
state qty=3
Page
  Section
    $control
    Text#count "Count {qty}"
'''.trimLeft()));
  await tester.pump(const Duration(milliseconds: 600));
  expect(session.notationIssues, isEmpty);
  expect(result.errors, isEmpty);
  return session;
}

NodeBox box(WidgetTester tester, String id) {
  NodeBox? found;
  void visit(RenderObject o) {
    if (o is NodeBox && o.id == id && o.attached) found = o;
    o.visitChildren(visit);
  }
  for (final view in tester.binding.renderViews) { visit(view); }
  return found!;
}

Offset center(NodeBox box) => box.localToGlobal(box.size.center(Offset.zero));

String numberText(WidgetTester tester, [String id = 'number']) {
  RenderTextField? field;
  void visit(RenderObject o) {
    if (o is RenderTextField) field = o;
    o.visitChildren(visit);
  }
  visit(box(tester, id));
  return field!.editor.text;
}

void main() {
  testWidgets('Stepper has one number stop and its keys honor step and bounds with semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await showNumber(tester, 'Stepper#quantity "Quantity" bind=qty min=1 max=9 step=2');
    final keys = Keyboard(tester);
    for (var i = 0; i < 12 && keys.focusedId != 'number'; i++) { await keys.tab(); }
    expect(keys.focusedId, 'number');
    expect(keys.ringShown, isTrue);
    expect(keys.semantics!.isTextField, isTrue);
    expect(keys.semantics!.label, 'Quantity');
    expect(keys.semantics!.value, '3');
    expect(keys.semantics!.data.hint, contains('Minimum 1'));
    expect(keys.semantics!.data.hint, contains('maximum 9'));
    expect(keys.semantics!.data.hasAction(SemanticsAction.increase), isTrue);
    expect(keys.semantics!.data.hasAction(SemanticsAction.decrease), isTrue);
    expect(keys.stopIds(box(tester, 'number')).where((id) => id == 'number').length, 1);
    expect(keys.stopIds(box(tester, 'number')), isNot(contains('minus')));
    expect(keys.stopIds(box(tester, 'number')), isNot(contains('plus')));
    await keys.up(); expect(keys.semantics!.value, '5');
    await keys.down(); expect(keys.semantics!.value, '3');
    await keys.press(LogicalKeyboardKey.pageUp); expect(keys.semantics!.value, '9');
    expect(keys.semantics!.data.hasAction(SemanticsAction.increase), isFalse);
    await keys.press(LogicalKeyboardKey.pageDown); expect(keys.semantics!.value, '1');
    await keys.end(); expect(keys.semantics!.value, '9');
    await keys.home(); expect(keys.semantics!.value, '1');
    handle.dispose();
  });

  testWidgets('Stepper buttons click once and repeat while held, capped at maximum', (tester) async {
    await showNumber(tester, 'Stepper#quantity "Quantity" bind=qty min=1 max=9 step=2');
    final plus = center(box(tester, 'plus'));
    await tester.tapAt(plus);
    await tester.pump(const Duration(milliseconds: 100));
    expect(numberText(tester), '5');
    expect(Keyboard(tester).ringShown, isFalse);
    final gesture = await tester.startGesture(plus);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    // The field reaches the maximum and never exceeds it.
    expect(numberText(tester), '9');
  });

  testWidgets('Counter and NumberInput use the same numeric keyboard contract on a phone in dark mode', (tester) async {
    for (final (notation, id) in [
      ('Counter#quantity "Quantity" bind=qty min=1 max=9 step=2', 'stepValue'),
      ('NumberInput#quantity bind=qty min=1 max=9 step=2 label="Quantity"', 'field'),
    ]) {
      await showNumber(tester, notation, size: const Size(390, 844), dark: true);
      final keys = Keyboard(tester);
      for (var i = 0; i < 12 && keys.focusedId != id; i++) { await keys.tab(); }
      expect(keys.focusedId, id);
      expect(keys.semantics!.isTextField, isTrue);
      expect(keys.semantics!.label, 'Quantity');
      await keys.up();
      expect(numberText(tester, id), '5');
      await keys.end();
      expect(numberText(tester, id), '9');
      await keys.home();
      expect(numberText(tester, id), '1');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('CartLine quantity exposes one named field and updates through its event', (tester) async {
    final handle = tester.ensureSemantics();
    await showNumber(tester, 'CartLine#item "Mug" "Oat" price="\$48" qty={qty} max=9 step=2 onChanged={qty=result}');
    final keys = Keyboard(tester);
    for (var i = 0; i < 12 && keys.focusedId != 'stepValue'; i++) { await keys.tab(); }
    expect(keys.focusedId, 'stepValue');
    expect(keys.semantics!.label, 'Quantity of Mug');
    expect(keys.semantics!.value, '3');
    await keys.up();
    expect(numberText(tester, 'stepValue'), '5');
    await keys.end();
    expect(numberText(tester, 'stepValue'), '9');
    handle.dispose();
  });

  testWidgets('plain notation number input steps without a Cards block', (tester) async {
    await showNumber(tester, 'Input#quantity "Quantity" bind=qty type=number min=1 max=9 step=2');
    final keys = Keyboard(tester);
    for (var i = 0; i < 12 && keys.focusedId != 'quantity'; i++) { await keys.tab(); }
    expect(keys.focusedId, 'quantity');
    await keys.up();
    expect(numberText(tester, 'quantity'), '5');
    await keys.press(LogicalKeyboardKey.pageDown);
    expect(numberText(tester, 'quantity'), '1');
  });

  testWidgets('touch step buttons are at least 44 by 44 on a phone', (tester) async {
    for (final (notation, id) in [
      ('Stepper#quantity "Quantity" bind=qty min=1 max=9 step=2', 'plus'),
      ('Counter#quantity "Quantity" bind=qty min=1 max=9 step=2', 'stepPlus'),
      ('CartLine#item "Mug" "Oat" qty={qty} max=9 step=2 onChanged={qty=result}', 'stepPlus'),
      ('NumberInput#quantity bind=qty min=1 max=9 step=2', 'up'),
    ]) {
      await showNumber(tester, notation, size: const Size(390, 844));
      expect(box(tester, id).size.width, greaterThanOrEqualTo(44), reason: notation);
      expect(box(tester, id).size.height, greaterThanOrEqualTo(44), reason: notation);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
