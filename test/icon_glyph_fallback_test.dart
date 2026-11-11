// A Material icon whose SVG isn't available (loading, or no version 1 on
// Google's server, as grid_view rounded) draws its MaterialIcons glyph
// instead of nothing, when it carries the codepoint.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/paint/icon_glyph.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only Material icons with a codepoint have a stand-in glyph', () {
    expect(IconSources.glyphOf({'type': 'MATERIAL_ICON', 'name': 'grid_view', 'style': 'rounded', 'codepoint': 63428}), 63428);
    expect(IconSources.glyphOf({'source': 'icon', 'codepoint': 57669}), 57669);
    expect(IconSources.glyphOf({'type': 'MATERIAL_ICON', 'name': 'grid_view'}), isNull);
    expect(IconSources.glyphOf({'type': 'CUPERTINO_ICON', 'codepoint': 1}), isNull);
    expect(IconSources.glyphOf({'source': 'image', 'image': 'x.png', 'codepoint': 3}), isNull);
  });

  testWidgets('the glyph paints while the SVG is unavailable', (tester) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['i'],
      'nodes': {
        'i': {
          'type': 'icon',
          'layout': {'width': 24, 'height': 24},
          'props': {
            'icon': {'type': 'MATERIAL_ICON', 'name': 'grid_view', 'style': 'rounded', 'codepoint': 63428},
            'color': '#FF1D1A16',
          },
        },
      },
    });
    final tree = NodeTree(DocumentSource(doc));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'i'))));
    // The network is off in tests: the SVG never loads. Something is drawn.
    final glyph = tester.renderObject(find.byType(NodeView));
    expect(glyph, paints..paragraph());
  });
}
