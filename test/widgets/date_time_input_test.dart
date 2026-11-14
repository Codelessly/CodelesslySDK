
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/pickers.dart';
import 'package:codelessly_sdk/src/render/controls/root.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';

import '../lists/support.dart' as lists;

LayoutDocument _doc(Map<String, Object?> nodes) => LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': nodes.keys.toList(), 'layout': {'width': 400, 'height': 300}},
        ...nodes,
      },
    });

/// The picker field drawn for node [id] (render/controls/pickers.dart).
RenderPickerField _picker(RenderTree tree, String id) {
  RenderPickerField? found;
  void visit(RenderObject o) {
    if (o is RenderPickerField) found ??= o;
    o.visitChildren(visit);
  }

  visit(tree.boxOf(id)!);
  return found!;
}

/// The center of node [id] on screen.
Offset _center(WidgetTester tester, NodeTree tree, String id) =>
    tester.getTopLeft(find.byType(NodeView)) + tree.boxOf(id)!.rectIn(tester.renderObject(find.byType(NodeView)))!.center;

// A date/time input styled like a text field: its value in a pattern, or a
// bound display text, and no dialog when its picker is the design's own.
//
// A date/time input reads its value by a pattern, in its own style, and bare
// shows only the value (or hint) and its icon inside the node's box.

Map<String, Json> _screen(Map<String, Object?> props) => {
  'col': {
    'type': 'column',
    'children': ['dt'],
    'layout': {'width': 390, 'height': 200},
  },
  'dt': {
    'type': 'dateTimeInput',
    'layout': {
      'width': {'fill': 358},
      'height': 60,
    },
    'bind': {'props.value': r'${arrival}'},
    'props': {
      'mode': 'dateTime',
      'decoration': {
        'filled': true,
        'fillColor': '#FF18181C',
        'contentPadding': [18, 0, 18, 0],
        'prefixIcon': {
          'icon': {'type': 'MATERIAL_ICON', 'name': 'event', 'style': 'rounded'},
          'size': 24,
        },
      },
      'style': {'fontSize': 18, 'color': '#FFF7F5F0'},
      ...props,
    },
  },
};

void _ours() {
  testWidgets('shows its value in its pattern and follows a bound value', (tester) async {
    final s = await lists.show(
      tester,
      _screen({'format': 'EEE, MMM d · h:mm a'}),
      variables: [lists.v('arrival', '2026-11-12T09:05:00')],
    );
    await tester.pumpAndSettle();
    expect(_picker(s.tree, 'dt').shown, 'Thu, Nov 12 · 9:05 AM');
    s.scope.set('arrival', '2026-11-12T13:20:00');
    await tester.pumpAndSettle();
    expect(_picker(s.tree, 'dt').shown, 'Thu, Nov 12 · 1:20 PM');
    expect(s.tree.boxOf('dt')!.size.height, 60);
  });

  testWidgets('shows its display text instead, and with its own picker a tap opens no dialog', (tester) async {
    final s = await lists.show(
      tester,
      _screen({'displayText': 'Now · 1:20 PM', 'picker': 'none'}),
      variables: [lists.v('arrival', '2026-11-12T13:20:00')],
    );
    await tester.pumpAndSettle();
    expect(_picker(s.tree, 'dt').shown, 'Now · 1:20 PM');
    await tester.tapAt(s.center('dt'));
    await tester.pumpAndSettle();
    expect(tester.renderObject<RenderControlRoot>(find.byType(NodeView)).overlayEntries, isEmpty);
  });
}

Future<lists.Screen> _field(WidgetTester tester, Map<String, Object?> props) => lists.show(tester, {
      'col': {'type': 'column', 'children': ['d'], 'layout': {'width': 300, 'height': 100}},
      'd': {
        'type': 'dateTimeInput',
        'layout': {'width': 300, 'height': 34, 'padding': [10, 0, 10, 0]},
        'decoration': {'strokes': [{'color': '#FFB8C2CE'}], 'radius': 4},
        'props': props,
      },
    });

void _master() {
  testWidgets('with its own picker a tap runs the node\'s click reactions', (tester) async {
    final s = await lists.show(tester, {
      'col': {'type': 'column', 'children': ['d'], 'layout': {'width': 300, 'height': 100}},
      'd': {
        'type': 'dateTimeInput',
        'layout': {'width': 300, 'height': 34},
        'props': {'mode': 'date', 'value': '2026-12-01', 'format': 'MMM d, y', 'bare': true, 'picker': 'none'},
        'actions': [lists.reaction('click', [{'type': 'setVariable', 'variable': 'opened', 'value': true}])],
      },
    }, variables: [lists.v('opened', false, VariableType.boolean)]);
    await tester.pumpAndSettle();
    expect(_picker(s.tree, 'd').shown, 'Dec 1, 2026');
    await tester.tapAt(s.center('d'));
    await tester.pumpAndSettle();
    expect(s['opened'], isTrue);
    expect(tester.renderObject<RenderControlRoot>(find.byType(NodeView)).overlayEntries, isEmpty);
  });

  testWidgets('without a pattern it is SSUI\'s field, the date in words', (tester) async {
    final s = await _field(tester, {'mode': 'date', 'value': '2026-12-01'});
    await tester.pumpAndSettle();
    expect(_picker(s.tree, 'd').shown, 'Tue, Dec 1');
    expect(find.byType(InputDecorator), findsNothing);
  });
}

