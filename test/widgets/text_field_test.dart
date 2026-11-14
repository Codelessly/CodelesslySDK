
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/codelessly_api.dart' show LayoutDocument;
import 'package:codelessly_sdk/codelessly_sdk.dart' hide captureImage;
import 'package:codelessly_sdk/src/render/controls/slider.dart' show RenderSlider;
import 'package:codelessly_sdk/src/render/controls/toggles.dart' show RenderToggle;
import 'package:codelessly_sdk/src/render/node_tree.dart' show RenderNodeDecoration;
import 'package:codelessly_sdk/src/render/controls/field_frame.dart' show FieldBorderKind;
import 'package:codelessly_sdk/src/render/controls/text_field.dart';
import 'package:codelessly_sdk/src/render/controls/tokens.dart' show ControlTokens;
import 'package:codelessly_sdk/src/runtime/actions/text_fields.dart' show TextFieldHandle;
import 'package:flutter/material.dart' hide Node;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../controls/toggles_support.dart';
import '../lists/support.dart' as lists;
import '../support/fields.dart';
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

Iterable<RenderObject> _below(RenderObject r) sync* {
  final kids = <RenderObject>[];
  r.visitChildren(kids.add);
  for (final k in kids) {
    yield k;
    yield* _below(k);
  }
}

