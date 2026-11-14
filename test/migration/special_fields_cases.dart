// The nodes that used the last special-case fields (codelessly_api's
// steps_special.dart), as 30.1.0 wrote them, and how a test draws one. The
// same file drew them with the renderer of 30.1.0 to take the goldens
// (goldens/special-*.png) and the texts recorded in special_fields_test.dart;
// the test draws what the migration makes of them.
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' show Json, LayoutDocument, Node, Variable, VariableType;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every case: a name, its nodes (the first is the root), its size.
final Map<String, (Map<String, Json>, Size)> specialCases = {
  // plotter_v2's ruler (its editor trees' slider), with a pointer thumb.
  'ruler': ({
    'n': {
      'type': 'slider',
      'layout': {'width': 300, 'height': 40},
      'props': {
        'value': 0.3, 'min': -1, 'max': 1, 'trackShape': 'ruler', 'thumbShape': 'pointer', //
        'activeTrackColor': '#FF3B6E5A', 'inactiveTrackColor': '#FFF1EDE2', 'thumbColor': '#FFB3261E',
        'thumbStrokeColor': '#FF22302A', 'overlayColor': '#00000000', 'padding': [0, 0, 0, 0],
        'rulerTicks': 20, 'rulerMajorEvery': 5, 'rulerTickColor': '#FF22302A', 'rulerMinorTickColor': '#FF56645C',
      },
    },
  }, const Size(300, 40)),
  'ruler-defaults': ({
    'n': {
      'type': 'slider',
      'layout': {'width': 241, 'height': 33},
      'props': {'value': 0.7, 'trackShape': 'ruler', 'inactiveTrackColor': '#FFEEEEEE', 'activeTrackColor': '#FF0057FF'},
    },
  }, const Size(241, 33)),
  'marker': ({
    'n': {
      'type': 'slider',
      'layout': {'width': 260, 'height': 40},
      'props': {
        'value': 0.6, 'fillFromEnd': true, 'activeTrackColor': '#FF0057FF', 'inactiveTrackColor': '#FFDDE3EE', //
        'thumbColor': '#FF0057FF', 'markerValue': 0.25, 'markerColor': '#FFFF5A1F', 'markerWidth': 3, 'markerHeight': 16,
      },
    },
  }, const Size(260, 40)),
  'grip': ({
    'n': {
      'type': 'slider',
      'layout': {'width': 260, 'height': 40},
      'props': {
        'value': 0.45, 'thumbShape': 'rectangle', 'thumbSize': [22, 30], 'thumbCornerRadius': 3, 'thumbColor': '#FFFFFFFF', //
        'thumbBorderColor': '#FF22302A', 'thumbBorderWidth': 1.5, 'thumbGripColor': '#FF22302A',
        'activeTrackColor': '#FF22302A', 'inactiveTrackColor': '#FFCCCCCC',
      },
    },
  }, const Size(260, 40)),
  'fade': ({
    'n': {
      'type': 'slider',
      'layout': {'width': 260, 'height': 40},
      'props': {
        'value': 0.7, 'fillFromEnd': true, 'activeTrackStartOpacity': 0.15, 'trackHeight': 8, //
        'activeTrackColor': '#FF0057FF', 'inactiveTrackColor': '#FFDDE3EE', 'thumbColor': '#FF0057FF',
      },
    },
  }, const Size(260, 40)),
  'highlight': ({
    'n': {
      'type': 'textField',
      'layout': {'width': 280, 'height': 56},
      'props': {
        'initialValue': 'sin(x) + cos(x', 'style': {'fontSize': 16, 'color': '#FF22302A'}, //
        'highlightStart': 9, 'highlightEnd': 14,
        'highlightStyle': {'color': '#FFB3261E', 'backgroundColor': '#FFF7E3DC'},
      },
    },
  }, const Size(280, 56)),
  'row-edge': ({
    'n': {
      'type': 'tableView',
      'layout': {'width': 300, 'height': 200},
      'props': {
        'columns': [
          {'key': 'a', 'label': 'A'},
          {'key': 'b', 'label': 'B'},
        ],
        'rowCount': 4, 'rowHeight': 36, 'columnWidth': 150, 'gridLineColor': '#FFE0E2E8', //
        'selectedRow': 1, 'selectedRowColor': '#FFEAF1FF', 'selectedRowEdgeColor': '#FF0057FF', 'selectedRowEdgeWidth': 4,
      },
      'slots': {'cell': 'cell'},
    },
    'cell': {
      'type': 'box',
      'layout': {'width': {'fill': 1}, 'height': {'fill': 1}},
    },
  }, const Size(300, 200)),
};

/// Draws the document of [nodes] (the first is the root) at [size], as a
/// running app draws it, and returns its pixels; with [golden], they must
/// match that image.
Future<List<int>> drawCase(WidgetTester tester, Map<String, Json> nodes, Size size, {String? golden}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final doc = LayoutDocument(roots: [nodes.keys.first], nodes: {
    for (final e in nodes.entries) e.key: Node.fromJson(e.value, id: e.key)!,
  });
  final vars = VariableScope(const <Variable>[]);
  final tree = NodeTree(DocumentSource(doc),
      binder: NodeBinder(scope: vars), environment: const IslandEnvironment(interactive: true));
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: key,
        child: SizedBox.fromSize(
          size: size,
          child: ColoredBox(color: Colors.white, child: NodeView(tree: tree, rootId: nodes.keys.first, interactive: true)),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  if (golden != null) await expectLater(find.byKey(key), matchesGoldenFile('goldens/$golden.png'));
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final data = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final d = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return d;
  }))!;
  await tester.pumpWidget(const SizedBox());
  tree.dispose();
  vars.dispose();
  return data.buffer.asUint8List().toList();
}

/// The count of a text that counts up, as a running app shows it.
Json countUpText(String text, {int duration = 400, bool onShow = true, String curve = 'linear'}) => {
      'type': 'text',
      'props': {'text': text, 'countUp': true, 'countUpDuration': duration, 'countUpCurve': curve, 'countUpOnShow': onShow},
      'bind': {'props.text': r'${n}'},
    };

/// A variable `n` of text [value].
Variable textVariable(String value) => Variable(id: 'n', name: 'n', type: VariableType.text, value: value);
