import 'dart:io';
import 'dart:typed_data';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A family name GoogleFonts doesn't know, so the SDK uses it as it is and
/// the test loads DM Serif Display (ascent 1.036em, descent 0.335em) under it.
const FontName _serif = FontName(
  family: 'Leading Test Serif',
  weight: FontWeightNumeric.w400,
  style: 'Regular',
);

TextNode _title(double fontSize, double percent) => TextNode(
  id: 'title',
  name: 'title',
  basicBoxLocal: NodeBox(0, 0, 300, fontSize * percent / 100),
  data: 'Settings',
  horizontalFit: SizeFit.shrinkWrap,
  verticalFit: SizeFit.shrinkWrap,
  textMixedProps: [
    StartEndProp(
      start: 0,
      end: 8,
      fontSize: fontSize,
      fontName: _serif,
      lineHeight: LineHeight.percent(percent),
    ),
  ],
)..parentID = kRootNode;

/// The distance from the top of the text's box to its alphabetic baseline.
double _baselineIn(WidgetTester tester, Finder text) {
  final RenderBox box = tester.renderObject(text);
  RenderObject.debugCheckingIntrinsics = true;
  try {
    return box.getDistanceToBaseline(TextBaseline.alphabetic)!;
  } finally {
    RenderObject.debugCheckingIntrinsics = false;
  }
}

Widget _sdkText(TextNode node, {required bool material}) {
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  final Widget text = Builder(
    builder: (context) => manager.buildWidgetFromNode(
      node,
      context,
      settings: const WidgetBuildSettings(debugLabel: 'test'),
    ),
  );
  return ChangeNotifierProvider<CodelesslyContext>.value(
    value: CodelesslyContext.empty(),
    child: MaterialApp(
      // A Scaffold's Material sets an M3 default text style whose leading is
      // distributed evenly; without one, the text style is the plain one.
      home: material
          ? Scaffold(body: Align(alignment: Alignment.topLeft, child: text))
          : DefaultTextStyle(
              style: const TextStyle(),
              child: Align(alignment: Alignment.topLeft, child: text),
            ),
    ),
  );
}

void main() {
  late String family;

  setUpAll(() async {
    family = TextUtils.retrieveTextStyle(fontName: _serif).fontFamily!;
    final bytes = File(
      'test/fixtures/fonts/DMSerifDisplay-400.ttf',
    ).readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  });

  test('the SDK text style keeps Flutter\'s proportional leading', () {
    final style = TextUtils.retrieveTextStyle(
      fontSize: 40,
      fontName: _serif,
      lineHeight: const LineHeight.percent(105),
    );
    expect(style.height, 1.05);
    expect(style.leadingDistribution, TextLeadingDistribution.proportional);
  });

  for (final (double size, double percent) in [(40, 105), (22, 105), (56, 100)]) {
    testWidgets(
      'a ${size.toInt()}px text at $percent% line height sits on the '
      'baseline of TextStyle(height: ${percent / 100})',
      (tester) async {
        // The Flutter reference: a Text with a height and no other leading
        // setting, as a code-built app writes it.
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: DefaultTextStyle(
              style: const TextStyle(),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  'Settings',
                  style: TextStyle(
                    fontFamily: family,
                    fontSize: size,
                    height: percent / 100,
                  ),
                ),
              ),
            ),
          ),
        );
        final double reference = _baselineIn(tester, find.text('Settings'));
        final double referenceHeight = tester
            .getSize(find.text('Settings'))
            .height;
        // DM Serif Display's own metrics, distributed proportionally: the
        // ascent's share of the line.
        expect(
          reference,
          closeTo(size * percent / 100 * 1.036 / (1.036 + 0.335), 0.5),
        );

        for (final material in [false, true]) {
          await tester.pumpWidget(
            _sdkText(_title(size, percent), material: material),
          );
          expect(tester.takeException(), isNull);
          final Finder sdk = find.text('Settings');
          expect(
            _baselineIn(tester, sdk),
            closeTo(reference, 0.01),
            reason: material ? 'inside a Scaffold' : 'without Material',
          );
          expect(tester.getSize(sdk).height, closeTo(referenceHeight, 0.01));
        }
      },
    );
  }
}
