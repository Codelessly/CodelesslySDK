import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const ColorRGBA teal = ColorRGBA(r: 0.2, g: 0.6, b: 0.8, a: 1);

/// The stillpoint mixer slider: a 6dp track, a white 9dp knob with a
/// coloured centre and a soft glow, and an active track fading in.
SliderNode mixer({
  ColorRGBA? glow,
  double startOpacity = 1,
  Map<String, String> variables = const {},
}) => SliderNode(
  id: 'rain',
  name: 'Rain',
  basicBoxLocal: NodeBox(0, 0, 200, 40),
  value: 0.5,
  properties: SliderProperties(
    min: 0,
    max: 1,
    trackHeight: 6,
    thumbRadius: 9,
    thumbColor: teal,
    thumbStrokeColor: ColorRGBA.white,
    thumbStrokeWidth: 4,
    activeTrackColor: teal,
    inactiveTrackColor: const ColorRGBA(r: 1, g: 1, b: 1, a: 0.14),
    thumbGlowColor: glow,
    activeTrackStartOpacity: startOpacity,
  ),
)..variables.addAll(variables);

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  CodelesslyContext? codelessly,
}) => tester.pumpWidget(
  ChangeNotifierProvider<CodelesslyContext>.value(
    value: codelessly ?? CodelesslyContext.empty(),
    child: MaterialApp(
      home: Material(
        child: Center(child: SizedBox(width: 200, height: 40, child: child)),
      ),
    ),
  ),
);

SliderThemeData theme(WidgetTester tester) =>
    tester.widget<SliderTheme>(find.byType(SliderTheme).last).data;

/// Whether the slider draws a rounded rect with a gradient shader.
bool Function(Symbol, List<dynamic>) shaderSpy(List<bool> found) =>
    (Symbol method, List<dynamic> args) {
      if (method == #drawRRect && (args[1] as Paint).shader != null) {
        found.add(true);
      }
      return true;
    };

const WidgetBuildSettings runtime = WidgetBuildSettings(debugLabel: 'test');

