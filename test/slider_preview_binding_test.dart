import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  for (final (String label, Object stored) in <(String, Object)>[
    ('a decimal stored as text', '0.7'),
    ('a decimal stored as a number', 0.7),
  ]) {
    testWidgets('a slider bound to $label shows that value', (tester) async {
      final SliderNode node = SliderNode(
        id: 'rain',
        name: 'Rain',
        basicBoxLocal: NodeBox(0, 0, 200, 28),
        value: 0,
        properties: SliderProperties(min: 0, max: 1),
      )..variables['value'] = r'${rain}';
      final ScopedValues preview = ScopedValues.preview(
        variables: {
          'rain': VariableData(
            id: 'rain',
            name: 'rain',
            type: VariableType.decimal,
            value: stored,
          ),
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: SizedBox(
              width: 200,
              height: 28,
              child: PassiveSliderWidget(
                node: node,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
                scopedValues: preview,
              ),
            ),
          ),
        ),
      );
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        closeTo(0.7, 1e-9),
      );
    });
  }

  group('design canvas (preview) inputs read their bindings', () {
    late CodelesslyContext codelessly;
    setUp(() {
      codelessly = CodelesslyContext.empty()
        ..variables.addAll({
          'rain': Observable(
            VariableData(
              id: 'rain',
              name: 'rain',
              type: VariableType.decimal,
              value: 0.7,
            ),
          ),
          'cues': Observable(
            VariableData(
              id: 'cues',
              name: 'cues',
              type: VariableType.boolean,
              value: true,
            ),
          ),
        });
    });

    Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelessly,
        child: MaterialApp(
          home: Material(child: SizedBox(width: 200, height: 40, child: child)),
        ),
      ),
    );

    const WidgetBuildSettings preview = WidgetBuildSettings(
      debugLabel: 'test',
      isPreview: true,
    );

    testWidgets('slider shows the bound value, min and max', (tester) async {
      final SliderNode node = SliderNode(
        id: 's',
        name: 'Rain',
        basicBoxLocal: NodeBox(0, 0, 200, 28),
        value: 0,
        properties: SliderProperties(min: 0, max: 1),
      )..variables['value'] = r'${rain}';
      await pump(tester, PreviewSliderWidget(node: node, settings: preview));
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        closeTo(0.7, 1e-9),
      );
    });

    testWidgets('a dragged preview slider holds until the binding changes', (
      tester,
    ) async {
      final SliderNode node = SliderNode(
        id: 's',
        name: 'Rain',
        basicBoxLocal: NodeBox(0, 0, 200, 28),
        value: 0,
        properties: SliderProperties(min: 0, max: 1),
      )..variables['value'] = r'${rain}';
      await pump(tester, PreviewSliderWidget(node: node, settings: preview));
      tester.widget<Slider>(find.byType(Slider)).onChanged!(0.2);
      await tester.pump();
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        closeTo(0.2, 1e-9),
      );
      codelessly.variables['rain']!.value = codelessly.variables['rain']!.value
          .copyWith(value: 0.4);
      await pump(tester, PreviewSliderWidget(node: node, settings: preview));
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        closeTo(0.4, 1e-9),
      );
    });

    testWidgets('switch and checkbox show the bound value', (tester) async {
      final SwitchNode sw = SwitchNode(
        id: 'sw',
        name: 'Cues',
        basicBoxLocal: NodeBox(0, 0, 50, 30),
        value: false,
        properties: SwitchProperties(),
      )..variables['value'] = r'${cues}';
      await pump(tester, PreviewSwitchWidget(node: sw, settings: preview));
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      final CheckboxNode box = CheckboxNode(
        id: 'cb',
        name: 'Cues',
        basicBoxLocal: NodeBox(0, 0, 24, 24),
        value: false,
        properties: CheckboxProperties(),
      )..variables['value'] = r'${cues}';
      await pump(tester, PreviewCheckboxWidget(node: box, settings: preview));
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    });
  });
}
