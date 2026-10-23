import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const MultiSourceIconModel base = MultiSourceIconModel.icon(
    icon: MaterialIcon(
      codepoint: 0xe5e0,
      name: 'speed',
      style: MaterialIconStyle.filled,
    ),
  );

  test('a bound name picks the icon and its style', () {
    final MaterialIcon icon =
        iconWithName(base, 'kitchen_outlined').icon! as MaterialIcon;
    expect(icon.name, 'kitchen');
    expect(icon.style, MaterialIconStyle.outlined);
    expect(
      icon.toSvgUrl(),
      'https://fonts.gstatic.com/s/i/materialiconsoutlined/kitchen/v1/24px.svg',
    );

    final MaterialIcon filled = iconWithName(base, 'Air').icon! as MaterialIcon;
    expect(filled.name, 'air');
    expect(filled.style, MaterialIconStyle.filled);
    expect(
      (iconWithName(base, 'power_rounded').icon! as MaterialIcon).style,
      MaterialIconStyle.rounded,
    );
  });

  test('an empty or malformed name keeps the designed icon', () {
    expect(iconWithName(base, null), same(base));
    expect(iconWithName(base, '  '), same(base));
    expect(iconWithName(base, r'${item.icon}'), same(base));
  });
}
