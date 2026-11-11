import 'package:codelessly_sdk_v2/src/render/layout/design_scroll.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class Viewport extends SingleChildRenderObjectWidget {
  const Viewport({
    super.key,
    required super.child,
    this.interactive = true,
    this.reverse = false,
    this.axis = Axis.vertical,
  });
  final bool interactive, reverse;
  final Axis axis;
  @override
  RenderDesignScroll createRenderObject(BuildContext context) =>
      RenderDesignScroll(axis: axis)
        ..interactive = interactive
        ..reverse = reverse;
}

Widget scene({
  bool interactive = true,
  bool reverse = false,
  Axis axis = Axis.vertical,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: SizedBox(
      width: 200,
      height: 200,
      child: Viewport(
        interactive: interactive,
        reverse: reverse,
        axis: axis,
        child: SizedBox(
          width: axis == Axis.horizontal ? 800 : 200,
          height: axis == Axis.vertical ? 800 : 200,
        ),
      ),
    ),
  ),
);
void main() {
  testWidgets('wheel scrolling clamps and preserves hit-test transforms', (
    tester,
  ) async {
    await tester.pumpWidget(scene());
    final viewport = tester.renderObject<RenderDesignScroll>(
      find.byType(Viewport),
    );
    expect(viewport.maxScrollExtent, 600);
    final center = tester.getCenter(find.byType(Viewport));
    tester.binding.handlePointerEvent(
      PointerScrollEvent(position: center, scrollDelta: const Offset(0, 125)),
    );
    await tester.pump();
    expect(viewport.offset, 125);
    expect(viewport.child!.getTransformTo(viewport).getTranslation().y, -125);
    viewport.jumpTo(900);
    await tester.pump();
    expect(viewport.offset, 600);
    viewport.jumpTo(-20);
    await tester.pump();
    expect(viewport.offset, 0);
  });
  testWidgets('touch drag scrolls and design canvas remains at rest', (
    tester,
  ) async {
    await tester.pumpWidget(scene());
    final viewport = tester.renderObject<RenderDesignScroll>(
      find.byType(Viewport),
    );
    await tester.drag(find.byType(Viewport), const Offset(0, -100));
    await tester.pump();
    expect(viewport.offset, greaterThan(50));
    await tester.pumpWidget(scene(interactive: false));
    await tester.pump();
    // Recreate a different key to install the design viewport.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(scene(interactive: false));
    final design = tester.renderObject<RenderDesignScroll>(
      find.byType(Viewport),
    );
    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        position: tester.getCenter(find.byType(Viewport)),
        scrollDelta: const Offset(0, 100),
      ),
    );
    await tester.pump();
    expect(design.offset, 0);
  });
  testWidgets(
    'horizontal reversed viewport starts at end and scrolls backwards',
    (tester) async {
      await tester.pumpWidget(scene(reverse: true, axis: Axis.horizontal));
      final viewport = tester.renderObject<RenderDesignScroll>(
        find.byType(Viewport),
      );
      expect(viewport.child!.getTransformTo(viewport).getTranslation().x, -600);
      viewport.jumpTo(75);
      await tester.pump();
      expect(viewport.child!.getTransformTo(viewport).getTranslation().x, -525);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
