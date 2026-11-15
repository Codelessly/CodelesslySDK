// `textDirection` (Flutter's Directionality) on a node and everything under
// it: rows and wraps run from the right, start/end text alignment and
// directional padding follow the direction, directional icons mirror, and a
// bound direction re-lays the subtree when its value changes.
import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/paint/icon_glyph.dart' show IconSources, RenderIconGlyph;
import 'package:flutter/material.dart' hide Axis;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screen.dart';

Future<NodeTree> pump(WidgetTester tester, Map<String, Object?> nodes, {String? dir = 'rtl'}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 400);
  addTearDown(tester.view.reset);
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
    'roots': ['frame'],
    'nodes': {
      'frame': {
        'type': 'column',
        'children': ['w'],
        'layout': {'width': 400, 'height': 400},
        'props': {'crossAxisAlignment': 'start'},
        if (dir != null) 'textDirection': dir,
      },
      ...nodes,
    },
  })))
    ..responsive = ResponsiveWidth(Breakpoints.defaults, 400);
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(home: NodeView(tree: tree, rootId: 'frame')));
  return tree;
}

Rect rectOf(NodeTree t, WidgetTester tester, String id) =>
    t.boxOf(id)!.rectIn(tester.renderObject(find.byType(NodeView)))!;

/// [id]'s rect relative to the node under test, `w` (which itself sits at
/// the start of the frame: its right under right to left).
Rect rel(NodeTree t, WidgetTester tester, String id) => rectOf(t, tester, id).shift(-rectOf(t, tester, 'w').topLeft);

Map<String, Object?> box(double w, [double h = 20]) => {'type': 'box', 'layout': {'width': w, 'height': h}};

RenderParagraph paragraphOf(NodeTree t, String id) {
  RenderParagraph? found;
  void visit(RenderObject o) {
    if (o is RenderParagraph) found ??= o;
    o.visitChildren(visit);
  }

  visit(t.boxOf(id)!);
  return found!;
}

RenderIconGlyph glyphOf(NodeTree t, String id) {
  RenderIconGlyph? found;
  void visit(RenderObject o) {
    if (o is RenderIconGlyph) found ??= o;
    o.visitChildren(visit);
  }

  visit(t.boxOf(id)!);
  return found!;
}

