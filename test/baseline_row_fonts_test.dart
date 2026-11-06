import 'dart:io';
import 'dart:typed_data';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Lamplight's sidebar "43 watts": a 42 px serif number (Cormorant Garamond
// 500) and a 13 px sans unit (Inter 400) in a row with
// `crossAxisAlignment: baseline`, as the reference's
// `Row(crossAxisAlignment: CrossAxisAlignment.baseline)`. Two fonts with
// different ascents and descents still share one alphabetic baseline.

const String _fonts = '../references/lamplight/assets/fonts';

const FontName _serif = FontName(
  family: 'LampSerif',
  weight: FontWeightNumeric.w500,
);
const FontName _sans = FontName(
  family: 'LampSans',
  weight: FontWeightNumeric.w400,
);

Future<void> _load(FontName name, String file) async {
  final FontLoader loader = FontLoader(getFontFamilyNameAndVariant(name))
    ..addFont(
      Future<ByteData>.value(
        ByteData.sublistView(File('$_fonts/$file').readAsBytesSync()),
      ),
    );
  await loader.load();
}

TextNode _text(String id, String chars, double size, FontName font) =>
    TextNode(
      id: id,
      name: id,
      basicBoxLocal: NodeBox(0, 0, 60, size * 1.2),
      data: chars,
      horizontalFit: SizeFit.shrinkWrap,
      verticalFit: SizeFit.shrinkWrap,
      textMixedProps: [
        StartEndProp(
          start: 0,
          end: chars.length,
          fontSize: size,
          fontName: font,
        ),
      ],
    )..parentID = 'row';

void main() {
  final bool haveFonts = File('$_fonts/Inter-400.ttf').existsSync();

  setUpAll(() async {
    if (!haveFonts) return;
    await _load(_serif, 'CormorantGaramond-500.ttf');
    await _load(_sans, 'Inter-400.ttf');
  });

  testWidgets('a 42 px serif and a 13 px sans share a baseline', (
    tester,
  ) async {
    final big = _text('big', '43', 42, _serif);
    final small = _text('small', 'watts', 13, _sans);
    final row = RowColumnNode(
      id: 'row',
      name: 'Watts row',
      basicBoxLocal: NodeBox(0, 0, 120, 52),
      children: const ['big', 'small'],
      rowColumnType: RowColumnType.row,
      horizontalFit: SizeFit.shrinkWrap,
      verticalFit: SizeFit.shrinkWrap,
      spacing: 6,
      crossAxisAlignment: CrossAxisAlignmentC.baseline,
    )..parentID = kRootNode;
    final registry = NodeRegistry()
      ..setNodes({for (final n in <BaseNode>[row, big, small]) n.id: n});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  row,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    double baselineOf(String text) {
      final RenderBox box = tester.renderObject(find.text(text));
      RenderObject.debugCheckingIntrinsics = true;
      try {
        return box.localToGlobal(Offset.zero).dy +
            box.getDistanceToBaseline(TextBaseline.alphabetic)!;
      } finally {
        RenderObject.debugCheckingIntrinsics = false;
      }
    }

    final RichText number = tester.widget<RichText>(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == '43',
      ),
    );
    // The fonts are the ones loaded (not the test font): their tops differ
    // by more than the sizes alone would put them apart.
    final List<String?> families = [];
    number.text.visitChildren((InlineSpan span) {
      families.add(span.style?.fontFamily);
      return true;
    });
    families.add(number.text.style?.fontFamily);
    expect(families.whereType<String>().join(' '), contains('LampSerif'));
    expect(baselineOf('43'), closeTo(baselineOf('watts'), 0.5));
    // The unit isn't simply bottom- or top-aligned: its box ends above the
    // number's (Cormorant's descent is deeper than Inter's).
    final Rect numberBox = tester.getRect(find.text('43'));
    final Rect unitBox = tester.getRect(find.text('watts'));
    expect(unitBox.bottom, lessThan(numberBox.bottom - 2));
    expect(unitBox.top, greaterThan(numberBox.top + 10));
  }, skip: !haveFonts);
}
