import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/src/utils/flutter_icons_data_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MaterialIcon icon(String name, int codepoint, MaterialIconStyle style) =>
    MaterialIcon(codepoint: codepoint, name: name, style: style, version: 19);

void main() {
  test('catalog icons draw the Flutter glyph of their name and style', () {
    // The catalog stores Google's code point for close (0xe5cd), which is
    // snowboarding in Flutter's font.
    expect(
      flutterMaterialCodepoint(icon('close', 0xe5cd, MaterialIconStyle.rounded)),
      Icons.close_rounded.codePoint,
    );
    expect(
      flutterMaterialCodepoint(icon('close', 0xe5cd, MaterialIconStyle.filled)),
      Icons.close.codePoint,
    );
    expect(
      flutterMaterialCodepoint(icon('play_arrow', 0xe037, MaterialIconStyle.outlined)),
      Icons.play_arrow_outlined.codePoint,
    );
  });

  test('names Flutter renames (123 → onetwothree) still resolve', () {
    expect(
      flutterMaterialCodepoint(icon('123', 0xeb8d, MaterialIconStyle.filled)),
      Icons.onetwothree.codePoint,
    );
  });

  test('an icon Flutter does not ship falls back (null)', () {
    expect(
      flutterMaterialCodepoint(icon('no_such_icon', 1, MaterialIconStyle.filled)),
      isNull,
    );
  });
}
