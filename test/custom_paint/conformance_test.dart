// The data form IS Flutter's canvas: each draw op, rendered by the SDK from
// a node's `customPaint`, matches pixel for pixel the same drawing made by
// a Flutter CustomPainter with the Canvas and Paint calls the op names.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

typedef _Case = ({String name, Json paint, void Function(Canvas c, Size s) ref, List<Variable> variables});

_Case _c(String name, Json paint, void Function(Canvas c, Size s) ref, {List<Variable> variables = const []}) =>
    (name: name, paint: paint, ref: ref, variables: variables);

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w;

const _red = Color(0xFFE53935), _blue = Color(0xFF1E88E5), _ink = Color(0xFF212121);

final _cases = <_Case>[
  _c('path: SVG data, filled then stroked', {
    'painter': [
      {'op': 'path', 'd': 'M10 10 L50 14 L30 50 Z', 'paint': ['#FFE53935', {'color': '#FF212121', 'style': 'stroke', 'strokeWidth': 2, 'strokeJoin': 'round'}]},
    ],
  }, (c, s) {
    final p = Path()
      ..moveTo(10, 10)
      ..lineTo(50, 14)
      ..lineTo(30, 50)
      ..close();
    c.drawPath(p, Paint()..color = _red);
    c.drawPath(p, _stroke(_ink, 2)..strokeJoin = StrokeJoin.round);
  }),
  _c('path: points, closed, even-odd', {
    'painter': [
      {'op': 'path', 'points': [[5, 5], [55, 5], [55, 55], [5, 55], null, [20, 20], [40, 20], [40, 40], [20, 40]], 'close': true, 'fillType': 'evenOdd', 'paint': '#FF1E88E5'},
    ],
  }, (c, s) {
    final p = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(5, 5)
      ..lineTo(55, 5)
      ..lineTo(55, 55)
      ..lineTo(5, 55)
      ..moveTo(20, 20)
      ..lineTo(40, 20)
      ..lineTo(40, 40)
      ..lineTo(20, 40)
      ..close();
    c.drawPath(p, Paint()..color = _blue);
  }),
  _c('path: trimmed (PathMetric.extractPath)', {
    'painter': [
      {'op': 'path', 'd': 'M5 30 L55 30', 'trimStart': 0.2, 'trimEnd': 0.7, 'paint': {'color': '#FF212121', 'style': 'stroke', 'strokeWidth': 4}},
    ],
  }, (c, s) {
    final p = Path()
      ..moveTo(5, 30)
      ..lineTo(55, 30);
    final m = p.computeMetrics().single;
    c.drawPath(m.extractPath(m.length * 0.2, m.length * 0.7), _stroke(_ink, 4));
  }),
  _c('line (drawLine), round cap', {
    'painter': [
      {'op': 'line', 'p1': [8, 8], 'p2': [52, 40], 'paint': {'color': '#FFE53935', 'style': 'stroke', 'strokeWidth': 5, 'strokeCap': 'round'}},
    ],
  }, (c, s) => c.drawLine(const Offset(8, 8), const Offset(52, 40), _stroke(_red, 5)..strokeCap = StrokeCap.round)),
  _c('line: hairline (Flutter\'s strokeWidth 0)', {
    'painter': [
      {'op': 'line', 'p1': [0, 30.5], 'p2': [60, 30.5], 'paint': {'style': 'stroke'}},
    ],
  }, (c, s) => c.drawLine(const Offset(0, 30.5), const Offset(60, 30.5), Paint()..style = PaintingStyle.stroke)),
  _c('rect (drawRect)', {
    'painter': [
      {'op': 'rect', 'rect': [4.5, 6, 40, 30.25], 'paint': '#FF1E88E5'},
    ],
  }, (c, s) => c.drawRect(const Rect.fromLTWH(4.5, 6, 40, 30.25), Paint()..color = _blue)),
  _c('rrect (drawRRect), elliptical corners', {
    'painter': [
      {'op': 'rrect', 'rect': [5, 5, 50, 40], 'radius': [12, 6], 'paint': '#FFE53935'},
    ],
  }, (c, s) => c.drawRRect(RRect.fromRectXY(const Rect.fromLTWH(5, 5, 50, 40), 12, 6), Paint()..color = _red)),
  _c('circle (drawCircle), fill and stroke', {
    'painter': [
      {'op': 'circle', 'c': [30, 30], 'radius': 20.5, 'paint': ['#FF1E88E5', {'color': '#FF212121', 'style': 'stroke', 'strokeWidth': 1.4}]},
    ],
  }, (c, s) {
    c.drawCircle(const Offset(30, 30), 20.5, Paint()..color = _blue);
    c.drawCircle(const Offset(30, 30), 20.5, _stroke(_ink, 1.4));
  }),
  _c('oval (drawOval)', {
    'painter': [
      {'op': 'oval', 'rect': [5, 15, 50, 30], 'paint': '#FFE53935'},
    ],
  }, (c, s) => c.drawOval(const Rect.fromLTWH(5, 15, 50, 30), Paint()..color = _red)),
  _c('arc (drawArc), stroked and as a pie', {
    'painter': [
      {'op': 'arc', 'rect': [5, 5, 50, 50], 'startAngle': -1.5708, 'sweepAngle': 2.5, 'paint': {'color': '#FF1E88E5', 'style': 'stroke', 'strokeWidth': 6}},
      {'op': 'arc', 'rect': [15, 15, 30, 30], 'startAngle': 1, 'sweepAngle': 1.2, 'useCenter': true, 'paint': '#FFE53935'},
    ],
  }, (c, s) {
    c.drawArc(const Rect.fromLTWH(5, 5, 50, 50), -1.5708, 2.5, false, _stroke(_blue, 6));
    c.drawArc(const Rect.fromLTWH(15, 15, 30, 30), 1, 1.2, true, Paint()..color = _red);
  }),
  _c('points (drawPoints): points, lines, polygon', {
    'painter': [
      {'op': 'points', 'points': [[10, 10], [20, 10], [30, 10]], 'paint': {'color': '#FF212121', 'style': 'stroke', 'strokeWidth': 4, 'strokeCap': 'round'}},
      {'op': 'points', 'pointMode': 'lines', 'points': [[5, 25], [55, 25], [5, 35], [55, 35]], 'paint': {'color': '#FFE53935', 'style': 'stroke', 'strokeWidth': 2}},
      {'op': 'points', 'pointMode': 'polygon', 'points': [[5, 50], [30, 40], [55, 50]], 'paint': {'color': '#FF1E88E5', 'style': 'stroke', 'strokeWidth': 2}},
    ],
  }, (c, s) {
    c.drawPoints(ui.PointMode.points, const [Offset(10, 10), Offset(20, 10), Offset(30, 10)], _stroke(_ink, 4)..strokeCap = StrokeCap.round);
    c.drawPoints(ui.PointMode.lines, const [Offset(5, 25), Offset(55, 25), Offset(5, 35), Offset(55, 35)], _stroke(_red, 2));
    c.drawPoints(ui.PointMode.polygon, const [Offset(5, 50), Offset(30, 40), Offset(55, 50)], _stroke(_blue, 2));
  }),
  _c('paragraph (TextPainter.paint), centered on its offset', {
    'painter': [
      {'op': 'paragraph', 'text': 'Hi 42', 'offset': [30, 30], 'anchor': [0, 0], 'style': {'fontSize': 16, 'color': '#FF212121'}},
    ],
  }, (c, s) {
    final tp = TextPainter(
      text: TextSpan(text: 'Hi 42', style: textStyle(const api.TextStyle(fontSize: 16, color: api.Color(0xFF212121)))),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, const Offset(30, 30) - Offset(tp.width / 2, tp.height / 2));
  }),
  _c('linear gradient shader (Gradient.linear over the shape)', {
    'painter': [
      {'op': 'rect', 'rect': [10, 10, 40, 40], 'paint': {'shader': {'type': 'linear', 'stops': [{'position': 0, 'color': '#FFE53935'}, {'position': 1, 'color': '#FF1E88E5'}]}}},
    ],
  }, (c, s) => c.drawRect(const Rect.fromLTWH(10, 10, 40, 40),
      Paint()..shader = ui.Gradient.linear(const Offset(10, 30), const Offset(50, 30), const [_red, _blue], const [0, 1]))),
  _c('group: save, translate, scale, rotate, clipRect … restore', {
    'painter': [
      {'op': 'group', 'translate': [30, 30], 'scale': [1.5, 1], 'rotate': 0.4, 'clipRect': [-15, -15, 30, 20], 'ops': [
        {'op': 'rect', 'rect': [-20, -20, 40, 40], 'paint': '#FFE53935'},
      ]},
      {'op': 'circle', 'c': [8, 8], 'radius': 5, 'paint': '#FF1E88E5'},
    ],
  }, (c, s) {
    c.save();
    c.translate(30, 30);
    c.scale(1.5, 1);
    c.rotate(0.4);
    c.clipRect(const Rect.fromLTWH(-15, -15, 30, 20));
    c.drawRect(const Rect.fromLTWH(-20, -20, 40, 40), Paint()..color = _red);
    c.restore();
    c.drawCircle(const Offset(8, 8), 5, Paint()..color = _blue);
  }),
  _c('group: saveLayer with opacity and blend mode', {
    'painter': [
      {'op': 'rect', 'rect': [0, 0, 60, 60], 'paint': '#FF1E88E5'},
      {'op': 'group', 'opacity': 0.5, 'ops': [
        {'op': 'circle', 'c': [30, 30], 'radius': 20, 'paint': '#FFE53935'},
        {'op': 'circle', 'c': [40, 30], 'radius': 15, 'paint': '#FFE53935'},
      ]},
      {'op': 'group', 'blendMode': 'multiply', 'ops': [
        {'op': 'rect', 'rect': [0, 40, 60, 20], 'paint': '#FFFFEB3B'},
      ]},
    ],
  }, (c, s) {
    c.drawRect(const Rect.fromLTWH(0, 0, 60, 60), Paint()..color = _blue);
    c.saveLayer(null, Paint()..color = const Color.fromRGBO(0, 0, 0, 0.5));
    c.drawCircle(const Offset(30, 30), 20, Paint()..color = _red);
    c.drawCircle(const Offset(40, 30), 15, Paint()..color = _red);
    c.restore();
    c.saveLayer(null, Paint()..blendMode = BlendMode.multiply);
    c.drawRect(const Rect.fromLTWH(0, 40, 60, 20), Paint()..color = const Color(0xFFFFEB3B));
    c.restore();
  }),
  _c('group: transform (Matrix4), clipRRect, clipPath', {
    'painter': [
      {'op': 'group', 'transform': [1, 0.2, 0, 0, 0.3, 1, 0, 0, 0, 0, 1, 0, 5, 5, 0, 1], 'clipRRect': {'rect': [0, 0, 40, 40], 'radius': 10}, 'ops': [
        {'op': 'group', 'clipPath': 'M0 0 L40 0 L0 40 Z', 'ops': [
          {'op': 'rect', 'rect': [0, 0, 50, 50], 'paint': '#FF212121'},
        ]},
      ]},
    ],
  }, (c, s) {
    c.save();
    c.transform(Matrix4.fromList([1, 0.2, 0, 0, 0.3, 1, 0, 0, 0, 0, 1, 0, 5, 5, 0, 1]).storage);
    c.clipRRect(RRect.fromRectXY(const Rect.fromLTWH(0, 0, 40, 40), 10, 10));
    c.save();
    c.clipPath(Path()
      ..moveTo(0, 0)
      ..lineTo(40, 0)
      ..lineTo(0, 40)
      ..close());
    c.drawRect(const Rect.fromLTWH(0, 0, 50, 50), Paint()..color = _ink);
    c.restore();
    c.restore();
  }),
  _c('repeat with expressions: dial ticks by rotate', {
    'painter': [
      {'op': 'repeat', 'count': r'${ticks}', 'ops': [
        {'op': 'group', 'translate': [30, 30], 'rotate': r'${= index * 2 * pi / count}', 'ops': [
          {'op': 'line', 'p1': [0, -26], 'p2': [0, r'${= index % 3 == 0 ? -18 : -22}'],
           'paint': {'color': '#FF212121', 'style': 'stroke', 'strokeWidth': r'${= index % 3 == 0 ? 2 : 1}'}},
        ]},
      ]},
    ],
  }, (c, s) {
    for (var i = 0; i < 12; i++) {
      c.save();
      c.translate(30, 30);
      c.rotate(i * 2 * math.pi / 12);
      c.drawLine(const Offset(0, -26), Offset(0, i % 3 == 0 ? -18 : -22), _stroke(_ink, i % 3 == 0 ? 2 : 1));
      c.restore();
    }
  }, variables: [const Variable(name: 'ticks', type: VariableType.integer, value: 12)]),
  _c('view box: [minX, minY, w, h] stretched onto the box', {
    'viewBox': [10, 10, 30, 15],
    'painter': [
      {'op': 'circle', 'c': [25, 17.5], 'radius': 5, 'paint': '#FFE53935'},
    ],
  }, (c, s) {
    c.save();
    c.scale(60 / 30, 60 / 15);
    c.translate(-10, -10);
    c.drawCircle(const Offset(25, 17.5), 5, Paint()..color = _red);
    c.restore();
  }),
  _c('view box: a stroke that doesn\'t scale (scaleStroke: false) stays in box pixels', {
    'viewBox': [10, 10],
    'painter': [
      {'op': 'line', 'p1': [1, 5], 'p2': [9, 5], 'paint': {'color': '#FF212121', 'style': 'stroke', 'strokeWidth': 2, 'scaleStroke': false}},
    ],
  }, (c, s) {
    c.drawPath(Path()
      ..moveTo(6, 30)
      ..lineTo(54, 30), _stroke(_ink, 2));
  }),
];

