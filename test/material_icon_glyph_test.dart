import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a Material Icon draws the glyph Flutter bundles under its name', () {
    // The catalog stores Google Fonts' codepoint (explore = 0xe87a), which
    // is another glyph in Flutter's MaterialIcons font.
    const explore = MaterialIcon(
      codepoint: 0xe87a,
      name: 'explore',
      style: MaterialIconStyle.rounded,
    );
    expect(
      materialIconFlutterCodepoint(explore),
      Icons.explore_rounded.codePoint,
    );
    expect(
      materialIconFlutterCodepoint(
        const MaterialIcon(
          codepoint: 0xe145,
          name: 'add',
          style: MaterialIconStyle.filled,
        ),
      ),
      Icons.add.codePoint,
    );
  });

  test('icons Flutter does not ship have no bundled glyph', () {
    expect(
      materialIconFlutterCodepoint(
        const MaterialIcon(
          codepoint: 1,
          name: 'no_such_icon',
          style: MaterialIconStyle.filled,
        ),
      ),
      isNull,
    );
    expect(
      materialIconFlutterCodepoint(
        MaterialSymbol(
          codepoint: 0,
          fontFamily: 'MaterialSymbols',
          name: 'explore',
          style: MaterialSymbolStyle.rounded,
        ),
      ),
      isNull,
    );
  });
}
