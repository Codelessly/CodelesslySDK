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
}
