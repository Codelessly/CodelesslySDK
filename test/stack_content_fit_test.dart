// A stack's `contentFit`: children designed at the stack's size, scaled into
// whatever box the stack gets (FittedBox), as a picture-book stage that
// covers a phone's portrait art area and a desktop's landscape one.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

api.LayoutDocument stage(String fit, {double w = 390, double h = 600, List<double> align = const [0, 1]}) => api.LayoutDocument.fromJson({
      'roots': ['root'],
      'nodes': {
        'root': {
          'type': 'stack',
          'children': ['art'],
          'layout': {'width': w, 'height': h},
        },
        'art': {
          'type': 'stack',
          'children': ['rabbit'],
          // Designed at 1200x900; filling its parent.
          'layout': {'width': {'fill': 1200}, 'height': {'fill': 900}, 'x': {'start': 0, 'end': 0}, 'y': {'start': 0, 'end': 0}},
          'props': {'contentFit': fit, 'contentAlignment': align},
          'decoration': {'clip': 'hardEdge'},
        },
        'rabbit': {
          'type': 'box',
          'layout': {'width': 300, 'height': 300, 'x': {'start': 450}, 'y': {'start': 600}},
        },
      },
    });

Future<(NodeTree, RenderObject)> show(WidgetTester tester, api.LayoutDocument doc) async {
  final tree = NodeTree(DocumentSource(doc));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'root')),
  ));
  return (tree, tester.renderObject(find.byType(NodeView)));
}

void main() {
  test('contentFit and contentAlignment round-trip, default none', () {
    final doc = stage('cover', align: const [0, 1]);
    final art = doc.nodes['art']!;
    expect(art.prop(api.StackProps.contentFit), api.BoxFit.cover);
    expect(art.prop(api.StackProps.contentAlignment), const api.Alignment(0, 1));
    expect(art.toJson()['props'], {'contentFit': 'cover', 'contentAlignment': [0, 1]});
    expect(doc.nodes['root']!.prop(api.StackProps.contentFit), api.BoxFit.none);
  });

  testWidgets('cover: a portrait box shows the stage scaled to its height, centred', (tester) async {
    final (tree, view) = await show(tester, stage('cover'));
    // 600 / 900 = 2/3; the 1200-wide stage is 800 wide, centred in 390:
    // its left edge at (390 - 800) / 2 = -205.
    final r = tree.boxOf('rabbit')!.rectIn(view)!;
    expect(r.left, closeTo(-205 + 450 * 2 / 3, 0.01));
    expect(r.top, closeTo(600 * 2 / 3, 0.01));
    expect(r.width, closeTo(200, 0.01));
    expect(r.height, closeTo(200, 0.01));
  });

  testWidgets('contain: a landscape box letterboxes the stage', (tester) async {
    final (tree, view) = await show(tester, stage('contain', w: 780, h: 500, align: const [0, 0]));
    // min(780/1200, 500/900) = 5/9; stage 666.7 wide, centred in 780.
    const s = 5 / 9;
    final r = tree.boxOf('rabbit')!.rectIn(view)!;
    expect(r.left, closeTo((780 - 1200 * s) / 2 + 450 * s, 0.01));
    expect(r.top, closeTo(600 * s, 0.01));
    expect(r.width, closeTo(300 * s, 0.01));
  });

  testWidgets('none lays children out in the box itself', (tester) async {
    final (tree, view) = await show(tester, stage('none'));
    expect(tree.boxOf('rabbit')!.rectIn(view)!.size, const Size(300, 300));
  });
}
