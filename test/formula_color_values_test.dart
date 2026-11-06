import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

Object? eval(String expression, [Map<String, Object?> values = const {}]) =>
    FormulaEvaluator.evaluate(expression, (path) => values[path]);

void main() {
  final ColorRGBA lamp = ColorRGBA.fromHex('#FF8A2B')!;

  group('color functions take color values', () {
    test('mix, lerpColor, alpha and luminance read a ColorRGBA', () {
      final Map<String, Object?> values = {'lampColor': lamp};
      expect(eval("mix(lampColor, '#FFFFFF', 0)", values), '#FF8A2B');
      expect(eval("lerpColor('#000000', lampColor, 1)", values), '#FF8A2B');
      expect(eval('alpha(lampColor, 0.5)', values), '#80FF8A2B');
      expect(
        eval('luminance(lampColor)', values),
        eval("luminance('#FF8A2B')"),
      );
    });

    test('and a Flutter Color', () {
      expect(
        eval("mix(c, '#000000', 0)", {'c': const Color(0xFF1677FF)}),
        '#1677FF',
      );
      expect(
        eval('alpha(c)', {'c': const Color(0x801677FF)}),
        closeTo(0.502, 0.001),
      );
    });

    test('alpha takes #RGB too', () {
      expect(eval("alpha('#F00', 1)"), '#FFFF0000');
    });

    test('a color reads as hex in text', () {
      expect(FormulaEvaluator.stringify(lamp), '#FF8A2B');
      expect(
        FormulaEvaluator.stringify(lamp.copyWith(a: 0.5)),
        '#80FF8A2B',
      );
      expect(eval("'Color: ' + lampColor", {'lampColor': lamp}), 'Color: #FF8A2B');
    });

    test('a color variable reads as hex in a text binding', () {
      final ScopedValues values = ScopedValues.preview(
        variables: {
          'lampColor': VariableData(
            id: 'c',
            name: 'lampColor',
            type: VariableType.color,
            value: '#FF8A2B',
          ),
        },
      );
      expect(
        PropertyValueDelegate.substituteVariables(
          r'Lamp ${lampColor}, glow ${= alpha(lampColor, 0.3)}',
          scopedValues: values,
          nullSubstitutionMode: NullSubstitutionMode.emptyString,
        ),
        'Lamp #FF8A2B, glow #4DFF8A2B',
      );
    });
  });

  group('alpha with one argument', () {
    test('is the opacity, 0 to 1', () {
      expect(eval("alpha('#80FF0000')"), closeTo(0.502, 0.001));
      expect(eval("alpha('#FF0000')"), 1);
      expect(eval("alpha('#00FF0000')"), 0);
      expect(eval('alpha(c)', {'c': lamp.copyWith(a: 0.25)}), closeTo(0.25, 0.005));
      expect(eval("alpha('not a color')"), isNull);
    });

    test('the two-argument form still sets it', () {
      expect(eval("alpha('#FF4D4F', 0.12)"), '#1FFF4D4F');
    });
  });

  group('without', () {
    test('takes out a single value', () {
      expect(eval('without([0, 1, 2], 1)'), [0, 2]);
      expect(eval("without(['a', 'b'], 'a')"), ['b']);
    });

    test('takes out each value of a list', () {
      expect(eval('without([0, 1, 2, 3], [1, 3])'), [0, 2]);
    });

    test('without a second argument keeps the list', () {
      expect(eval('without([0, null, 2])'), [0, null, 2]);
    });
  });
}
