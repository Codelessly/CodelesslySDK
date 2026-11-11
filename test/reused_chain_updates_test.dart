import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'several bound updates before a frame keep reused render chains dirty through their parent',
    (tester) async {
      final scope = VariableScope([
        const api.Variable(
          name: 'width',
          type: api.VariableType.integer,
          value: 150,
        ),
        const api.Variable(
          name: 'count',
          type: api.VariableType.integer,
          value: 64,
        ),
      ]);
      final doc = LayoutDocument.fromJson({
        'roots': ['root'],
        'nodes': {
          'root': {
            'type': 'column',
            'children': ['card'],
            'layout': {'width': 400, 'height': 300},
          },
          'card': {
            'type': 'column',
            'children': ['label'],
            'layout': {
              'width': {'fill': 400},
              'height': 120,
              'padding': 16,
            },
            'decoration': {
              'fills': [
                {'color': '#E5FA52'},
              ],
              'strokes': [
                {'color': '#171918'},
              ],
              'radius': 4,
            },
            'bind': {'layout.width': r'${width}'},
          },
          'label': {
            'type': 'text',
            'props': {'text': r'${count}'},
            'layout': {
              'width': {'fill': 200},
              'height': 30,
            },
          },
        },
      });
      final tree = NodeTree(
        DocumentSource(doc),
        binder: NodeBinder(scope: scope),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: NodeView(tree: tree, rootId: 'root'),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        scope.set('width', 150 + i * 10);
        scope.set('count', 64 + i);
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      tree.dispose();
      scope.dispose();
    },
  );
}