void main() {
  for (final k in _cases) {
    testWidgets('${k.name} paints as Flutter\'s canvas', (tester) async {
      pixelRatioOne(tester);
      final tree = paintTree(paintDoc(k.paint), variables: k.variables);
      addTearDown(tree.dispose);
      final sdk = await shot(tester, NodeView(tree: tree, rootId: 'b'));
      final ref = await shot(tester, SizedBox(width: 60, height: 60, child: CustomPaint(painter: RefPainter(k.ref))));
      expect(sdk.where((v) => v != 255).length, greaterThan(0), reason: 'it drew something');
      expect(worstDifference(sdk, ref), lessThanOrEqualTo(1));
    });
  }

  testWidgets('image (drawImageRect) of a data URL', (tester) async {
    pixelRatioOne(tester);
    // A 4×4 image: a red top half, a blue bottom half.
    final (image, url) = (await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(const Rect.fromLTWH(0, 0, 4, 2), Paint()..color = _red);
      c.drawRect(const Rect.fromLTWH(0, 2, 4, 2), Paint()..color = _blue);
      final img = await rec.endRecording().toImage(4, 4);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      return (img, Uri.dataFromBytes(png!.buffer.asUint8List(), mimeType: 'image/png').toString());
    }))!;
    final tree = paintTree(paintDoc({
      'painter': [
        {'op': 'image', 'url': url, 'src': [0, 1, 4, 2], 'dst': [10, 10, 40, 40]},
      ],
    }));
    addTearDown(tree.dispose);
    await shot(tester, NodeView(tree: tree, rootId: 'b'));
    // Let the image decode, then paint again.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    final sdk = await shot(tester, NodeView(tree: tree, rootId: 'b'));
    final ref = await shot(tester, SizedBox(width: 60, height: 60, child: CustomPaint(painter: RefPainter((c, s) {
      c.drawImageRect(image, const Rect.fromLTWH(0, 1, 4, 2), const Rect.fromLTWH(10, 10, 40, 40), Paint());
    }))));
    expect(worstDifference(sdk, ref), lessThanOrEqualTo(1));
  });
}
