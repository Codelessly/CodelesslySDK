import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<RenderDesignScroll> build(
    WidgetTester tester,
    bool interactive,
  ) async {
    final tree = NodeTree(
      DocumentSource(
        LayoutDocument.fromJson({
          'roots': ['body'],
          'nodes': {
            'body': {
              'type': 'column',
              'layout': {'width': 200, 'height': 120},
              'props': {'scrollable': true},
              'children': ['a', 'b'],
            },
            'a': {
              'type': 'box',
              'layout': {'width': 200, 'height': 120},
            },
            'b': {
              'type': 'box',
              'layout': {'width': 200, 'height': 120},
            },
          },
        }),
      ),
    );
    addTearDown(tree.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: NodeView(tree: tree, rootId: 'body', interactive: interactive),
        ),
      ),
    );
    RenderDesignScroll? scroll;
    void visit(RenderObject object) {
      if (object is RenderDesignScroll) scroll = object;
      object.visitChildren(visit);
    }

    visit(tree.boxOf('body')!);
    return scroll!;
  }

  testWidgets('runtime wheel and drag scroll and clamp to content', (
    tester,
  ) async {
    final scroll = await build(tester, true);
    expect(scroll.maxScrollExtent, 120);
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(80, 80),
        scrollDelta: Offset(0, 50),
      ),
    );
    await tester.pump();
    expect(scroll.offset, 50);
    await tester.dragFrom(const Offset(80, 90), const Offset(0, -80));
    await tester.pump();
    expect(scroll.offset, greaterThan(50));
    scroll.jumpBy(1000);
    expect(scroll.offset, 120);
    scroll.jumpBy(-1000);
    expect(scroll.offset, 0);
  });
  testWidgets('design canvas remains at rest', (tester) async {
    final scroll = await build(tester, false);
    scroll.jumpBy(100);
    await tester.dragFrom(const Offset(80, 90), const Offset(0, -60));
    expect(scroll.offset, 0);
  });
}
