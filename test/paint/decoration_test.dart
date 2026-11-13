import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' hide Node;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// A box with a fill and a border paints as Flutter's Container does: one
// decoration, the fill tucked under the border, so at a fractional edge no
// light sliver of fill shows past the border.

// A box ruled on one side paints as Flutter's Border(bottom: ...): the rule
// runs the box's whole width (the ends were half a stroke short).

// A table's last column can stretch to the table's width (at rest and
// running); a box's stroke can rule a pair of opposite sides.

Map<String, Object?> table({bool stretch = true}) => {
      'roots': ['t'],
      'nodes': {
        't': {
          'type': 'tableView',
          'layout': {'width': {'fill': 100}, 'height': {'fill': 100}},
          'props': {
            'rowHeight': 30, 'headerHeight': 30, 'stretchLastColumn': stretch,
            'columns': [{'key': 'x', 'label': 'x', 'width': 80}, {'key': 'y', 'label': 'y', 'width': 100}],
          },
          'bind': {'data': r'${rows}'},
          'slots': {'cell': 'cell', 'columnHeader': 'head'},
        },
        'cell': {'type': 'text', 'props': {'text': r'${item.value}'}},
        'head': {'type': 'text', 'props': {'text': r'${item.label}'}},
      },
    };

// Elliptical corners: a node's decoration, clip and painted fills and
// strokes take each corner's x and y.

List<T> _under<T>(RenderObject root) {
  final out = <T>[];
  void visit(RenderObject o) {
    if (o is T) out.add(o as T);
    o.visitChildren(visit);
  }

  visit(root);
  return out;
}

// A decoration shaped as a circle paints as Flutter's BoxShape.circle: its
// fill and its stroke as circles (drawCircle), not a rounded rectangle; at a
// fractional position pixel for pixel a painter's two drawCircle calls.

class _Dot extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, 5.5, Paint()..color = const Color(0xFFE8772E));
    canvas.drawCircle(c, 5.5, Paint()
      ..color = const Color(0xFF2A1C10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4);
  }

  @override
  bool shouldRepaint(_Dot old) => false;
}

Future<List<int>> _shot(WidgetTester tester, Widget child) async {
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: key,
        child: Container(color: Colors.white, width: 30, height: 30, padding: const EdgeInsets.only(left: 7.3, top: 8.6), alignment: Alignment.topLeft, child: child),
      ),
    ),
  ));
  await tester.pump();
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final data = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final d = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return d;
  }))!;
  return [for (var i = 0; i < 30 * 30 * 4; i++) data.getUint8(i)];
}

// A radial gradient's `radius` (a share of the box's shortest side, as
// Flutter's RadialGradient) instead of the transform's reach to the box's
// edge across its width: a landscape box's vignette darkens as Flutter's.

LayoutDocument _doc(double? radius, {List<double>? transform}) => LayoutDocument.fromJson({
      'roots': ['canvas'],
      'nodes': {
        'canvas': {'type': 'canvas', 'slots': {'body': 'box'}, 'layout': {'width': 200, 'height': 100}},
        'box': {
          'type': 'box',
          'layout': {'width': 200, 'height': 100},
          'decoration': {
            'fills': [
              {
                'type': 'radial',
                'radius': ?radius,
                'transform': ?transform,
                'stops': [
                  {'position': 0, 'color': '#00000000'},
                  {'position': 1, 'color': '#FF000000'},
                ],
              },
            ],
          },
        },
      },
    });

Future<int> _alphaAt(WidgetTester tester, double? radius, Offset at, {List<double>? transform}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(200, 100);
  addTearDown(tester.view.reset);
  final tree = NodeTree(DocumentSource(_doc(radius, transform: transform)));
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: RepaintBoundary(key: key, child: NodeView(tree: tree, rootId: 'canvas'))),
  ));
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data;
  }))!;
  await tester.pumpWidget(const SizedBox());
  tree.dispose();
  return bytes.getUint8((at.dy.toInt() * 200 + at.dx.toInt()) * 4 + 3);
}

