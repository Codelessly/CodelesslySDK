import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// An image fill's tint draws a one-ink image (a postmark ring) in another
/// ink, keeping its transparency.
void main() {
  PaintModel fill({ColorRGBA? tint}) => PaintModel.image(
    id: 'img',
    downloadUrl: 'https://example.com/postmark.png',
    fit: Fit.contain,
    sourceWidth: 360,
    sourceHeight: 360,
    imageTint: tint,
  );

  test('a tint is kept through JSON', () {
    final PaintModel tinted = fill(tint: ColorRGBA.fromHex('#FFFBF2'));
    final PaintModel back = PaintModel.fromJson(tinted.toJson());
    expect(back.imageTint, tinted.imageTint);
    expect(fill().toJson().containsKey('imageTint'), isFalse);
  });

  test('the image is drawn through a srcIn color filter in the tint', () {
    const Widget image = SizedBox(width: 10, height: 10);
    expect(tintImage(fill(), image), same(image));
    final Widget tinted = tintImage(fill(tint: ColorRGBA.fromHex('#C8332B')), image);
    expect(tinted, isA<ColorFiltered>());
    expect(
      (tinted as ColorFiltered).colorFilter,
      const ColorFilter.mode(Color(0xFFC8332B), BlendMode.srcIn),
    );
  });

  // A hugging card with an airmail tile behind its text grows with the
  // text; the tile has to cover all of it, not stay at the image's size.
  test('an image fill covers a hugging node with children', () {
    RowColumnNode card({List<String> children = const []}) => RowColumnNode(
      id: 'card',
      name: 'card',
      basicBoxLocal: NodeBox(0, 0, 300, 120),
      rowColumnType: RowColumnType.column,
      horizontalFit: SizeFit.shrinkWrap,
      verticalFit: SizeFit.shrinkWrap,
      children: children,
      fills: [fill()],
    );
    const Widget tile = SizedBox();
    final Widget withContent = wrapFillWithPositioned(
      node: card(children: ['text']),
      fill: tile,
      paint: fill(),
    );
    expect(withContent, isA<Positioned>());
    final Positioned covering = withContent as Positioned;
    expect([covering.left, covering.top, covering.right, covering.bottom], [
      0,
      0,
      0,
      0,
    ]);
    // Without content, the image gives the node its size.
    final Positioned sized =
        wrapFillWithPositioned(node: card(), fill: tile, paint: fill())
            as Positioned;
    expect(sized.left, isNull);
  });
}
