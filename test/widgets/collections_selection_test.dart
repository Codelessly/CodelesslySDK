import 'package:codelessly_sdk/codelessly_sdk.dart' show Variable, VariableType;
import 'package:codelessly_sdk/src/widgets/collections_selection.dart';
import 'package:flutter/material.dart';
import "package:flutter/semantics.dart";
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keyboard.dart';
import '../support/screen.dart' as screen;

void main() {
  final items = [
    const SelectionChoice('a', 'First'),
    const SelectionChoice('b', 'Second'),
    const SelectionChoice('c', 'Third'),
    const SelectionChoice('d', 'Fourth'),
  ];

  testWidgets(
    'pointer and touch toggle keyed choices with selected semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var selected = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: SelectionListControl(
                label: 'Agenda',
                items: items,
                columns: 3,
                selected: () => selected,
                onChanged: (next) => selected = next,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('First'));
      await tester.pump();
      final pointerBoxes = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(SelectionListControl),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        pointerBoxes.any(
          (box) => (box.decoration as BoxDecoration).border?.top.width == 2,
        ),
        isFalse,
      );
      expect(
        tester.getTopLeft(find.text('Second')).dy,
        greaterThan(tester.getTopLeft(find.text('First')).dy),
      );
      await tester.tap(find.text('Third'));
      await tester.pump();
      expect(selected, ['a', 'c']);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('First').first)
            .hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Second').first)
            .hasFlag(SemanticsFlag.isSelected),
        isFalse,
      );
      expect(find.text('Agenda · 2 selected'), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('Second'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(selected.toSet(), {'a', 'b', 'c'});
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('First'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(selected.toSet(), {'b', 'c'});
      await tester.tap(find.text('Select all'));
      await tester.pump();
      expect(selected, ['a', 'b', 'c', 'd']);
      semantics.dispose();
    },
  );

  testWidgets(
    'one group Tab stop, arrows, Shift range, Space, Home End and select all',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var selected = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: SelectionListControl(
                label: 'Agenda',
                items: items,
                columns: 2,
                selected: () => selected,
                onChanged: (next) => selected = next,
              ),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final boxes = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(SelectionListControl),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        boxes.any(
          (box) => (box.decoration as BoxDecoration).border?.top.width == 2,
        ),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(selected, ['a']);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(selected, ['a', 'b']);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(selected, ['a']);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(selected, ['a', 'd']);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(selected, ['a', 'b', 'c', 'd']);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(selected, isEmpty);
      semantics.dispose();
    },
  );

  testWidgets(
    'RTL reverses horizontal arrows and a narrow dark list remains tappable',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var selected = <String>[];
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SelectionListControl(
                label: 'Agenda',
                items: items,
                columns: 3,
                selected: () => selected,
                onChanged: (next) => selected = next,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Second'));
      await tester.pump();
      expect(selected, ['b']);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(selected, ['b', 'a']);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('First').first)
            .hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
      semantics.dispose();
    },
  );

  testWidgets('in a page it is one stop of the page\x27s own Tab order, and keeps its choices in the bound list variable', (tester) async {
    final ui = await screen.show(
      tester,
      {
        'col': {
          'type': 'column',
          'layout': {'width': 600, 'height': 500},
          'children': ['before', 'sel', 'after'],
        },
        'before': {
          'type': 'filledButton',
          'props': {'label': 'Before'},
        },
        'sel': {
          'type': 'selectionList',
          'layout': {
            'width': 600,
            'height': {'hug': 0},
          },
          'props': {
            'variable': 'agenda',
            'label': 'Agenda',
            'columns': 2,
            'items': [
              {'key': 'a', 'label': 'First'},
              {'key': 'b', 'label': 'Second'},
              {'key': 'c', 'label': 'Third'},
            ],
          },
        },
        'after': {
          'type': 'filledButton',
          'props': {'label': 'After'},
        },
      },
      variables: [const Variable(id: 'agenda', name: 'agenda', type: VariableType.list, value: [])],
    );
    final keys = Keyboard(tester);
    await keys.tab();
    expect(keys.focusedId, 'before');
    await keys.tab();
    expect(keys.focusedId, 'sel');
    expect(keys.ringShown, isTrue);
    await keys.space();
    expect(ui['agenda'], ['a']);
    await keys.right();
    await keys.space();
    expect(ui['agenda'], ['a', 'b']);
    // Escape clears a selection, and with none is not the group's key.
    await keys.escape();
    expect(ui['agenda'], isEmpty);
    await keys.tab();
    expect(keys.focusedId, 'after');
    // A pointer toggles, and a value set from outside shows.
    await tester.tap(find.text('Third'));
    await tester.pump();
    expect(ui['agenda'], ['c']);
    ui.scope.set('agenda', ['a', 'b']);
    await tester.pump();
    await tester.pump();
    expect(find.text('Agenda · 2 selected'), findsOneWidget);
  });
}
