import 'dart:convert';
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
  testWidgets('a picker with a decoration is a formatted field; its dialog takes pickerTheme', (tester) async {
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
        'props': {'value': '13:00', 'format': 'HH:mm', 'use24h': true, 'decoration': field, 'pickerTheme': theme},
      },
    })));
    await tester.pumpWidget(MaterialApp(home: Material(child: Center(child: NodeView(tree: tree, rootId: 's', interactive: true)))));
    await tester.pumpAndSettle();
    // A field, not a button, showing the formatted value.
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(InputDecorator), findsNWidgets(2));
    expect(find.text('Mon 30 Nov 2026'), findsOneWidget);
    expect(find.text('13:00'), findsOneWidget);

    await tester.tapAt(_center(tester, tree, 'date'));
    await tester.pumpAndSettle();
    final dialog = tester.element(find.byType(DatePickerDialog));
    final t = Theme.of(dialog);
    expect(t.colorScheme.primary, const Color(0xFF2F4F46));
    expect(t.colorScheme.surfaceContainerHigh, const Color(0xFFFFFFFF));
    expect(t.datePickerTheme.shape, RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)));
    expect(find.text('FIRST DAY OFF'), findsOneWidget);
    Navigator.of(dialog).pop(DateTime(2026, 12, 4));
    await tester.pumpAndSettle();
    expect(find.text('Fri 4 Dec 2026'), findsOneWidget);

    await tester.tapAt(_center(tester, tree, 'time'));
    await tester.pumpAndSettle();
    final timeDialog = tester.element(find.byType(TimePickerDialog));
    expect(MediaQuery.of(timeDialog).alwaysUse24HourFormat, isTrue);
    expect(Theme.of(timeDialog).timePickerTheme.dialHandColor, const Color(0xFF2F4F46));
    Navigator.of(timeDialog).pop(const TimeOfDay(hour: 14, minute: 30));
    await tester.pumpAndSettle();
    expect(find.text('14:30'), findsOneWidget);
  });

  testWidgets('an empty picker field shows its hint', (tester) async {
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
    await tester.pumpWidget(MaterialApp(home: Material(child: Center(child: NodeView(tree: tree, rootId: 's', interactive: true)))));
    await tester.pumpAndSettle();
    expect(find.text('—'), findsWidgets);
    expect(find.text('00:00'), findsNothing);
  });

  testWidgets('a dense picker field takes its node\'s height, its value centred', (tester) async {
    final tree = NodeTree(DocumentSource(_doc({
      'time': {
        'type': 'timePicker',
        'layout': {'width': 160, 'height': 42},
        'props': {
          'value': '13:00',
          'use24h': true,
          'format': 'HH:mm',
          'decoration': {'isDense': true, 'contentPadding': [12, 4, 12, 4], 'border': {'type': 'outline'}},
        },
      },
    })));
    await tester.pumpWidget(MaterialApp(home: Material(child: Center(child: NodeView(tree: tree, rootId: 's', interactive: true)))));
    await tester.pumpAndSettle();
    final field = tester.getRect(find.byType(InputDecorator));
    expect(field.height, 42);
    final text = tester.getRect(find.text('13:00'));
    expect((text.center.dy - field.center.dy).abs(), lessThan(1.5));
  });

  testWidgets('a dense one-line field fills its fixed height', (tester) async {
    final tree = NodeTree(DocumentSource(_doc({'search': jsonDecode(r'''{"type": "textField", "name": "Search", "layout": {"width": 260, "height": 40}, "props": {"decoration": {"hintText": "Search names or skills", "hintStyle": {"fontFamily": "Instrument Sans", "fontSize": 14.5, "fontWeight": 400, "color": "#FF8C8F94", "height": 1.22, "fontFeatures": ["tabularFigures"]}, "hintMaxLines": 1, "isDense": true, "filled": true, "fillColor": "#FFFFFFFF", "contentPadding": [12, 11, 12, 11], "border": {"type": "outline", "borderSide": {"color": "#FFD3CDC0", "width": 1}, "borderRadius": 10, "gapPadding": 0}, "enabledBorder": {"type": "outline", "borderSide": {"color": "#FFD3CDC0", "width": 1}, "borderRadius": 10, "gapPadding": 0}, "focusedBorder": {"type": "outline", "borderSide": {"color": "#FF2F4F46", "width": 1.5}, "borderRadius": 10, "gapPadding": 0}, "errorBorder": {"type": "outline", "borderSide": {"color": "#FFB4544A", "width": 1}, "borderRadius": 10, "gapPadding": 0}, "focusedErrorBorder": {"type": "outline", "borderSide": {"color": "#FFB4544A", "width": 1.5}, "borderRadius": 10, "gapPadding": 0}, "errorStyle": {"fontFamily": "Instrument Sans", "fontSize": 12.5, "fontWeight": 600, "color": "#FFB4544A", "height": 1.22, "fontFeatures": ["tabularFigures"]}, "errorMaxLines": 1, "prefixIcon": {"icon": {"type": "MATERIAL_ICON", "name": "search", "style": "rounded"}, "size": 18, "color": "#FF8C8F94"}, "prefixIconConstraints": {"minWidth": 40, "minHeight": 18}}, "style": {"fontFamily": "Instrument Sans", "fontSize": 14.5, "fontWeight": 500, "color": "#FF23262B", "height": 1.22, "fontFeatures": ["tabularFigures"]}, "cursorColor": "#FF2F4F46", "initialValue": ""}}''') as Map<String, dynamic>})));
    await tester.pumpWidget(MaterialApp(home: Material(child: Center(child: NodeView(tree: tree, rootId: 's', interactive: true)))));
    await tester.pumpAndSettle();
    final box = tester.getRect(find.byType(InputDecorator));
    expect(box.height, 40);
    final hint = tester.getRect(find.text('Search names or skills'));
    // ignore: avoid_print
    print('box $box hint $hint');
    expect((hint.center.dy - box.center.dy).abs(), lessThan(1.5));
  });

  for (final density in [VisualDensity.standard, VisualDensity.compact]) {
    testWidgets('fixed-height fields keep their height under $density (desktop web is compact)', (tester) async {
      final tree = NodeTree(DocumentSource(_doc({
        'field': {
          'type': 'textField',
          'layout': {'width': 260, 'height': 40},
          'props': {
            'decoration': {'hintText': 'Search', 'isDense': true, 'contentPadding': [12, 11, 12, 11], 'border': {'type': 'outline'}},
          },
        },
        'time': {
          'type': 'timePicker',
          'layout': {'width': 160, 'height': 42, 'y': {'start': 100}},
          'props': {'value': '13:00', 'use24h': true, 'format': 'HH:mm', 'decoration': {'isDense': true, 'border': {'type': 'outline'}}},
        },
      })));
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(visualDensity: density, platform: TargetPlatform.linux),
        home: Material(child: Center(child: NodeView(tree: tree, rootId: 's', interactive: true))),
      ));
      await tester.pumpAndSettle();
      // The drawn field: the border container inside each decorator (its
      // box can be the node's height while a compact density draws less).
      double drawn(Finder f) {
        final border = find.descendant(of: f, matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_BorderContainer'));
        return tester.getSize(border.first).height;
      }
      final decorators = find.byType(InputDecorator);
      expect([drawn(decorators.at(0)), drawn(decorators.at(1))]..sort(), [40, 42]);
    });
  }

  testWidgets('a decorated picker in a form column takes its node\'s height', (tester) async {
    // Rota's New request form (mobile), cut down to the From field: in this
    // scrolling column the picker's island is laid out without a height,
    // and its suffix icon's 48 px slot made the field 48 high.
    final j = jsonDecode(_requestForm) as Map<String, dynamic>;
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(j)));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(visualDensity: VisualDensity.compact),
      home: Material(child: SizedBox(width: 390, height: 844, child: NodeView(tree: tree, rootId: 'n1', interactive: true))),
    ));
    await tester.pumpAndSettle();
    final border = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_BorderContainer');
    expect(tester.getSize(border.first).height, 42);
  });

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
    // on the web inside its 46 px box. The fill and border are the box's.
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
    final box = find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is ShapeDecoration);
    expect(tester.getSize(box).height, 46);
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });

  testWidgets('an error text that is a yes/no shows the error border without a message (SDK 8.x)', (tester) async {
    InputDecoration decorationWith(Object errorText) => inputDecoration(
        api.InputDecoration.fromJson({'errorText': errorText}), api.EdgeInsets.zero);
    final on = decorationWith(true);
    expect(on.error, isA<SizedBox>(), reason: 'in error, nothing under the field');
    expect(decorationWith(false).error, isNull);
    expect(decorationWith('Give the card a title.').error, isNotNull);
    // A field in error draws the error border.
    final source = DocumentSource(_doc({
      'f': {
        'type': 'textField',
        'layout': {'width': 200, 'height': 48},
        'props': {
          'decoration': {
            'errorText': true,
            'errorBorder': {'type': 'outline', 'borderSide': {'color': '#FFE5484D'}},
          },
        },
      },
    }));
    final (tree, _) = await _show(tester, source);
    expect(_widget<TextField>(tree).decoration!.error, isA<SizedBox>());
    expect(tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration.errorBorder, isNotNull);
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });

  testWidgets('a caret at the end of the text stays at the end when a new value arrives', (tester) async {
    // A dialog's name field autofocuses while its bound default is still
    // empty: the caret sits at 0, the end. When the default arrives the
    // caret belongs after it, as in a field created with that text.
    final source = DocumentSource(_doc({
      'f': {
        'type': 'textField',
        'layout': {'width': 200, 'height': 46},
        'props': {'initialValue': '', 'autofocus': true},
      },
    }));
    final (tree, _) = await _show(tester, source, interactive: true);
    await tester.pump();
    source.document = source.document.copyWith(nodes: {
      ...source.document.nodes,
      'f': source.document['f']!.withProp(api.TextFieldProps.initialValue, 'Untitled 8'),
    });
    await tester.pump();
    final controller = _widget<TextField>(tree).controller!;
    expect(controller.text, 'Untitled 8');
    expect(controller.selection, const TextSelection.collapsed(offset: 10));

    // A caret inside the text keeps its place.
    controller.selection = const TextSelection.collapsed(offset: 3);
    source.document = source.document.copyWith(nodes: {
      ...source.document.nodes,
      'f': source.document['f']!.withProp(api.TextFieldProps.initialValue, 'Untitled 9'),
    });
    await tester.pump();
    expect(controller.selection, const TextSelection.collapsed(offset: 3));
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

const _requestForm = r'''{"roots": ["n1"], "nodes": {"n7": {"type": "icon", "layout": {"width": 18, "height": 18}, "props": {"icon": {"type": "MATERIAL_ICON", "name": "arrow_back", "style": "rounded", "size": 18}, "color": "#FF5C6067"}}, "n6": {"type": "row", "name": "Icon button Back", "layout": {"width": 20, "height": 20}, "decoration": {"fills": [{"color": "#00000000"}], "radius": 10}, "props": {"mainAxisAlignment": "center", "crossAxisAlignment": "center"}, "tooltip": "Back", "key": "h1", "children": []}, "n8": {"type": "text", "layout": {"width": {"flexible": 100}, "height": {"hug": 40}}, "props": {"text": "TIME OFF", "style": {"fontFamily": "Instrument Sans", "fontSize": 11, "fontWeight": 600, "color": "#FF8C8F94", "height": 1.2, "letterSpacing": 0.9, "fontFeatures": ["tabularFigures"]}, "maxLines": 1, "overflow": "ellipsis"}}, "n5": {"type": "row", "layout": {"width": {"fill": 100}, "height": {"hug": 40}}, "props": {"mainAxisAlignment": "start", "crossAxisAlignment": "center", "spacing": 4}, "children": []}, "n9": {"type": "spacer", "layout": {"width": 6, "height": 6}}, "n10": {"type": "text", "layout": {"width": {"hug": 40}, "height": {"hug": 40}}, "props": {"text": "New request", "style": {"fontFamily": "Instrument Serif", "fontSize": 32, "fontWeight": 400, "color": "#FF23262B", "height": 1.05, "letterSpacing": -0.2}, "maxLines": 1, "overflow": "ellipsis"}}, "n4": {"type": "column", "name": "Page title", "layout": {"width": {"fill": 100}, "height": {"hug": 40}}, "props": {"mainAxisAlignment": "start", "crossAxisAlignment": "stretch"}, "children": []}, "n11": {"type": "spacer", "layout": {"width": 20, "height": 20}}, "n14": {"type": "text", "layout": {"width": {"hug": 40}, "height": {"hug": 40}, "margin": [0, 0, 0, 8]}, "props": {"text": "WHO", "style": {"fontFamily": "Instrument Sans", "fontSize": 11, "fontWeight": 600, "color": "#FF8C8F94", "height": 1.2, "letterSpacing": 0.9, "fontFeatures": ["tabularFigures"]}}}, "n15": {"type": "row", "name": "People", "layout": {"width": {"fill": 100}, "height": {"hug": 40}}, "props": {"scrollDirection": "horizontal", "wrap": true, "wrapSpacing": 6, "runSpacing": 6, "scrollable": false}}, "n16": {"type": "text", "name": "Error Pick who it\u2019s for", "layout": {"width": {"hug": 40}, "height": {"hug": 40}, "margin": [0, 6, 0, 0]}, "props": {"text": "Pick who it\u2019s for", "style": {"fontFamily": "Instrument Sans", "fontSize": 12.5, "fontWeight": 600, "color": "#FFB4544A", "height": 1.22, "letterSpacing": 0, "fontFeatures": ["tabularFigures"]}}}, "n17": {"type": "spacer", "layout": {"width": 18, "height": 18}}, "n20": {"type": "text", "layout": {"width": {"hug": 40}, "height": {"hug": 40}, "margin": [0, 0, 0, 8]}, "props": {"text": "FROM", "style": {"fontFamily": "Instrument Sans", "fontSize": 11, "fontWeight": 600, "color": "#FF8C8F94", "height": 1.2, "letterSpacing": 0.9, "fontFeatures": ["tabularFigures"]}}}, "n21": {"type": "datePicker", "name": "From date", "layout": {"width": {"fill": 100}, "height": 42}, "props": {"value": "2026-11-30", "format": "EEE d MMM yyyy", "style": {"fontFamily": "Instrument Sans", "fontSize": 14.5, "fontWeight": 500, "color": "#FF23262B", "height": 1.22, "fontFeatures": ["tabularFigures"]}, "decoration": {"border": {"type": "outline", "borderRadius": 10, "borderSide": {"color": "#FFD3CDC0", "width": 1}}, "enabledBorder": {"type": "outline", "borderRadius": 10, "borderSide": {"color": "#FFD3CDC0", "width": 1}}, "focusedBorder": {"type": "outline", "borderRadius": 10, "borderSide": {"color": "#FF2F4F46", "width": 1.5}}, "errorBorder": {"type": "outline", "borderRadius": 10, "borderSide": {"color": "#FFB4544A", "width": 1}}, "focusedErrorBorder": {"type": "outline", "borderRadius": 10, "borderSide": {"color": "#FFB4544A", "width": 1}}, "prefixIcon": {"icon": {"type": "MATERIAL_ICON", "name": "calendar_today", "style": "outlined"}, "size": 17, "color": "#FF8C8F94"}, "suffixIcon": {"icon": {"type": "MATERIAL_ICON", "name": "expand_more", "style": "rounded"}, "size": 18, "color": "#FF8C8F94"}, "prefixIconConstraints": {"minWidth": 40, "minHeight": 40}, "filled": true, "fillColor": "#FFFFFFFF", "hoverColor": "#FFFBFAF7", "isDense": true, "contentPadding": [12, 11, 12, 11], "errorStyle": {"fontSize": 0.01, "height": 0.01}, "hintText": "\u2014", "hintStyle": {"fontFamily": "Instrument Sans", "fontSize": 14.5, "fontWeight": 500, "color": "#FF8C8F94", "height": 1.22, "fontFeatures": ["tabularFigures"]}}, "pickerTheme": {"backgroundColor": "#FFFFFFFF", "accentColor": "#FF2F4F46", "onAccentColor": "#FFFFFFFF", "textColor": "#FF23262B", "mutedColor": "#FF8C8F94", "dividerColor": "#FFE6E2D9", "radius": 14, "dayRadius": 8, "fontFamily": "Instrument Sans", "headlineStyle": {"fontFamily": "Instrument Serif", "fontSize": 30, "color": "#FF23262B"}}, "helpText": "FIRST DAY OFF"}}, "n19": {"type": "column", "name": "From field", "layout": {"width": {"fill": 100}, "height": {"hug": 40}}, "props": {"mainAxisAlignment": "start", "crossAxisAlignment": "stretch"}, "children": ["n21"]}, "n23": {"type": "text", "layout": {"width": {"hug": 40}, "height": {"hug": 40}, "margin": [0, 0, 0, 8]}, "props": {"text": "TO", "style": {"fontFamily": "Instrument Sans", "fontSize": 11, "fontWeight": 600, "color": "#FF8C8F94", "height": 1.2, "letterSpacing": 0.9, "fontFeatures": ["tabularFigures"]}}}, "n24": {"type": "datePicker", "name": "To date", "layout": {"width": {"fill": 100}, "height": 42}, "props": {"value": "2026-11-30", "format": "EEE d MMM yyyy", "style": {"fontFamily": "Instrument Sans", "fontSize": 14.5, "fontWeight": 500, "color": "#FF23262B", "height": 1.22, "fontFeatures": ["tabularFigures"]}, "decoration": {"border": {"type": "outline", "borderRadius": 10, "borderSide": {"color": "#FFD3CDC0", "width": 1}}, "enabledBorder": {"type": "outline", "borderRadius": 10, "borderSide": {"color": "#FFD3CDC0", "width": 1}}, "focusedBorder": {"type": "outline", "borderRadius": 10, "borderSide": {"color": "#FF2F4F46", "width": 1.5}}, "errorBorder": {"type": "outline", "borderRadius": 10, "borderSide": {"color": "#FFB4544A", "width": 1}}, "focusedErrorBorder": {"type": "outline", "borderRadius": 10, "borderSide": {"color": "#FFB4544A", "width": 1}}, "prefixIcon": {"icon": {"type": "MATERIAL_ICON", "name": "calendar_today", "style": "outlined"}, "size": 17, "color": "#FF8C8F94"}, "suffixIcon": {"icon": {"type": "MATERIAL_ICON", "name": "expand_more", "style": "rounded"}, "size": 18, "color": "#FF8C8F94"}, "prefixIconConstraints": {"minWidth": 40, "minHeight": 40}, "filled": true, "fillColor": "#FFFFFFFF", "hoverColor": "#FFFBFAF7", "isDense": true, "contentPadding": [12, 11, 12, 11], "errorStyle": {"fontSize": 0.01, "height": 0.01}, "hintText": "\u2014", "hintStyle": {"fontFamily": "Instrument Sans", "fontSize": 14.5, "fontWeight": 500, "color": "#FF8C8F94", "height": 1.22, "fontFeatures": ["tabularFigures"]}}, "pickerTheme": {"backgroundColor": "#FFFFFFFF", "accentColor": "#FF2F4F46", "onAccentColor": "#FFFFFFFF", "textColor": "#FF23262B", "mutedColor": "#FF8C8F94", "dividerColor": "#FFE6E2D9", "radius": 14, "dayRadius": 8, "fontFamily": "Instrument Sans", "headlineStyle": {"fontFamily": "Instrument Serif", "fontSize": 30, "color": "#FF23262B"}}, "helpText": "LAST DAY OFF"}}, "n22": {"type": "column", "name": "To field", "layout": {"width": {"fill": 100}, "height": {"hug": 40}}, "props": {"mainAxisAlignment": "start", "crossAxisAlignment": "stretch"}, "children": []}, "n18": {"type": "column", "name": "Dates", "layout": {"width": {"fill": 100}, "height": {"hug": 40}}, "props": {"mainAxisAlignment": "start", "crossAxisAlignment": "stretch", "spacing": 14}, "children": ["n19"]}, "n25": {"type": "spacer", "layout": {"width": 8, "height": 8}}, "n26": {"type": "text", "name": "Days", "layout": {"width": {"hug": 40}, "height": {"hug": 40}}, "props": {"text": "${= (toDate < fromDate) ? 'Ends before it starts' : (diffDays(fromDate, toDate) + 1) + ' day' + ((diffDays(fromDate, toDate) + 1) == 1 ? '' : 's')}", "style": {"fontFamily": "Instrument Sans", "fontSize": 12.5, "fontWeight": 600, "color": "#FF8C8F94", "height": 1.22, "letterSpacing": 0, "fontFeatures": ["tabularFigures"]}}}, "n27": {"type": "spacer", "layout": {"width": 18, "height": 18}}, "n28": {"type": "text", "layout": {"width": {"hug": 40}, "height": {"hug": 40}, "margin": [0, 0, 0, 8]}, "props": {"text": "REASON", "style": {"fontFamily": "Instrument Sans", "fontSize": 11, "fontWeight": 600, "color": "#FF8C8F94", "height": 1.2, "letterSpacing": 0.9, "fontFeatures": ["tabularFigures"]}}}, "n29": {"type": "textField", "name": "Reason input", "layout": {"width": {"fill": 100}, "height": {"hug": 80}}, "props": {"initialValue": "", "style": {"fontFamily": "Instrument Sans", "fontSize": 14.5, "fontWeight": 500, "color": "#FF23262B", "height": 1.22, "fontFeatures": ["tabularFigures"]}, "cursorColor": "#FF2F4F46", "maxLines": 3, "minLines": 3, "keyboardType": "multiline", "decoration": {"hintText": "Holiday, appointment, exams\u2026", "hintStyle": {"fontFamily": "Instrument Sans", "fontSize": 14.5, "fontWeight": 400, "color": "#FF8C8F94", "height": 1.22, "fontFeatures": ["tabularFigures"]}, "isDense": true, "filled": true, "fillColor": "#FFFFFFFF", "hoverColor": "#FFFFFFFF", "focusColor": "#FFFFFFFF", "contentPadding": [12, 11, 12, 11], "border": {"type": "outline", "borderSide": {"color": "#FFD3CDC0", "width": 1}, "borderRadius": 10}, "enabledBorder": {"type": "outline", "borderSide": {"color": "#FFD3CDC0", "width": 1}, "borderRadius": 10}, "focusedBorder": {"type": "outline", "borderSide": {"color": "#FF2F4F46", "width": 1.5}, "borderRadius": 10}}}}, "n30": {"type": "text", "name": "Error Add a reason", "layout": {"width": {"hug": 40}, "height": {"hug": 40}, "margin": [0, 6, 0, 0]}, "props": {"text": "Add a reason", "style": {"fontFamily": "Instrument Sans", "fontSize": 12.5, "fontWeight": 600, "color": "#FFB4544A", "height": 1.22, "letterSpacing": 0, "fontFeatures": ["tabularFigures"]}}}, "n31": {"type": "spacer", "layout": {"width": 22, "height": 22}}, "n34": {"type": "text", "layout": {"width": {"hug": 40}, "height": {"hug": 40}}, "props": {"text": "Cancel", "style": {"fontFamily": "Instrument Sans", "fontSize": 14, "fontWeight": 600, "color": "#FF5C6067", "height": 1.22, "letterSpacing": 0, "fontFeatures": ["tabularFigures"]}, "maxLines": 1}}, "n33": {"type": "row", "name": "Button Cancel", "layout": {"width": {"hug": 40}, "height": 40, "padding": [16, 0, 16, 0]}, "decoration": {"fills": [{"color": "#00000000"}], "radius": 10}, "props": {"mainAxisAlignment": "center", "crossAxisAlignment": "center", "spacing": 8}, "key": "h3", "children": []}, "n36": {"type": "text", "layout": {"width": {"hug": 40}, "height": {"hug": 40}}, "props": {"text": "Add request", "style": {"fontFamily": "Instrument Sans", "fontSize": 14, "fontWeight": 600, "color": "#FFFFFFFF", "height": 1.22, "letterSpacing": 0, "fontFeatures": ["tabularFigures"]}, "maxLines": 1}}, "n35": {"type": "row", "name": "Button Add request", "layout": {"width": {"hug": 40}, "height": 40, "padding": [16, 0, 16, 0]}, "decoration": {"fills": [{"color": "#FF2F4F46"}], "radius": 10}, "props": {"mainAxisAlignment": "center", "crossAxisAlignment": "center", "spacing": 8}, "key": "h2", "children": []}, "n32": {"type": "row", "name": "Form actions", "layout": {"width": {"fill": 100}, "height": {"hug": 40}}, "props": {"mainAxisAlignment": "end", "crossAxisAlignment": "center", "spacing": 8}, "children": []}, "n13": {"type": "column", "name": "Request form", "layout": {"width": {"fill": 100}, "height": {"hug": 40}, "padding": [20, 20, 20, 20], "constraints": {"maxWidth": 640}}, "decoration": {"fills": [{"color": "#FFFFFFFF"}], "strokes": [{"color": "#FFE6E2D9"}], "strokeWidth": 1, "radius": 12}, "props": {"mainAxisAlignment": "start", "crossAxisAlignment": "stretch"}, "children": ["n18"]}, "n12": {"type": "column", "name": "Form column", "layout": {"width": {"fill": 100}, "height": {"hug": 40}}, "props": {"mainAxisAlignment": "start", "crossAxisAlignment": "center"}, "children": ["n13"]}, "n3": {"type": "column", "name": "Request body", "layout": {"width": {"fill": 100}, "height": {"fill": 100}, "padding": [16, 18, 16, 16], "flex": 1}, "props": {"mainAxisAlignment": "start", "crossAxisAlignment": "stretch", "scrollable": true}, "children": ["n12"]}, "n41": {"type": "icon", "layout": {"width": 19, "height": 19}, "props": {"icon": {"type": "MATERIAL_ICON", "name": "calendar_view_week", "style": "rounded", "size": 19}, "color": "#FF5C6067"}}, "n40": {"type": "row", "layout": {"width": 48, "height": 28, "x": {"align": 0}, "y": {"align": 0}}, "decoration": {"fills": [{"color": "#00000000"}], "radius": 14}, "props": {"mainAxisAlignment": "center", "crossAxisAlignment": "center"}, "children": []}, "n39": {"type": "stack", "name": "Bar pill Rota", "layout": {"width": 56, "height": 32}, "children": []}, "n42": {"type": "text", "layout": {"width": {"hug": 40}, "height": {"hug": 40}}, "props": {"text": "Rota", "style": {"fontFamily": "Instrument Sans", "fontSize": 11, "fontWeight": 600, "color": "#FF5C6067", "height": 1.22, "letterSpacing": 0, "fontFeatures": ["tabularFigures"]}}}, "n38": {"type": "column", "name": "Tab Rota", "layout": {"width": {"fill": 100}, "height": {"fill": 100}, "flex": 1}, "props": {"mainAxisAlignment": "center", "crossAxisAlignment": "center", "spacing": 3}, "children": []}, "n46": {"type": "icon", "layout": {"width": 19, "height": 19}, "props": {"icon": {"type": "MATERIAL_ICON", "name": "people_alt", "style": "outlined", "size": 19}, "color": "#FF5C6067"}}, "n45": {"type": "row", "layout": {"width": 48, "height": 28, "x": {"align": 0}, "y": {"align": 0}}, "decoration": {"fills": [{"color": "#00000000"}], "radius": 14}, "props": {"mainAxisAlignment": "center", "crossAxisAlignment": "center"}, "children": []}, "n44": {"type": "stack", "name": "Bar pill Team", "layout": {"width": 56, "height": 32}, "children": []}, "n47": {"type": "text", "layout": {"width": {"hug": 40}, "height": {"hug": 40}}, "props": {"text": "Team", "style": {"fontFamily": "Instrument Sans", "fontSize": 11, "fontWeight": 600, "color": "#FF5C6067", "height": 1.22, "letterSpacing": 0, "fontFeatures": ["tabularFigures"]}}}, "n43": {"type": "column", "name": "Tab Team", "layout": {"width": {"fill": 100}, "height": {"fill": 100}, "flex": 1}, "props": {"mainAxisAlignment": "center", "crossAxisAlignment": "center", "spacing": 3}, "children": []}, "n51": {"type": "icon", "layout": {"width": 19, "height": 19}, "props": {"icon": {"type": "MATERIAL_ICON", "name": "beach_access", "style": "outlined", "size": 19}, "color": "#FF2F4F46"}}, "n50": {"type": "row", "layout": {"width": 48, "height": 28, "x": {"align": 0}, "y": {"align": 0}}, "decoration": {"fills": [{"color": "#FFE3EBE7"}], "radius": 14}, "props": {"mainAxisAlignment": "center", "crossAxisAlignment": "center"}, "children": []}, "n53": {"type": "text", "layout": {"width": {"hug": 40}, "height": {"hug": 40}}, "props": {"text": "${pendingCount}", "style": {"fontFamily": "Instrument Sans", "fontSize": 11.5, "fontWeight": 700, "color": "#FFFFFFFF", "height": 1.22, "letterSpacing": 0, "fontFeatures": ["tabularFigures"]}}}, "n52": {"type": "row", "name": "Badge bar", "layout": {"width": {"hug": 40}, "height": 20, "padding": [6, 0, 6, 0], "constraints": {"minWidth": 20}, "x": {"end": -2}, "y": {"start": -4}}, "decoration": {"fills": [{"color": "#FFB0832B"}], "radius": 10}, "props": {"mainAxisAlignment": "center", "crossAxisAlignment": "center"}, "children": []}, "n49": {"type": "stack", "name": "Bar pill Time off", "layout": {"width": 56, "height": 32}, "children": []}, "n54": {"type": "text", "layout": {"width": {"hug": 40}, "height": {"hug": 40}}, "props": {"text": "Time off", "style": {"fontFamily": "Instrument Sans", "fontSize": 11, "fontWeight": 600, "color": "#FF2F4F46", "height": 1.22, "letterSpacing": 0, "fontFeatures": ["tabularFigures"]}}}, "n48": {"type": "column", "name": "Tab Time off", "layout": {"width": {"fill": 100}, "height": {"fill": 100}, "flex": 1}, "props": {"mainAxisAlignment": "center", "crossAxisAlignment": "center", "spacing": 3}, "children": []}, "n58": {"type": "icon", "layout": {"width": 19, "height": 19}, "props": {"icon": {"type": "MATERIAL_ICON", "name": "history", "style": "rounded", "size": 19}, "color": "#FF5C6067"}}, "n57": {"type": "row", "layout": {"width": 48, "height": 28, "x": {"align": 0}, "y": {"align": 0}}, "decoration": {"fills": [{"color": "#00000000"}], "radius": 14}, "props": {"mainAxisAlignment": "center", "crossAxisAlignment": "center"}, "children": []}, "n56": {"type": "stack", "name": "Bar pill History", "layout": {"width": 56, "height": 32}, "children": []}, "n59": {"type": "text", "layout": {"width": {"hug": 40}, "height": {"hug": 40}}, "props": {"text": "History", "style": {"fontFamily": "Instrument Sans", "fontSize": 11, "fontWeight": 600, "color": "#FF5C6067", "height": 1.22, "letterSpacing": 0, "fontFeatures": ["tabularFigures"]}}}, "n55": {"type": "column", "name": "Tab History", "layout": {"width": {"fill": 100}, "height": {"fill": 100}, "flex": 1}, "props": {"mainAxisAlignment": "center", "crossAxisAlignment": "center", "spacing": 3}, "children": []}, "n63": {"type": "icon", "layout": {"width": 19, "height": 19}, "props": {"icon": {"type": "MATERIAL_ICON", "name": "tune", "style": "rounded", "size": 19}, "color": "#FF5C6067"}}, "n62": {"type": "row", "layout": {"width": 48, "height": 28, "x": {"align": 0}, "y": {"align": 0}}, "decoration": {"fills": [{"color": "#00000000"}], "radius": 14}, "props": {"mainAxisAlignment": "center", "crossAxisAlignment": "center"}, "children": []}, "n61": {"type": "stack", "name": "Bar pill Setup", "layout": {"width": 56, "height": 32}, "children": []}, "n64": {"type": "text", "layout": {"width": {"hug": 40}, "height": {"hug": 40}}, "props": {"text": "Setup", "style": {"fontFamily": "Instrument Sans", "fontSize": 11, "fontWeight": 600, "color": "#FF5C6067", "height": 1.22, "letterSpacing": 0, "fontFeatures": ["tabularFigures"]}}}, "n60": {"type": "column", "name": "Tab Setup", "layout": {"width": {"fill": 100}, "height": {"fill": 100}, "flex": 1}, "props": {"mainAxisAlignment": "center", "crossAxisAlignment": "center", "spacing": 3}, "children": []}, "n37": {"type": "row", "name": "Bottom bar", "layout": {"width": {"fill": 100}, "height": 64}, "decoration": {"fills": [{"color": "#FFFFFFFF"}], "strokes": [{"color": "#FFE6E2D9"}], "strokeWidth": 1, "strokeSides": "top"}, "props": {"mainAxisAlignment": "start", "crossAxisAlignment": "center"}, "children": []}, "n2": {"type": "column", "name": "Mobile shell", "layout": {"width": {"fill": 100}, "height": {"fill": 100}, "x": {"start": 0, "end": 0}, "y": {"start": 0, "end": 0}}, "props": {"mainAxisAlignment": "start", "crossAxisAlignment": "stretch"}, "children": ["n3"]}, "n67": {"type": "icon", "layout": {"width": 18, "height": 18}, "props": {"icon": {"type": "MATERIAL_ICON", "name": "info_outline", "style": "rounded", "size": 18}, "color": "#FFB8BCC2"}}, "n68": {"type": "text", "layout": {"width": {"flexible": 100}, "height": {"hug": 40}}, "props": {"text": "${toast.text}", "style": {"fontFamily": "Instrument Sans", "fontSize": 13.5, "fontWeight": 500, "color": "#FFFFFFFF", "height": 1.3, "letterSpacing": 0, "fontFeatures": ["tabularFigures"]}}}, "n70": {"type": "text", "layout": {"width": {"hug": 40}, "height": {"hug": 40}}, "props": {"text": "Undo", "style": {"fontFamily": "Instrument Sans", "fontSize": 13.5, "fontWeight": 700, "color": "#FFA9CBBE", "height": 1.22, "letterSpacing": 0, "fontFeatures": ["tabularFigures"]}}}, "n69": {"type": "row", "name": "Undo", "layout": {"width": {"hug": 40}, "height": {"hug": 40}, "padding": [10, 6, 10, 6]}, "decoration": {"radius": 8}, "props": {"mainAxisAlignment": "start", "crossAxisAlignment": "center"}, "children": []}, "n66": {"type": "row", "name": "Toast", "layout": {"width": {"hug": 40}, "height": {"hug": 40}, "padding": [14, 10, 8, 10], "constraints": {"maxWidth": 560}}, "decoration": {"fills": [{"color": "#FF23262B"}], "radius": 12, "effects": [{"type": "dropShadow", "color": "#3323262B", "offset": [0, 8], "blurRadius": 24, "spreadRadius": 0}]}, "props": {"mainAxisAlignment": "start", "crossAxisAlignment": "center", "spacing": 10}, "children": []}, "n65": {"type": "row", "name": "Toast layer", "layout": {"width": {"fill": 100}, "height": {"hug": 40}, "x": {"start": 16, "end": 16}, "y": {"end": 84}}, "props": {"mainAxisAlignment": "center", "crossAxisAlignment": "center"}, "children": []}, "n1": {"type": "stack", "name": "timeoff mobile", "layout": {"width": {"fill": 100}, "height": {"fill": 100}}, "decoration": {"fills": [{"color": "#FFF6F4EF"}]}, "children": ["n2"]}}}''';
