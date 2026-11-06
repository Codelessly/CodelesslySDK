import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'icon_binding_test.dart' as icons;

// A colour binding written as a plain colour (`"iconColor": "#7A4520"`)
// rather than a variable or a formula is that colour, as `${= '#7A4520'}`
// is: it was read as a variable path that names nothing and ignored.

RectangleNode _box(Map<String, String> variables) =>
    RectangleNode(id: 'box', name: 'box', basicBoxLocal: NodeBox(0, 0, 10, 10))
      ..variables.addAll(variables);

void main() {
  test('hex literals parse as colours', () {
    expect(
      PropertyValueDelegate.parseColorLiteral('#7A4520'),
      ColorRGBA.fromHex('#FF7A4520'),
    );
    expect(
      PropertyValueDelegate.parseColorLiteral(' #f0a '),
      ColorRGBA.fromHex('#FFFF00AA'),
    );
    expect(
      PropertyValueDelegate.parseColorLiteral('#807A4520'),
      ColorRGBA.fromHex('#807A4520'),
    );
    for (final String text in [
      '7A4520',
      '#7A452',
      '#GGGGGG',
      r'${pal.ink}',
      'pal.ink',
      '#7A4520 ',
    ]) {
      expect(
        PropertyValueDelegate.parseColorLiteral(text),
        text.trim() == '#7A4520' ? isNotNull : isNull,
        reason: text,
      );
    }
  });

  testWidgets('an icon colour bound to a literal paints that colour', (
    tester,
  ) async {
    final ScopedValues values = await icons.scope(tester);
    final IconNode icon = icons.star(null)..variables['iconColor'] = '#7A4520';
    expect(
      PassiveIconWidget.resolvedIcon(icon, values).color,
      ColorRGBA.fromHex('#7A4520'),
    );
  });

  testWidgets('fills, strokes and text colours take literals too', (
    tester,
  ) async {
    final ScopedValues values = await icons.scope(tester);
    final RectangleNode box = _box({
      'fill': '#F00',
      'stroke': '#4000FF00',
      'textColor': '#123456',
    });
    expect(
      PropertyValueDelegate.getPropertyValue<PaintModel>(
        box,
        'fill',
        scopedValues: values,
      )?.toFlutterColor()?.toARGB32(),
      0xFFFF0000,
    );
    final PaintModel? stroke =
        PropertyValueDelegate.getPropertyValue<PaintModel>(
          box,
          'stroke',
          scopedValues: values,
        );
    expect(stroke?.color, const ColorRGB(r: 0, g: 1, b: 0));
    expect(stroke?.opacity, closeTo(0x40 / 255, 1e-9));
    expect(
      PropertyValueDelegate.getPropertyValue<ColorRGBA>(
        box,
        'textColor',
        scopedValues: values,
      ),
      ColorRGBA.fromHex('#123456'),
    );
    // A literal never stands for anything but a colour.
    expect(
      PropertyValueDelegate.getPropertyValue<String>(
        _box({'data': '#123456'}),
        'data',
        scopedValues: values,
      ),
      isNull,
    );
    // A formula giving a colour still works, and a path that names nothing
    // still gives nothing.
    expect(
      PropertyValueDelegate.getPropertyValue<ColorRGBA>(
        _box({'textColor': r"${= '#00FF00'}"}),
        'textColor',
        scopedValues: values,
      ),
      ColorRGBA.fromHex('#00FF00'),
    );
    expect(
      PropertyValueDelegate.getPropertyValue<ColorRGBA>(
        _box({'textColor': r'${nothing.here}'}),
        'textColor',
        scopedValues: values,
      ),
      isNull,
    );
  });
}
