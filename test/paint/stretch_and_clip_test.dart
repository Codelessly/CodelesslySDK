// Images that stretch and shapes that clip (codelessly_api docs/design/26),
// checked by their pixels and by taps: an image fill's centerSlice keeps its
// corners at their own size as the box grows (nine-slice), a decoration's
// clipPath (in the box's unit square) cuts the node and its children and lets
// a tap outside it through, a drawn shape's blurRadius softens its edge, and a
// linear gradient's angle runs as CSS's does.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

import '../support/screen.dart' as harness;

/// The RGBA pixels of node [root] of [nodes], and its width.
Future<(ByteData, int)> _pixels(WidgetTester tester, Map<String, Json> nodes, String root) async {
  final doc = LayoutDocument.fromJson({'schema': 3, 'roots': [root], 'nodes': nodes});
  final tree = NodeTree(NodeValues(DocumentSource(doc)), binder: NodeBinder(scope: VariableScope(const [])));
  addTearDown(tree.dispose);
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: RepaintBoundary(key: key, child: NodeView(tree: tree, rootId: root))),
  ));
  // Images decode asynchronously.
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
  return (data, boundary.size.width.round());
}

int _red(ByteData d, int w, int x, int y) => d.getUint8((y * w + x) * 4);

/// A 30×30 PNG: a black frame 10 px wide round a white middle.
Future<String> _framePng(WidgetTester tester) async {
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas
      ..drawRect(const Rect.fromLTWH(0, 0, 30, 30), Paint()..color = const Color(0xFF000000))
      ..drawRect(const Rect.fromLTWH(10, 10, 10, 10), Paint()..color = const Color(0xFFFFFFFF));
    final image = await recorder.endRecording().toImage(30, 30);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return png!.buffer.asUint8List();
  });
  return 'data:image/png;base64,${base64Encode(bytes!)}';
}

Map<String, Json> _imageBox(String url, double w, double h, {List<double>? slice}) => {
      'b': {
        'type': 'box',
        'layout': {'width': w, 'height': h},
        'decoration': {
          'fills': [
            {
              'type': 'image',
              'image': {'url': url, 'fit': 'fill', if (slice != null) 'centerSlice': slice},
            },
          ],
        },
      },
    };

