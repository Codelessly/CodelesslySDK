
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/inputs_shapes.dart';
import 'package:codelessly_sdk/src/widgets/inputs_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

Finder get _padPaint => find.byWidgetPredicate((w) => w is CustomPaint && w.painter is SignaturePainter);
SignaturePainter _painter(WidgetTester tester) => tester.widget<CustomPaint>(_padPaint).painter! as SignaturePainter;
RenderObject _padRender(WidgetTester tester) => tester.renderObject(_padPaint);

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

bool _selected(WidgetTester tester, String type) => type == 'choiceChip'
    ? tester.widget<ChoiceChip>(find.byType(ChoiceChip)).selected
    : tester.widget<FilterChip>(find.byType(FilterChip)).selected;

SegmentedButton<String> control(NodeTree tree) {
  SegmentedButton<String>? found;
  void visit(Element e) {
    if (e.widget is SegmentedButton<String>) {
      found = e.widget as SegmentedButton<String>;
    }
    e.visitChildren(visit);
  }

  for (final host in tree.islands.hosts) {
    final e = host.element;
    if (e != null) visit(e);
  }
  return found!;
}

Future<void> _showSegmented(WidgetTester tester, Map<String, Object?> props, {double width = 96, double height = 28}) async {
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

Future<void> _showSwitch(WidgetTester tester, Map<String, Object?> node) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
    'roots': ['s'],
    'nodes': {'s': node},
  })));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(key: UniqueKey(), tree: tree, rootId: 's', interactive: true)),
  ));
}

Finder get _paint => find.descendant(of: find.byType(PlainToggle), matching: find.byType(CustomPaint)).first;

