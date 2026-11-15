// The families an SVG's text names, resolved as a text node's are.
import 'package:codelessly_sdk/src/render/convert.dart' show FontDemand;
import 'package:codelessly_sdk/src/render/paint/svg_fonts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => FontDemand.handler = null);

  test('generic families become the site font; a named one is drawn, or the site font when it is lacking', () {
    const svg = '<svg><text font-family="sans-serif">a</text><text font-family="\'DejaVu Sans\', monospace">b</text>'
        '<text style="font-family: Inter; font-size: 12px">c</text></svg>';
    // One family each: vector_graphics reads the attribute as a single family
    // name, so a list ("DejaVu Sans, Lora") would name a font nothing has.
    final out = SvgFonts.resolve(svg, defaultFamily: 'Lora');
    expect(out, contains('<text font-family="Lora">a'));
    expect(out, contains('<text font-family="DejaVu Sans">b'));
    expect(out, contains('font-family: Inter; font-size'));
    // A caller that knows its fonts: a family it lacks falls to the next one
    // the list names (monospace: the site font), but is still reported.
    final reported = <String>[];
    SvgFonts.isAvailable = (family) => family == 'Inter';
    SvgFonts.onFamily = (family, _) => reported.add(family);
    addTearDown(() {
      SvgFonts.isAvailable = null;
      SvgFonts.onFamily = null;
    });
    final known = SvgFonts.resolve(svg, defaultFamily: 'Lora');
    expect(known, contains('<text font-family="Lora">b'));
    expect(known, contains('font-family: Inter; font-size'));
    expect(reported, ['DejaVu Sans', 'Inter']);
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
