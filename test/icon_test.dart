import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Material icon URLs', () {
    MaterialIcon icon(MaterialIconStyle style) => MaterialIcon(
      codepoint: 0xe88a,
      fontFamily: 'MaterialIcons',
      name: 'home',
      style: style,
      version: 16,
    );

    test('use the style in the path', () {
      expect(
        icon(MaterialIconStyle.outlined).toSvgUrl(),
        'https://fonts.gstatic.com/s/i/materialiconsoutlined/home/v16/24px.svg',
      );
      expect(
        icon(MaterialIconStyle.filled).toSvgUrl(),
        'https://fonts.gstatic.com/s/i/materialicons/home/v16/24px.svg',
      );
    });

    test('two-tone has no space in the path', () {
      expect(
        icon(MaterialIconStyle.twoTone).toSvgUrl(),
        'https://fonts.gstatic.com/s/i/materialiconstwotone/home/v16/24px.svg',
      );
    });
  });

  group('Material Symbol URLs', () {
    final symbol = MaterialSymbol(
      codepoint: 0xe88a,
      fontFamily: 'MaterialSymbolsRounded',
      name: 'home',
      style: MaterialSymbolStyle.rounded,
    );

    test('default axes', () {
      expect(
        symbol.toSvgUrl(),
        'https://fonts.gstatic.com/s/i/short-term/release/'
        'materialsymbolsrounded/home/default/24px.svg',
      );
    });

    test('axes are snapped to the prebuilt variants', () {
      expect(
        symbol.toSvgUrl(fill: 1, weight: 680, grade: -20, opticalSize: 46),
        'https://fonts.gstatic.com/s/i/short-term/release/'
        'materialsymbolsrounded/home/wght700gradN25fill1/48px.svg',
      );
    });

    test('variant names', () {
      expect(materialSymbolVariant(), 'default');
      expect(materialSymbolVariant(weight: 400, grade: 0, fill: 0), 'default');
      expect(materialSymbolVariant(weight: 100), 'wght100');
      expect(materialSymbolVariant(grade: 150), 'grad200');
      expect(materialSymbolVariant(fill: 0.6), 'fill1');
      expect(
        materialSymbolVariant(weight: 300, grade: -25, fill: 1),
        'wght300gradN25fill1',
      );
    });
  });

  testWidgets('Cupertino icons render from the cupertino_icons font', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SvgIcon(
          icon: CupertinoIcon(
            codepoint: CupertinoIcons.heart.codePoint,
            name: 'heart',
          ),
          size: 30,
        ),
      ),
    );
    final Icon icon = tester.widget(find.byType(Icon));
    expect(icon.icon, CupertinoIcons.heart);
    expect(icon.size, 30);
  });

  testWidgets('Icons without a source render an empty box', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SvgIcon(
            icon: CupertinoIcon(codepoint: 0x1, name: 'unknown'),
            size: 20,
          ),
        ),
      ),
    );
    expect(find.byType(Icon), findsNothing);
    expect(tester.getSize(find.byType(SizedBox).last), const Size(20, 20));
  });

  test('rounded Material icons load the Round SVG by name', () {
    // The editor stores Google's codepoint (0xe8b6 is search there); the
    // icon is drawn from its SVG by name, never from Flutter's font, where
    // that number is another glyph (and a runtime IconData breaks release
    // builds).
    expect(
      const MaterialIcon(
        codepoint: 0xe8b6,
        fontFamily: 'MaterialIcons',
        name: 'search',
        style: MaterialIconStyle.rounded,
        version: 17,
      ).toSvgUrl(),
      'https://fonts.gstatic.com/s/i/materialiconsround/search/v17/24px.svg',
    );
  });
}