void main() {
  _inWrappingRow();
  testWidgets('a decorated date picker is a formatted field, and its picker takes the picker theme', (tester) async {
    const theme = {
      'backgroundColor': '#FFFFFFFF',
      'accentColor': '#FF2F4F46',
      'textColor': '#FF23262B',
      'mutedColor': '#FF8C8F94',
      'radius': 14,
      'dayRadius': 8,
      'fontFamily': 'Arial',
    };
    final field = {
      'border': {'type': 'outline', 'borderRadius': 10, 'borderSide': {'color': '#FFD3CDC0'}},
      'prefixIcon': {'icon': {'type': 'MATERIAL_ICON', 'name': 'calendar_today', 'style': 'outlined'}, 'size': 17},
      'filled': true,
      'fillColor': '#FFFFFFFF',
    };
    final tree = NodeTree(DocumentSource(_doc({
      'date': {
        'type': 'datePicker',
        'layout': {'width': 260, 'height': 42},
        'props': {
          'value': '2026-11-30',
          'format': 'EEE d MMM yyyy',
          'helpText': 'FIRST DAY OFF',
          'decoration': field,
          'pickerTheme': theme,
        },
      },
      'time': {
        'type': 'timePicker',
        'layout': {'width': 160, 'height': 42, 'y': {'start': 80}},
        'props': {'value': '13:00', 'format': 'HH:mm', 'alwaysUse24HourFormat': true, 'decoration': field, 'pickerTheme': theme},
      },
    })));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: Material(child: Center(child: NodeView(tree: tree, rootId: 's', interactive: true)))));
    await tester.pumpAndSettle();
    // A field drawn by the SDK, not a Material button or decorator.
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(InputDecorator), findsNothing);
    expect(_picker(tree, 'date').shown, 'Mon 30 Nov 2026');
    expect(_picker(tree, 'date').border!.side.color, const Color(0xFFD3CDC0));
    expect(_picker(tree, 'time').shown, '13:00');

    await tester.tapAt(_center(tester, tree, 'date'));
    await tester.pump();
    final panel = _picker(tree, 'date').panel!;
    expect(panel.calendar!.lookOf(DateTime(2026, 11, 30)).fill, const Color(0xFF2F4F46));
    expect(panel.outline.tlRadiusX, 14);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_picker(tree, 'date').shown, 'Fri 4 Dec 2026');

    await tester.tapAt(_center(tester, tree, 'time'));
    await tester.pump();
    final time = _picker(tree, 'time').panel!.time!;
    expect(time.use24h, isTrue);
    expect(time.display, '13:00');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_picker(tree, 'time').shown, '14:30');
  });

  testWidgets('an empty date picker shows its hint', (tester) async {
    final tree = NodeTree(DocumentSource(_doc({
      'time': {
        'type': 'timePicker',
        'layout': {'width': 160, 'height': 42},
        'props': {
          'value': '',
          'decoration': {'hintText': '—', 'border': {'type': 'outline'}},
        },
      },
    })));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: Material(child: Center(child: NodeView(tree: tree, rootId: 's', interactive: true)))));
    await tester.pumpAndSettle();
    expect(_picker(tree, 'time').shown, '—');
  });

  group('how the value is shown', () {
    _ours();
    _master();
  });
}

void _inWrappingRow() {
  for (final type in ['dateTimeInput', 'datePicker', 'timePicker', 'textField', 'dropdown']) for (final wrap in [true, false]) {
    testWidgets('a $type of a hugging width in a ${wrap ? 'wrapping ' : ''}row takes its own width, not the row\'s', (tester) async {
      final doc = LayoutDocument.fromJson({
        'roots': ['row'],
        'nodes': {
          'row': {
            'type': 'row',
            'children': ['a', 'b'],
            'props': {'wrap': wrap, 'spacing': 8, 'runSpacing': 8},
            'layout': {'width': 600, 'height': {'hug': 120}},
          },
          'a': {'type': type, 'layout': {'width': {'hug': 180}, 'height': 40}},
          'b': {'type': 'box', 'layout': {'width': 80, 'height': 40}, 'decoration': {'fills': [{'color': '#FF000000'}]}},
        },
      });
      final tree = NodeTree(DocumentSource(doc));
      await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'row'))));
      await tester.pump();
      final view = tester.renderObject(find.byType(NodeView));
      final a = tree.boxOf('a')!.rectIn(view)!;
      final b = tree.boxOf('b')!.rectIn(view)!;
      expect(tester.takeException(), isNull);
      expect(a.width, lessThan(600), reason: '$type is $a in a row 600 wide');
      expect(b.top, lessThan(a.bottom), reason: 'the box after it ($b) stays on its line, beside $a');
      expect(b.left, greaterThanOrEqualTo(a.right));
      await tester.pumpWidget(const SizedBox());
      tree.dispose();
    });
  }
}
