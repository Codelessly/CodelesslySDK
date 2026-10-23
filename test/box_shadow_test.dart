import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Shadows written as JSON (by the editor API or by hand) can leave out
  // spread, offset and color; building them used to throw on a null check.
  test('a drop shadow with only a radius builds', () {
    final RectangleNode node = RectangleNode(
      id: 'card',
      name: 'Card',
      basicBoxLocal: NodeBox(0, 0, 100, 100),
      effects: [
        Effect(id: 'shadow', type: EffectType.dropShadow, radius: 0),
        Effect(
          id: 'hard',
          type: EffectType.dropShadow,
          radius: 2,
          offset: const Vec(3, 3),
          color: ColorRGBA.black54,
        ),
      ],
    );
    final List<BoxShadow> shadows = retrieveBoxShadow(
      node,
      ScopedValues.empty(),
    );
    expect(shadows, hasLength(2));
    expect(shadows.first.spreadRadius, 0);
    expect(shadows.first.offset, Offset.zero);
    expect(shadows.first.color, const Color(0xFF000000));
    expect(shadows.last.offset, const Offset(3, 3));
    expect(shadows.last.blurRadius, 2);
  });
}
