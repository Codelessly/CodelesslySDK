import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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
  testWidgets('a textColor formula recolors the text', (tester) async {
    final Color? color = await paintedColor(
      tester,
      reading({'textColor': r'${= 0.87 > 0.75 ? "#FF4D4F" : "#E9EBEE"}'}),
    );
    expect(color?.toARGB32(), 0xFFFF4D4F);
  });

  testWidgets('without a binding the text keeps its fill', (tester) async {
    final Color? color = await paintedColor(tester, reading({}));
    expect(color?.toARGB32(), 0xFFE9EBEE);
  });
}