void main() {
  group('rows', () {
    Map<String, Object?> row() => {
          'w': {
            'type': 'row',
            'children': ['a', 'b'],
            'layout': {'width': 300, 'height': 20},
            'props': {'spacing': 10},
          },
          'a': box(50),
          'b': box(80),
        };

    testWidgets('a row under a right-to-left ancestor runs from the right edge', (tester) async {
      final t = await pump(tester, row());
      expect(rel(t, tester, 'a'), const Rect.fromLTWH(250, 0, 50, 20));
      expect(rel(t, tester, 'b'), const Rect.fromLTWH(160, 0, 80, 20));
    });

    testWidgets('left to right (and no direction at all) keeps the row as it was', (tester) async {
      for (final dir in ['ltr', null]) {
        final t = await pump(tester, row(), dir: dir);
        expect(rel(t, tester, 'a'), const Rect.fromLTWH(0, 0, 50, 20));
        expect(rel(t, tester, 'b'), const Rect.fromLTWH(60, 0, 80, 20));
      }
    });

    testWidgets('a node\'s own direction overrides the one it inherits', (tester) async {
      final nodes = row();
      (nodes['w']! as Map<String, Object?>)['textDirection'] = 'ltr';
      final t = await pump(tester, nodes);
      expect(rel(t, tester, 'a').left, 0);
    });

    testWidgets('a column\'s start alignment is the right edge', (tester) async {
      final t = await pump(tester, {
        'w': {
          'type': 'column',
          'children': ['a'],
          'layout': {'width': 300, 'height': 100},
          'props': {'crossAxisAlignment': 'start'},
        },
        'a': box(50),
      });
      expect(rel(t, tester, 'a').right, 300);
    });

    testWidgets('a wrapping row fills its lines from the right', (tester) async {
      final t = await pump(tester, {
        'w': {
          'type': 'row',
          'children': ['a', 'b', 'c'],
          'layout': {'width': 200, 'height': {'hug': 20}},
          'props': {'wrap': true, 'spacing': 10, 'runSpacing': 5, 'crossAxisAlignment': 'start'},
        },
        'a': box(90),
        'b': box(90),
        'c': box(90),
      });
      expect(rel(t, tester, 'a'), const Rect.fromLTWH(110, 0, 90, 20));
      expect(rel(t, tester, 'b'), const Rect.fromLTWH(10, 0, 90, 20));
      expect(rel(t, tester, 'c'), const Rect.fromLTWH(110, 25, 90, 20));
    });
  });

  group('directional padding and margin', () {
    Map<String, Object?> padded(Object padding) => {
          'w': {
            'type': 'row',
            'children': ['a'],
            'layout': {'width': 300, 'height': 40, 'padding': padding},
            'props': {'mainAxisAlignment': 'start'},
          },
          'a': box(50),
        };

    testWidgets('start padding is on the right under right to left', (tester) async {
      final t = await pump(tester, padded({'start': 20, 'top': 0, 'end': 4, 'bottom': 0}));
      expect(rel(t, tester, 'a').right, 280);
    });

    testWidgets('start padding is on the left under left to right', (tester) async {
      final t = await pump(tester, padded({'start': 20, 'top': 0, 'end': 4, 'bottom': 0}), dir: 'ltr');
      expect(rel(t, tester, 'a').left, 20);
    });

    testWidgets('absolute padding stays where it was written', (tester) async {
      final t = await pump(tester, padded([20, 0, 4, 0]));
      // Left 20 stays on the left; the row starts at the right, inside 4.
      expect(rel(t, tester, 'a').right, 296);
    });

    testWidgets('a start margin is on the right under right to left', (tester) async {
      final t = await pump(tester, {
        'w': {
          'type': 'column',
          'children': ['a'],
          'layout': {'width': 300, 'height': 100},
          'props': {'crossAxisAlignment': 'start'},
        },
        'a': {
          'type': 'box',
          'layout': {'width': 50, 'height': 20, 'margin': {'start': 12}},
        },
      });
      expect(rel(t, tester, 'a').right, 288);
    });

    test('EdgeInsets reads and writes the directional form', () {
      final e = api.EdgeInsets.fromJson({'start': 20, 'top': 1, 'end': 4, 'bottom': 2});
      expect(e.directional, isTrue);
      expect(e.toJson(), {'start': 20, 'top': 1, 'end': 4, 'bottom': 2});
      expect(e.resolve(rtl: true), const api.EdgeInsets.fromLTRB(4, 1, 20, 2));
      expect(e.resolve(rtl: false), const api.EdgeInsets.fromLTRB(20, 1, 4, 2));
      expect(api.EdgeInsets.fromJson({'left': 3, 'right': 5}), const api.EdgeInsets.fromLTRB(3, 0, 5, 0));
    });
  });

  group('stroke sides', () {
    Future<api.StrokeSides> sidesOf(WidgetTester tester, String sides, {String dir = 'rtl'}) async {
      final t = await pump(tester, {
        'w': {
          'type': 'box',
          'layout': {'width': 100, 'height': 40},
          'decoration': {
            'strokes': [{'color': '#FF000000'}],
            'strokeSides': sides,
          },
        },
      }, dir: dir);
      return t.boxOf('w')!.node!.decoration.strokeSides;
    }

    testWidgets('an end stroke is the left side under right to left, the right under left to right', (tester) async {
      expect(await sidesOf(tester, 'end'), api.StrokeSides.left);
      expect(await sidesOf(tester, 'end', dir: 'ltr'), api.StrokeSides.right);
      expect(await sidesOf(tester, 'noStart'), api.StrokeSides.noRight);
      expect(await sidesOf(tester, 'top'), api.StrokeSides.top);
    });
  });

  group('text', () {
    Map<String, Object?> text(String align) => {
          'w': {
            'type': 'text',
            'layout': {'width': 300, 'height': {'hug': 20}},
            'props': {
              'text': 'שלום',
              'textAlign': align,
              'style': {'fontSize': 14, 'color': '#FF000000'},
            },
          },
        };

    testWidgets('a paragraph lays out right to left, start-aligned to the right', (tester) async {
      final t = await pump(tester, text('start'));
      final p = paragraphOf(t, 'w');
      expect(p.textDirection, TextDirection.rtl);
      expect(p.textAlign, TextAlign.start);
      // Its line ends at the box's right edge.
      final line = p.getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 4)).first;
      expect(line.right, moreOrLessEquals(p.size.width, epsilon: 0.5));
    });

    testWidgets('end alignment is the left edge under right to left', (tester) async {
      final t = await pump(tester, text('end'));
      final p = paragraphOf(t, 'w');
      final line = p.getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 4)).first;
      expect(line.left, moreOrLessEquals(0, epsilon: 0.5));
    });

    testWidgets('a hugging text placed by its start alignment sits at the right of a wider box', (tester) async {
      final t = await pump(tester, {
        'w': {
          'type': 'text',
          'layout': {'width': 300, 'height': 20},
          'props': {'text': 'abc', 'textAlign': 'start', 'style': {'fontSize': 14, 'color': '#FF000000'}},
        },
      });
      final p = paragraphOf(t, 'w');
      final line = p.getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 3)).first;
      final right = p.localToGlobal(Offset(line.right, 0)).dx - rectOf(t, tester, 'w').left;
      expect(right, moreOrLessEquals(300, epsilon: 0.5));
    });
  });

  group('icons', () {
    Map<String, Object?> icon(String name) => {
          'w': {
            'type': 'icon',
            'layout': {'width': 24, 'height': 24},
            'props': {
              'icon': {'type': 'MATERIAL_ICON', 'name': name},
            },
          },
        };

    testWidgets('a directional icon mirrors under right to left', (tester) async {
      for (final name in ['arrow_back', 'chevron_right_rounded', 'arrow_forward_ios']) {
        final t = await pump(tester, icon(name));
        expect(glyphOf(t, 'w').mirrored, isTrue, reason: name);
      }
    });

    testWidgets('other icons, and any icon left to right, do not', (tester) async {
      expect(glyphOf(await pump(tester, icon('home')), 'w').mirrored, isFalse);
      expect(glyphOf(await pump(tester, icon('arrow_back'), dir: 'ltr'), 'w').mirrored, isFalse);
    });

    test('mirrorsInRtl reads the base name of any style', () {
      expect(IconSources.mirrorsInRtl({'type': 'MATERIAL_ICON', 'name': 'arrow_back_rounded'}), isTrue);
      expect(IconSources.mirrorsInRtl({'type': 'MATERIAL_SYMBOL', 'name': 'send'}), isTrue);
      expect(IconSources.mirrorsInRtl({'type': 'MATERIAL_ICON', 'name': 'star'}), isFalse);
      expect(IconSources.mirrorsInRtl({'source': 'image', 'image': 'https://x/arrow_back.png'}), isFalse);
    });
  });

  testWidgets('a bound direction mirrors its subtree and follows the variable', (tester) async {
    final s = await show(tester, {
      'col': {
        'type': 'column',
        'children': ['row'],
        'layout': {'width': 300, 'height': 100},
        'bind': {'textDirection': r"${= rtl ? 'rtl' : 'ltr'}"},
      },
      'row': {
        'type': 'row',
        'children': ['a'],
        'layout': {'width': 300, 'height': 20},
      },
      'a': {'type': 'box', 'layout': {'width': 50, 'height': 20}},
    }, variables: [v('rtl', true, VariableType.boolean)]);
    double left() => s.tree.boxOf('a')!.localToGlobal(Offset.zero).dx - s.tree.boxOf('row')!.localToGlobal(Offset.zero).dx;
    expect(left(), 250);
    s.scope.set('rtl', false);
    await tester.pump();
    expect(left(), 0);
  });
}
