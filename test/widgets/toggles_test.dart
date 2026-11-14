
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/segmented.dart';
import 'package:codelessly_sdk/src/render/controls/slider.dart';
import 'package:codelessly_sdk/src/render/controls/toggles.dart';
import 'package:codelessly_sdk/src/render/controls/chips.dart' show RenderChip;
import 'package:codelessly_sdk/src/widgets/inputs.dart' show RenderSignaturePad;
import 'package:codelessly_sdk/src/widgets/inputs_shapes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../controls/toggles_support.dart';
import '../lists/support.dart' as lists;
import '../support/screen.dart' as harness;

// A signature pad's sign line (solid or dashed, placed and inset), its mark
// (a glyph or a sized icon, above or before the line), its placeholder's
// style and place, and a caption under the line; a checkbox's unchecked
// fill, checked side, compact sizes in node pixels, and a design board's
// checked box shown at rest.

Map<String, Json> _pad(Map<String, Object?> props) => {
  'col': {
    'type': 'column',
    'children': ['sg'],
    'layout': {'width': 400, 'height': 300},
  },
  'sg': {
    'type': 'signature',
    'layout': {'width': 300, 'height': 200},
    'props': props,
  },
};

RenderSignaturePad _padRender(WidgetTester tester) {
  RenderSignaturePad? found;
  void visit(RenderObject o) {
    if (o is RenderSignaturePad) found = o;
    o.visitChildren(visit);
  }

  tester.binding.renderViews.first.visitChildren(visit);
  return found!;
}

SignaturePainter _painter(WidgetTester tester) => _padRender(tester).painter;

Map<String, Json> _box(Map<String, Object?> props, {double size = 40}) => {
  'col': {
    'type': 'column',
    'children': ['cb'],
    'layout': {'width': 300, 'height': 100},
  },
  'cb': {
    'type': 'checkbox',
    'layout': {'width': size, 'height': size},
    'bind': {'props.value': r'${on}'},
    'props': props,
  },
};

// A signature pad's sign line and placeholder where the design puts them:
// a line 16 px in from the sides and 28 px up, no ×, "Sign here" under it.

// A switch that is off can't be toggled; a controlled one shows only its
// bound value, its reactions deciding.

Map<String, Json> _screen(Map<String, Object?> props, {List<Json> actions = const []}) => {
  'col': {
    'type': 'column',
    'children': ['sw'],
    'layout': {'width': 300, 'height': 100},
  },
  'sw': {
    'type': 'switch',
    'layout': {'width': 60, 'height': 40},
    'bind': {'props.value': r'${on}'},
    'props': props,
    'actions': [if (actions.isNotEmpty) lists.reaction('changed', actions)],
  },
};

class _Screen {
  _Screen(this.scope, this.tree);
  final VariableScope scope;
  final NodeTree tree;
}

Future<_Screen> _show(
  WidgetTester tester,
  String type, {
  bool controlled = true,
  bool expression = false,
  bool enabled = true,
  bool interactive = true,
  bool reactions = true,
}) async {
  final source = DocumentSource(
    LayoutDocument.fromJson({
      'roots': ['root'],
      'nodes': {
        'root': {
          'type': 'column',
          'children': ['chip'],
          'layout': {'width': 390, 'height': 200},
          'props': {'crossAxisAlignment': 'start'},
        },
        'chip': {
          'type': type,
          'layout': {
            'width': {'hug': 0},
            'height': {'hug': 0},
          },
          'props': {'label': 'North', 'isEnabled': enabled},
          if (controlled)
            'bind': {
              'props.selected': expression
                  ? r'${= region == "North"}'
                  : r'${selected}',
            },
          if (reactions)
            'actions': [
              {
                'trigger': {'type': 'changed'},
                'actions': [
                  {
                    'type': 'setVariable',
                    'variable': 'changes',
                    'op': 'add',
                    'value': '1',
                  },
                  {
                    'type': 'setVariable',
                    'variable': 'last',
                    'value': r'${result}',
                  },
                  if (expression)
                    {
                      'type': 'setVariable',
                      'variable': 'region',
                      'value': 'North',
                    },
                ],
              },
              {
                'trigger': {'type': 'click'},
                'actions': [
                  {
                    'type': 'setVariable',
                    'variable': 'clicks',
                    'op': 'add',
                    'value': '1',
                  },
                  {
                    'type': 'setVariable',
                    'variable': 'clickSawSelection',
                    'value': r'${selected}',
                  },
                ],
              },
            ],
        },
      },
    }),
  );
  final scope = VariableScope([
    const Variable(name: 'selected', type: VariableType.boolean, value: false),
    const Variable(name: 'region', value: 'All regions'),
    const Variable(name: 'changes', type: VariableType.integer, value: 0),
    const Variable(name: 'clicks', type: VariableType.integer, value: 0),
    const Variable(name: 'last', type: VariableType.boolean, value: false),
    const Variable(
      name: 'clickSawSelection',
      type: VariableType.boolean,
      value: false,
    ),
  ]);
  final tree = NodeTree(source, binder: NodeBinder(scope: scope));
  final actions = TreeReactions(
    runner: const CodelesslyActions(),
    context: RuntimeActionContext(scope: scope, tree: tree),
  );
  tree.interactions = actions;
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: NodeView(tree: tree, rootId: 'root', interactive: interactive),
      ),
    ),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    actions.dispose();
    tree.dispose();
    scope.dispose();
  });
  return _Screen(scope, tree);
}

