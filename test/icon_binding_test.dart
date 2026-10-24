import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_actions_test.dart' as harness;

/// A star icon whose glyph is bound to [glyph].
IconNode star(String? glyph) => IconNode(
  id: 'star',
  name: 'star',
  basicBoxLocal: NodeBox(0, 0, 24, 24),
  icon: const MaterialIcon(
    codepoint: 0xe838,
    name: 'star',
    style: MaterialIconStyle.filled,
    version: 22,
  ),
)..variables.addAll({'icon': ?glyph});

/// The scoped values of a pumped screen. (The icon itself isn't pumped: its
/// SVG would be fetched, and tests have no network.)
Future<ScopedValues> scope(WidgetTester tester) async {
  await harness.pumpLayouts(tester, [
    harness.layoutOf('main', [
      harness.canvas('main', 'mainBody'),
      harness.body('mainBody', 'main', ['box']),
      RectangleNode(
        id: 'box',
        name: 'box',
        basicBoxLocal: NodeBox(0, 0, 10, 10),
      )..parentID = 'mainBody',
    ]),
  ]);
  await tester.pumpAndSettle();
  return ScopedValues.of(
    tester.element(
      find.byKey(const ValueKey('Rectangle Transformer of box [box]')),
    ),
  );
}

void main() {
  testWidgets('a bound glyph name picks the icon and its version', (
    tester,
  ) async {
    final ScopedValues values = await scope(tester);
    final IconModel icon = PassiveIconWidget.resolvedIcon(
      star(r"${= 1 > 2 ? 'star' : 'star_border'}"),
      values,
    ).icon!;
    expect(icon.name, 'star_border');
    expect((icon as MaterialIcon).version, materialIconVersions['star_border']);
    expect(icon.style, MaterialIconStyle.filled);
    expect(icon.toSvgUrl(), contains('/materialicons/star_border/v'));
  });

  testWidgets('without a binding the icon keeps its glyph', (tester) async {
    final ScopedValues values = await scope(tester);
    expect(
      PassiveIconWidget.resolvedIcon(star(null), values).icon!.name,
      'star',
    );
  });

  test('named() keeps the icon for an empty name or a Cupertino icon', () {
    const material = MaterialIcon(
      codepoint: 0xe838,
      name: 'star',
      style: MaterialIconStyle.outlined,
      version: 22,
    );
    expect(material.named(''), same(material));
    expect(material.named(' Home ').name, 'home');
    expect(
      (material.named('home') as MaterialIcon).style,
      MaterialIconStyle.outlined,
    );
    // An unknown name keeps the icon's own version.
    expect((material.named('not_an_icon') as MaterialIcon).version, 22);
    final cupertino = CupertinoIcon(name: 'battery_full', codepoint: 0xf113);
    expect(cupertino.named('star'), same(cupertino));
  });
}
