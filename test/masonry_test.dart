import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codelessly_sdk/src/widgets/collections_layout.dart';

class Grid extends MultiChildRenderObjectWidget {
  const Grid({super.key, required super.children});
  @override
  RenderGridItems createRenderObject(BuildContext context) => RenderGridItems()
    ..crossAxisCount = 2
    ..masonry = true
    ..crossAxisSpacing = 10
    ..mainAxisSpacing = 12
    ..itemCount = 4
    ..hugMain = true;
}

void main() {
  testWidgets(
    'masonry keeps natural extents and advances each lane independently',
    (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 210,
              child: Grid(
                children: [
                  SizedBox(height: 40),
                  SizedBox(height: 90),
                  SizedBox(height: 60),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      );
      final g = tester.renderObject<RenderGridItems>(find.byType(Grid));
      final list = g.children;
      expect(list.map((x) => x.size.height).toList(), [40, 90, 60, 20]);
      expect(
        (list[2].parentData as CollectionParentData).offset,
        const Offset(0, 52),
      );
      expect(
        (list[3].parentData as CollectionParentData).offset,
        const Offset(110, 102),
      );
      expect(g.size.height, 122);
    },
  );
}
