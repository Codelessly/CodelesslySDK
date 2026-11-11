// A design canvas draws a transform gesture's pose given by data (a caption
// placed by its record), where a running app starts it.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/behaviors.dart' show RenderPose;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the pose of a transform gesture shows on the design canvas', (tester) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': ['cap'], 'layout': {'width': 300, 'height': 300}},
        'cap': {
          'type': 'box',
          'layout': {'width': 40, 'height': 20, 'x': {'align': 0}, 'y': {'align': 0}},
          'transformGesture': {'x': 30, 'y': -50, 'scale': 2, 'rotation': 0},
        },
      },
    });
    final tree = NodeTree(DocumentSource(doc));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: NodeView(tree: tree, rootId: 's')));
    RenderPose? pose;
    void find(RenderObject o) {
      if (o is RenderPose) pose ??= o;
      o.visitChildren(find);
    }

    find(tree.boxOf('cap')!);
    expect(pose, isNotNull);
    final m = pose!.transform;
    expect(m.getTranslation().x, 30);
    expect(m.getTranslation().y, -50);
    expect(m.getMaxScaleOnAxis(), 2);
  });
}
