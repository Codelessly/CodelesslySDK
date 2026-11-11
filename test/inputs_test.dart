import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LayoutDocument _doc(Map<String, Object?> nodes) => LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': nodes.keys.toList(), 'layout': {'width': 400, 'height': 300}},
        ...nodes,
      },
    });

Future<(NodeTree, RenderObject)> _show(WidgetTester tester, DocumentSource source, {bool interactive = false}) async {
  final tree = NodeTree(source);
  await tester.pumpWidget(MaterialApp(home: Center(child: NodeView(tree: tree, rootId: 's', interactive: interactive))));
  return (tree, tester.renderObject(find.byType(NodeView)));
}

/// The widgets of [tree]'s islands.
Iterable<Widget> _islandWidgets(NodeTree tree) sync* {
  for (final host in tree.islands.hosts) {
    final root = host.element;
    if (root == null) continue;
    final all = <Widget>[];
    void walk(Element e) {
      all.add(e.widget);
      e.visitChildren(walk);
    }

    walk(root);
    yield* all;
  }
}

T _widget<T extends Widget>(NodeTree tree) => _islandWidgets(tree).whereType<T>().single;

/// The center of node [id] on screen.
Offset _center(WidgetTester tester, NodeTree tree, String id) =>
    tester.getTopLeft(find.byType(NodeView)) + tree.boxOf(id)!.rectIn(tester.renderObject(find.byType(NodeView)))!.center;

