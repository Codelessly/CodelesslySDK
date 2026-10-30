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

  testWidgets('Material icons draw Flutter\'s glyph for their name, not the web '
      'font codepoint', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SvgIcon(
          // 0xe8fd is help_outline in the Material Icons web font; in
          // Flutter's font it is another glyph.
          icon: MaterialIcon(
            codepoint: 0xe8fd,
            name: 'help_outline',
            style: MaterialIconStyle.filled,
            version: 12,
          ),
          size: 22,
        ),
      ),
    );
    final Icon drawn = tester.widget(find.byType(Icon));
    expect(drawn.icon!.codePoint, Icons.help_outline.codePoint);
    expect(drawn.icon!.fontFamily, 'MaterialIcons');
  });

  test('outlined and rounded icons map to Flutter\'s styled names', () {
    MaterialIcon of(String name, MaterialIconStyle style) =>
        MaterialIcon(codepoint: 1, name: name, style: style, version: 1);
    expect(flutterMaterialCodepoint(of('layers', MaterialIconStyle.outlined)),
        Icons.layers_outlined.codePoint);
    expect(flutterMaterialCodepoint(of('home', MaterialIconStyle.rounded)),
        Icons.home_rounded.codePoint);
    expect(flutterMaterialCodepoint(of('architecture', MaterialIconStyle.filled)),
        Icons.architecture.codePoint);
    expect(flutterMaterialCodepoint(of('home', MaterialIconStyle.twoTone)), isNull);
    expect(flutterMaterialCodepoint(of('no_such_icon_x', MaterialIconStyle.filled)), isNull);
  });
}
