import 'package:codelessly_api/codelessly_api.dart';
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
    RectangleNode node(String url) => RectangleNode(
      id: 'r',
      name: 'r',
      basicBoxLocal: NodeBox(0, 0, 10, 10),
      fills: [PaintModel(id: 'f', type: PaintType.image, downloadUrl: url)],
    );
    expect(node(r'${fArt}').getUsedVariableNames(), {'fArt'});
    expect(
      node(r'${= editing ? record.art : fallback}').getUsedVariableNames(),
      {'editing', 'record', 'fallback'},
    );
    expect(node('https://x/y.jpg').getUsedVariableNames(), isEmpty);
  });
}
