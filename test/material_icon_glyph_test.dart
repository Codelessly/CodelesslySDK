import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The editor saves Material icons with Google's codepoints; Flutter's
/// bundled font numbers them differently, so the SDK finds the glyph by name.
void main() {
  test(
    "a Material icon is drawn with Flutter's glyph for its name and style",
    () {
      MaterialIcon icon(
        String name,
        MaterialIconStyle style,
        int googleCodepoint,
      ) => MaterialIcon(name: name, codepoint: googleCodepoint, style: style);
      expect(
        flutterMaterialCodepoint(icon('add', MaterialIconStyle.filled, 0xe145)),
        Icons.add.codePoint,
      );
      expect(
        flutterMaterialCodepoint(
          icon('search', MaterialIconStyle.filled, 0xe8b6),
        ),
        Icons.search.codePoint,
      );
      expect(
        flutterMaterialCodepoint(
          icon('calendar_today', MaterialIconStyle.outlined, 0xe935),
        ),
        Icons.calendar_today_outlined.codePoint,
      );
      expect(
        flutterMaterialCodepoint(
          icon('no_such_icon_name', MaterialIconStyle.filled, 1),
        ),
        isNull,
      );
    },
  );
}
