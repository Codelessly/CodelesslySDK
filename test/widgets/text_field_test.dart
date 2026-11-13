
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/codelessly_api.dart' show LayoutDocument;
import 'package:codelessly_sdk/codelessly_sdk.dart' hide captureImage;
import 'package:codelessly_sdk/src/render/node_tree.dart' show RenderNodeDecoration;
import 'package:codelessly_sdk/src/widgets/inputs.dart';
import 'package:flutter/material.dart' hide Node;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lists/support.dart' as lists;
import '../support/screen.dart' as harness;

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

// A one-line text field with a fixed height draws its border box at that
// height (a 60 px search field), whatever its padding and font.
//
// A one-line text field with a fixed height (a 50 px search box in a stack,
// the save sheet's name field in a column) is that tall in a running app.

/// The field under a desktop app's theme (compact density).
Future<void> compact(WidgetTester tester) async {
  final view = find.byType(NodeView);
  final widget = tester.widget<NodeView>(view);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(visualDensity: VisualDensity.compact),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: widget),
      ),
    ),
  );
}

void _ours() {
  for (final interactive in [true, false])
    for (final fit in ['fixed', 'fill', 'hugParent']) {
      testWidgets(
        'a $fit-height one-line field is as tall as its box, on desktop too (interactive: $interactive)',
        variant: TargetPlatformVariant.only(TargetPlatform.linux),
        (tester) async {
          final hugParent = fit == 'hugParent';
          final border = {
            'borderSide': {'color': '#FF34343C', 'width': 2},
            'borderRadius': 14,
          };
          await lists.show(tester, {
            'col': {
              'type': 'column',
              'children': [hugParent ? 'wrap' : 'field'],
              'layout': {'width': 390, 'height': 200},
            },
            'wrap': {
              'type': 'column',
              'children': ['field'],
              'layout': {
                'width': {'fill': 100},
                'height': {'hug': 40},
                'padding': [16, 0, 16, 0],
              },
              'props': {'crossAxisAlignment': 'start'},
            },
            'field': {
              'type': 'textField',
              'layout': {
                'width': {'fill': 358},
                'height': fit == 'fill' ? {'fill': 60} : 60,
                if (fit == 'fill') 'flex': 1,
              },
              'props': {
                'style': {'fontFamily': 'Archivo', 'fontSize': 18},
                'decoration': {
                  'hintText': 'Search',
                  'prefixIcon': {
                    'icon': {'type': 'MATERIAL_ICON', 'name': 'search', 'style': 'rounded'},
                    'size': 26,
                    'color': '#FF9C9CA6',
                  },
                  'filled': true,
                  'fillColor': '#FF18181C',
                  'contentPadding': [18, 0, 18, 0],
                  'border': border,
                  'enabledBorder': border,
                  'focusedBorder': border,
                },
              },
            },
          }, interactive: interactive);
          await compact(tester);
          await tester.pumpAndSettle();
          final decorator = tester.getSize(find.byType(InputDecorator));
          expect(decorator.height, fit == 'fill' ? 200 : 60);
          // The outline is drawn around the whole box: its fill reaches the
          // box's top and bottom rows.
          final image = await tester.runAsync(() => captureImage(tester.element(find.byType(InputDecorator))));
          final bytes = (await tester.runAsync(() => image!.toByteData()))!;
          int alphaAt(int x, int y) => bytes.getUint8((y * image!.width + x) * 4 + 3);
          final x = image!.width ~/ 2;
          final painted = [
            for (var y = 0; y < image.height; y++)
              if (alphaAt(x, y) > 0) y,
          ];
          expect(
            painted.first,
            lessThanOrEqualTo(2),
            reason: 'rows painted: ${painted.first}..${painted.last} of ${image.height}',
          );
          expect(painted.last, greaterThanOrEqualTo(image.height - 3));
        },
      );
    }
}

Map<String, Object?> field() => {
      'type': 'textField',
      'layout': {'width': {'fill': 300}, 'height': 50},
      'props': {
        'textAlignVertical': 'center',
        'decoration': {
          'hintText': 'Search', 'filled': true, 'fillColor': '#FFF6F4EF', 'isDense': true, 'contentPadding': [14, 0, 14, 0],
          'enabledBorder': {'type': 'outline', 'borderSide': {'color': '#00000000', 'width': 2}, 'borderRadius': 12},
        },
      },
    };

void _master() {
  _focusTests();

}

