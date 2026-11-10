
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Map<String, Object?> vars = {
    'art': 'a.jpg',
    'sleeves': ['k.jpg', 'w.jpg'],
  };
  Object? eval(String expression) =>
      FormulaEvaluator.evaluate(expression, (path) => vars[path]);

  test('lists join with concat and +', () {
    expect(eval('concat([art], sleeves)'), ['a.jpg', 'k.jpg', 'w.jpg']);
    expect(eval('concat(art, sleeves, null)'), ['a.jpg', 'k.jpg', 'w.jpg']);
    expect(eval('[art] + sleeves'), ['a.jpg', 'k.jpg', 'w.jpg']);
    expect(eval('"a" + 1'), 'a1');
    expect(eval('1 + 2'), 3);
  });

  test('an image fill bound to a variable or formula is listened to', () {
    Set<String> reads(String url) => Expressions.readsOf(url).map(rootOf).toSet();
    expect(reads(r'${fArt}'), {'fArt'});
    expect(reads(r'${= editing ? record.art : fallback}'), {'editing', 'record', 'fallback'});
    expect(reads('https://x/y.jpg'), isEmpty);
  });
}
