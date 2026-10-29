import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

TextNode text(Map<String, String> variables) => TextNode.fromJson({
  'id': 'text',
  'name': 'Label',
  'type': 'text',
  'basicBoxLocal': [0, 0, 120, 20],
  'characters': 'Mid zone',
  'textMixedProps': [
    {
      'start': 0,
      'end': 8,
      'fills': [
        {'id': 'f', 'type': 'solid', 'color': '#111111'},
      ],
    },
  ],
})..variables.addAll(variables);

TextNode reading(Map<String, String> variables) => TextNode(
  id: 'reading',
  name: 'Reading',
  basicBoxLocal: NodeBox(0, 0, 120, 30),
  characters: '87%',
  textMixedProps: [
    StartEndProp(
      start: 0,
      end: 3,
      fontSize: 20,
      fills: [PaintModel.solid(id: 'p', color: ColorRGB.fromHex('#E9EBEE'))],
    ),
  ],
)..variables.addAll(variables);

Future<List<Color?>> pumpText(WidgetTester tester, TextNode node) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Center(
          child: PassiveTextWidget(
            node: node,
            settings: const WidgetBuildSettings(debugLabel: 'test'),
          ),
        ),
      ),
    ),
  );
  final RichText rich = tester.widget<RichText>(find.byType(RichText).first);
  final List<Color?> colors = [];
  rich.text.visitChildren((span) {
    if (span is TextSpan && span.text != null) colors.add(span.style?.color);
    return true;
  });
  return colors;
}

Future<Color?> paintedColor(WidgetTester tester, TextNode node) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Center(
          child: Builder(
            builder: (context) => TextUtils.buildTextForTextNode(
              context,
              node,
              variablesOverrides: const [],
              nullSubstitutionMode: NullSubstitutionMode.emptyString,
              replaceVariablesWithSymbol: false,
            ),
          ),
        ),
      ),
    ),
  );
  final RichText rich = tester.widget<RichText>(find.byType(RichText));
  Color? color;
  rich.text.visitChildren((span) {
    if (span is TextSpan && span.text != null) {
      color = span.style?.color;
      return false;
    }
    return true;
  });
  return color;
}

void main() {
  testWidgets('A textColor formula recolors every span of a text', (
    WidgetTester tester,
  ) async {
    final colors = await pumpText(
      tester,
      text({'textColor': r'${= 1 < 2 ? "#F3ECDD" : "#1F2B2E"}'}),
    );
    expect(colors, isNotEmpty);
    for (final c in colors) {
      expect(c?.toARGB32(), 0xFFF3ECDD);
    }
  });

  testWidgets('A text without a textColor binding keeps its span colors', (
    WidgetTester tester,
  ) async {
    final colors = await pumpText(tester, text({}));
    expect(colors.single?.toARGB32(), isNot(0xFFF3ECDD));
  });

  testWidgets('a textColor formula recolors the text through TextUtils', (
    WidgetTester tester,
  ) async {
    final Color? color = await paintedColor(
      tester,
      reading({'textColor': r'${= 0.87 > 0.75 ? "#FF4D4F" : "#E9EBEE"}'}),
    );
    expect(color?.toARGB32(), 0xFFFF4D4F);
  });

  testWidgets('without a binding TextUtils keeps the fill', (
    WidgetTester tester,
  ) async {
    final Color? color = await paintedColor(tester, reading({}));
    expect(color?.toARGB32(), 0xFFE9EBEE);
  });
}
