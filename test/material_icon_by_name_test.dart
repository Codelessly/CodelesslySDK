import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/utils/material_icons_by_name.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Icon models hold the codepoints of Google's Material Icons fonts (what
/// the editor's icon picker stores), which differ from those of Flutter's
/// MaterialIcons font. The glyph must be found by name and style, or every
/// icon draws another one (play_arrow, 0xe037, drew ac_unit).
void main() {
  Future<IconData?> glyphOf(WidgetTester tester, MaterialIcon icon) async {
    await tester.pumpWidget(
      MaterialApp(home: SvgIcon(icon: icon, size: 24, color: Colors.black)),
    );
    return tester.widget<Icon>(find.byType(Icon)).icon;
  }

  testWidgets('a picked icon draws its own glyph, not its codepoint\'s',
      (tester) async {
    const icon = MaterialIcon(
      codepoint: 0xe037, // play_arrow in Google's fonts, ac_unit in Flutter's
      name: 'play_arrow',
      style: MaterialIconStyle.filled,
      version: 16,
    );
    expect(await glyphOf(tester, icon), Icons.play_arrow);
  });

  testWidgets('styles pick the styled glyph', (tester) async {
    expect(
      await glyphOf(
        tester,
        const MaterialIcon(codepoint: 0xe037, name: 'play_arrow', style: MaterialIconStyle.rounded),
      ),
      Icons.play_arrow_rounded,
    );
    expect(
      await glyphOf(
        tester,
        const MaterialIcon(codepoint: 0, name: 'radio', style: MaterialIconStyle.outlined),
      ),
      Icons.radio_outlined,
    );
  });

  test('names Flutter spells differently map by Google name', () {
    expect(materialIconsByName['10k'], Icons.ten_k);
    expect(materialIconsByName['class'], Icons.class_);
    expect(materialIconsByName['3d_rotation_sharp'], Icons.threed_rotation_sharp);
  });
}
