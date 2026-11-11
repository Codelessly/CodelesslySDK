import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:codelessly_sdk_v2/src/render/layout/design_scroll.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Viewport extends SingleChildRenderObjectWidget {
  const _Viewport({required super.child, this.axis = Axis.vertical, this.reverse = false});
  final Axis axis;
  final bool reverse;
  @override
  RenderRuntimeScroll createRenderObject(BuildContext context) => RenderRuntimeScroll(axis: axis)..reverse = reverse;
}

void main() {
  testWidgets('scrolling node uses a live viewport only in interactive runtime', (tester) async {
    final tree = NodeTree(
      DocumentSource(
        LayoutDocument.fromJson({
          'roots': ['column'],
          'nodes': {
            'column': {
              'type': 'column',
              'layout': {'width': 200, 'height': 200},
              'props': {'scrollable': true},
              'children': ['content'],
            },
            'content': {
              'type': 'container',
              'layout': {'width': 200, 'height': 800},
            },
          },
        }),
      ),
    );
    addTearDown(tree.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: NodeView(tree: tree, rootId: 'column', interactive: true),
        ),
      ),
    );
    final found = <RenderRuntimeScroll>[];
    void visit(RenderObject object) {
      if (object is RenderRuntimeScroll) found.add(object);
      object.visitChildren(visit);
    }

    visit(tester.renderObject(find.byType(NodeView)));
    expect(found, hasLength(1));
    expect(found.single.maxScrollExtent, 600);
    found.single.jumpTo(300);
    await tester.pump();
    expect(found.single.pixels, 300);
  });

  testWidgets('runtime viewport drags, clamps, wheels and retains offset across layout', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(width: 200, height: 200, child: _Viewport(child: SizedBox(width: 200, height: 800))),
        ),
      ),
    );
    final viewport = tester.renderObject<RenderRuntimeScroll>(find.byType(_Viewport));
    expect(viewport.maxScrollExtent, 600);
    await tester.drag(find.byType(_Viewport), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(viewport.pixels, greaterThan(100));
    viewport.jumpTo(900);
    expect(viewport.pixels, 600);
    viewport.jumpTo(100);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.byType(_Viewport)));
    await tester.sendEventToBinding(
      PointerScrollEvent(position: tester.getCenter(find.byType(_Viewport)), scrollDelta: const Offset(0, 70)),
    );
    await tester.pump();
    expect(viewport.pixels, 170);
    viewport.userScrollable = false;
    await tester.sendEventToBinding(
      PointerScrollEvent(position: tester.getCenter(find.byType(_Viewport)), scrollDelta: const Offset(0, 70)),
    );
    await tester.pump();
    expect(viewport.pixels, 170);
    viewport.markNeedsLayout();
    await tester.pump();
    expect(viewport.pixels, 170);
    await mouse.removePointer();
  });

  testWidgets('horizontal reversed viewport paints the end at zero and scrolls back', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 200,
            height: 100,
            child: _Viewport(axis: Axis.horizontal, reverse: true, child: SizedBox(width: 700, height: 100)),
          ),
        ),
      ),
    );
    final viewport = tester.renderObject<RenderRuntimeScroll>(find.byType(_Viewport));
    final transform = Matrix4.identity();
    viewport.applyPaintTransform(viewport.child!, transform);
    expect(MatrixUtils.getAsTranslation(transform), const Offset(-500, 0));
    viewport.jumpTo(80);
    final next = Matrix4.identity();
    viewport.applyPaintTransform(viewport.child!, next);
    expect(MatrixUtils.getAsTranslation(next), const Offset(-420, 0));
    viewport.jumpTo(-10);
    expect(viewport.pixels, 0);
  });
}
