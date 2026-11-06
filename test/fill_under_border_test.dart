import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// A card's colour sits inside its border by half the border's inset, as
/// Flutter's BoxDecoration paints a background under a uniform border, so
/// the colour's rim doesn't show through the border's anti-aliased edge.
void main() {
  RectangleNode card(StrokeAlignC align, {StrokeSide side = StrokeSide.all}) =>
      RectangleNode(
        id: 'card',
        name: 'Card',
        basicBoxLocal: NodeBox(0, 0, 200, 120),
        fills: [PaintModel.solid(id: 'f', color: ColorRGB.fromHex('#FFFBF2'))],
        strokes: [PaintModel.solid(id: 's', color: ColorRGB.fromHex('#1F2A44'))],
        strokeWeight: 2.5,
        strokeAlign: align,
        strokeSide: side,
      );

  test('an inside border insets the fill by half its width', () {
    expect(fillInsetUnderBorder(card(StrokeAlignC.inside)), 1.25);
  });

  test('a centred border by a quarter, an outside one not at all', () {
    expect(fillInsetUnderBorder(card(StrokeAlignC.center)), 0.625);
    expect(fillInsetUnderBorder(card(StrokeAlignC.outside)), 0);
  });

  test('a border on one side leaves the fill alone', () {
    expect(
      fillInsetUnderBorder(card(StrokeAlignC.inside, side: StrokeSide.top)),
      0,
    );
  });

  test('no visible stroke, no inset', () {
    final RectangleNode plain = card(StrokeAlignC.inside)..strokes = [];
    expect(fillInsetUnderBorder(plain), 0);
  });
}