/// The chip on screen (a render object: render/controls/chips.dart).
RenderChip _chip(WidgetTester tester) {
  RenderChip? found;
  void visit(RenderObject o) {
    if (o is RenderChip) found ??= o;
    o.visitChildren(visit);
  }

  visit(tester.binding.renderViews.first);
  return found!;
}

Offset _chipCenter(WidgetTester tester) {
  final c = _chip(tester);
  return c.localToGlobal(c.size.center(Offset.zero));
}

bool _selected(WidgetTester tester, String type) => _chip(tester).selected;

RenderSegmentedButton control(NodeTree tree, [String id = 'tabs']) => controlIn<RenderSegmentedButton>(tree, id);

Future<NodeTree> _showSegmented(WidgetTester tester, Map<String, Object?> props, {double width = 96, double height = 28}) async {
  final source = DocumentSource(LayoutDocument.fromJson({
    'roots': ['seg'],
    'nodes': {
      'seg': {
        'type': 'segmentedButton',
        'layout': {'width': width, 'height': height},
        'props': {
          'segments': [
            {'value': '1', 'label': '1×'},
            {'value': '2', 'label': '2×'},
            {'value': '4', 'label': '4×'},
          ],
          'selected': ['1'],
          'showSelectedIcon': false,
          ...props,
        },
      },
    },
  }));
  final scope = VariableScope(const []);
  final tree = NodeTree(source, binder: NodeBinder(scope: scope));
  await tester.pumpWidget(MaterialApp(home: Center(child: NodeView(tree: tree, rootId: 'seg', interactive: true))));
  await tester.pumpAndSettle();
  addTearDown(() {
    tree.dispose();
    scope.dispose();
  });
  return tree;
}

// An input island follows its bindings when a variable changes after the
// first build, on a running screen and on a design canvas alike (the
// editor's design capture sets preview values, then captures).

// A switch drawn as a plain toggle: a thumb border that eases between its
// off and on colors like the track's, and the slide's duration and curve.

const _rule = Color(0xFFDDDDDD), _ink = Color(0xFF111111);

Map<String, Object?> _switch({bool value = false, Map<String, Object?> props = const {}}) => {
      'type': 'switch',
      'layout': {'width': 50, 'height': 30},
      'props': {
        'fillTrack': true,
        'thumbInset': 3,
        'value': value,
        'inactiveTrackColor': '#FFFFFFFF',
        'activeTrackColor': '#FF111111',
        'inactiveThumbColor': '#FFFFFFFF',
        'activeThumbColor': '#FFFFFFFF',
        'uniformThumb': true,
        ...props,
      },
    };

Future<RenderToggle> _showSwitch(WidgetTester tester, Map<String, Object?> node) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
    'roots': ['s'],
    'nodes': {'s': node},
  })));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(key: UniqueKey(), tree: tree, rootId: 's', interactive: true)),
  ));
  return controlIn<RenderToggle>(tree, 's');
}

const _border = {'inactiveThumbBorderColor': '#FFDDDDDD', 'activeThumbBorderColor': '#FF111111', 'thumbBorderWidth': 1};

// Runtime of the widgets area's features.