void main() {
  testWidgets('date and time pickers stay in their app navigator', (tester) async {
    final tree = NodeTree(DocumentSource(_doc({
      'date': {'type': 'datePicker', 'layout': {'width': 160, 'height': 50}},
      'time': {'type': 'timePicker', 'layout': {'width': 160, 'height': 50, 'y': {'start': 80}}},
    })));
    final outer = GlobalKey<NavigatorState>();
    final inner = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: outer, home: Navigator(
      key: inner,
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => Material(
        child: Center(child: FeedbackThemeScope(
          theme: const FeedbackTheme(primary: Color(0xFF147D68), surface: Colors.white, bodyStyle: TextStyle(fontFamily: 'Arial')),
          child: NodeView(tree: tree, rootId: 's', interactive: true),
        )),
      )),
    )));
    await tester.pumpAndSettle();
    await tester.tapAt(_center(tester, tree, 'date'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(Theme.of(tester.element(find.byType(DatePickerDialog))).colorScheme.primary, const Color(0xFF147D68));
    expect(inner.currentState!.canPop(), isTrue);
    expect(outer.currentState!.canPop(), isFalse);
    inner.currentState!.pop(DateTime(2026, 6, 1));
    await tester.pumpAndSettle();
    await tester.tapAt(_center(tester, tree, 'time'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(Theme.of(tester.element(find.byType(TimePickerDialog))).colorScheme.primary, const Color(0xFF147D68));
    expect(inner.currentState!.canPop(), isTrue);
    expect(outer.currentState!.canPop(), isFalse);
    inner.currentState!.pop(const TimeOfDay(hour: 9, minute: 30));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });

  testWidgets('a one-line field of fixed height keeps it under a compact density', (tester) async {
    // Desktop platforms default to a compact density, which takes 8 px off
    // an input's container: a 46 px field drew 38 px tall in the editor and
    // on the web inside its 46 px box. The height the design fixed wins.
    final tree = NodeTree(DocumentSource(_doc({
      'f': {
        'type': 'textField',
        'layout': {'width': 300, 'height': 46},
        'props': {
          'initialValue': 'Untitled 1',
          'decoration': {
            'filled': true, 'isDense': true, 'contentPadding': [13, 12, 13, 12],
            'enabledBorder': {'type': 'outline', 'borderSide': {'width': 2}, 'borderRadius': 8},
          },
        },
      },
    })));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(visualDensity: VisualDensity.compact),
      home: Center(child: NodeView(tree: tree, rootId: 's')),
    ));
    final border = find.descendant(of: find.byType(InputDecorator), matching: find.byType(CustomPaint)).last;
    expect(tester.getSize(border).height, 46);
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });

  testWidgets('a text field is a real TextField, sized by its fits', (tester) async {
    final source = DocumentSource(_doc({
      'f': {
        'type': 'textField',
        'layout': {'width': 200, 'height': {'hug': 48}, 'x': {'start': 10}, 'y': {'start': 20}, 'padding': [12, 16, 12, 16]},
        'props': {'initialValue': 'Hi', 'decoration': {'hintText': 'Name', 'errorText': r"${= bad ? 'x' : ''}"}},
      },
    }));
    final (tree, view) = await _show(tester, source);
    final field = _widget<TextField>(tree);
    expect(field.controller!.text, 'Hi');
    expect(field.decoration!.hintText, 'Name');
    // An unevaluated formula is no error.
    expect(field.decoration!.error, isNull);
    final rect = tree.boxOf('f')!.rectIn(view)!;
    expect(rect.left, 10);
    expect(rect.width, 200);
    expect(rect.height, greaterThan(40));

    // A new initial value from the document shows.
    source.document = source.document.copyWith(nodes: {
      ...source.document.nodes,
      'f': source.document['f']!.withProp(api.TextFieldProps.initialValue, 'Grace'),
    });
    await tester.pump();
    expect(_widget<TextField>(tree).controller!.text, 'Grace');
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });

  testWidgets('toggles take taps only when interactive', (tester) async {
    final doc = _doc({
      'c': {'type': 'checkbox', 'layout': {'width': 40, 'height': 40}, 'props': {'value': false}},
      'w': {'type': 'switch', 'layout': {'width': 59, 'height': 40, 'x': {'start': 100}}},
    });
    var (tree, _) = await _show(tester, DocumentSource(doc));
    await tester.tapAt(_center(tester, tree, 'c'));
    await tester.pump();
    expect(_widget<Checkbox>(tree).value, isFalse);
    await tester.pumpWidget(const SizedBox());
    tree.dispose();

    (tree, _) = await _show(tester, DocumentSource(doc), interactive: true);
    await tester.tapAt(_center(tester, tree, 'c'));
    await tester.tapAt(_center(tester, tree, 'w'));
    await tester.pump();
    expect(_widget<Checkbox>(tree).value, isTrue);
    expect(_widget<Switch>(tree).value, isTrue);
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });

  testWidgets('a slider and a signature take their design size whatever their fits', (tester) async {
    final (tree, view) = await _show(
        tester,
        DocumentSource(_doc({
          'sl': {'type': 'slider', 'layout': {'width': {'hug': 300}, 'height': {'hug': 48}}, 'props': {'value': 0.5}},
          'sg': {'type': 'signature', 'layout': {'width': {'hug': 200}, 'height': 100, 'y': {'start': 60}}},
        })));
    expect(tree.boxOf('sl')!.rectIn(view)!.size, const Size(300, 48));
    expect(tree.boxOf('sg')!.rectIn(view)!.size, const Size(200, 100));
    expect(_widget<Slider>(tree).value, 0.5);
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });

  test('preview texts: formulas come out empty, variables stay', () {
    expect(previewText(null), isNull);
    expect(previewText(''), isNull);
    expect(previewText('Hi'), 'Hi');
    expect(previewText(r"${= a ? '!' : ''}"), isNull);
    expect(previewText(r'Total: ${= sum({a: 1})} kg'), 'Total:  kg');
    expect(previewText(r'${name}'), r'${name}');
  });

  test('text field line limits', () {
    expect(textFieldLines(maxLines: 1, minLines: null), (1, null));
    expect(textFieldLines(maxLines: null, minLines: 3), (null, 3));
    expect(textFieldLines(maxLines: 2, minLines: 4), (4, 4));
    expect(textFieldLines(maxLines: 0, minLines: 0), (null, null));
    expect(textFieldLines(maxLines: 3, minLines: 2, expands: true), (null, null));
  });
}
