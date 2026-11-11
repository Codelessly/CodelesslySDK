// An active state's patch wins over a binding of what it sets: the hovered
// row's fill shows even though the fill is bound.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a state patch drops the bindings it sets', () {
    final n = Node.fromJson({
      'type': 'row',
      'bind': {
        'decoration.fills[0]': r'${tint}',
        'props.style.color': r'${ink}',
        'visible': r'${shown}',
      },
    }, id: 'r')!;
    final hovered = NodeTree.withoutBindsUnder(n, {
      'decoration': {
        'fills': [
          {'color': '#FF222228'},
        ],
      },
    });
    expect(hovered.bind.keys, ['props.style.color', 'visible']);
    // A style patch that sets the colour drops the colour's binding only.
    final restyled = NodeTree.withoutBindsUnder(n, {
      'props': {
        'style': {'color': '#FF0E0E10'},
      },
    });
    expect(restyled.bind.keys, ['decoration.fills[0]', 'visible']);
    // A patch of something else keeps every binding.
    expect(identical(NodeTree.withoutBindsUnder(n, {'scale': 0.97}), n), isTrue);
  });
}
