import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const Color _static = Color(0xFF111111);

IconNode icon(Map<String, String> variables) => IconNode(
  id: 'icon',
  name: 'Icon',
  basicBoxLocal: NodeBox(0, 0, 24, 24),
  // A Cupertino icon paints from its font, without loading an SVG.
  icon: CupertinoIcon(name: 'battery_full', codepoint: 0xf113),
  color: _static.toColorRGBA(),
)..variables.addAll(variables);

Future<Icon> pumpIcon(WidgetTester tester, IconNode node) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Center(child: PassiveIconWidget(node: node)),
      ),
    ),
  );
  return tester.widget<Icon>(find.byType(Icon));
}

void main() {
  testWidgets('An icon paints the color its iconColor formula gives it', (
    WidgetTester tester,
  ) async {
    final Icon painted = await pumpIcon(
      tester,
      icon({'iconColor': r'${= 1 > 2 ? "#FBF8F3" : "#C8643B"}'}),
    );
    expect(painted.color?.toARGB32(), 0xFFC8643B);
  });

  testWidgets('An icon without a color binding keeps its static color', (
    WidgetTester tester,
  ) async {
    final Icon painted = await pumpIcon(tester, icon({}));
    expect(painted.color?.toARGB32(), _static.toARGB32());
  });
}
