import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The editor stores the Material Icons font's codepoints (add is 0xE145);
  // Flutter's bundled font numbers its glyphs differently (Icons.add is
  // 0xE047), so the glyph has to be found by name and style.
  test('Material icons resolve to Flutter glyphs by name and style', () {
    const add = MaterialIcon(codepoint: 0xE145, name: 'add', style: MaterialIconStyle.filled);
    expect(flutterMaterialIconData(add)!.codePoint, Icons.add.codePoint);
    const home = MaterialIcon(codepoint: 0xE88A, name: 'home', style: MaterialIconStyle.outlined);
    expect(flutterMaterialIconData(home)!.codePoint, Icons.home_outlined.codePoint);
    const chevron = MaterialIcon(codepoint: 0xE5CB, name: 'chevron_left', style: MaterialIconStyle.rounded);
    expect(flutterMaterialIconData(chevron)!.codePoint, Icons.chevron_left_rounded.codePoint);
    expect(flutterMaterialIconData(chevron)!.fontFamily, 'MaterialIcons');
  });

  test('unknown glyphs and two-tone icons fall back to their SVG', () {
    expect(flutterMaterialIconData(const MaterialIcon(codepoint: 1, name: 'not_an_icon', style: MaterialIconStyle.filled)), isNull);
    expect(flutterMaterialIconData(const MaterialIcon(codepoint: 0xE145, name: 'add', style: MaterialIconStyle.twoTone)), isNull);
  });

  testWidgets('an icon node draws the Flutter glyph, not the stored codepoint', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SvgIcon(icon: MaterialIcon(codepoint: 0xE145, name: 'add', style: MaterialIconStyle.filled), size: 24),
    ));
    final Icon drawn = tester.widget<Icon>(find.byType(Icon));
    expect(drawn.icon!.codePoint, Icons.add.codePoint);
  });
}
