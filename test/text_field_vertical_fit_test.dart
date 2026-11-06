import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// Lamplight's scene name input: Inter 15, dense, no content padding, no
// border. Hugging its height it came out 20 px (bodySmall's 1.33 line
// height) and taller under a Scaffold; in a fixed 52 px box with
// textAlignVertical center its line stayed at the top.

const InputBorderModel _none = InputBorderModel(
  borderType: BorderTypeEnum.none,
);
const FontName _inter = FontName(
  family: 'Inter',
  weight: FontWeightNumeric.w500,
  style: 'Medium',
);

TextFieldNode _field(
  SizeFit verticalFit, {
  double height = 52,
  TextAlignVerticalEnum align = TextAlignVerticalEnum.center,
  String? helperText,
}) => TextFieldNode(
  id: 'name',
  name: 'Name input',
  basicBoxLocal: NodeBox(0, 0, 300, height),
  horizontalFit: SizeFit.fixed,
  verticalFit: verticalFit,
  properties: TextFieldProperties(
    textAlignVertical: align,
    inputStyle: TextProp(fontSize: 15, fontName: _inter),
    decoration: InputDecorationModel(
      isDense: true,
      filled: false,
      hintText: 'e.g. Reading corner',
      hintStyle: TextProp(fontSize: 15, fontName: _inter),
      helperText: helperText,
      border: _none,
      enabledBorder: _none,
      focusedBorder: _none,
      disabledBorder: _none,
      errorBorder: _none,
      focusedErrorBorder: _none,
      contentPadding: EdgeInsetsModel.zero,
    ),
  ),
)..parentID = kRootNode;

Future<void> _pump(WidgetTester tester, TextFieldNode node) async {
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Builder(
                  builder: (context) => manager.buildWidgetFromNode(
                    node,
                    context,
                    settings: const WidgetBuildSettings(debugLabel: 'test'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Rect _hint(WidgetTester tester) =>
    tester.getRect(find.text('e.g. Reading corner'));

void main() {
  late String family;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    family = TextUtils.retrieveTextStyle(fontName: _inter).fontFamily!;
    final Uint8List bytes = File('test/fixtures/fonts/Inter-500.ttf')
        .readAsBytesSync();
    await (FontLoader(
      family,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });

  /// One line of Inter 15 as Flutter's Text sets it.
  Future<double> line(WidgetTester tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Text(
            'Ag',
            style: TextStyle(
              fontFamily: family,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
    return tester.getSize(find.text('Ag')).height;
  }

  testWidgets('a field that hugs its height is one line of its style tall', (
    tester,
  ) async {
    final double oneLine = await line(tester);
    expect(oneLine, closeTo(15 * 1.21, 1));
    // Its design height (12 px, as a solver measured it) doesn't cut it.
    await _pump(tester, _field(SizeFit.shrinkWrap, height: 12));
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(TextField)).height,
      closeTo(oneLine, 0.5),
    );
    expect(_hint(tester).height, closeTo(oneLine, 0.5));
    // On desktop (the web, the editor) the theme's compact density took
    // 8 px off the intrinsic height it hugs: 10 px for one line of 18.
  }, variant: TargetPlatformVariant.all());

  // The theme's compact density takes nothing off a dense field either: it
  // is its padding and its line tall (see text_field_hug_height_test.dart).
  testWidgets('a dense field is its padding and its line tall', (
    tester,
  ) async {
    final double oneLine = await line(tester);
    for (final (double padding, double height) in [
      (0, oneLine),
      (2, oneLine + 4),
      (6, oneLine + 12),
      (10, oneLine + 20),
    ]) {
      final TextFieldNode node = _field(SizeFit.shrinkWrap, height: 12);
      node.properties.decoration = node.properties.decoration.copyWith(
        contentPadding: EdgeInsetsModel.symmetric(vertical: padding),
      );
      await _pump(tester, node);
      expect(
        tester.getSize(find.byType(TextField)).height,
        closeTo(height, 0.5),
        reason: 'padding $padding',
      );
    }
  }, variant: TargetPlatformVariant.desktop());

  for (final (TextAlignVerticalEnum align, double share) in [
    (TextAlignVerticalEnum.top, 0),
    (TextAlignVerticalEnum.center, 0.5),
    (TextAlignVerticalEnum.bottom, 1),
  ]) {
    testWidgets('a fixed 52 px field puts its line at the ${align.name}', (
      tester,
    ) async {
      final double oneLine = await line(tester);
      await _pump(tester, _field(SizeFit.fixed, align: align));
      expect(tester.getSize(find.byType(TextField)).height, 52);
      expect(_hint(tester).top, closeTo((52 - oneLine) * share, 0.5));
      expect(
        tester.getRect(find.byType(EditableText)).top,
        closeTo((52 - oneLine) * share, 0.5),
      );
    });
  }

  testWidgets('a helper text keeps Flutter\'s own placement', (tester) async {
    await _pump(tester, _field(SizeFit.fixed, helperText: 'Required'));
    expect(_hint(tester).top, 0);
  });
}
