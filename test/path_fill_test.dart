// A path sized `fill` fills the room it's given, also under a parent that
// doesn't stretch it (a start-aligned column): Strata v2's river wave was
// drawn at its 100 px design width instead of the column's.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Size> _size(WidgetTester tester, String cross, Object width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final doc = LayoutDocument.fromJson({
    'roots': ['canvas'],
    'nodes': {
      'canvas': {'type': 'canvas', 'slots': {'body': 'col'}, 'layout': {'width': 390, 'height': 844}},
      'col': {
        'type': 'column',
        'children': ['wave'],
        'layout': {'width': {'fill': 390}, 'height': {'hug': 20}, 'padding': [20, 0, 20, 0]},
        'props': {'crossAxisAlignment': cross},
      },
      'wave': {
        'type': 'path',
        'layout': {'width': width, 'height': 14},
        'props': {'data': 'M0 7 L360 7', 'viewBox': [360, 14]},
      },
    },
  });
  final tree = NodeTree(DocumentSource(doc));
  await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'canvas'))));
  final size = tree.boxOf('wave')!.size;
  await tester.pumpWidget(const SizedBox());
  tree.dispose();
  return size;
}

void main() {
  testWidgets('fill under a start-aligned column fills it', (tester) async {
    expect(await _size(tester, 'start', {'fill': 100}), const Size(350, 14));
  });
  testWidgets('fill under a stretching column fills it', (tester) async {
    expect(await _size(tester, 'stretch', {'fill': 100}), const Size(350, 14));
  });
  testWidgets('fixed keeps its size under a start-aligned column', (tester) async {
    expect(await _size(tester, 'start', 120), const Size(120, 14));
  });
}
