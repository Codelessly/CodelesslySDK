// Shared by the custom paint tests: render a node with a `customPaint`, and
// the same drawing done by a Flutter CustomPainter, to pixels.
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// A CustomPainter calling [draw].
class RefPainter extends CustomPainter {
  RefPainter(this.draw);
  final void Function(Canvas canvas, Size size) draw;
  @override
  void paint(Canvas canvas, Size size) => draw(canvas, size);
  @override
  bool shouldRepaint(RefPainter old) => true;
}

/// The RGBA pixels of [child], laid out at its own size at (0, 0) over white
/// in a [w] × [h] boundary.
Future<List<int>> shot(WidgetTester tester, Widget child, {int w = 64, int h = 64}) async {
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: key,
        child: Container(color: Colors.white, width: w.toDouble(), height: h.toDouble(), alignment: Alignment.topLeft, child: child),
      ),
    ),
  ));
  await tester.pump();
  return pixels(tester, key);
}

Future<List<int>> pixels(WidgetTester tester, GlobalKey key) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final data = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final d = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return d;
  }))!;
  return data.buffer.asUint8List().toList();
}

/// The largest per-channel difference of two shots.
int worstDifference(List<int> a, List<int> b) {
  expect(a.length, b.length);
  var worst = 0;
  for (var i = 0; i < a.length; i++) {
    final d = (a[i] - b[i]).abs();
    if (d > worst) worst = d;
  }
  return worst;
}

/// How many pixels differ by more than [tolerance] in a channel.
int differingPixels(List<int> a, List<int> b, {int tolerance = 1}) {
  var n = 0;
  for (var i = 0; i < a.length; i += 4) {
    if ((a[i] - b[i]).abs() > tolerance || (a[i + 1] - b[i + 1]).abs() > tolerance ||
        (a[i + 2] - b[i + 2]).abs() > tolerance || (a[i + 3] - b[i + 3]).abs() > tolerance) {
      n++;
    }
  }
  return n;
}

/// A document with one box [id] of [w] × [h] carrying [customPaint] (and
/// [extra] node keys), plus [more] nodes. Schema 3: its text is Flutter's
/// (the font's own line height), as the reference painters draw it.
LayoutDocument paintDoc(Json customPaint, {double w = 60, double h = 60, String id = 'b', Json extra = const {}, Map<String, Json> more = const {}}) =>
    LayoutDocument.fromJson({
      'schema': 3,
      'roots': [id],
      'nodes': {
        id: {'type': 'box', 'layout': {'width': w, 'height': h}, 'customPaint': customPaint, ...extra},
        ...more,
      },
    });

/// A tree over [doc], its expressions read from [variables].
NodeTree paintTree(LayoutDocument doc, {List<Variable> variables = const []}) =>
    NodeTree(DocumentSource(doc), binder: NodeBinder(scope: VariableScope(variables)));

void pixelRatioOne(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 400);
  addTearDown(tester.view.reset);
}
