import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an arc flight bows to the side and lands exactly', () {
    final tween = HeroArcRectTween(
      begin: const Rect.fromLTWH(0, 0, 20, 20),
      end: const Rect.fromLTWH(200, 0, 100, 100),
    );
    expect(tween.lerp(0), const Rect.fromLTWH(0, 0, 20, 20));
    expect(tween.lerp(1), const Rect.fromLTWH(200, 0, 100, 100));
    final Rect mid = tween.lerp(0.5)!;
    // A straight flight's centre would be at y = 30; the arc bows away.
    expect((mid.center.dy - 30).abs(), greaterThan(20));
    expect(mid.width, 60);
  });

  test('arc is a hero flight in node JSON', () {
    final RectangleNode node =
        RectangleNode(
            id: 'b',
            name: 'Ball',
            basicBoxLocal: NodeBox(0, 0, 10, 10),
          )
          ..heroTag = 'planet-jupiter'
          ..heroFlight = HeroFlight.arc;
    expect(RectangleNode.fromJson(node.toJson()).heroFlight, HeroFlight.arc);
  });
}
