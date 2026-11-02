import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Icons placed from the editor's catalog carry Google's web font
/// codepoints, which number the glyphs differently from Flutter's bundled
/// MaterialIcons font; the glyph is looked up by name.
void main() {
  Future<IconData> glyph(WidgetTester tester, MaterialIcon icon) async {
    await tester.pumpWidget(MaterialApp(home: SvgIcon(icon: icon, size: 24)));
    return tester.widget<Icon>(find.byType(Icon)).icon!;
  }

  testWidgets('a catalog codepoint draws the icon of its name', (tester) async {
    final IconData data = await glyph(
      tester,
      const MaterialIcon(codepoint: 0xe01b, name: 'av_timer', style: MaterialIconStyle.filled, version: 12),
    );
    expect(data.codePoint, Icons.av_timer.codePoint);
  });

  testWidgets('styles pick their own glyph', (tester) async {
    final IconData data = await glyph(
      tester,
      const MaterialIcon(codepoint: 1, name: 'edit', style: MaterialIconStyle.outlined),
    );
    expect(data.codePoint, Icons.edit_outlined.codePoint);
  });

  testWidgets('an unknown name keeps its stored codepoint', (tester) async {
    final IconData data = await glyph(
      tester,
      const MaterialIcon(codepoint: 0xe123, name: 'no_such_icon', style: MaterialIconStyle.filled),
    );
    expect(data.codePoint, 0xe123);
  });
}
