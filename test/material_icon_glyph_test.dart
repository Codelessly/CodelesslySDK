import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/utils/material_icons_by_name.dart';
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
      const MaterialIcon(
        codepoint: 0xe01b,
        name: 'av_timer',
        style: MaterialIconStyle.filled,
        version: 12,
      ),
    );
    expect(data.codePoint, Icons.av_timer.codePoint);
  });

  testWidgets('styles pick their own glyph', (tester) async {
    final IconData data = await glyph(
      tester,
      const MaterialIcon(
        codepoint: 1,
        name: 'edit',
        style: MaterialIconStyle.outlined,
      ),
    );
    expect(data.codePoint, Icons.edit_outlined.codePoint);
  });

  test('names Flutter renames (123 → onetwothree) still resolve', () {
    expect(materialIconsByName['123'], Icons.onetwothree);
    expect(materialIconsByName['close_rounded'], Icons.close_rounded);
  });

  testWidgets('a Material Symbol Flutter ships draws its bundled glyph', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SvgIcon(
          icon: MaterialSymbol(
            codepoint: 0,
            fontFamily: 'MaterialSymbols',
            name: 'close',
            style: MaterialSymbolStyle.rounded,
          ),
        ),
      ),
    );
    final Icon drawn = tester.widget(find.byType(Icon));
    expect(drawn.icon!.codePoint, Icons.close_rounded.codePoint);
  });

  test('an unknown name has no font glyph (it is drawn from its SVG)', () {
    expect(materialIconsByName['no_such_icon'], isNull);
  });

  test('the SDK never builds a non-constant IconData', () {
    // Flutter's icon tree shaking rejects `IconData(...)` from runtime
    // values, which fails every release web build (the site's included).
    final RegExp call = RegExp(r'(?<!const )(?<![\w.])IconData\(');
    final List<String> offenders = [
      for (final File file in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart'))
          for (final (int i, String line) in file.readAsLinesSync().indexed)
            if (!line.trimLeft().startsWith('//') && call.hasMatch(line))
              '${file.path}:${i + 1}',
    ];
    expect(offenders, isEmpty);
  });
}
