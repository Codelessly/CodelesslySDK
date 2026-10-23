import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// Applies a 4x5 color matrix to an RGB color (alpha 1).
List<double> apply(List<double> m, List<double> rgb) => [
  for (int row = 0; row < 3; row++)
    m[row * 5] * rgb[0] + m[row * 5 + 1] * rgb[1] + m[row * 5 + 2] * rgb[2],
];

void main() {
  test('saturation 0 turns colors into grey of the same luminance', () {
    final grey = apply(saturationMatrix(0), [1, 0, 0]);
    for (final channel in grey) {
      expect(channel, closeTo(0.2126, 1e-9));
    }
    final white = apply(saturationMatrix(0), [1, 1, 1]);
    for (final channel in white) {
      expect(channel, closeTo(1, 1e-9));
    }
  });

  test('saturation 1 keeps colors', () {
    expect(apply(saturationMatrix(1), [0.2, 0.5, 0.9]), [0.2, 0.5, 0.9]);
  });
}