void main() {
  testWidgets('a centerSlice keeps the corners at their own size as the box grows', (tester) async {
    final url = await _framePng(tester);
    // Stretched whole, the 10 px frame grows with the box: 40 px across a
    // box 120 wide, 20 down one 60 high.
    final (whole, w0) = await _pixels(tester, _imageBox(url, 120, 60), 'b');
    expect(_red(whole, w0, 12, 30), 0, reason: 'stretched whole, the frame is 40 px wide');
    expect(_red(whole, w0, 60, 15), 0, reason: 'stretched whole, the frame is 20 px high');
    for (final (w, h) in [(120.0, 60.0), (240.0, 140.0)]) {
      final (d, dw) = await _pixels(tester, _imageBox(url, w, h, slice: const [10, 10, 10, 10]), 'b');
      final midX = (w / 2).round(), midY = (h / 2).round();
      // The frame is 10 px on every side at every size; the middle stretches.
      expect(_red(d, dw, 5, midY), 0, reason: '$w×$h: the left edge is the frame');
      expect(_red(d, dw, 13, midY), 255, reason: '$w×$h: 13 px in is the middle');
      expect(_red(d, dw, w.round() - 5, midY), 0, reason: '$w×$h: the right edge is the frame');
      expect(_red(d, dw, w.round() - 13, midY), 255, reason: '$w×$h: 13 px in from the right is the middle');
      expect(_red(d, dw, midX, 5), 0, reason: '$w×$h: the top edge is the frame');
      expect(_red(d, dw, midX, 13), 255, reason: '$w×$h: 13 px down is the middle');
      expect(_red(d, dw, midX, h.round() - 5), 0, reason: '$w×$h: the bottom edge is the frame');
      expect(_red(d, dw, midX, h.round() - 13), 255, reason: '$w×$h: 13 px up is the middle');
      expect(_red(d, dw, 5, 5), 0, reason: '$w×$h: a corner');
    }
  });

  testWidgets('a centerSlice is in logical pixels: at scale 2 the frame is 5 px', (tester) async {
    final url = await _framePng(tester);
    final nodes = _imageBox(url, 120, 60, slice: const [5, 5, 5, 5]);
    (((nodes['b']!['decoration'] as Map)['fills'] as List).single as Map)['image']['scale'] = 2;
    final (d, w) = await _pixels(tester, nodes, 'b');
    expect(_red(d, w, 2, 30), 0);
    expect(_red(d, w, 8, 30), 255);
  });

  Map<String, Json> clipped({Json? reactions}) => {
        'col': {'type': 'column', 'children': ['h'], 'layout': {'width': 200, 'height': {'hug': 100}}},
        // The bottom right half under the line from (1, 0.5) to (0, 1) is cut.
        'h': {
          'type': 'stack',
          'children': ['c'],
          'layout': {'width': 200, 'height': 100},
          'decoration': {
            'fills': [{'color': '#FF0000FF'}],
            'clipPath': 'M0 0 H1 V0.5 L0 1 Z',
          },
        },
        'c': {
          'type': 'box',
          'layout': {'width': 200, 'height': 100},
          'decoration': {'fills': [{'color': '#FFFF0000'}]},
          if (reactions != null) 'actions': [reactions],
        },
      };

  testWidgets('a clipPath in the unit square cuts the node and its children', (tester) async {
    final (d, w) = await _pixels(tester, clipped(), 'col');
    expect(_red(d, w, 20, 20), 255, reason: 'inside: the child paints');
    expect(d.getUint8((20 * w + 20) * 4 + 2), 0, reason: 'inside: the child, over the box\'s blue');
    // Under the line (x 190: the line is at y 52.5): nothing of the box or
    // the child is drawn.
    expect(d.getUint8((90 * w + 190) * 4 + 3), 0, reason: 'cut: transparent');
    expect(d.getUint8((45 * w + 190) * 4), 255, reason: 'just above the line: drawn');
  });

  testWidgets('a tap outside the clipPath passes through; inside it reaches the child', (tester) async {
    final s = await harness.show(
      tester,
      clipped(reactions: harness.reaction('click', [harness.add('taps')])),
      variables: [harness.v('taps', 0, VariableType.integer)],
    );
    await tester.pump();
    final origin = s.tree.boxOf('h')!.localToGlobal(Offset.zero);
    await tester.tapAt(origin + const Offset(190, 90));
    await tester.pumpAndSettle();
    expect(s['taps'], 0, reason: 'outside the path');
    await tester.tapAt(origin + const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(s['taps'], 1, reason: 'inside the path');
  });

  Map<String, Json> dot(double blur) => {
        'b': {
          'type': 'box',
          'layout': {'width': 100, 'height': 100},
          'decoration': {'fills': [{'color': '#FFFFFFFF'}]},
          'customPaint': {
            'viewBox': [100, 100],
            'painter': [
              {'op': 'circle', 'c': [50, 50], 'radius': 20, 'paint': blur == 0 ? '#FF000000' : {'color': '#FF000000', 'blurRadius': blur}},
            ],
          },
        },
      };

  testWidgets('a drawn shape with a blurRadius has a soft edge', (tester) async {
    final (sharp, w) = await _pixels(tester, dot(0), 'b');
    expect(_red(sharp, w, 50 + 26, 50), 255, reason: 'sharp: white just past the edge');
    expect(_red(sharp, w, 50 + 14, 50), 0, reason: 'sharp: black inside');
    final (soft, _) = await _pixels(tester, dot(20), 'b');
    final out = _red(soft, w, 50 + 26, 50), inside = _red(soft, w, 50 + 14, 50);
    expect(out, inInclusiveRange(1, 254), reason: 'soft: grey just past the edge');
    expect(inside, inInclusiveRange(1, 254), reason: 'soft: grey just inside');
    expect(out, greaterThan(inside), reason: 'it fades outward');
  });

  Map<String, Json> angled(double angle, double w, double h) => {
        'b': {
          'type': 'box',
          'layout': {'width': w, 'height': h},
          'decoration': {
            'fills': [
              {
                'type': 'linear',
                'angle': angle,
                'stops': [
                  {'position': 0, 'color': '#FF000000'},
                  {'position': 1, 'color': '#FFFFFFFF'},
                ],
              },
            ],
          },
        },
      };

  testWidgets('a gradient angle runs as CSS: 90 left to right, 180 down, 45 corner to corner', (tester) async {
    final (right, w1) = await _pixels(tester, angled(90, 200, 100), 'b');
    expect(_red(right, w1, 1, 50), lessThan(10));
    expect(_red(right, w1, 198, 50), greaterThan(245));
    expect(_red(right, w1, 100, 5), _red(right, w1, 100, 95), reason: 'the same down a column');
    final (down, w2) = await _pixels(tester, angled(180, 200, 100), 'b');
    expect(_red(down, w2, 100, 1), lessThan(10));
    expect(_red(down, w2, 100, 98), greaterThan(245));
    // 45°: toward the top right; the line reaches the far corners at any
    // aspect (CSS's gradient line), so those corners are its ends.
    for (final (w, h) in [(200.0, 100.0), (100.0, 260.0)]) {
      final (d, dw) = await _pixels(tester, angled(45, w, h), 'b');
      expect(_red(d, dw, 1, h.round() - 2), lessThan(12), reason: '$w×$h: the bottom left corner is the start');
      expect(_red(d, dw, w.round() - 2, 1), greaterThan(243), reason: '$w×$h: the top right corner is the end');
      expect(_red(d, dw, (w / 2).round(), (h / 2).round()), inInclusiveRange(118, 138), reason: '$w×$h: the middle is halfway');
    }
  });

  int alpha(ByteData d, int w, int x, int y) => d.getUint8((y * w + x) * 4 + 3);
  int blue(ByteData d, int w, int x, int y) => d.getUint8((y * w + x) * 4 + 2);

  const notches = [
    {'center': 'centerLeft', 'radius': 12},
    {'center': 'centerRight', 'radius': 12},
  ];
  Map<String, Json> ticket(double w, double h, {Json extra = const {}, Json? reactions}) => {
        't': {
          'type': 'stack',
          'layout': {'width': w, 'height': h},
          'decoration': {
            'fills': [{'color': '#FF0000FF'}],
            'radius': 8,
            'clipCuts': notches,
            ...extra,
          },
          if (reactions != null) 'actions': [reactions],
        },
      };

  testWidgets('clipCuts are in pixels: a ticket\'s notches stay round 12 px circles at two aspects', (tester) async {
    for (final (w, h) in [(160.0, 80.0), (320.0, 200.0)]) {
      final (d, dw) = await _pixels(tester, ticket(w, h), 't');
      final mid = (h / 2).round();
      for (final x in [1, 6, 10]) {
        expect(alpha(d, dw, x, mid), 0, reason: '$w×$h: x $x on the middle line is in the left notch');
        expect(alpha(d, dw, dw - 1 - x, mid), 0, reason: '$w×$h: and in the right one');
      }
      expect(alpha(d, dw, 14, mid), 255, reason: '$w×$h: 14 px in is past the 12 px notch');
      expect(alpha(d, dw, 3, mid - 14), 255, reason: '$w×$h: 14 px above the middle is past it');
      expect(alpha(d, dw, 3, mid - 9), 0, reason: '$w×$h: 9 px above the middle, 3 in, is inside the circle');
    }
  });

  testWidgets('a border follows the clip shape, inside it, and the shadow takes its shape', (tester) async {
    final (d, w) = await _pixels(
        tester,
        ticket(200, 100, extra: {
          'strokes': [{'color': '#FFFF0000'}],
          'strokeWidth': 3,
        }),
        't');
    expect(_red(d, w, 13, 50), 255, reason: 'just past the notch: the border');
    expect(blue(d, w, 13, 50), 0);
    expect(_red(d, w, 20, 50), 0, reason: 'further in: the fill');
    expect(blue(d, w, 20, 50), 255);
    expect(_red(d, w, 100, 1), 255, reason: 'the top edge is bordered too');
    // A shadow with no fill over it shows the shape: the notch stays empty.
    final (s, sw) = await _pixels(tester, {
      'c': {'type': 'stack', 'children': ['t'], 'layout': {'width': 220, 'height': 120}},
      't': {
        'type': 'box',
        'layout': {'width': 200, 'height': 100},
        'decoration': {
          'clipCuts': notches,
          'effects': [
            {'type': 'dropShadow', 'color': '#FF000000', 'offset': [0, 0], 'blurRadius': 0},
          ],
        },
      },
    }, 'c');
    expect(alpha(s, sw, 100, 50), 255, reason: 'the shadow under the body');
    expect(alpha(s, sw, 5, 50), 0, reason: 'none in the notch');
  });

  testWidgets('a tap in a notch passes through', (tester) async {
    final s = await harness.show(tester, {
      'col': {'type': 'column', 'children': ['t'], 'layout': {'width': 200, 'height': {'hug': 100}}},
      ...ticket(200, 100, reactions: harness.reaction('click', [harness.add('taps')])),
    }, variables: [harness.v('taps', 0, VariableType.integer)]);
    await tester.pump();
    final origin = s.tree.boxOf('t')!.localToGlobal(Offset.zero);
    await tester.tapAt(origin + const Offset(4, 50));
    await tester.pumpAndSettle();
    expect(s['taps'], 0, reason: 'in the notch');
    await tester.tapAt(origin + const Offset(100, 50));
    await tester.pumpAndSettle();
    expect(s['taps'], 1, reason: 'on the body');
  });

  const leftHalf = 'M0 0 H0.5 V1 H0 Z';

  testWidgets('every node takes a clip: a text, an icon and a picture cut to their left half', (tester) async {
    await tester.runAsync(_loadIconFont);
    final url = await _framePng(tester);
    Json at(double x, Json node) => {...node, 'layout': {...node['layout'] as Map, 'x': x, 'y': 0}};
    final (d, w) = await _pixels(tester, {
      's': {'type': 'stack', 'children': ['tx', 'ic', 'im'], 'layout': {'width': 300, 'height': 60}},
      'tx': at(0, {
        'type': 'text',
        'layout': {'width': 100, 'height': 60},
        'props': {'text': 'MMMM', 'style': {'fontSize': 40, 'color': '#FF000000'}},
        'decoration': {'clipPath': leftHalf},
      }),
      'ic': at(120, {
        'type': 'icon',
        'layout': {'width': 60, 'height': 60},
        'props': {'icon': {'type': 'MATERIAL_ICON', 'name': 'circle', 'render': 'glyph'}, 'color': '#FF000000'},
        'decoration': {'clipPath': leftHalf},
      }),
      'im': at(200, {
        'type': 'box',
        'layout': {'width': 60, 'height': 60},
        'decoration': {
          'fills': [{'type': 'image', 'image': {'url': url, 'fit': 'fill'}}],
          'clipPath': leftHalf,
        },
      }),
    }, 's');
    bool any(int x0, int x1) {
      for (var x = x0; x < x1; x++) {
        for (var y = 0; y < 60; y++) {
          if (alpha(d, w, x, y) > 0) return true;
        }
      }
      return false;
    }

    expect(any(0, 49), isTrue, reason: 'the text\'s left half is drawn');
    expect(any(51, 100), isFalse, reason: 'its right half is cut');
    expect(any(120, 149), isTrue, reason: 'the icon\'s left half');
    expect(any(151, 180), isFalse, reason: 'its right half is cut');
    expect(any(200, 229), isTrue, reason: 'the picture\'s left half');
    expect(any(231, 260), isFalse, reason: 'its right half is cut');
  });

  testWidgets('a button cut to its left half takes a tap there only', (tester) async {
    final s = await harness.show(tester, {
      'col': {'type': 'column', 'children': ['b'], 'layout': {'width': 200, 'height': {'hug': 48}}},
      'b': {
        'type': 'button',
        'layout': {'width': 160, 'height': 48},
        'props': {'label': 'Tap'},
        'decoration': {'clipPath': leftHalf},
        'actions': [harness.reaction('click', [harness.add('taps')])],
      },
    }, variables: [harness.v('taps', 0, VariableType.integer)]);
    await tester.pump();
    final origin = s.tree.boxOf('b')!.localToGlobal(Offset.zero);
    await tester.tapAt(origin + const Offset(140, 24));
    await tester.pumpAndSettle();
    expect(s['taps'], 0, reason: 'the cut half');
    await tester.tapAt(origin + const Offset(20, 24));
    await tester.pumpAndSettle();
    expect(s['taps'], 1, reason: 'the kept half');
  });

  testWidgets('clipFit none without a view box: the path is in the box\'s pixels', (tester) async {
    final (d, w) = await _pixels(tester, {
      'b': {
        'type': 'box',
        'layout': {'width': 200, 'height': 100},
        'decoration': {
          'fills': [{'color': '#FF0000FF'}],
          'clipPath': 'M0 0 H50 V50 H0 Z',
          'clipFit': 'none',
        },
      },
    }, 'b');
    expect(alpha(d, w, 40, 40), 255);
    expect(alpha(d, w, 60, 40), 0, reason: '50 px, not half the box');
    // A view box stretched: [100,100] over 200×100, so x 50 is 100 px.
    final (v, vw) = await _pixels(tester, {
      'b': {
        'type': 'box',
        'layout': {'width': 200, 'height': 100},
        'decoration': {
          'fills': [{'color': '#FF0000FF'}],
          'clipPath': 'M0 0 H50 V50 H0 Z',
          'clipViewBox': [100, 100],
        },
      },
    }, 'b');
    expect(alpha(v, vw, 95, 40), 255);
    expect(alpha(v, vw, 105, 40), 0);
  });
}

/// The MaterialIcons font, which an icon drawn as a glyph uses.
Future<void> _loadIconFont() async {
  final dir = '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}/bin/cache/artifacts/material_fonts';
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(File('$dir/MaterialIcons-Regular.otf').readAsBytesSync()))))
      .load();
}
