import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('an expanded dropdown shows its value across the field, '
      'whatever its design width', (tester) async {
    const String spot = 'Fitzgerald';
    // Laid out at 300 wide, stored with a narrower design box.
    final node = DropdownNode(
      id: 'spot',
      name: 'Spot',
      basicBoxLocal: NodeBox(0, 0, 90, 44),
      value: spot,
      properties: DropdownProperties(
        items: const [spot, 'Point Pinos'],
        isExpanded: true,
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                height: 44,
                child: PassiveDropdownWidget(
                  node: node,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final Size text = tester.getSize(find.text(spot).first);
    final TextPainter full = TextPainter(
      text: TextSpan(
        text: spot,
        style: tester.widget<Text>(find.text(spot).first).style,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(text.width, greaterThanOrEqualTo(full.width - 0.5));
  });
}
