// A binding of a paint the node doesn't have yet (`decoration.fills[0]` on
// a node with no fills) adds it: Wireless's sidebar highlights the open
// show with a fill bound on a row that has none at design time.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

LayoutDocument doc(Map<String, Object?> decoration, Map<String, Object?> bind) => LayoutDocument.fromJson({
      'roots': ['row'],
      'nodes': {
        'row': {
          'type': 'box',
          'layout': {'width': 64, 'height': 64},
          'decoration': decoration,
          'bind': bind,
        },
      },
    });

Node bound(LayoutDocument d, VariableScope vars) =>
    NodeBinder(scope: vars).bind(DocumentSource(d), d.nodes['row']!, null).node;

void main() {
  final vars = VariableScope([const Variable(id: 'on', name: 'on', type: VariableType.boolean, value: true)]);

  test('a bound first fill is added to a node with none', () {
    final n = bound(doc({'radius': 10}, {'decoration.fills[0]': r"${= on ? '#22F4E9D3' : '#00000000'}"}), vars);
    expect(n.decoration.fills, hasLength(1));
    expect(n.decoration.fills.single.color?.toJson(), '#22F4E9D3');
  });

  test('a bound first stroke is added to a node with none', () {
    final n = bound(doc({}, {'decoration.strokes[0]': '#FFE8A33D'}), vars);
    expect(n.decoration.strokes, hasLength(1));
  });

  test('a bound fill still replaces the one the node has', () {
    final n = bound(doc({'fills': [{'color': '#FF000000'}]}, {'decoration.fills[0]': '#FFFFFFFF'}), vars);
    expect(n.decoration.fills.single.color?.toJson(), '#FFFFFFFF');
  });
}