void main() {
  testWidgets('a fixed-height field shows its focused border when focused', (tester) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['p'],
      'nodes': {
        'p': {'type': 'stack', 'children': ['f'], 'layout': {'width': 400, 'height': 200}},
        'f': {
          'type': 'textField',
          'layout': {'width': {'fill': 300}, 'height': 50},
          'props': {
            'textAlignVertical': 'center',
            'decoration': {
              'hintText': 'Search', 'filled': true, 'fillColor': '#FFF6F4EF', 'isDense': true, 'contentPadding': [14, 0, 14, 0],
              'enabledBorder': {'type': 'outline', 'borderSide': {'color': '#00000000', 'width': 2}, 'borderRadius': 12},
              'focusedBorder': {'type': 'outline', 'borderSide': {'color': '#FF0E2747', 'width': 2}, 'borderRadius': 12},
            },
          },
        },
      },
    });
    final tree = NodeTree(NodeValues(DocumentSource(doc)));
    addTearDown(tree.dispose);
    await tester.pumpWidget(Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'p', interactive: true)));
    final f = textField(tester);
    expect(f.currentBorder.side.color, const Color(0x00000000));
    await tapField(tester, f);
    expect(f.currentBorder.side.color, const Color(0xFF0E2747), reason: 'the focused border, without another rebuild');
    expect(f.boxRect.height, 50);
  });

  group('a focused field that goes away', () {
    Map<String, Json> form() => {
          'col': {'type': 'column', 'children': ['form', 'thanks'], 'layout': {'width': 400, 'height': 400}},
          'form': {
            'type': 'column',
            'children': ['field', 'submit'],
            'layout': {'width': 360, 'height': {'hug': 120}},
            'bind': {'visible': r'${= !done}'},
          },
          'field': {
            'type': 'textField',
            'layout': {'width': 360, 'height': 56},
            'bind': {'props.initialValue': r'${email}'},
            'actions': [
              harness.reaction('changed', [
                {'type': 'setVariable', 'variable': 'email', 'value': r'${result}'},
              ]),
            ],
          },
          'submit': {
            'type': 'box',
            'layout': {'width': 200, 'height': 48},
            'decoration': {'fills': [{'color': '#FF000000'}]},
            'actions': [
              harness.reaction('click', [
                {'type': 'setVariable', 'variable': 'done', 'value': r'${= true}'},
              ]),
            ],
          },
          'thanks': {'type': 'box', 'layout': {'width': 100, 'height': 20}, 'bind': {'visible': r'${done}'}},
        };

    testWidgets('typing, then a tap that hides the form, removes the field cleanly', (tester) async {
      final s = await harness.show(tester, form(), variables: [
        harness.v('email', ''),
        harness.v('done', false, VariableType.boolean),
      ]);
      await typeInto(tester, 'a@b.co');
      await tester.pump();
      expect(s['email'], 'a@b.co');
      await tester.tapAt(s.center('submit'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(s['done'], true);
      expect(RenderTextField.focused, isNull, reason: 'a hidden field gives the focus back');
    });

    testWidgets('a focused field in a list item that a tap removes goes without an error', (tester) async {
      final s = await harness.show(tester, {
        'col': {'type': 'column', 'children': ['list', 'clear'], 'layout': {'width': 400, 'height': 400}},
        'list': {
          'type': 'listView',
          'children': ['field'],
          'layout': {'width': 360, 'height': {'hug': 120}},
          'props': {'scrollable': false},
          'bind': {'data': r'${rows}'},
        },
        'field': {'type': 'textField', 'layout': {'width': 360, 'height': 56}, 'bind': {'props.initialValue': r'${item}'}},
        'clear': {
          'type': 'box',
          'layout': {'width': 200, 'height': 48},
          'decoration': {'fills': [{'color': '#FF000000'}]},
          'actions': [
            harness.reaction('click', [
              {'type': 'setVariable', 'variable': 'rows', 'value': r'${= []}'},
            ]),
          ],
        },
      }, variables: [harness.v('rows', ['a', 'b'], VariableType.list)]);
      await typeInto(tester, 'xyz');
      await tester.pump();
      await tester.tapAt(s.center('clear'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(textFields(tester), isEmpty);
    });

    testWidgets('a focused field hidden by a variable change lets the focus go without an error', (tester) async {
      final s = await harness.show(tester, form(), variables: [
        harness.v('email', ''),
        harness.v('done', false, VariableType.boolean),
      ]);
      textField(tester).requestFocus();
      await tester.pump();
      s.scope.set('done', true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(RenderTextField.focused, isNull);
    });
  });

  testWidgets('a fixed-height field keeps its height, whatever its padding', (tester) async {
    final (tree, view) = await _show(tester, DocumentSource(_doc({
      'field': {
        'type': 'textField',
        'layout': {'width': 260, 'height': 40},
        'props': {
          'decoration': {'hintText': 'Search', 'isDense': true, 'contentPadding': [12, 11, 12, 11], 'border': {'type': 'outline'}},
        },
      },
    })), interactive: true);
    expect(tree.boxOf('field')!.rectIn(view)!.height, 40);
    final f = textField(tester);
    expect(f.boxRect.height, 40);
    expect(f.contentRect.center.dy, closeTo(20, .5), reason: 'the line centred in the box');
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });

  testWidgets('an error bound to yes or no shows the error border without a message', (tester) async {
    for (final (error, border, message) in [(true, true, ''), (false, false, ''), ('Give the card a title.', true, 'Give the card a title.')]) {
      final source = DocumentSource(_doc({
        'f': {
          'type': 'textField',
          'layout': {'width': 200, 'height': 48},
          'props': {
            'decoration': {
              'errorText': error,
              'errorBorder': {'type': 'outline', 'borderSide': {'color': '#FFE5484D'}},
            },
          },
        },
      }));
      final (tree, _) = await _show(tester, source);
      final f = textField(tester);
      expect(f.decoration.hasError, border, reason: '$error');
      expect(f.belowText, message);
      if (border) expect(f.currentBorder.side.color, const Color(0xFFE5484D));
      await tester.pumpWidget(const SizedBox());
      tree.dispose();
    }
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
    final editor = textField(tester).editor;
    expect(editor.text, 'Untitled 8');
    expect(editor.selection, const TextSelection.collapsed(offset: 10));

    // A caret inside the text keeps its place.
    editor.selection = const TextSelection.collapsed(offset: 3);
    source.document = source.document.copyWith(nodes: {
      ...source.document.nodes,
      'f': source.document['f']!.withProp(api.TextFieldProps.initialValue, 'Untitled 9'),
    });
    await tester.pump();
    expect(textField(tester).editor.selection, const TextSelection.collapsed(offset: 3));
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });

  testWidgets('a text field is sized by its width and height settings, and shows its value and hint', (tester) async {
    final source = DocumentSource(_doc({
      'f': {
        'type': 'textField',
        'layout': {'width': 200, 'height': {'hug': 48}, 'x': {'start': 10}, 'y': {'start': 20}},
        'props': {'initialValue': 'Hi', 'decoration': {'hintText': 'Name', 'errorText': r"${= bad ? 'x' : ''}"}},
      },
    }));
    final (tree, view) = await _show(tester, source);
    final f = textField(tester);
    expect(f.editor.text, 'Hi');
    expect(f.decoration.hint, 'Name');
    // An unevaluated formula is no error.
    expect(f.decoration.hasError, isFalse);
    final rect = tree.boxOf('f')!.rectIn(view)!;
    expect(rect.left, 10);
    expect(rect.width, 200);
    expect(rect.height, 28, reason: 'SSUI\'s field height when it hugs');

    // A new initial value from the document shows.
    source.document = source.document.copyWith(nodes: {
      ...source.document.nodes,
      'f': source.document['f']!.withProp(api.TextFieldProps.initialValue, 'Grace'),
    });
    await tester.pump();
    expect(textField(tester).editor.text, 'Grace');
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
    expect(controlIn<RenderToggle>(tree, 'c').value, isFalse);
    await tester.pumpWidget(const SizedBox());
    tree.dispose();

    (tree, _) = await _show(tester, DocumentSource(doc), interactive: true);
    await tester.tapAt(_center(tester, tree, 'c'));
    await tester.tapAt(_center(tester, tree, 'w'));
    await tester.pump();
    expect(controlIn<RenderToggle>(tree, 'c').value, isTrue);
    expect(controlIn<RenderToggle>(tree, 'w').value, isTrue);
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
    expect(controlIn<RenderSlider>(tree, 'sl').value, 0.5);
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });

  test('on the design canvas a field shows variable names and leaves formulas empty', () {
    expect(fieldPreviewText(null), '');
    expect(fieldPreviewText(''), '');
    expect(fieldPreviewText('Hi'), 'Hi');
    expect(fieldPreviewText(r"${= a ? '!' : ''}"), '');
    expect(fieldPreviewText(r'Total: ${= sum({a: 1})} kg'), 'Total:  kg');
    expect(fieldPreviewText(r'${name}'), r'${name}');
  });

  test('a text field keeps to its minimum and maximum lines', () {
    final tokens = ControlTokens.resolve(api.ThemeTokens.none, dark: false);
    TextFieldConfig config(Map<String, Object?> props, {Object height = 48}) => TextFieldConfig.of(
        LayoutDocument.fromJson({
          'roots': ['f'],
          'nodes': {'f': {'type': 'textField', 'layout': {'width': 200, 'height': height}, 'props': props}},
        })['f']!,
        tokens);
    final one = config({});
    expect((one.maxLines, one.minLines, one.oneLine), (1, null, true));
    final three = config({'maxLines': 0, 'minLines': 3}, height: {'hug': 48});
    expect((three.maxLines, three.minLines), (null, 3));
    final raised = config({'maxLines': 2, 'minLines': 4}, height: {'hug': 48});
    expect((raised.maxLines, raised.minLines), (4, 4));
    final expands = config({'maxLines': 3, 'minLines': 2});
    expect((expands.maxLines, expands.minLines, expands.expands), (null, null, true));
  });

  group('fixed height', () {
    for (final interactive in [true, false]) {
      for (final fit in ['fixed', 'fill', 'hugParent']) {
        testWidgets('a $fit-height one-line field is as tall as its box (interactive: $interactive)', (tester) async {
          final hugParent = fit == 'hugParent';
          final border = {'borderSide': {'color': '#FF34343C', 'width': 2}, 'borderRadius': 14};
          await lists.show(tester, {
            'col': {'type': 'column', 'children': [hugParent ? 'wrap' : 'field'], 'layout': {'width': 390, 'height': 200}},
            'wrap': {
              'type': 'column',
              'children': ['field'],
              'layout': {'width': {'fill': 100}, 'height': {'hug': 40}, 'padding': [16, 0, 16, 0]},
              'props': {'crossAxisAlignment': 'start'},
            },
            'field': {
              'type': 'textField',
              'layout': {'width': {'fill': 358}, 'height': fit == 'fill' ? {'fill': 60} : 60, if (fit == 'fill') 'flex': 1},
              'props': {
                'style': {'fontSize': 18},
                'decoration': {
                  'hintText': 'Search',
                  'prefixIcon': {'icon': {'type': 'MATERIAL_ICON', 'name': 'search', 'style': 'rounded'}, 'size': 26, 'color': '#FF9C9CA6'},
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
          await tester.pumpAndSettle();
          final f = textField(tester);
          expect(f.boxRect.height, fit == 'fill' ? 200 : 60);
          expect(f.fillNow, const Color(0xFF18181C));
          expect(f.currentBorder.kind, FieldBorderKind.outline);
          expect(f.currentBorder.side.width, 2);
        });
      }
    }

    testWidgets('a prefix icon is centered in the field\'s whole height', (tester) async {
      await lists.show(tester, {
        'col': {'type': 'column', 'children': ['field'], 'layout': {'width': 390, 'height': 200}},
        'field': {
          'type': 'textField',
          'layout': {'width': {'fill': 358}, 'height': 68},
          'props': {
            'style': {'fontSize': 21},
            'decoration': {
              'hintText': 'Search',
              'prefixIcon': {'icon': {'type': 'MATERIAL_ICON', 'name': 'search', 'style': 'rounded'}, 'size': 26},
              'prefixIconPadding': [20, 0, 8, 0],
              'contentPadding': [0, 0, 18, 0],
            },
          },
        },
      });
      await tester.pumpAndSettle();
      final f = textField(tester);
      final icons = <RenderBox>[];
      f.visitChildren((c) {
        if (c is! RenderEditable) icons.add(c as RenderBox);
      });
      final icon = (icons.single.parentData! as BoxParentData).offset & icons.single.size;
      expect(icon.size, const Size(26, 26));
      expect(icon.left, 20);
      expect(icon.center.dy, closeTo(f.boxRect.center.dy, 1));
      expect(f.contentRect.left, 20 + 26 + 8 + f.scale.gap);
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
      await tapField(tester, textField(tester));
      await typeInto(tester, 'y = x');
      await tester.pump(const Duration(milliseconds: 30));
      await typeInto(tester, 'y = x^');
      await tester.pump(const Duration(milliseconds: 30));
      await typeInto(tester, 'y = x^2');
      // The first echo ('y = x') arrives now, after two newer edits.
      await tester.pump(const Duration(milliseconds: 60));
      expect(textField(tester).editor.text, 'y = x^2');
      await tester.pump(const Duration(milliseconds: 200));
      expect(textField(tester).editor.text, 'y = x^2');
      expect(scope.read('t'), 'y = x^2');
      // A value from elsewhere still replaces the text.
      scope.set('t', 'a = 2');
      await tester.pump();
      expect(textField(tester).editor.text, 'a = 2');
    });

    testWidgets('a run of the text (a bound range) is drawn in its style', (tester) async {
      await show(tester, {
        'type': 'textField', 'layout': {'width': 200, 'height': 40},
        'props': {'initialValue': 'y = sin(x*x'},
        'bind': {'props.runs': "\${= [{'start': col, 'end': col + 1, 'style': {'color': '#FFB3261E', 'backgroundColor': '#FFF7E3DC'}}]}"},
      }, [harness.v('col', 7, api.VariableType.integer)]);
      final parts = (textField(tester).editable.text! as TextSpan).children!.cast<TextSpan>();
      expect(parts.map((p) => p.text), ['y = sin', '(', 'x*x']);
      expect(parts[1].style!.color, const Color(0xFFB3261E));
    });

    testWidgets('runs that overlap merge their styles in order; a run past the end is cut at it', (tester) async {
      await show(tester, {
        'type': 'textField', 'layout': {'width': 200, 'height': 40},
        'props': {
          'initialValue': 'abcdef',
          'runs': [
            {'start': 1, 'end': 4, 'style': {'color': '#FFB3261E'}},
            {'start': 3, 'end': 40, 'style': {'fontWeight': 700}},
          ],
        },
      }, const []);
      final parts = (textField(tester).editable.text! as TextSpan).children!.cast<TextSpan>();
      expect(parts.map((p) => p.text), ['a', 'bc', 'd', 'ef']);
      expect(parts[0].style, isNull);
      expect(parts[2].style!.color, const Color(0xFFB3261E));
      expect(parts[2].style!.fontWeight, FontWeight.w700);
      expect(parts[3].style!.color, isNull);
    });

    testWidgets('the focus action reaches the field\'s handle', (tester) async {
      final (_, tree) = await show(tester, {'type': 'textField', 'layout': {'width': 200, 'height': 40}}, const []);
      TextFieldHandle.of(tree, 'f')!.focusNode.requestFocus();
      await tester.pump();
      expect(textField(tester).focusNode.hasFocus, isTrue);
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
      // The dropdown (a render object) sits in the padded box: 220 less 10 + 8.
      RenderBox? dropdown;
      void visit(RenderObject o) {
        if (o.runtimeType.toString() == 'RenderDropdown') dropdown ??= o as RenderBox;
        o.visitChildren(visit);
      }

      visit(box);
      expect(dropdown!.size.width, 202);
      expect(dropdown!.localToGlobal(Offset.zero).dx - box.localToGlobal(Offset.zero).dx, closeTo(10, 0.5));
    });
  });
}