void _focusTests() {
  testWidgets('a fixed-height field shows its focused border when focused', (tester) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['p'],
      'nodes': {
        'p': {'type': 'stack', 'children': ['f'], 'layout': {'width': 400, 'height': 200}},
        'f': {
          ...field(),
          'props': {
            ...(field()['props']! as Map<String, Object?>),
            'decoration': {
              ...((field()['props']! as Map)['decoration'] as Map<String, Object?>),
              'focusedBorder': {'type': 'outline', 'borderSide': {'color': '#FF0E2747', 'width': 2}, 'borderRadius': 12},
            },
          },
        },
      },
    });
    final tree = NodeTree(NodeValues(DocumentSource(doc)));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'p', interactive: true)),
    ));
    Color side() {
      final box = tester.widget<DecoratedBox>(find.ancestor(
        of: find.byType(TextField),
        matching: find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is ShapeDecoration),
      ).first);
      return ((box.decoration as ShapeDecoration).shape as OutlineInputBorder).borderSide.color;
    }
    expect(side(), const Color(0x00000000));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(side(), const Color(0xFF0E2747), reason: 'the focused border, without another rebuild');
  });
}

// A fixed-height one-line field with nothing tall in it (no prefix icon)
// still draws its border box at its full height, not a 48 px one.

// A text field whose initialValue is fed back from its own `changed`
// reaction through a slow action (a script result, a delay) keeps what was
// typed since; a highlight range draws in its style.

Future<(VariableScope, NodeTree)> show(WidgetTester tester, Map<String, Object?> field, List<Variable> vars) async {
  final doc = LayoutDocument.fromJson({'roots': ['f'], 'nodes': {'f': field}});
  final scope = VariableScope(vars);
  final values = NodeValues(DocumentSource(doc));
  final tree = NodeTree(values, binder: NodeBinder(scope: scope));
  final context = RuntimeActionContext(scope: scope, ui: const NoActionUi(), tree: tree, nodeValues: values, services: Services());
  final reactions = TreeReactions(runner: const CodelesslyActions(), context: context);
  tree.interactions = reactions;
  addTearDown(() {
    reactions.dispose();
    tree.dispose();
  });
  await tester.pumpWidget(MaterialApp(home: Material(child: Align(alignment: Alignment.topLeft,
      child: NodeView(tree: tree, rootId: 'f', interactive: true)))));
  await tester.pump();
  return (scope, tree);
}

// An input node with its own fill, border and padding draws them around its
// widget (the node's shell), the widget filling the padded box.

Iterable<RenderObject> _below(RenderObject r) sync* {
  final kids = <RenderObject>[];
  r.visitChildren(kids.add);
  for (final k in kids) {
    yield k;
    yield* _below(k);
  }
}

