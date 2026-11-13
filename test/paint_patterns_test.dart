// Repeating patterns in paints, checked by their pixels: a gradient
// transform repeating along one axis draws straight lines (horizontal and
// vertical), a gradient with a length in pixels repeats every n px whatever
// the box's size (CSS repeating-linear-gradient(..., 80px)), and the noise
// paint is SVG feTurbulence's noise, tiled without a seam.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/paint/noise.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The RGBA pixels of a [w] × [h] box painted with [fills].
Future<(ByteData, int)> _pixels(WidgetTester tester, List<Json> fills, {double w = 400, double h = 300}) async {
  final doc = LayoutDocument.fromJson({
    'roots': ['b'],
    'nodes': {
      'b': {'type': 'box', 'layout': {'width': w, 'height': h}, 'decoration': {'fills': fills}},
    },
  });
  final tree = NodeTree(NodeValues(DocumentSource(doc)), binder: NodeBinder(scope: VariableScope(const [])));
  addTearDown(tree.dispose);
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: RepaintBoundary(key: key, child: NodeView(tree: tree, rootId: 'b'))),
  ));
  // A noise tile decodes asynchronously, as an image.
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final data = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final d = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return d;
  }))!;
  return (data, w.round());
}

const _white = {'color': '#FFFFFFFF'};
List<Json> _stops(double line) => [
      {'position': 0, 'color': '#FF000000'},
      {'position': line, 'color': '#FF000000'},
      {'position': line, 'color': '#00000000'},
      {'position': 1, 'color': '#00000000'},
    ];

void main() {
  testWidgets('a transform repeating along y draws horizontal lines, along x vertical ones', (tester) async {
    // u = 10·y: 10 lines down the box; u = 18·x - 0.5: 18 across.
    final (h, w1) = await _pixels(tester, [_white, {'type': 'linear', 'tileMode': 'repeated', 'transform': [0, 10, 0, 1, 0, 0], 'stops': _stops(0.1)}]);
    int red(ByteData d, int w, int x, int y) => d.getUint8((y * w + x) * 4);
    for (final y in [1, 31, 151]) {
      expect({for (final x in [5, 100, 250, 395]) red(h, w1, x, y)}, {0}, reason: 'row $y is a line all across');
    }
    for (final y in [15, 45, 165]) {
      expect({for (final x in [5, 100, 250, 395]) red(h, w1, x, y)}, {255}, reason: 'row $y is between lines all across');
    }
    final (v, w2) = await _pixels(tester, [_white, {'type': 'linear', 'tileMode': 'repeated', 'transform': [20, 0, 0, 0, 1, 0], 'stops': _stops(0.1)}]);
    for (final x in [1, 21, 201]) {
      expect({for (final y in [5, 100, 295]) red(v, w2, x, y)}, {0}, reason: 'column $x is a line all down');
    }
    for (final x in [12, 32, 212]) {
      expect({for (final y in [5, 100, 295]) red(v, w2, x, y)}, {255}, reason: 'column $x is between lines all down');
    }
  });

  testWidgets('a length in pixels repeats every n px, whatever the box', (tester) async {
    for (final (w, hgt) in [(400.0, 300.0), (517.0, 233.0)]) {
      final (d, wi) = await _pixels(tester, [
        _white,
        // A 1 px line every 80 px: down (horizontal lines) and across (vertical).
        {'type': 'linear', 'begin': 'topCenter', 'end': 'bottomCenter', 'length': 80, 'tileMode': 'repeated', 'stops': _stops(1 / 80)},
        {'type': 'linear', 'begin': 'centerLeft', 'end': 'centerRight', 'length': 80, 'tileMode': 'repeated', 'stops': _stops(1 / 80)},
      ], w: w, h: hgt);
      int red(int x, int y) => d.getUint8((y * wi + x) * 4);
      for (final y in [0, 80, 160]) {
        expect(red(37, y), 0, reason: 'a horizontal line at y=$y ($w wide)');
      }
      for (final x in [0, 80, 160, 240]) {
        expect(red(x, 37), 0, reason: 'a vertical line at x=$x');
      }
      expect(red(37, 40), 255);
      expect(red(41, 43), 255);
    }
  });

  testWidgets('a noise paint draws SVG turbulence as alpha, tiles seamlessly and is the same for the same seed', (tester) async {
    final (d, w) = await _pixels(tester, [
      _white,
      {'type': 'noise', 'noise': {'baseFrequency': 0.05, 'numOctaves': 2, 'seed': 7}, 'color': '#FF000000'},
    ], w: 300, h: 300);
    final t = Turbulence(seed: 7, baseFrequencyX: 0.05, baseFrequencyY: 0.05, numOctaves: 2, fractalNoise: true);
    int red(int x, int y) => d.getUint8((y * w + x) * 4);
    for (final (x, y) in [(3, 4), (100, 17), (200, 199), (255, 0)]) {
      final alpha = t.channelAt(0, x, y, noiseTileSize, noiseTileSize);
      // Black at that alpha over white.
      expect(red(x, y), closeTo(255 - alpha, 2), reason: '($x, $y)');
    }
    // The tile repeats every 256 px.
    for (final y in [0, 10, 40]) {
      expect(red(256 + y % 40, y), red(y % 40, y));
    }
    // Stitched: a whole number of lattice cells per tile, so the noise wraps.
    expect(t.turbulence(0, 256, 30, 256, 256), closeTo(t.turbulence(0, 0, 30, 256, 256), 1e-9));
    // Deterministic: another seed is another grain.
    final other = Turbulence(seed: 8, baseFrequencyX: 0.05, baseFrequencyY: 0.05, numOctaves: 2, fractalNoise: true);
    expect([for (var x = 0; x < 20; x++) other.channelAt(0, x, 5, 256, 256)], isNot([for (var x = 0; x < 20; x++) t.channelAt(0, x, 5, 256, 256)]));
  });

}
