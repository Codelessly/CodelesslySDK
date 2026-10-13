import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  const settings = WidgetBuildSettings(debugLabel: 'test');

  testWidgets('radio renders inside a RadioGroup', (tester) async {
    final node = RadioNode(
      id: 'r',
      name: 'r',
      basicBoxLocal: NodeBox(0, 0, 40, 40),
      value: 'a',
      groupValue: 'b',
      properties: RadioProperties(
        innerRadius: 5,
        backgroundColor: ColorRGBA.white,
        side: const BorderSideModel(width: 2),
      ),
    );
    String? changed;
    await tester.pumpWidget(
      host(
        PassiveRadioWidget(
          node: node,
          onChanged: (_, v) => changed = v,
          settings: settings,
        ),
      ),
    );
    expect(find.byType(RadioGroup<String>), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(Radio<String>));
    expect(changed, 'a');
  });

  testWidgets('slider renders every shape and indicator mode', (tester) async {
    for (final track in SliderTrackShapeEnum.values) {
      for (final indicator in SliderValueIndicatorShape.values) {
        final node = SliderNode(
          id: 's',
          name: 's',
          basicBoxLocal: NodeBox(0, 0, 300, 48),
          value: 20,
          properties: SliderProperties(
            trackShape: track,
            valueIndicatorShape: indicator,
            showValueIndicator: ShowValueIndicatorC.alwaysVisible,
            secondaryTrackValue: 50,
            padding: const EdgeInsetsModel.all(4),
          ),
        );
        await tester.pumpWidget(
          host(
            TransformerSlider(
              node: node,
              value: 20,
              onChanged: (_) {},
              settings: settings,
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$track $indicator');
      }
    }
  });
}
