import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// A layout whose `art` box draws an image fill with [url], binding [bind].
LayoutDocument doc(String url, {Map<String, Object?> bind = const {}}) => LayoutDocument.fromJson({
      'roots': ['art'],
      'nodes': {
        'art': {
          'type': 'box',
          'layout': {'width': 64, 'height': 64},
          'decoration': {
            'fills': [
              {'id': 'cover', 'type': 'image', 'image': {'url': url, 'fit': 'cover'}},
            ],
          },
          if (bind.isNotEmpty) 'bind': bind,
        },
      },
    });

String? boundUrl(LayoutDocument d, VariableScope vars) {
  final source = DocumentSource(d);
  final node = d.nodes['art']!;
  final bound = NodeBinder(scope: vars).bind(source, node, null).node;
  return bound.decoration.fills.single.image?.url;
}

void main() {
  final vars = VariableScope([
    const Variable(id: 'show', name: 'show', type: VariableType.map, value: {'cover': 'https://example.com/a.png'}),
  ]);

  test('an image URL holding \${...} is filled in from the scope', () {
    expect(boundUrl(doc(r'${show.cover}'), vars), 'https://example.com/a.png');
    expect(boundUrl(doc(r'https://cdn.test/${show.cover}'), vars), 'https://cdn.test/https://example.com/a.png');
  });

  test('a plain URL is left alone', () {
    expect(boundUrl(doc('https://example.com/b.png'), vars), 'https://example.com/b.png');
  });

  test("the node's own binding of the paint wins", () {
    final d = doc(r'${show.cover}', bind: {'decoration.fills[0].image.url': 'https://example.com/own.png'});
    expect(boundUrl(d, vars), 'https://example.com/own.png');
  });
}
