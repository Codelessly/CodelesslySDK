import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/spinner.dart';
import 'package:codelessly_sdk/src/widgets/indicators_paint.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// [nodes] placed freeform at (10, 10) in a 400×300 stack.
LayoutDocument _doc(Map<String, Map<String, Object?>> nodes) => LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': [...nodes.keys], 'layout': {'width': 400, 'height': 300}},
        for (final e in nodes.entries)
          e.key: {
            ...e.value,
            'layout': {'x': {'start': 10}, 'y': {'start': 10}, ...?e.value['layout'] as Map?},
          },
      },
    });

Iterable<RenderObject> _descendants(RenderObject o) sync* {
  final kids = <RenderObject>[];
  o.visitChildren(kids.add);
  for (final k in kids) {
    yield k;
    yield* _descendants(k);
  }
}

void main() {
  _themeChangeRepaintsIndicators();
  testWidgets('a spinner animates', (tester) async {
    final doc = _doc({
      'spin': {'type': 'circularProgressIndicator', 'layout': {'width': 24, 'height': 24}, 'props': {'color': '#FF2D6CDF'}},
      'still': {'type': 'circularProgressIndicator', 'layout': {'width': 24, 'height': 24}, 'props': {'value': 0.5}},
      'ios': {'type': 'activityIndicator', 'layout': {'width': 30, 'height': 30}, 'props': {'radius': 12}},
    });
    final tree = NodeTree(DocumentSource(doc));
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's'))));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    // Render objects on their own tickers, no Material or Cupertino widget.
    RenderSpinner spinner(String id) => _descendants(tree.boxOf(id)!).whereType<RenderSpinner>().single;
    expect(spinner('spin').spinning, isTrue);
    expect(spinner('spin').color, const Color(0xFF2D6CDF));
    expect(spinner('still').spinning, isFalse, reason: 'a value is a ring, not a spinner');
    expect(spinner('ios').style, SpinnerStyle.ticks);
    expect(spinner('ios').spinning, isTrue);
    final turns = spinner('spin').turns;
    await tester.pump(const Duration(milliseconds: 200));
    expect(spinner('spin').turns, isNot(turns), reason: 'indeterminate: it turns on the ticker');
    expect(tester.binding.hasScheduledFrame, isTrue);
    final view = tester.renderObject(find.byType(NodeView));
    // Fixed in a freeform parent: the node's size; the indicator a square.
    expect(tree.boxOf('spin')!.rectIn(view), const Rect.fromLTWH(10, 10, 24, 24));
    expect(tree.boxOf('ios')!.rectIn(view)!.size, const Size(30, 30));
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });

  testWidgets('a spinner in a row is centered and as wide as it is tall', (tester) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['r'],
      'nodes': {
        'r': {'type': 'row', 'children': ['spin', 'ios'], 'layout': {'width': 200, 'height': 48}},
        'spin': {'type': 'circularProgressIndicator', 'layout': {'width': 16, 'height': 16, 'padding': 1.25}},
        'ios': {'type': 'activityIndicator', 'layout': {'width': 20, 'height': 20}, 'props': {'radius': 10}},
      },
    });
    final tree = NodeTree(DocumentSource(doc));
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'r'))));
    final view = tester.renderObject(find.byType(NodeView));
    // A square of its design size less padding (13.5), centered: the node
    // takes the row's height.
    expect(tree.boxOf('spin')!.rectIn(view), const Rect.fromLTWH(0, 0, 13.5, 48));
    expect(tree.boxOf('ios')!.rectIn(view), const Rect.fromLTWH(13.5, 14, 20, 20));
    expect(_descendants(tree.boxOf('spin')!).whereType<RenderSpinner>().single.size, const Size(13.5, 13.5));
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });

  testWidgets('progress bars and gauges take their box and paint', (tester) async {
    final doc = _doc({
      'bar': {'type': 'progressBar', 'layout': {'width': 150, 'height': 10}, 'props': {'value': 40}},
      'arc': {'type': 'progressBar', 'layout': {'width': 120, 'height': 100}, 'props': {'value': 40, 'shape': 'arc', 'needleColor': '#FF000000', 'tickCount': 4}},
      'dial': {'type': 'radialGauge', 'layout': {'width': 200, 'height': 168}, 'props': {'value': 72}},
      'meter': {'type': 'gaugeMeter', 'layout': {'width': 30, 'height': 120}, 'props': {'value': 60, 'shape': 'bar', 'limit': 80, 'ticks': 5}},
      'chart': {'type': 'chart', 'layout': {'width': 300, 'height': 160}, 'props': {
        'series': [{'field': 'a'}, {'field': 'p', 'kind': 'tick'}],
        'data': [{'label': 'x', 'a': 3, 'p': 4}, {'label': 'y', 'p': 4}],
      }},
      'donut': {'type': 'chart', 'layout': {'width': 100, 'height': 100}, 'props': {'chartType': 'donut', 'data': [{'value': 1}, {'value': 2}]}},
      'plot': {'type': 'plotChart', 'layout': {'width': 300, 'height': 120}, 'props': {'points': [1, 3, 2], 'xMax': 2, 'selectedX': 1}},
      'bars': {'type': 'barChart', 'layout': {'width': 200, 'height': 100}, 'props': {'values': [1, null, 3], 'labels': ['a', 'b', 'c']}},
      'bars2': {'type': 'barChart', 'layout': {'width': 300, 'height': 160}, 'props': {
        'values': [7, 12, 5], 'labels': ['Solo', 'Team', 'Enterprise'], 'max': 16, 'highlight': 1,
        'gridLines': 4, 'gridLabels': ['4', '8', '12', '16'], 'gridLabelsLeft': true, 'maxBarWidth': 48, 'showValues': true,
      }},
      'line': {'type': 'lineChart', 'layout': {'width': 300, 'height': 200}, 'props': {'data': [{'x': 0, 'y': 1}, {'x': 1, 'y': 3}], 'yAxisTitle': 'ft'}},
      'qr': {'type': 'barcode', 'layout': {'width': 120, 'height': 120}, 'props': {'data': 'hello'}},
      'ean': {'type': 'barcode', 'layout': {'width': 120, 'height': 60}, 'props': {'data': 'letters', 'symbology': 'ean13'}},
    });
    final tree = NodeTree(DocumentSource(doc));
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's'))));
    final view = tester.renderObject(find.byType(NodeView));
    for (final n in doc.nodes.values) {
      if (n.id == 's') continue;
      final rect = tree.boxOf(n.id)!.rectIn(view)!;
      expect(rect.topLeft, const Offset(10, 10), reason: n.id);
      expect(rect.size, Size(n.layout.width.value, n.layout.height.value), reason: n.id);
      final paint = _descendants(tree.boxOf(n.id)!).whereType<RenderCustomPaint>().single;
      expect(paint.painter, isA<NodePainter>());
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });

}

