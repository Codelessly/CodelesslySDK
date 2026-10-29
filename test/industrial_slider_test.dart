import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

SliderNode rule({
  double value = 75,
  Map<String, String> variables = const {},
  bool fillFromEnd = true,
}) => SliderNode(
  id: 'slider',
  name: 'Black tank limit',
  basicBoxLocal: NodeBox(0, 0, 300, 32),
  value: value,
  markerValue: 87,
  properties: SliderProperties(
    min: 0,
    max: 100,
    divisions: 20,
    isDiscrete: true,
    selectableMin: 5,
    selectableMax: 95,
    fillFromEnd: fillFromEnd,
    thumbShape: SliderThumbShapeEnum.rectangle,
    thumbBorderColor: ColorRGBA.black,
    thumbGripColor: ColorRGBA.black,
    tickMarkStyle: SliderTickMarkStyle.notch,
    notchEvery: 2,
    trackHeight: 6,
    trackShape: SliderTrackShapeEnum.rectangle,
  ),
)..variables.addAll(variables);

Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  ChangeNotifierProvider<CodelesslyContext>.value(
    value: CodelesslyContext.empty(),
    child: MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  ),
);

SliderThemeData theme(WidgetTester tester) =>
    tester.widget<SliderTheme>(find.byType(SliderTheme).last).data;

void main() {
  testWidgets('draws the fader thumb, notches, end fill and the marker', (
    tester,
  ) async {
    await pump(
      tester,
      PassiveSliderWidget(
        node: rule(),
        settings: const WidgetBuildSettings(debugLabel: 'test'),
      ),
    );
    expect(tester.takeException(), isNull);
    final SliderThemeData data = theme(tester);
    expect(data.thumbShape, isA<RectSliderThumbShape>());
    expect(data.tickMarkShape, isA<NotchSliderTickMarkShape>());
    final track = data.trackShape as IndustrialSliderTrackShape;
    expect(track.fillFromEnd, isTrue);
    expect(track.markerFraction, closeTo(0.87, 1e-9));
  });

  testWidgets('marker and active color follow their bindings', (tester) async {
    await pump(
      tester,
      PassiveSliderWidget(
        node: rule(
          variables: {
            'markerValue': r'${= 64}',
            'activeTrackColor': r'${= 64 > 50 ? "#FF4D4F" : "#F2C230"}',
          },
        ),
        settings: const WidgetBuildSettings(debugLabel: 'test'),
      ),
    );
    final SliderThemeData data = theme(tester);
    expect(
      (data.trackShape as IndustrialSliderTrackShape).markerFraction,
      closeTo(0.64, 1e-9),
    );
    expect(data.activeTrackColor!.toARGB32(), 0xFFFF4D4F);
  });

  testWidgets('the thumb stays in the selectable range and reports the end '
      'of a drag', (tester) async {
    final List<double> changes = [];
    final List<double> ends = [];
    await pump(
      tester,
      TransformerSlider(
        node: rule(value: 75),
        settings: const WidgetBuildSettings(debugLabel: 'test'),
        value: 75,
        onChanged: changes.add,
        onChangeEnd: ends.add,
      ),
    );
    final Slider slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 75);
    // Drag far past the left end: the value stops at 5, not 0.
    await tester.drag(find.byType(Slider), const Offset(-600, 0));
    await tester.pump();
    expect(changes, isNotEmpty);
    expect(changes.last, 5);
    expect(ends.single, 5);
  });

  testWidgets('a plain slider keeps the Material shapes', (tester) async {
    await pump(
      tester,
      PassiveSliderWidget(
        node: SliderNode(
          id: 's',
          name: 's',
          basicBoxLocal: NodeBox(0, 0, 300, 48),
          value: 50,
          properties: SliderProperties(),
        ),
        settings: const WidgetBuildSettings(debugLabel: 'test'),
      ),
    );
    final SliderThemeData data = theme(tester);
    expect(data.thumbShape, isA<RoundSliderThumbShape>());
    expect(data.trackShape, isA<RoundedRectSliderTrackShape>());
  });
}
