import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a switch bound to a variable shows its preview value', (tester) async {
    final SwitchNode node = SwitchNode(
      id: 'sw',
      name: 'Guidance cues',
      basicBoxLocal: NodeBox(0, 0, 50, 30),
      value: false,
      properties: SwitchProperties(),
    )..variables['value'] = r'${cues}';
    final ScopedValues preview = ScopedValues.preview(
      variables: {
        'cues': VariableData(id: 'cues', name: 'cues', type: VariableType.boolean, value: true),
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: PassiveSwitchWidget(
            node: node,
            settings: const WidgetBuildSettings(debugLabel: 'test'),
            scopedValues: preview,
          ),
        ),
      ),
    );
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });
}