/// The ARGB color at ([x], [y]) of [key]'s boundary.
Future<int> _pixel(WidgetTester tester, GlobalKey key, int x, int y) async => (await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = (await image.toByteData())!;
      final at = 4 * (y * image.width + x);
      image.dispose();
      return bytes.getUint8(at + 3) << 24 | bytes.getUint8(at) << 16 | bytes.getUint8(at + 1) << 8 | bytes.getUint8(at + 2);
    }))!;

void _themeChangeRepaintsIndicators() {
  testWidgets('a gauge with no colors of its own repaints in the new theme when the theme (or its mode) changes', (tester) async {
    final doc = _doc({
      'meter': {
        'type': 'gaugeMeter',
        'layout': {'width': 120, 'height': 30},
        'props': {'value': 100, 'min': 0, 'max': 100, 'shape': 'bar', 'ticks': 0},
      },
    });
    final components = ComponentRegistry()..theme = ThemeTokens.fromJson({'primary': '#FFFF0000'});
    final tree = NodeTree(DocumentSource(doc), components: components);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        home: Align(alignment: Alignment.topLeft, child: RepaintBoundary(key: key, child: NodeView(tree: tree, rootId: 's')))));
    await tester.pump(const Duration(seconds: 2));
    Future<int> fill() => _pixel(tester, key, 70, 25);
    expect((await fill()).toRadixString(16), 'ffff0000');
    // What a setThemeMode does: the screen's theme is now the dark one.
    components.theme = ThemeTokens.fromJson({'primary': '#FF0000FF'});
    await tester.pump(const Duration(seconds: 2));
    expect((await fill()).toRadixString(16), 'ff0000ff');
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });
}
