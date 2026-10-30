import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// A halo: a radial gradient from a color at 35% to transparent.
RectangleNode halo(Map<String, String> variables) => RectangleNode.fromJson({
  ...RectangleNode(
    id: 'halo',
    name: 'Halo',
    basicBoxLocal: NodeBox(0, 0, 200, 200),
    fills: [
      PaintModel.fromJson({
        'id': 'g',
        'type': 'gradientRadial',
        'gradientTransform': [1, 0, 0, 0, 1, 0],
        'gradientStops': [
          {
            'position': 0,
            'color': {'r': 0.49, 'g': 0.89, 'b': 0.85, 'a': 0.35},
          },
          {
            'position': 1,
            'color': {'r': 0.49, 'g': 0.89, 'b': 0.85, 'a': 0},
          },
        ],
      }),
    ],
  ).toJson(),
  'variables': variables,
});

Object? formula(String expression) =>
    FormulaEvaluator.evaluate(expression, (_) => null);

void main() {
  group('mix', () {
    test('blends two colors', () {
      expect(formula("mix('#7DE3D8', '#FFFFFF', 0.35)"), '#ABEDE6');
      expect(formula("mix('#000000', '#FFFFFF', 0.5)"), '#808080');
      expect(formula("mix('#000', '#FFF', 0)"), '#000000');
      expect(formula("mix('#7DE3D8', '#B9A8F5', 1)"), '#B9A8F5');
    });

    test('keeps alpha and clamps t', () {
      expect(formula("mix('#00FFFFFF', '#FFFFFFFF', 0.5)"), '#80FFFFFF');
      expect(formula("mix('#000000', '#FFFFFF', 2)"), '#FFFFFF');
      expect(formula("mix('nope', '#FFFFFF', 0.5)"), isNull);
    });
  });

  group('fill-stop bindings', () {
    Map<String, dynamic> patchOf(RectangleNode node) {
      final Map<String, dynamic> patch = {};
      StyleBindings.addTo(patch, node, scopedValues: ScopedValues.empty());
      return patch;
    }

    test('a #RRGGBB stop color follows the binding and keeps its alpha', () {
      final patch = patchOf(
        halo({StyleBindings.fillStop(0): r"${= '#F7B79B'}"}),
      );
      final PaintModel fill = PaintModel.fromJson(patch['fills'][0]);
      final ColorRGBA c = fill.gradientStops![0].color;
      expect(c.toFlutterColor().toARGB32() & 0xFFFFFF, 0xF7B79B);
      expect(c.a, closeTo(0.35, 0.005));
      expect(fill.gradientStops![1].color.a, 0, reason: 'unbound stops stay');
    });

    test('#AARRGGBB sets the alpha too', () {
      final patch = patchOf(
        halo({StyleBindings.fillStop(1): r"${= '#80FFFFFF'}"}),
      );
      final PaintModel fill = PaintModel.fromJson(patch['fills'][0]);
      expect(fill.gradientStops![1].color.a, closeTo(128 / 255, 1e-3));
    });

    test('no binding, no change', () {
      expect(patchOf(halo({})), isEmpty);
    });
  });
}