double _position(WidgetTester tester) => (tester.widget<CustomPaint>(_paint).painter! as PlainTogglePainter).position.value;

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
      expect(find.byType(CustomSingleChildLayout), findsNothing);
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

    test('draws its strokes as curves, or as straight segments when not smooth', () {
      const pts = [Offset(0, 0), Offset(10, 10), Offset(20, 0)];
      double length(Path p) => p.computeMetrics().fold(0.0, (a, m) => a + m.length);
      // Through the middle point: 2 × √200; the curve cuts the corner.
      expect(length(SignaturePainter.linePath(pts)), closeTo(28.28, 0.01));
      expect(length(SignaturePainter.smoothPath(pts)), lessThan(28.2));
    });
  
  });

  group('a checkbox', () {
    testWidgets('fills its unchecked box with its fill color', (tester) async {
      await lists.show(
        tester,
        _box({'fillColor': '#FF1C1C21', 'activeColor': '#FF1FE07A'}),
        variables: [lists.v('on', false, VariableType.boolean)],
      );
      final c = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(c.fillColor!.resolve({}), const Color(0xFF1C1C21));
      // Checked, its activeColor fills it.
      expect(c.fillColor!.resolve({WidgetState.selected}), isNull);
      expect(c.activeColor, const Color(0xFF1FE07A));
    });

    testWidgets('keeps its size, compact or full', (tester) async {
      await lists.show(
        tester,
        _box({
          'compact': true,
          'borderRadius': 4,
          'side': {'width': 2},
        }, size: 18),
        variables: [lists.v('on', false, VariableType.boolean)],
      );
      var c = tester.widget<Checkbox>(find.byType(Checkbox));
      expect((c.shape! as RoundedRectangleBorder).borderRadius, BorderRadius.circular(4));
      expect(c.side!.width, 2);
      await lists.show(
        tester,
        _box({
          'borderRadius': 4,
          'side': {'width': 2},
        }, size: 80),
        variables: [lists.v('on', false, VariableType.boolean)],
      );
      c = tester.widget<Checkbox>(find.byType(Checkbox));
      expect((c.shape! as RoundedRectangleBorder).borderRadius, BorderRadius.circular(4));
      expect(c.side!.width, 2);
    });

    testWidgets('shows checked at once on the design canvas', (tester) async {
      final s = await lists.show(tester, _box({}), variables: [lists.v('on', false, VariableType.boolean)]);
      await tester.pumpWidget(
        TickerMode(
          enabled: false,
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: NodeView(tree: s.tree, rootId: 'col'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      s.scope.set('on', true);
      await tester.pump();
      await tester.pump();
      final state = tester.state(find.byType(Checkbox)) as ToggleableStateMixin;
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect(state.position.value, 1.0);
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
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(s['on'], false);
      expect(tester.widget<Switch>(find.byType(Switch)).value, false);
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
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(s['taps'], 1);
      expect(tester.widget<Switch>(find.byType(Switch)).value, false);
      s.scope.set('on', true);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, true);
    });
  });

  group('a selectable chip', () {
    for (final type in ['choiceChip', 'filterChip']) {
      testWidgets(
        'a tap on a $type writes its bound value and reports the change once',
        (tester) async {
          final s = await _show(tester, type);
          expect(_selected(tester, type), isFalse);
          await tester.tap(find.text('North'));
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
          await tester.tap(find.text('North'));
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
          await tester.tap(find.text('North'));
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
        await tester.tap(find.text('North'));
        await tester.pumpAndSettle();
        expect(_selected(tester, type), true);
        await tester.tap(find.text('North'));
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
          await tester.tap(find.text('North'), warnIfMissed: false);
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
        final style = control(tree).style!.textStyle!.resolve({});
        expect(style!.fontFamily, 'Alegreya');
        expect(style.fontSize, 13);
        expect(style.fontWeight, FontWeight.w700);
        source.document = source.document.copyWith(
          nodes: {
            'tabs': source.document['tabs']!.withProp(
              api.SegmentedButtonProps.textStyle,
              const api.TextStyle(fontFamily: 'Alegreya', fontSize: 18),
            ),
          },
        );
        await tester.pump();
        expect(control(tree).style!.textStyle!.resolve({})!.fontSize, 18);
        await tester.pumpWidget(const SizedBox());
        tree.dispose();
      },
    );
    testWidgets('without a label style takes the app theme\'s', (
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
      final tree = NodeTree(source);
      await tester.pumpWidget(
        MaterialApp(
          home: NodeView(tree: tree, rootId: 'tabs'),
        ),
      );
      expect(control(tree).style!.textStyle, isNull);
      await tester.pumpWidget(const SizedBox());
      tree.dispose();
    });

    testWidgets('set compact fits a 96 × 28 box', (tester) async {
      await _showSegmented(tester, {
        'expanded': true,
        'segmentHeight': 28,
        'shrinkTapTarget': true,
        'padding': [0, 0, 0, 0],
        'backgroundColor': '#00000000',
      });
      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byType(SegmentedButton<String>));
      expect(size.width, closeTo(96, 0.5));
      expect(size.height, closeTo(28, 0.5));
      final b = tester.widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>));
      expect(b.expandedInsets, EdgeInsets.zero);
    });

    testWidgets('by default is Flutter\'s segmented button', (tester) async {
      await _showSegmented(tester, {}, width: 200, height: 48);
      final b = tester.widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>));
      expect(b.expandedInsets, isNull);
      expect(b.style?.minimumSize, isNull);
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
        expect(tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>)).groupValue, '');
        s.scope.set('plan', 'Team');
        s.scope.set('size', 12.0);
        await tester.pumpAndSettle();
        expect(tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>)).groupValue, 'Team');
        expect(tester.widget<Slider>(find.byType(Slider)).value, 12.0);
      });
    }
  });

  group('a switch with its own look', () {
    for (final on in [false, true]) {
      testWidgets('draws its thumb\'s ${on ? 'on' : 'off'} border inside the thumb\'s edge', (tester) async {
        await _showSwitch(tester, _switch(value: on, props: _border));
        // Thumb 24 across at (15|35, 15): fill, then a 1 px ring inside it.
        final x = on ? 35.0 : 15.0;
        expect(
          tester.renderObject(_paint),
          paints
            ..rrect()
            ..circle(x: x, y: 15, radius: 12, color: const Color(0xFFFFFFFF))
            ..circle(x: x, y: 15, radius: 11.5, color: on ? _ink : _rule, style: PaintingStyle.stroke, strokeWidth: 1),
        );
      });
    }

    testWidgets('slides its thumb over its duration and along its curve', (tester) async {
      await _showSwitch(tester, _switch(props: {'toggleDurationMs': 180, 'toggleCurve': 'linear'}));
      await tester.tap(find.byType(PlainToggle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(_position(tester), closeTo(0.5, 0.01));
      await tester.pump(const Duration(milliseconds: 90));
      expect(_position(tester), 1);
    });

    testWidgets('with a thumb inset or shadows draws its own track and thumb', (tester) async {
      await show(tester, {
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
      expect(find.byType(PlainToggle), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      final node = api.Node.fromJson({'type': 'switch', 'props': {'fillTrack': true, 'thumbInset': 3}}, id: 's')!;
      expect(PlainToggle.thumbDiameters(node, 30, material3: true), (on: 24.0, off: 16.0));
      final painter = PlainTogglePainter(
          position: const AlwaysStoppedAnimation(1), node: node, material3: true, textDirection: TextDirection.ltr);
      expect(painter.thumbAt(const Size(50, 30), 1).center, const Offset(35, 15));
      expect(painter.thumbAt(const Size(50, 30), 0).center, const Offset(15, 15));
    });

  
  });
}