void main() {
  group('fills and borders', () {
    testWidgets('a fill and a border paint as a Flutter Container does, at a fractional width', (tester) async {
      final doc = LayoutDocument.fromJson({
        'roots': ['b'],
        'nodes': {
          'b': {
            'type': 'box', 'layout': {'width': 40.3, 'height': 20},
            'decoration': {'fills': [{'color': '#FFFFFFFF'}], 'strokes': [{'color': '#FF000000'}], 'strokeWidth': 1.2},
          },
        },
      });
      final tree = NodeTree(NodeValues(DocumentSource(doc)), binder: NodeBinder(scope: VariableScope(const [])));
      addTearDown(tree.dispose);
      await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Align(alignment: Alignment.topLeft, child: Column(children: [
        RepaintBoundary(key: const Key('sdk'), child: ColoredBox(color: const Color(0xFF808080), child: Padding(padding: const EdgeInsets.all(4), child: NodeView(tree: tree, rootId: 'b')))),
        RepaintBoundary(key: const Key('flutter'), child: ColoredBox(color: const Color(0xFF808080), child: Padding(padding: const EdgeInsets.all(4),
            child: Container(width: 40.3, height: 20, decoration: BoxDecoration(color: const Color(0xFFFFFFFF), border: Border.all(width: 1.2)))))),
      ]))));
      await tester.pump();
      Future<Uint8List> shot(String k) async {
        late Uint8List bytes;
        await tester.runAsync(() async {
          final image = await tester.renderObject<RenderRepaintBoundary>(find.byKey(Key(k))).toImage(pixelRatio: 2);
          bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
        });
        return bytes;
      }
      expect(await shot('sdk'), await shot('flutter'));
    });

    for (final side in ['bottom', 'left']) {
      testWidgets('a border on the $side side paints as a Flutter Container\'s does', (tester) async {
        final doc = LayoutDocument.fromJson({
          'roots': ['b'],
          'nodes': {
            'b': {
              'type': 'box', 'layout': {'width': 40, 'height': 20},
              'decoration': {'fills': [{'color': '#FFFFFFFF'}], 'strokes': [{'color': '#FF000000'}], 'strokeWidth': 1.4, 'strokeSides': side},
            },
          },
        });
        final tree = NodeTree(NodeValues(DocumentSource(doc)), binder: NodeBinder(scope: VariableScope(const [])));
        addTearDown(tree.dispose);
        const s = BorderSide(width: 1.4);
        await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Align(alignment: Alignment.topLeft, child: Column(children: [
          RepaintBoundary(key: const Key('sdk'), child: ColoredBox(color: const Color(0xFF808080), child: Padding(padding: const EdgeInsets.all(4), child: NodeView(tree: tree, rootId: 'b')))),
          RepaintBoundary(key: const Key('flutter'), child: ColoredBox(color: const Color(0xFF808080), child: Padding(padding: const EdgeInsets.all(4),
              child: Container(width: 40, height: 20, decoration: BoxDecoration(color: const Color(0xFFFFFFFF),
                  border: side == 'bottom' ? const Border(bottom: s) : const Border(left: s)))))),
        ]))));
        await tester.pump();
        Future<Uint8List> shot(String k) async {
          late Uint8List bytes;
          await tester.runAsync(() async {
            final image = await tester.renderObject<RenderRepaintBoundary>(find.byKey(Key(k))).toImage(pixelRatio: 2);
            bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
          });
          return bytes;
        }
        expect(await shot('sdk'), await shot('flutter'));
      });
    }

    for (final (sides, top, right, bottom, left) in const [
      ('bottomRight', false, true, true, false),
      ('noTop', false, true, true, true),
    ]) {
      testWidgets('a border set to $sides draws exactly those sides', (tester) async {
        final doc = {
          'roots': ['b'],
          'nodes': {
            'b': {
              'type': 'box',
              'layout': {'width': 100, 'height': 40},
              'decoration': {
                'fills': [{'color': '#FFFFFFFF'}],
                'strokes': [{'color': '#FF000000'}],
                'strokeWidth': 2,
                'strokeSides': sides,
              },
            },
          },
        };
        final tree = NodeTree(NodeValues(DocumentSource(LayoutDocument.fromJson(doc))));
        addTearDown(tree.dispose);
        await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft,
            child: RepaintBoundary(key: const ValueKey('r'), child: NodeView(tree: tree, rootId: 'b', interactive: false)))));
        await tester.pump();
        late ByteData bytes;
        late int w;
        await tester.runAsync(() async {
          final image = await tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('r'))).toImage();
          w = image.width;
          bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        });
        bool dark(int x, int y) => bytes.getUint8((y * w + x) * 4) < 60;
        expect(dark(50, 0), top, reason: 'top');
        expect(dark(99, 20), right, reason: 'right');
        expect(dark(50, 39), bottom, reason: 'bottom');
        expect(dark(0, 20), left, reason: 'left');
      });
    }
  });

  group('corners and shapes', () {
    testWidgets('a box with elliptical corners paints and clips to them', (tester) async {
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
        'roots': ['s'],
        'nodes': {
          's': {'type': 'stack', 'children': ['solid', 'gradient'], 'layout': {'width': 400, 'height': 200}},
          'solid': {
            'type': 'stack',
            'layout': {'width': 80, 'height': 40, 'x': {'start': 0}, 'y': {'start': 0}},
            'decoration': {'fills': [{'color': '#FFFF0000'}], 'radius': [40, 10], 'clip': 'antiAlias'},
          },
          'gradient': {
            'type': 'box',
            'layout': {'width': 80, 'height': 40, 'x': {'start': 100}, 'y': {'start': 0}},
            'decoration': {
              'fills': [
                {'type': 'linear', 'stops': [{'color': '#FF000000', 'position': 0}, {'color': '#FFFFFFFF', 'position': 1}]},
              ],
              'strokes': [{'color': '#FF0000FF'}],
              'strokeWidth': 2,
              'radius': [[30, 12], 4, 0, 0],
            },
          },
        },
      })));
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's'))));

      const oval = BorderRadius.all(Radius.elliptical(40, 10));
      final solid = tree.boxOf('solid')!;
      final decorated = _under<RenderDecoratedBox>(solid).map((d) => d.decoration).whereType<BoxDecoration>();
      expect(decorated.map((d) => d.borderRadius), contains(oval));
      expect(_under<RenderClipRRect>(solid).single.borderRadius, oval);

      final gradient = tree.boxOf('gradient')!;
      final painter = _under<RenderBox>(gradient).firstWhere((o) => o.runtimeType.toString() == 'RenderNodePaint');
      const corners = BorderRadius.only(topLeft: Radius.elliptical(30, 12), topRight: Radius.circular(4));
      final rect = Offset.zero & painter.size;
      expect(painter, paints..rrect(rrect: corners.toRRect(rect))..path());
      expect(tester.takeException(), isNull);
    });

    testWidgets('a circle shape paints a circle', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(200, 200);
      addTearDown(tester.view.reset);
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
        'roots': ['b'],
        'nodes': {
          'b': {
            'type': 'box',
            'layout': {'width': 11, 'height': 11},
            'decoration': {
              'shape': 'circle',
              'fills': [
                {'color': '#FFE8772E'},
              ],
              'strokes': [
                {'color': '#FF2A1C10'},
              ],
              'strokeWidth': 1.4,
              'strokeAlign': 'center',
            },
          },
        },
      })));
      final sdk = await _shot(tester, NodeView(tree: tree, rootId: 'b'));
      tree.dispose();
      final ref = await _shot(tester, SizedBox(width: 11, height: 11, child: CustomPaint(painter: _Dot())));
      var worst = 0;
      for (var i = 0; i < sdk.length; i++) {
        final d = (sdk[i] - ref[i]).abs();
        if (d > worst) worst = d;
      }
      expect(worst, lessThanOrEqualTo(1));
    });
  });

  group('gradients', () {
    testWidgets('a radial gradient\'s radius is a share of the shortest side, or half the width without one', (tester) async {
      // 50 px right of the center: the whole radius at 0.5 (half the 100 px
      // tall box, Flutter's default), half of the 100 px the transform's
      // radius reaches.
      final withRadius = await _alphaAt(tester, 0.5, const Offset(150, 50));
      final without = await _alphaAt(tester, null, const Offset(150, 50));
      expect(withRadius, greaterThan(240));
      expect(without, inInclusiveRange(100, 155));
    });
  });
}
