import 'dart:async';
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('live samples and gesture-layer toggles coalesce before layout', (tester) async {
    final vars = VariableScope([
      const Variable(
        id: 'points',
        name: 'points',
        type: VariableType.list,
        value: [
          {'x': 0, 'y': 0},
          {'x': 1, 'y': 1},
        ],
      ),
      const Variable(id: 'pan', name: 'pan', type: VariableType.boolean, value: true),
    ]);
    final doc = LayoutDocument.fromJson({
      'roots': ['root'],
      'nodes': {
        'root': {
          'type': 'column',
          'children': ['plot'],
          'layout': {'width': 400, 'height': 400},
        },
        'plot': {
          'type': 'stack',
          'children': ['curve', 'overlay'],
          'layout': {
            'width': {'fill': 400},
            'height': {'fill': 400},
          },
          'decoration': {'clip': 'hardEdge'},
        },
        'curve': {
          'type': 'lineChart',
          'layout': {
            'width': {'fill': 400},
            'height': {'fill': 400},
          },
          'bind': {'props.data': r'${points}'},
        },
        'overlay': {
          'type': 'stack',
          'layout': {
            'width': {'fill': 400},
            'height': {'fill': 400},
          },
          'transformGesture': {'bounds': 'none', 'target': 'content'},
          'bind': {'transformGesture.enabled': r'${pan}'},
        },
      },
    });
    final tree = NodeTree(DocumentSource(doc), binder: NodeBinder(scope: vars));
    await tester.pumpWidget(
      MaterialApp(
        home: NodeView(tree: tree, rootId: 'root'),
      ),
    );
    for (var i = 0; i < 20; i++) {
      vars.set('pan', i.isEven);
      scheduleMicrotask(
        () => vars.set('points', [
          {'x': 0, 'y': i},
          {'x': 1, 'y': i + 1},
        ]),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
    vars.dispose();
  });
}
