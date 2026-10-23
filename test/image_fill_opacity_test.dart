import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // An image fill at 35% opacity painted at about 12%: the fill wrapped the
  // image in an Opacity and the network image applied the opacity again.
  testWidgets('an image fill applies its opacity once', (tester) async {
    final RectangleNode node = RectangleNode(
      id: 'paper',
      name: 'Paper',
      basicBoxLocal: NodeBox(0, 0, 100, 100),
      fills: [
        PaintModel(
          id: 'topo',
          type: PaintType.image,
          downloadUrl: 'https://example.com/topo.png',
          opacity: 0.35,
          fit: Fit.cover,
        ),
      ],
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: buildFill(
          node,
          index: 0,
          useInk: false,
          settings: const WidgetBuildSettings(debugLabel: 'test'),
          scopedValues: ScopedValues.empty(),
        ),
      ),
    );
    final double opacity = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .fold(1.0, (value, widget) => value * widget.opacity);
    final double imageOpacity = tester
        .widgetList<Image>(find.byType(Image))
        .fold(1.0, (value, widget) => value * (widget.opacity?.value ?? 1));
    expect(opacity * imageOpacity, closeTo(0.35, 0.001));
  });
}
