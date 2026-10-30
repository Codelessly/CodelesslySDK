import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('glyphs come from Flutter\'s font by name and style', () {
    // Google's catalog codepoint for pause (0xe034) is `9k` in Flutter's font.
    expect(
      flutterIconCodepoint(
        const MaterialIcon(codepoint: 0xe034, name: 'pause', style: MaterialIconStyle.filled),
      ),
      Icons.pause.codePoint,
    );
    expect(
      flutterIconCodepoint(
        const MaterialIcon(codepoint: 0xe897, name: 'lock', style: MaterialIconStyle.rounded),
      ),
      Icons.lock_rounded.codePoint,
    );
    expect(
      flutterIconCodepoint(
        const MaterialIcon(codepoint: 1, name: 'home', style: MaterialIconStyle.outlined),
      ),
      Icons.home_outlined.codePoint,
    );
    expect(
      flutterIconCodepoint(
        const MaterialIcon(codepoint: 1, name: 'not_an_icon', style: MaterialIconStyle.filled),
      ),
      isNull,
    );
  });

  testWidgets('an icon draws Flutter\'s glyph for its name', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SvgIcon(
          icon: MaterialIcon(codepoint: 0xe034, name: 'pause', style: MaterialIconStyle.rounded),
        ),
      ),
    );
    final Icon drawn = tester.widget<Icon>(find.byType(Icon));
    expect(drawn.icon!.codePoint, Icons.pause_rounded.codePoint);
    expect(drawn.icon!.fontFamily, 'MaterialIcons');
  });
}
