import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// Lamplight sets its titles in Cormorant Garamond and its text in Inter with
// Flutter's default line height. The SDK's text came out taller (a 28 px
// title 37 px instead of 34, 15 px Inter 20 instead of 18): every style was
// merged over Material 3's bodySmall, whose `height: 1.33` stayed when the
// text's line height was auto.

const FontName _serif = FontName(
  family: 'Cormorant Garamond',
  weight: FontWeightNumeric.w600,
  style: 'SemiBold',
);
const FontName _sans = FontName(
  family: 'Inter',
  weight: FontWeightNumeric.w500,
  style: 'Medium',
);

TextNode _text(String data, FontName font, double size) => TextNode(
  id: 'text',
  name: 'Text',
  basicBoxLocal: NodeBox(0, 0, 10, 10),
  data: data,
  horizontalFit: SizeFit.shrinkWrap,
  verticalFit: SizeFit.shrinkWrap,
  textMixedProps: [
    StartEndProp(start: 0, end: data.length, fontSize: size, fontName: font),
  ],
)..parentID = kRootNode;

Widget _sdk(TextNode node) {
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  return ChangeNotifierProvider<CodelesslyContext>.value(
    value: CodelesslyContext.empty(),
    child: MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: Builder(
            builder: (context) => manager.buildWidgetFromNode(
              node,
              context,
              settings: const WidgetBuildSettings(debugLabel: 'test'),
            ),
          ),
        ),
      ),
    ),
  );
}

/// A plain Flutter `Text`, as the reference app writes it.
Widget _flutter(String data, String family, double size, FontWeight weight) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: const TextStyle(),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            data,
            style: TextStyle(
              fontFamily: family,
              fontSize: size,
              fontWeight: weight,
            ),
          ),
        ),
      ),
    );

Future<void> _load(String family, String file) async {
  final Uint8List bytes = File('test/fixtures/fonts/$file').readAsBytesSync();
  await (FontLoader(
    family,
  )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
}

void main() {
  late String serifFamily;
  late String sansFamily;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // The real fonts, under the family names the SDK's styles ask for.
    serifFamily = TextUtils.retrieveTextStyle(fontName: _serif).fontFamily!;
    sansFamily = TextUtils.retrieveTextStyle(fontName: _sans).fontFamily!;
    await _load(serifFamily, 'CormorantGaramond-600.ttf');
    await _load(sansFamily, 'Inter-500.ttf');
  });

  test('an auto line height leaves the font its own line height', () {
    final TextStyle style = TextUtils.retrieveTextStyle(
      fontSize: 28,
      fontName: _serif,
      lineHeight: LineHeight.auto,
      letterSpacing: LetterSpacing.zero,
    );
    expect(style.height, isNull);
    expect(style.letterSpacing, 0);
    expect(style.inherit, isFalse);
    expect(style.leadingDistribution, TextLeadingDistribution.proportional);
    expect(
      TextUtils.retrieveTextStyle(
        fontSize: 28,
        lineHeight: const LineHeight.percent(120),
      ).height,
      1.2,
    );
  });

  for (final (String label, String data, FontName font, double size) in [
    ('Cormorant Garamond 28', 'Good evening', _serif, 28),
    ('Cormorant Garamond 42', '7:42 PM', _serif, 42),
    ('Inter 15', 'e.g. Reading corner', _sans, 15),
    ('Inter 13', 'Dining nook', _sans, 13),
  ]) {
    testWidgets('$label: a text node is as large as Flutter\'s Text', (
      tester,
    ) async {
      final String family = font == _serif ? serifFamily : sansFamily;
      await tester.pumpWidget(
        _flutter(data, family, size, font.flutterFontWeight),
      );
      final Size reference = tester.getSize(find.text(data));
      // Cormorant's line is 1.211em (ascent 0.924, descent 0.287), Inter's
      // 1.21em: about 34 px for 28 px, not 28 * 1.33 = 37.
      expect(reference.height, closeTo(size * 1.21, 1));

      await tester.pumpWidget(_sdk(_text(data, font, size)));
      expect(tester.takeException(), isNull);
      final Size sdk = tester.getSize(find.text(data));
      expect(sdk.height, closeTo(reference.height, 0.01));
      expect(sdk.width, closeTo(reference.width, 0.01));
    });
  }
}