void main() {
  testWidgets('by default there is no glow and the active track is solid', (
    tester,
  ) async {
    await pump(tester, PassiveSliderWidget(node: mixer(), settings: runtime));
    final SliderThemeData data = theme(tester);
    expect(data.thumbShape, isA<StrokedSliderThumbShape>());
    expect(data.thumbShape, isNot(isA<GlowSliderThumbShape>()));
    expect(data.trackShape, isA<RoundedRectSliderTrackShape>());
    expect(find.byType(Slider), isNot(paints..circle(hasMaskFilter: true)));
  });

  testWidgets('a glow colour paints a blurred circle behind the knob', (
    tester,
  ) async {
    const ColorRGBA glow = ColorRGBA(r: 0.2, g: 0.6, b: 0.8, a: 0.4);
    await pump(
      tester,
      PassiveSliderWidget(
        node: mixer(glow: glow),
        settings: runtime,
      ),
    );
    expect(tester.takeException(), isNull);
    final SliderComponentShape shape = theme(tester).thumbShape!;
    expect(shape, isA<GlowSliderThumbShape>());
    shape as GlowSliderThumbShape;
    expect(shape.color, glow.toFlutterColor());
    expect(shape.blur, kSliderDefaultThumbGlowBlur);
    expect(shape.spread, kSliderDefaultThumbGlowSpread);
    expect(shape.thumb, isA<StrokedSliderThumbShape>());
    // Glow (radius knob + 6, blurred) first, then the knob over it.
    expect(
      find.byType(Slider),
      paints
        ..circle(
          radius: 9 + kSliderDefaultThumbGlowSpread,
          color: glow.toFlutterColor(),
          hasMaskFilter: true,
        )
        ..circle(radius: 9, color: teal.toFlutterColor()),
    );
  });

  testWidgets('a hidden thumb draws no glow', (tester) async {
    final SliderNode node = mixer(glow: teal)..properties.showThumb = false;
    await pump(tester, PassiveSliderWidget(node: node, settings: runtime));
    expect(theme(tester).thumbShape, isNot(isA<GlowSliderThumbShape>()));
  });

  testWidgets('a start opacity below 1 fades the active track in', (
    tester,
  ) async {
    await pump(
      tester,
      PassiveSliderWidget(node: mixer(startOpacity: 0.5), settings: runtime),
    );
    final SliderTrackShape? track = theme(tester).trackShape;
    expect(track, isA<IndustrialSliderTrackShape>());
    expect((track! as IndustrialSliderTrackShape).activeStartOpacity, 0.5);
    final List<bool> found = [];
    expect(find.byType(Slider), paints..everything(shaderSpy(found)));
    expect(found, isNotEmpty, reason: 'the active track has a gradient');
  });

  testWidgets('a solid industrial track has no gradient', (tester) async {
    final SliderNode node = mixer()..properties.fillFromEnd = true;
    await pump(tester, PassiveSliderWidget(node: node, settings: runtime));
    expect(theme(tester).trackShape, isA<IndustrialSliderTrackShape>());
    final List<bool> found = [];
    expect(find.byType(Slider), paints..everything(shaderSpy(found)));
    expect(found, isEmpty);
  });

  group('colour bindings through node variables', () {
    late CodelesslyContext codelessly;
    setUp(() {
      codelessly = CodelesslyContext.empty()
        ..variables.addAll({
          for (final (String name, VariableType type, Object value)
              in <(String, VariableType, Object)>[
                ('accent', VariableType.color, '#FF5722'),
                ('glow', VariableType.color, '#4CAF50'),
                ('fade', VariableType.decimal, 0.25),
              ])
            name: Observable(
              VariableData(id: name, name: name, type: type, value: value),
            ),
        });
    });

    final Map<String, String> bindings = {
      'activeTrackColor': r'${accent}',
      'inactiveTrackColor': r'${glow}',
      'thumbColor': r'${accent}',
      'thumbGlowColor': r'${glow}',
      'activeTrackStartOpacity': r'${fade}',
    };
    final Color accent = ColorRGBA.fromHex('#FF5722')!.toFlutterColor();
    final Color glow = ColorRGBA.fromHex('#4CAF50')!.toFlutterColor();

    void expectBound(WidgetTester tester) {
      final SliderThemeData data = theme(tester);
      expect(data.activeTrackColor, accent);
      expect(data.inactiveTrackColor, glow);
      expect(data.thumbColor, accent);
      expect((data.thumbShape! as GlowSliderThumbShape).color, glow);
      expect(
        (data.trackShape! as IndustrialSliderTrackShape).activeStartOpacity,
        0.25,
      );
    }

    testWidgets('at runtime', (tester) async {
      await pump(
        tester,
        PassiveSliderWidget(
          node: mixer(variables: bindings),
          settings: runtime,
        ),
        codelessly: codelessly,
      );
      expectBound(tester);
    });

    testWidgets('on the design canvas (preview)', (tester) async {
      await pump(
        tester,
        PreviewSliderWidget(
          node: mixer(variables: bindings),
          settings: const WidgetBuildSettings(
            debugLabel: 'test',
            isPreview: true,
          ),
        ),
        codelessly: codelessly,
      );
      expectBound(tester);
    });

    testWidgets('a bound thumb colour also tints a derived overlay', (
      tester,
    ) async {
      await pump(
        tester,
        PassiveSliderWidget(
          node: mixer(variables: {'thumbColor': r'${accent}'}),
          settings: runtime,
        ),
        codelessly: codelessly,
      );
      expect(
        theme(tester).overlayColor,
        accent.withValues(alpha: kSliderDefaultOverlayOpacity),
      );
    });

    testWidgets('without bindings the stored colours show', (tester) async {
      await pump(
        tester,
        PassiveSliderWidget(node: mixer(), settings: runtime),
        codelessly: codelessly,
      );
      final SliderThemeData data = theme(tester);
      expect(data.thumbColor, teal.toFlutterColor());
      expect(data.activeTrackColor, teal.toFlutterColor());
    });
  });
}
