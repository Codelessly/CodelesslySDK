// A scroll view that hugs its content (a sheet as tall as its content up to
// the screen, scrolling past that) keeps where it was scrolled to when its
// content changes: typing into a field in it relaid it out with room for
// all of it, and the position went back to the top.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/layout/design_scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a hugging scroll view keeps its offset through a content change', (tester) async {
    final scope = VariableScope([const Variable(name: 'tall', type: VariableType.boolean, value: false)]);
    final tree = NodeTree(
      DocumentSource(LayoutDocument.fromJson({
        'roots': ['page'],
        'nodes': {
          'page': {
            'type': 'row',
            'children': ['card'],
            'layout': {'width': 400, 'height': 500, 'padding': 20},
            'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
          },
          'card': {
            'type': 'column',
            'children': ['scroll'],
            'layout': {'width': {'fill': 360}, 'height': {'hug': 10}},
            'props': {'crossAxisAlignment': 'stretch'},
          },
          'scroll': {
            'type': 'column',
            'children': ['a', 'grow', 'b'],
            'layout': {'width': {'fill': 360}, 'height': {'hug': 10}, 'padding': 20},
            'props': {'scrollable': true, 'crossAxisAlignment': 'stretch'},
          },
          'a': {'type': 'box', 'layout': {'width': {'fill': 320}, 'height': 400}},
          'grow': {
            'type': 'box',
            'layout': {'width': {'fill': 320}, 'height': 40},
            'bind': {'layout.height': r'${= tall ? 60 : 40}'},
          },
          'b': {'type': 'box', 'layout': {'width': {'fill': 320}, 'height': 300}},
        },
      })),
      binder: NodeBinder(scope: scope, logic: const LayoutLogic()),
    );
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'page', interactive: true)),
    ));
    await tester.pump();
    RenderDesignScroll? scroll;
    void visit(RenderObject o) {
      if (o is RenderDesignScroll && scroll == null) scroll = o;
      o.visitChildren(visit);
    }
    visit(tester.renderObject(find.byType(NodeView)));
    expect(scroll!.maxScrollExtent, greaterThan(150));
    scroll!.jumpBy(150);
    await tester.pump();
    expect(scroll!.offset, 150);
    // The content changes (a field grows as it's typed into).
    scope.set('tall', true);
    await tester.pump();
    await tester.pump();
    expect(scroll!.offset, 150);
  });
}
