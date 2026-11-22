// A table's grid lines run both ways unless `columnLines` is false: then
// only its rows are ruled (at rest and running).
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _table({bool? columnLines}) => {
  'schema': 3,
  'roots': ['t'],
  'nodes': {
    't': {
      'type': 'tableView',
      'layout': {
        'width': {'fill': 100},
        'height': {'fill': 100},
      },
      'props': {
        'rowHeight': 30,
        'headerHeight': 30,
        'gridLineColor': '#FFFF0000',
        'columnLines': ?columnLines,
        'columns': [
          {'key': 'x', 'label': 'x', 'width': 80},
          {'key': 'y', 'label': 'y', 'width': 100},
        ],
      },
      'bind': {'data': r'${rows}'},
      'slots': {'cell': 'cell', 'columnHeader': 'head'},
    },
    'cell': {
      'type': 'text',
      'props': {'text': r'${item.value}'},
    },
    'head': {
      'type': 'text',
      'props': {'text': r'${item.label}'},
    },
  },
};

/// Whether the pixel at [x], [y] of the table drawn from [doc] is the red of
/// its grid lines.
Future<bool Function(int x, int y)> _reds(WidgetTester tester, Map<String, Object?> doc, {required bool interactive}) async {
  final scope = VariableScope([
    Variable(
      name: 'rows',
      type: api.VariableType.list,
      value: [
        {'x': '1', 'y': '2'},
        {'x': '3', 'y': '4'},
      ],
    ),
  ]);
  final tree = NodeTree(NodeValues(DocumentSource(LayoutDocument.fromJson(doc))), binder: NodeBinder(scope: scope));
  addTearDown(tree.dispose);
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 400,
            height: 200,
            child: NodeView(tree: tree, rootId: 't', interactive: interactive),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
  final px = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba)))!.buffer.asUint8List();
  final w = image.width;
  return (x, y) {
    final i = (y * w + x) * 4;
    return px[i] > 200 && px[i + 1] < 60 && px[i + 2] < 60;
  };
}

void main() {
  for (final interactive in [false, true]) {
    final how = interactive ? 'running' : 'at rest';
    testWidgets('a table draws the lines between its columns and under its rows ($how)', (tester) async {
      tester.view.physicalSize = const Size(400, 200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final red = await _reds(tester, _table(), interactive: interactive);
      // The first column ends at 80: its line is the pixel before, in a body row.
      expect(red(79, 45), isTrue, reason: 'the line between the columns');
      expect([for (var y = 0; y < 100; y++) red(40, y)], contains(true), reason: 'a rule under a row');
    });

    testWidgets('columnLines false: only its rows are ruled ($how)', (tester) async {
      tester.view.physicalSize = const Size(400, 200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final red = await _reds(tester, _table(columnLines: false), interactive: interactive);
      expect([for (var y = 0; y < 100; y++) if (y % 30 > 3 && y % 30 < 26) red(79, y)], everyElement(isFalse),
          reason: 'no line between the columns');
      expect([for (var y = 0; y < 100; y++) red(40, y)], contains(true), reason: 'a rule under a row');
    });
  }
}
