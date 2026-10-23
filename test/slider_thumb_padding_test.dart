import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SliderNode slider(Map<String, dynamic> properties, {double width = 300}) =>
    SliderNode.fromJson({
      'id': 'slider',
      'name': 'slider',
      'type': 'slider',
      'basicBoxLocal': [0, 0, width, 48],
      'value': 0,
      'properties': properties,
    })..parentID = kRootNode;

/// Pumps [node] and returns the value a tap at [dx] picks.
Future<double> valueAt(WidgetTester tester, SliderNode node, double dx) async {
  final values = <double>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        child: Align(
          alignment: Alignment.topLeft,
          child: TransformerSlider(
            node: node,
            settings: const WidgetBuildSettings(debugLabel: 'test'),
            onChanged: values.add,
            value: 0,
          ),
        ),
      ),
    ),
  );
  await tester.tapAt(Offset(dx, 24));
  await tester.pump();
  return values.last;
}

void main() {
  group('Slider padding', () {
    testWidgets('Without padding, the track is inset for the thumb overlay', (
      tester,
    ) async {
      final SliderNode node = slider({});
      expect(node.properties.padding, isNull);
      // The track starts 24px in (the overlay radius) and spans 252px.
      expect(await valueAt(tester, node, 24 + 126), closeTo(50, 0.5));
    });

    testWidgets('padding: 0 runs the track edge to edge', (tester) async {
      final SliderNode node = slider({'padding': 0});
      expect(node.properties.padding, EdgeInsetsModel.zero);
      expect(node.toJson()['properties'], {'padding': 0});
      expect(await valueAt(tester, node, 150), closeTo(50, 0.5));
      expect(await valueAt(tester, node, 75), closeTo(25, 0.5));
    });

    testWidgets('Set padding insets the track by that much', (tester) async {
      final SliderNode node = slider({
        'padding': [10, 0],
      });
      // 10px each side: the track is 280px wide.
      expect(await valueAt(tester, node, 10 + 70), closeTo(25, 0.5));
    });
  });

  group('Slider thumb shape', () {
    testWidgets('A round thumb is the default', (tester) async {
      final SliderNode node = slider({});
      expect(node.properties.thumbShape, SliderThumbShapeEnum.circle);
      await valueAt(tester, node, 150);
      final SliderTheme theme = tester.widget(find.byType(SliderTheme).last);
      expect(theme.data.thumbShape, isA<StrokedSliderThumbShape>());
    });

    testWidgets('A rounded rectangle thumb has its width and height', (
      tester,
    ) async {
      final SliderNode node = slider({
        'thumbShape': 'roundedRect',
        'thumbWidth': 12,
        'thumbHeight': 30,
        'thumbCornerRadius': 3,
        'thumbStrokeColor': ColorRGBA.white.toJson(),
        'thumbStrokeWidth': 1,
      });
      expect(SliderNode.fromJson(node.toJson()).properties, node.properties);
      await valueAt(tester, node, 150);
      final SliderTheme theme = tester.widget(find.byType(SliderTheme).last);
      final shape = theme.data.thumbShape as RoundedRectSliderThumbShape;
      expect(shape.size, const Size(12, 30));
      expect(shape.cornerRadius, 3);
      expect(shape.strokeWidth, 1);
      expect(shape.strokeColor, Colors.white);
      expect(tester.takeException(), isNull);
    });

    testWidgets('A vertical slider swaps the thumb into its own layout', (
      tester,
    ) async {
      final SliderNode node = SliderNode.fromJson({
        'id': 'fader',
        'name': 'fader',
        'type': 'slider',
        'basicBoxLocal': [0, 0, 48, 300],
        'value': 0,
        'properties': {
          'orientation': 'vertical',
          'thumbShape': 'roundedRect',
          'thumbWidth': 40,
          'thumbHeight': 16,
          'padding': [8, 0],
        },
      })..parentID = kRootNode;
      final values = <double>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: TransformerSlider(
                node: node,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
                onChanged: values.add,
                value: 50,
              ),
            ),
          ),
        ),
      );
      final SliderTheme theme = tester.widget(find.byType(SliderTheme).last);
      final shape = theme.data.thumbShape as RoundedRectSliderThumbShape;
      // Along the (turned) track first: the cap is 40 wide and 16 tall on
      // screen.
      expect(shape.size, const Size(16, 40));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Hiding the thumb hides a rectangular one too', (tester) async {
      final SliderNode node = slider({
        'thumbShape': 'roundedRect',
        'showThumb': false,
      });
      await valueAt(tester, node, 150);
      final SliderTheme theme = tester.widget(find.byType(SliderTheme).last);
      final shape = theme.data.thumbShape as RoundedRectSliderThumbShape;
      expect(shape.size, Size.zero);
    });
  });
}
