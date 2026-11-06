import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// A bound image (the Orrery's play / pause icon) must rebuild when the
/// variables in its URL change, not only when something else rebuilds it.
void main() {
  test('an image fill URL template is listened to', () {
    final RectangleNode icon = RectangleNode(
      id: 'icon',
      name: 'Icon',
      basicBoxLocal: NodeBox(0, 0, 20, 20),
      fills: [
        PaintModel(
          id: 'img',
          type: PaintType.image,
          downloadUrl: r"${= playing ? 'https://x/pause.png' : 'https://x/play.png'}",
        ),
      ],
    );
    final List<String> templates = inlineTextTemplatesOf(icon);
    expect(templates.any((t) => t.contains('playing')), isTrue);
    expect(FormulaEvaluator.referencedPathsInText(templates.first), contains('playing'));
  });
}
