import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('textDecoration binds every span of a text', () {
    final node = TextNode.fromJson({
      'id': 't',
      'name': 't',
      'type': 'text',
      'basicBoxLocal': [0, 0, 40, 20],
      'data': 'Qxh7',
      'textMixedProps': [
        {'start': 0, 'end': 4, 'fontSize': 18},
      ],
    })..variables['textDecoration'] = r'${= true}';
    final patch = <String, dynamic>{};
    StyleBindings.addTo(patch, node, scopedValues: ScopedValues.empty());
    expect((patch['textMixedProps'] as List).single['textDecoration'], 'strikethrough');
  });

  test('decoration values are read by name or as a bool', () {
    expect(StyleBindings.parseTextDecoration('underline'), TextDecorationEnum.underline);
    expect(StyleBindings.parseTextDecoration('lineThrough'), TextDecorationEnum.strikethrough);
    expect(StyleBindings.parseTextDecoration(false), TextDecorationEnum.none);
    expect(StyleBindings.parseTextDecoration(3), isNull);
  });
}
