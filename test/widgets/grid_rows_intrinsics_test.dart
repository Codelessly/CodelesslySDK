// A grid whose rows hug their items (shrinkWrapRows: copies that grow
// across a row) measures each row by its items' intrinsic length; an item
// that cannot say one (a LayoutBuilder inside it: a component's reorderable
// list) is measured by its laid-out length instead. No exception reaches
// the writer (kanban, test 9: "LayoutBuilder does not support returning
// intrinsic dimensions" from a board's lanes written `grow`).
import 'package:codelessly_sdk/src/widgets/collections_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Grid extends MultiChildRenderObjectWidget {
  const _Grid({required super.children});

  @override
  RenderGridItems createRenderObject(BuildContext context) => RenderGridItems()
    ..crossAxisCount = 2
    ..crossAxisSpacing = 10
    ..itemCount = 2
    ..shrinkWrapRows = true
    ..hugMain = true;
}

void main() {
  testWidgets('a row of a hugging grid with an item that has no intrinsic size is as long as its longest item', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 210,
            child: _Grid(
              children: [
                LayoutBuilder(builder: (context, constraints) => const SizedBox(height: 50)),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final g = tester.renderObject<RenderGridItems>(find.byType(_Grid));
    expect(g.size.height, 50);
    expect(g.children.map((c) => c.size.height), everyElement(50));
  });
}
