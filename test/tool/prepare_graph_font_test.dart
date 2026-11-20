// The render tool gives what draws text with no family of its own the
// default one, so a headless render draws its letters: a chart's axis
// family, and a graph's style, which names its family inside a record.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/prepare.dart';

void main() {
  Map<String, Object?> nodeOf(Map<String, Object?> props) {
    final prepared = prepare({
      'nodes': {
        'g': {'type': 'graph', 'props': props},
      },
    }, dir: '.', defaultFamily: 'Roboto', codepoints: const {});
    return ((prepared.json['nodes']! as Map)['g'] as Map).cast<String, Object?>();
  }

  test('a graph with no style, or a style with no family, draws in the default family', () {
    expect(((nodeOf({})['props'] as Map)['style'] as Map)['fontFamily'], 'Roboto');
    final styled = (nodeOf({
      'style': {'topInset': 6},
    })['props'] as Map)['style'] as Map;
    expect(styled, {'topInset': 6, 'fontFamily': 'Roboto'});
  });

  test('a chart\'s family written empty is none of its own: the default one', () {
    final prepared = prepare({
      'nodes': {
        'b': {
          'type': 'barChart',
          'props': {'labelFontFamily': ''},
        },
        'm': {
          'type': 'barChart',
          'props': {'labelFontFamily': 'JetBrains Mono'},
        },
      },
    }, dir: '.', defaultFamily: 'Roboto', codepoints: const {});
    final nodes = prepared.json['nodes']! as Map;
    expect(((nodes['b'] as Map)['props'] as Map)['labelFontFamily'], 'Roboto');
    expect(((nodes['m'] as Map)['props'] as Map)['labelFontFamily'], 'JetBrains Mono');
  });

  test('a family the style names is kept', () {
    final own = (nodeOf({
      'style': {'fontFamily': 'Inter'},
    })['props'] as Map)['style'] as Map;
    expect(own['fontFamily'], 'Inter');
  });
}
