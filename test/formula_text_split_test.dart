import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a text splits into whole formulas and variables', () {
    const String text =
        r'Hi ${name}, ${= merge(r, {favorite: true}).favorite} and ${= 1 + 2}!';
    expect(
      variableSyntaxIdentifierRegex.allMatches(text).map((m) => m[0]).toList(),
      <String>[
        r'${name}',
        r'${= merge(r, {favorite: true}).favorite}',
        r'${= 1 + 2}',
      ],
    );
  });
}
