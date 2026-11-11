import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/paint/icon_glyph.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('an icon bound to a name swaps its glyph', (tester) async {
    final vars = VariableScope([
      const Variable(id: 'playing', name: 'playing', type: VariableType.boolean, value: false),
    ]);
    final doc = LayoutDocument.fromJson({
      'roots': ['root'],
      'nodes': {
        'root': {'type': 'column', 'children': ['icon'], 'layout': {'width': 100, 'height': 100}},
        'icon': {
          'type': 'icon',
          'layout': {'width': 24, 'height': 24},
          'props': {
            'icon': {'type': 'MATERIAL_ICON', 'name': 'play_arrow', 'style': 'filled'},
          },
          'bind': {'props.icon': r"${= playing ? 'pause' : 'play_arrow'}"},
        },
      },
    });
    final tree = NodeTree(DocumentSource(doc), binder: NodeBinder(scope: vars));
    await tester.pumpWidget(MaterialApp(home: NodeView(tree: tree, rootId: 'root')));
    RenderIconGlyph glyph() {
      RenderIconGlyph? found;
      void visit(RenderObject o) {
        if (o is RenderIconGlyph) found = o;
        o.visitChildren(visit);
      }
      visit(tree.boxOf('icon')!);
      return found!;
    }
    expect(glyph().icon['name'], 'play_arrow');
    vars.set('playing', true);
    await tester.pump();
    expect(glyph().icon['name'], 'pause');
    expect(glyph().icon['type'], 'MATERIAL_ICON');
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
    vars.dispose();
  });
}
