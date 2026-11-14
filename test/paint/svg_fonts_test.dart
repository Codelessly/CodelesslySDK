// The families an SVG's text names, resolved as a text node's are.
import 'package:codelessly_sdk/src/render/convert.dart' show FontDemand;
import 'package:codelessly_sdk/src/render/paint/svg_fonts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => FontDemand.handler = null);

  test('generic families become the site font and named ones keep it as their fallback', () {
    final out = SvgFonts.resolve(
      '<svg><text font-family="sans-serif">a</text><text font-family="\'DejaVu Sans\', monospace">b</text>'
      '<text style="font-family: Inter; font-size: 12px">c</text></svg>',
      defaultFamily: 'Lora',
    );
    expect(out, contains('<text font-family="Lora">a'));
    expect(out, contains('<text font-family="DejaVu Sans, Lora">b'));
    expect(out, contains('font-family: Inter, Lora; font-size'));
  });

  test('text naming no family inherits the site font from the root', () {
    expect(SvgFonts.resolve('<svg width="4"><text>a</text></svg>', defaultFamily: 'Lora'),
        '<svg width="4" font-family="Lora"><text>a</text></svg>');
    expect(SvgFonts.resolve('<svg font-family="serif"><text>a</text></svg>', defaultFamily: 'Lora'),
        '<svg font-family="Lora"><text>a</text></svg>');
  });

  test('named families are asked for at the weights the SVG uses, once each', () {
    final asked = <String>[];
    FontDemand.handler = (family, weight, italic) => asked.add('$family $weight');
    SvgFonts.resolve('<svg><text font-family="Brand Sans" font-weight="bold">a</text><text font-family="Brand Sans">b</text></svg>',
        defaultFamily: 'Lora');
    expect(asked, ['Brand Sans 700']);
  });

  test('an SVG without text is left as it is, and without a site font generic families stay for the platform', () {
    const plain = '<svg><rect width="2" height="2"/></svg>';
    expect(identical(SvgFonts.resolve(plain, defaultFamily: 'Lora'), plain), isTrue);
    expect(SvgFonts.resolve('<svg><text font-family="serif">a</text></svg>'), '<svg><text font-family="serif">a</text></svg>');
  });
}