Future<(NodeTree, RenderObject)> show(WidgetTester tester, Map<String, Map<String, Object?>> nodes, String root,
    {double width = 800, double height = 600}) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({'roots': [root], 'nodes': nodes})));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
      home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, height: height, child: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: root))))));
  return (tree, tester.renderObject(find.byType(NodeView)));
}

Map<String, Object?> box(double w, double h) => {
      'type': 'box',
      'layout': {'width': w, 'height': h},
    };

void main() {
  group('a signature pad', () {
    testWidgets('by default shows a solid line, a × mark and its placeholder', (tester) async {
      await lists.show(tester, _pad({}));
      final p = _painter(tester);
      expect(p.dashed, isFalse);
      expect(p.signLineOffset, isNull);
      expect(p.signLineInset, 20);
      expect(p.signLineWidth, 1);
      expect(p.markGlyph, isTrue);
      expect(p.markSize, 16);
      expect(p.leadingMark, isFalse);
      expect(p.placeholderStyle, isNull);
      expect(p.caption, isEmpty);
      // 200 high: the line at 152, across 20 … 280.
      expect(_padRender(tester), paints..line(p1: const Offset(20, 152), p2: const Offset(280, 152)));
      expect(_padRender(tester).markIcon, isNull);
    });

    testWidgets('draws its caption under the line', (tester) async {
      await lists.show(
        tester,
        _pad({
          'signLineOffset': 50,
          'signLineInset': 24,
          'showSignMark': false,
          'caption': 'SIGN ABOVE THE LINE',
          'captionStyle': {'fontWeight': 800, 'fontSize': 11, 'letterSpacing': 1.4, 'color': '#FF5E5E66'},
          'captionGap': 10,
          'value': [
            [
              [10, 10],
              [20, 20],
            ],
          ],
        }),
      );
      final p = _painter(tester);
      expect(p.caption, 'SIGN ABOVE THE LINE');
      expect(p.captionStyle!.fontSize, 11);
      expect(p.captionStyle!.letterSpacing, 1.4);
      expect(p.captionStyle!.color, const Color(0xFF5E5E66));
      // Line at 150, 1 px wide: the caption's top at 150.5 + 10.
      expect(
        _padRender(tester),
        paints
          ..line()
          ..paragraph(offset: const Offset(24, 160.5)),
      );
    });

    testWidgets('a drag draws a stroke and reports every stroke; a read-only pad takes none', (tester) async {
      final nodes = _pad({});
      nodes['sg']!['actions'] = [
        lists.reaction('changed', [
          {'type': 'setVariable', 'variable': 'count', 'value': r'${= length(result)}'},
        ]),
      ];
      final s = await lists.show(tester, nodes, variables: [Variable(name: 'count', type: VariableType.integer, value: 0)]);
      final pad = _padRender(tester);
      final origin = pad.localToGlobal(Offset.zero);
      await tester.dragFrom(origin + const Offset(40, 40), const Offset(60, 30));
      await tester.pump();
      expect(pad.painter.strokes, hasLength(1));
      expect(pad.painter.strokes.single.first, const Offset(40, 40));
      expect(s.scope.read('count'), 1);
      await tester.dragFrom(origin + const Offset(40, 90), const Offset(80, 0));
      await tester.pump();
      expect(pad.painter.strokes, hasLength(2));
      expect(s.scope.read('count'), 2);

      await lists.show(tester, _pad({'readOnly': true}));
      final still = _padRender(tester);
      await tester.dragFrom(still.localToGlobal(Offset.zero) + const Offset(40, 40), const Offset(60, 30));
      await tester.pump();
      expect(still.painter.strokes, isEmpty);
    });

    test('draws its strokes as curves, or as straight segments when not smooth', () {
      const pts = [Offset(0, 0), Offset(10, 10), Offset(20, 0)];
      double length(Path p) => p.computeMetrics().fold(0.0, (a, m) => a + m.length);
      // Through the middle point: 2 × √200; the curve cuts the corner.
      expect(length(SignaturePainter.linePath(pts)), closeTo(28.28, 0.01));
      expect(length(SignaturePainter.smoothPath(pts)), lessThan(28.2));
    });
  
  });

  group('a checkbox', () {
    testWidgets('fills its unchecked box with its fill color, its checked one with its active color', (tester) async {
      final screen = await lists.show(
        tester,
        _box({'fillColor': '#FF1C1C21', 'activeColor': '#FF1FE07A'}),
        variables: [lists.v('on', false, VariableType.boolean)],
      );
      final c = controlIn<RenderToggle>(screen.tree, 'cb');
      expect(c.markFill, const Color(0xFF1C1C21));
      screen.scope.set('on', true);
      await tester.pumpAndSettle();
      expect(c.markFill, const Color(0xFF1FE07A));
    });

    testWidgets('keeps its size, compact or full: its corners and sides are node pixels', (tester) async {
      var screen = await lists.show(
        tester,
        _box({
          'compact': true,
          'borderRadius': 4,
          'side': {'width': 2},
        }, size: 18),
        variables: [lists.v('on', false, VariableType.boolean)],
      );
      var c = controlIn<RenderToggle>(screen.tree, 'cb');
      expect(c.markRect.size, const Size(18, 18), reason: 'compact: the box is the node');
      expect(c.markSide!.width, 2);
      screen = await lists.show(
        tester,
        _box({
          'borderRadius': 4,
          'side': {'width': 2},
        }, size: 80),
        variables: [lists.v('on', false, VariableType.boolean)],
      );
      c = controlIn<RenderToggle>(screen.tree, 'cb');
      expect(c.size, const Size(80, 80));
      expect(c.markRect.size, const Size(36, 36), reason: 'Flutter\'s 18 px box in its 40 px target, scaled to the node');
      expect(c.markSide!.width, 2);
    });

    testWidgets('shows checked at once on the design canvas', (tester) async {
      final s = await lists.show(tester, _box({}), variables: [lists.v('on', false, VariableType.boolean)], interactive: false);
      s.scope.set('on', true);
      await tester.pump();
      await tester.pump();
      final c = controlIn<RenderToggle>(s.tree, 'cb');
      expect(c.value, isTrue);
      expect(c.position, 1.0);
    });
  });

  group('a switch', () {
    testWidgets('ignores taps when disabled', (tester) async {
      final s = await lists.show(
        tester,
        _screen(
          {'enabled': false},
          actions: [
            {'type': 'setVariable', 'variable': 'on', 'value': r'${result}'},
          ],
        ),
        variables: [lists.v('on', false, VariableType.boolean)],
      );
      await tester.pumpAndSettle();
      await tester.tapAt(s.center('sw'));
      await tester.pumpAndSettle();
      expect(s['on'], false);
      expect(controlIn<RenderToggle>(s.tree, 'sw').value, false);
    });

    testWidgets('bound to a value shows only what its reactions set', (tester) async {
      final s = await lists.show(
        tester,
        _screen(
          {'controlled': true},
          actions: [
            {'type': 'setVariable', 'variable': 'taps', 'op': 'add', 'value': '1'},
          ],
        ),
        variables: [lists.v('on', false, VariableType.boolean), lists.v('taps', 0, VariableType.integer)],
      );
      await tester.pumpAndSettle();
      await tester.tapAt(s.center('sw'));
      await tester.pumpAndSettle();
      expect(s['taps'], 1);
      expect(controlIn<RenderToggle>(s.tree, 'sw').value, false);
      s.scope.set('on', true);
      await tester.pumpAndSettle();
      expect(controlIn<RenderToggle>(s.tree, 'sw').value, true);
    });
  });

  group('a selectable chip', () {
    for (final type in ['choiceChip', 'filterChip']) {
      testWidgets(
        'a tap on a $type writes its bound value and reports the change once',
        (tester) async {
          final s = await _show(tester, type);
          expect(_selected(tester, type), isFalse);
          await tester.tapAt(_chipCenter(tester));
          await tester.pumpAndSettle();
          expect(_selected(tester, type), isTrue);
          expect(s.scope.read('selected'), true);
          expect(s.scope.read('last'), true);
          expect(s.scope.read('changes'), 1);
          expect(s.scope.read('clicks'), 1);
          expect(
            s.scope.read('clickSawSelection'),
            true,
            reason: 'writeback and changed precede click',
          );
          await tester.tapAt(_chipCenter(tester));
          await tester.pumpAndSettle();
          expect(_selected(tester, type), isFalse);
          expect(s.scope.read('selected'), false);
          expect(s.scope.read('last'), false);
          expect(s.scope.read('changes'), 2);
          expect(s.scope.read('clicks'), 2);
        },
      );
      testWidgets(
        'a bound $type shows the bound value, not its own guess',
        (tester) async {
          final s = await _show(tester, type);
          await tester.tapAt(_chipCenter(tester));
          await tester.pumpAndSettle();
          s.scope.set('selected', false);
          await tester.pumpAndSettle();
          expect(_selected(tester, type), false);
          s.scope.set('selected', true);
          await tester.pumpAndSettle();
          expect(_selected(tester, type), true);
        },
      );
      testWidgets('an unbound $type toggles itself', (
        tester,
      ) async {
        await _show(tester, type, controlled: false, reactions: false);
        await tester.tapAt(_chipCenter(tester));
        await tester.pumpAndSettle();
        expect(_selected(tester, type), true);
        await tester.tapAt(_chipCenter(tester));
        await tester.pumpAndSettle();
        expect(_selected(tester, type), false);
      });
      for (final disabled in ['disabled', 'design']) {
        testWidgets('a $type that is $disabled does not select', (
          tester,
        ) async {
          final s = await _show(
            tester,
            type,
            enabled: disabled != 'disabled',
            interactive: disabled != 'design',
          );
          await tester.tapAt(_chipCenter(tester));
          await tester.pumpAndSettle();
          expect(_selected(tester, type), false);
          expect(s.scope.read('selected'), false);
          expect(s.scope.read('changes'), 0);
          expect(s.scope.read('clicks'), 0);
        });
      }
    }
  });

  group('a segmented button', () {
    testWidgets(
      'takes its label style and follows changes to it',
      (tester) async {
        final source = DocumentSource(
          LayoutDocument.fromJson({
            'roots': ['tabs'],
            'nodes': {
              'tabs': {
                'type': 'segmentedButton',
                'layout': {'width': 320, 'height': 48},
                'props': {
                  'segments': [
                    {'value': 'Results', 'label': 'Results'},
                    {'value': 'Swing', 'label': 'Swing'},
                  ],
                  'selected': ['Results'],
                  'textStyle': {
                    'fontFamily': 'Alegreya',
                    'fontSize': 13,
                    'fontWeight': 700,
                  },
                },
              },
            },
          }),
        );
        final tree = NodeTree(source);
        await tester.pumpWidget(
          MaterialApp(
            home: NodeView(tree: tree, rootId: 'tabs', interactive: true),
          ),
        );
        final label = control(tree).labels.first;
        expect(label.fontFamily, 'Alegreya');
        final glyph13 = label.glyphs.first.height;
        source.document = source.document.copyWith(
          nodes: {
            'tabs': source.document['tabs']!.withProp(
              api.SegmentedButtonProps.textStyle,
              const api.TextStyle(fontFamily: 'Alegreya', fontSize: 18),
            ),
          },
        );
        await tester.pump();
        expect(control(tree).labels.first.glyphs.first.height, greaterThan(glyph13), reason: 'its labels take the new size');
        await tester.pumpWidget(const SizedBox());
        tree.dispose();
      },
    );
    testWidgets('without a label style takes the document theme\'s font', (
      tester,
    ) async {
      final source = DocumentSource(
        LayoutDocument.fromJson({
          'roots': ['tabs'],
          'nodes': {
            'tabs': {
              'type': 'segmentedButton',
              'layout': {'width': 320, 'height': 48},
              'props': {
                'segments': [
                  {'value': 'Results', 'label': 'Results'},
                ],
                'selected': ['Results'],
              },
            },
          },
        }),
      );
      final tree = NodeTree(source)..theme = ThemeTokens.fromJson({'fontFamily': 'Barlow'});
      await tester.pumpWidget(
        MaterialApp(
          home: NodeView(tree: tree, rootId: 'tabs'),
        ),
      );
      expect(control(tree).labels.single.fontFamily, 'Barlow');
      await tester.pumpWidget(const SizedBox());
      tree.dispose();
    });

    testWidgets('set compact fits a 96 × 28 box, its segments sharing the width', (tester) async {
      final tree = await _showSegmented(tester, {
        'expanded': true,
        'segmentHeight': 28,
        'shrinkTapTarget': true,
        'padding': [0, 0, 0, 0],
        'backgroundColor': '#00000000',
      });
      expect(tester.takeException(), isNull);
      final b = control(tree, 'seg');
      expect(b.size.width, closeTo(96, 0.5));
      expect(b.size.height, closeTo(28, 0.5));
      expect(b.segmentRects.map((r) => r.width), everyElement(closeTo((96 - 4) / 3, 0.01)));
    });

    testWidgets('by default is SSUI\'s segmented control, its segments the node\'s height less the well\'s inset', (tester) async {
      final tree = await _showSegmented(tester, {}, width: 200, height: 32);
      expect(tester.takeException(), isNull);
      final b = control(tree, 'seg');
      expect(b.size, const Size(200, 32));
      expect(b.segmentRects.map((r) => r.height), everyElement(28));
      expect(b.trackColor, const Color(0xFFF3F4F6), reason: 'SSUI\'s subtleFill');
      expect(b.selectedColor, const Color(0xFFFFFFFF));
    });
  });

  group('following a bound value', () {
    for (final interactive in [true, false]) {
      testWidgets('a radio and a slider follow their variable when it changes (interactive: $interactive)', (tester) async {
        final s = await harness.show(
          tester,
          {
            'col': {'type': 'column', 'children': ['r', 's'], 'layout': {'width': 300, 'height': 100}},
            'r': {
              'type': 'radio',
              'layout': {'width': 18, 'height': 18},
              'props': {'value': 'Team'},
              'bind': {'props.groupValue': r'${plan}'},
            },
            's': {
              'type': 'slider',
              'layout': {'width': 300, 'height': 28},
              'props': {'value': 0, 'min': 0, 'max': 50},
              'bind': {'props.value': r'${size}'},
            },
          },
          variables: [harness.v('plan', ''), harness.v('size', 0.0, VariableType.decimal)],
          interactive: interactive,
        );
        await tester.pumpAndSettle();
        expect(controlIn<RenderToggle>(s.tree, 'r').value, '');
        s.scope.set('plan', 'Team');
        s.scope.set('size', 12.0);
        await tester.pumpAndSettle();
        expect(controlIn<RenderToggle>(s.tree, 'r').value, 'Team');
        expect(controlIn<RenderToggle>(s.tree, 'r').checked, isTrue);
        expect(controlIn<RenderSlider>(s.tree, 's').value, 12.0);
      });
    }
  });

  group('a switch with its own look', () {
    for (final on in [false, true]) {
      testWidgets('draws its thumb\'s ${on ? 'on' : 'off'} border inside the thumb\'s edge', (tester) async {
        final toggle = await _showSwitch(tester, _switch(value: on, props: _border));
        // Thumb 24 across at (15|35, 15): fill, then a 1 px ring inside it.
        final x = on ? 35.0 : 15.0;
        expect(toggle.thumb, (center: Offset(x, 15), radius: 12.0));
        expect(
          toggle,
          paints
            ..rrect()
            ..circle(x: x, y: 15, radius: 12, color: const Color(0xFFFFFFFF))
            ..circle(x: x, y: 15, radius: 11.5, color: on ? _ink : _rule, style: PaintingStyle.stroke, strokeWidth: 1),
        );
      });
    }

    testWidgets('slides its thumb over its duration and along its curve', (tester) async {
      final toggle = await _showSwitch(tester, _switch(props: {'toggleDurationMs': 180, 'toggleCurve': 'linear'}));
      await tester.tapAt(toggle.localToGlobal(toggle.size.center(Offset.zero)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(toggle.position, closeTo(0.5, 0.01));
      await tester.pump(const Duration(milliseconds: 90));
      expect(toggle.position, 1);
    });

    testWidgets('with a thumb inset and shadows draws its own track and thumb, the thumb round at any size', (tester) async {
      final (tree, _) = await show(tester, {
        's': {
          'type': 'switch',
          'layout': {'width': 50, 'height': 30},
          'props': {
            'fillTrack': true,
            'thumbInset': 3,
            'value': true,
            'activeTrackColor': '#FF00AA00',
            'activeThumbColor': '#FFFFFFFF',
            'thumbShadows': [{'type': 'dropShadow', 'color': '#33000000', 'blurRadius': 4, 'offset': [0, 1]}],
          },
        },
      }, 's');
      final toggle = controlIn<RenderToggle>(tree, 's');
      expect(toggle.markRect, const Rect.fromLTWH(0, 0, 50, 30), reason: 'its track fills the node');
      expect(toggle.trackColor, const Color(0xFF00AA00));
      expect(toggle.thumb, (center: const Offset(35, 15), radius: 12.0));
      // The shadow, then the thumb.
      expect(toggle, paints..rrect(color: const Color(0xFF00AA00))..circle(x: 35, y: 16)..circle(x: 35, y: 15, radius: 12));
    });
  });

}