void main() {
  for (final density in [VisualDensity.standard, VisualDensity.compact]) {
    testWidgets('a fixed-height field keeps its height under $density density', (tester) async {
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

  testWidgets('an error bound to yes or no shows the error border without a message', (tester) async {
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

  testWidgets('the caret stays at the end of the text when a new value arrives', (tester) async {
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

  testWidgets('a text field is a real Flutter TextField, sized by its width and height settings', (tester) async {
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

  testWidgets('a checkbox and a switch take taps only in a running app', (tester) async {
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

  testWidgets('a slider and a signature keep their design size whatever their sizing', (tester) async {
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

  test('on the design canvas a field shows variable names and leaves formulas empty', () {
    expect(previewText(null), isNull);
    expect(previewText(''), isNull);
    expect(previewText('Hi'), 'Hi');
    expect(previewText(r"${= a ? '!' : ''}"), isNull);
    expect(previewText(r'Total: ${= sum({a: 1})} kg'), 'Total:  kg');
    expect(previewText(r'${name}'), r'${name}');
  });

  test('a text field keeps to its minimum and maximum lines', () {
    expect(textFieldLines(maxLines: 1, minLines: null), (1, null));
    expect(textFieldLines(maxLines: null, minLines: 3), (null, 3));
    expect(textFieldLines(maxLines: 2, minLines: 4), (4, 4));
    expect(textFieldLines(maxLines: 0, minLines: 0), (null, null));
    expect(textFieldLines(maxLines: 3, minLines: 2, expands: true), (null, null));
  });

  group('fixed height', () {
    _ours();
    _master();


    testWidgets('a prefix icon is centered in the field\'s whole height', (tester) async {
      await lists.show(tester, {
        'col': {
          'type': 'column',
          'children': ['field'],
          'layout': {'width': 390, 'height': 200},
        },
        'field': {
          'type': 'textField',
          'layout': {'width': {'fill': 358}, 'height': 68},
          'props': {
            'style': {'fontSize': 21},
            'decoration': {
              'hintText': 'Search',
              'prefixIcon': {
                'icon': {'type': 'MATERIAL_ICON', 'name': 'search', 'style': 'rounded'},
                'size': 26,
              },
              'prefixIconPadding': [20, 0, 8, 0],
              'contentPadding': [0, 0, 18, 0],
            },
          },
        },
      });
      await compact(tester);
      await tester.pumpAndSettle();
      final box = tester.getRect(find.byType(InputDecorator));
      // The glyph sits in an Align that hugs it (its padding around).
      final icon = tester.getRect(find
          .descendant(
            of: find.byType(InputDecorator),
            matching: find.byWidgetPredicate((w) => w is Align && w.widthFactor == 1 && w.heightFactor == 1),
          )
          .first);
      expect(icon.center.dy, closeTo(box.center.dy, 1));
    });
  });

  group('typing into a bound field', () {
    testWidgets('a late update from an earlier keystroke does not undo what was typed since', (tester) async {
      final (scope, _) = await show(tester, {
        'type': 'textField', 'layout': {'width': 200, 'height': 40},
        'bind': {'props.initialValue': r'${t}'},
        'actions': [
          harness.reaction('changed', [
            {'type': 'delay', 'ms': 100},
            {'type': 'setVariable', 'variable': 't', 'value': r'${result}'},
          ]),
        ],
      }, [harness.v('t', 'y = ')]);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'y = x');
      await tester.pump(const Duration(milliseconds: 30));
      await tester.enterText(find.byType(TextField), 'y = x^');
      await tester.pump(const Duration(milliseconds: 30));
      await tester.enterText(find.byType(TextField), 'y = x^2');
      // The first echo ('y = x') arrives now, after two newer edits.
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'y = x^2');
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'y = x^2');
      expect(scope.read('t'), 'y = x^2');
      // A value from elsewhere still replaces the text.
      scope.set('t', 'a = 2');
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'a = 2');
    });

    testWidgets('a highlighted range of the text is drawn in its style', (tester) async {
      await show(tester, {
        'type': 'textField', 'layout': {'width': 200, 'height': 40},
        'props': {'initialValue': 'y = sin(x*x', 'highlightStart': 7, 'highlightEnd': 8,
          'highlightStyle': {'color': '#FFB3261E', 'backgroundColor': '#FFF7E3DC'}},
        'bind': {'props.highlightStart': r'${col}', 'props.highlightEnd': r'${= col + 1}'},
      }, [harness.v('col', 7, api.VariableType.integer)]);
      final controller = tester.widget<TextField>(find.byType(TextField)).controller! as HighlightTextController;
      final span = controller.buildTextSpan(context: tester.element(find.byType(TextField)), withComposing: false);
      final parts = span.children!.cast<TextSpan>();
      expect(parts.map((p) => p.text), ['y = sin', '(', 'x*x']);
      expect(parts[1].style!.color, const Color(0xFFB3261E));
    });
  });

  group('decoration', () {
    testWidgets('a dropdown with a decoration and padding draws its box around the widget', (tester) async {
      final s = await harness.show(tester, {
        'col': {'type': 'column', 'children': ['d'], 'layout': {'width': 400, 'height': 100}},
        'd': {
          'type': 'dropdown',
          'layout': {'width': 220, 'height': 34, 'padding': [10, 0, 8, 0]},
          'decoration': {
            'fills': [{'color': '#FFFFFFFF'}],
            'strokes': [{'color': '#FFB8C2CE'}],
            'strokeWidth': 1,
            'radius': 4,
          },
          'props': {
            'items': ['Plan', 'Use'],
            'value': 'Plan',
            'isDense': true,
            'isExpanded': true,
            'underline': false,
          },
        },
      });
      await tester.pumpAndSettle();
      final box = s.tree.boxOf('d')!;
      expect(box.size, const Size(220, 34));
      final decorations = _below(box).whereType<RenderNodeDecoration>().toList();
      expect(decorations, isNotEmpty);
      expect((decorations.first.decoration as BoxDecoration).borderRadius, BorderRadius.circular(4));
      // The dropdown widget sits in the padded box: 220 less 10 + 8.
      final dropdown = tester.getRect(find.byType(DropdownButton<Object>));
      expect(dropdown.width, 202);
      expect(dropdown.left - tester.getTopLeft(find.byType(NodeView)).dx - box.localToGlobal(Offset.zero).dx, closeTo(10, 0.5));
    });
  });
}
