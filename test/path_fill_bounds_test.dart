import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A shape's path may reach past its box (the Alignments sextant's brass
/// band rises above its baseline); its fill covers the whole path.
void main() {
  RectangleNode shape(String path) => RectangleNode(
    id: 's',
    name: 'Band',
    basicBoxLocal: NodeBox(0, 0, 100, 40),
    fills: [PaintModel.solid(id: 'f', color: ColorRGB.fromHex('#C9A24B'))],
  )..path = path;

  test('a path inside its box fills the box', () {
    final List<Widget> out = clipFillsToNotches(
      shape('M0 10 L100 10 L100 40 L0 40 Z'),
      [const SizedBox()],
    );
    expect(out.single, isA<Positioned>());
    final Positioned p = out.single as Positioned;
    expect(p.top, 0);
    expect(p.width, isNull, reason: 'Positioned.fill');
  });

  test('a path above its box is filled over its bounds', () {
    final List<Widget> out = clipFillsToNotches(
      shape('M0 -20 L100 -20 L100 40 L0 40 Z'),
      [const SizedBox()],
    );
    final Positioned p = out.single as Positioned;
    expect(p.top, -20);
    expect(p.height, 60);
    final ClipPath clip = p.child as ClipPath;
    final SvgPathClipper clipper = clip.clipper as SvgPathClipper;
    expect(clipper.offset, const Offset(0, 20));
  });
}
