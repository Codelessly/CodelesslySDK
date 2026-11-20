import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Node;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// A text's `style.foreground` paints its glyphs: a gradient lies over them
// across the text's box, a solid paint is their color. (The glyphs were
// drawn with no color at all: white, invisible on a light page, with
// text_no_color.)

void main() {
  Future<RenderObject> show(WidgetTester tester, Map<String, Object?> style) async {
    final tree = NodeTree(
      DocumentSource(LayoutDocument.fromJson({
        'schema': 3,
        'roots': ['col'],
        'nodes': {
          'col': {'type': 'column', 'children': ['t'], 'layout': {'width': 200, 'height': {'hug': 40}}},
          't': {
            'type': 'text',
            'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
            'props': {'text': 'Robin', 'style': {'fontSize': 20, ...style}},
          },
        },
      })),
    );
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'col'))));
    return tester.renderObject(find.byType(NodeView));
  }

  T? find1<T>(RenderObject root) {
    T? out;
    void visit(RenderObject o) {
      if (out == null && o is T) out = o as T;
      o.visitChildren(visit);
    }

    visit(root);
    return out;
  }

  const gradient = {
    'type': 'linear',
    'stops': [
      {'position': 0, 'color': '#FF6FB8FC'},
      {'position': 1, 'color': '#FFCEABFD'},
    ],
  };

  testWidgets('a gradient masks glyphs drawn opaque', (tester) async {
    final root = await show(tester, {'foreground': gradient, 'color': '#FF8DAFFC'});
    final mask = find1<RenderShaderMask>(root);
    expect(mask, isNotNull);
    expect(mask!.blendMode, BlendMode.srcIn);
    final p = find1<RenderParagraph>(root)!;
    expect(p.text.style?.color, const Color(0xFFFFFFFF));
  });

  testWidgets('a solid foreground is the glyphs\' color; no foreground, no mask', (tester) async {
    final solid = await show(tester, {'foreground': {'type': 'solid', 'color': '#FF112233'}});
    expect(find1<RenderParagraph>(solid)!.text.style?.color, const Color(0xFF112233));
    expect(find1<RenderShaderMask>(solid), isNull);
    final plain = await show(tester, {'color': '#FF445566'});
    expect(find1<RenderParagraph>(plain)!.text.style?.color, const Color(0xFF445566));
    expect(find1<RenderShaderMask>(plain), isNull);
  });
}
