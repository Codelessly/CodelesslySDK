// An icon's `size` (Flutter's `Icon.size`): the glyph drawn at that size,
// centered in the node's box, as Flutter's Icon centers its glyph in the box
// it is given; a hugging icon takes the size. Unset, the glyph fills the box
// as before.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/paint/icon_glyph.dart';
import 'package:flutter/material.dart' hide Icon;
import 'package:flutter/material.dart' as m show Icon;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<RenderIconGlyph> glyphOf(WidgetTester tester, Json icon) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['root'],
      'nodes': {
        'root': {'type': 'column', 'children': ['icon'], 'layout': {'width': 100, 'height': 100}, 'props': {'crossAxisAlignment': 'start'}},
        'icon': {'type': 'icon', ...icon},
      },
    });
    final tree = NodeTree(DocumentSource(doc));
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'root'))));
    RenderIconGlyph? found;
    void visit(RenderObject o) {
      if (o is RenderIconGlyph) found = o;
      o.visitChildren(visit);
    }
    visit(tree.boxOf('icon')!);
    addTearDown(tree.dispose);
    return found!;
  }

  testWidgets('an icon\'s size centers the glyph in its box, as Flutter\'s Icon does', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: SizedBox(width: 40, height: 40, child: m.Icon(Icons.search, size: 18))),
    ));
    final p = tester.renderObject<RenderParagraph>(find.descendant(of: find.byType(m.Icon), matching: find.byType(RichText)));
    final flutter = p.localToGlobal(Offset.zero) & p.size;
    final g = await glyphOf(tester, {
      'layout': {'width': 40, 'height': 40},
      'props': {'icon': 'search', 'size': 18},
    });
    expect(g.size, const Size(40, 40));
    expect(g.glyphRect, flutter);
  });

  testWidgets('a hugging icon takes its size; without size the glyph fills the box', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Align(alignment: Alignment.topLeft, child: m.Icon(Icons.search, size: 18))));
    final flutterSize = tester.getSize(find.byType(m.Icon));
    final hug = await glyphOf(tester, {
      'layout': {'width': {'hug': 24}, 'height': {'hug': 24}},
      'props': {'icon': 'search', 'size': 18},
    });
    expect(hug.size, flutterSize);
    final plain = await glyphOf(tester, {
      'layout': {'width': 24, 'height': 24},
      'props': {'icon': 'search'},
    });
    expect(plain.glyphRect, Offset.zero & const Size(24, 24));
  });

  testWidgets('an icon that says nothing of its size is the default icon size, not nothing', (tester) async {
    // What an agent writes: an icon name and no numbers.
    final g = await glyphOf(tester, {
      'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
      'props': {'icon': 'info'},
    });
    expect(g.size, const Size.square(kDefaultIconSize));
    expect(g.glyphRect, Offset.zero & const Size.square(kDefaultIconSize));
    // A design size is still the box the glyph fills.
    final boxed = await glyphOf(tester, {
      'layout': {'width': {'hug': 20}, 'height': {'hug': 20}},
      'props': {'icon': 'info'},
    });
    expect(boxed.glyphRect, Offset.zero & const Size.square(20));
  });
}
