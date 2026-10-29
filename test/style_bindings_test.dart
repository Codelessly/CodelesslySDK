import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A chip-like rectangle whose hard shadow is hidden until it is selected.
RectangleNode chip(Map<String, String> variables) => RectangleNode.fromJson({
  ...RectangleNode(
    id: 'chip',
    name: 'Chip',
    basicBoxLocal: NodeBox(0, 0, 80, 32),
    fills: [PaintModel.solid(id: 'fill', color: ColorRGB.fromHex('#FBF8F3'))],
    strokes: [
      PaintModel.solid(id: 'stroke', color: ColorRGB.fromHex('#2B2420')),
    ],
    strokeWeight: 1,
    cornerRadius: const CornerRadius.all(RadiusModel.circular(4)),
    effects: [
      Effect.dropShadow(
        id: 'shadow',
        visible: false,
        radius: 6,
        color: ColorRGBA.black,
        offset: const Vec(0, 4),
        spread: 0,
      ),
    ],
  ).toJson(),
  'variables': variables,
})..parentID = kRootNode;

Observable<VariableData> boolVariable(String name, bool value) => Observable(
  VariableData(id: name, name: name, type: VariableType.boolean, value: value),
);

class Host {
  Host(this.node, {Map<String, Observable<VariableData>> variables = const {}})
    : context = CodelesslyContext.empty()..variables.addAll(variables) {
    registry.setNodes({node.id: node});
    manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
  }

  final BaseNode node;
  final CodelesslyContext context;
  final NodeRegistry registry = NodeRegistry();
  late final PassiveNodeTransformerManager manager;

  late WidgetTester _tester;

  /// The node as its bindings style it now, after [pump].
  BaseNode get styled => manager.applyStyleOverrides(
    _tester.element(find.byKey(const Key('host'))),
    node,
  );

  /// Pumps the node's widget, or only a host to read [styled] in when
  /// [build] is false (an icon loads its SVG from the network).
  Future<void> pump(WidgetTester tester, {bool build = true}) async {
    _tester = tester;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: context,
        child: MaterialApp(
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: Builder(
                key: const Key('host'),
                builder: (context) => build
                    ? manager.buildWidgetFromNode(
                        node,
                        context,
                        settings: const WidgetBuildSettings(debugLabel: 'test'),
                      )
                    : const SizedBox(),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  }
}

List<BoxShadow> shadows(WidgetTester tester) => tester.allWidgets
    .whereType<Container>()
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .expand((d) => d.boxShadow ?? const <BoxShadow>[])
    .toList();

Border? border(WidgetTester tester) => tester.allWidgets
    .whereType<DecoratedBox>()
    .map((box) => box.decoration)
    .whereType<BoxDecoration>()
    .map((d) => d.border)
    .whereType<Border>()
    .firstOrNull;

void main() {
  group('effects', () {
    testWidgets('effectsVisible shows a hidden shadow, and the shadow takes '
        'the color, offset and blur bound to it', (tester) async {
      final selected = boolVariable('selected', false);
      final host = Host(
        chip({
          'effectsVisible': r'${= selected}',
          'effectsColor': r"${= selected ? '#2B2420' : '#000000'}",
          'effectsOffsetX': r'${= selected ? 2 : 0}',
          'effectsOffsetY': r'${= selected ? 2 : 0}',
          'effectsBlur': r'${= selected ? 0 : 6}',
        }),
        variables: {'selected': selected},
      );
      await host.pump(tester);
      expect(shadows(tester), isEmpty);

      selected.set(selected.value.copyWith(value: true));
      await tester.pump();

      final List<BoxShadow> painted = shadows(tester);
      expect(painted, hasLength(1));
      expect(painted.single.color.toARGB32(), 0xFF2B2420);
      expect(painted.single.offset, const Offset(2, 2));
      expect(painted.single.blurRadius, 0);
      // The node itself is unchanged.
      expect((host.node as RectangleNode).effects.single.visible, isFalse);
      expect(
        (host.node as RectangleNode).effects.single.offset,
        const Vec(0, 4),
      );
    });

    testWidgets('effect-visible-<id> and shadow-color-<id> win over the '
        'node-wide bindings', (tester) async {
      final host = Host(
        chip({
          'effectsVisible': r'${= false}',
          'effect-visible-shadow': r'${= true}',
          'effectsColor': r"${= '#FF0000'}",
          'shadow-color-shadow': r"${= '#00FF00'}",
        }),
      );
      await host.pump(tester);
      final List<BoxShadow> painted = shadows(tester);
      expect(painted, hasLength(1));
      expect(painted.single.color.toARGB32(), 0xFF00FF00);
      // Unbound values stay.
      expect(painted.single.offset, const Offset(0, 4));
      expect(painted.single.blurRadius, 6);
    });

    testWidgets('effectsVisible hides a visible shadow', (tester) async {
      final RectangleNode node = chip({'effectsVisible': r'${= 1 > 2}'});
      node.effects = [node.effects.single.copyWith(visible: true)];
      final host = Host(node);
      await host.pump(tester);
      expect(shadows(tester), isEmpty);
    });

    testWidgets('A node without effect bindings is not restyled', (
      tester,
    ) async {
      final host = Host(chip({}));
      await host.pump(tester);
      expect(identical(host.styled, host.node), isTrue);
    });
  });

  testWidgets('strokeWeight follows its formula', (tester) async {
    final selected = boolVariable('selected', false);
    final host = Host(
      chip({'strokeWeight': r'${= selected ? 3 : 1}'}),
      variables: {'selected': selected},
    );
    await host.pump(tester);
    expect(border(tester)?.top.width, 1);

    selected.set(selected.value.copyWith(value: true));
    await tester.pump();
    expect(border(tester)?.top.width, 3);
    expect((host.node as RectangleNode).strokeWeight, 1);
  });

  testWidgets('cornerRadius follows its formula', (tester) async {
    final host = Host(chip({'cornerRadius': r'${= 8 * 2}'}));
    await host.pump(tester);
    final BorderRadius? radius = tester.allWidgets
        .whereType<Container>()
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.borderRadius)
        .whereType<BorderRadius>()
        .firstOrNull;
    expect(radius, BorderRadius.circular(16));
    expect(
      (host.styled as RectangleNode).cornerRadius,
      const CornerRadius.all(RadiusModel.circular(16), linked: true),
    );
  });

  group('text', () {
    TextNode text(Map<String, String> variables) => TextNode.fromJson({
      ...TextNode(
        id: 'text',
        name: 'Text',
        basicBoxLocal: NodeBox(0, 0, 100, 20),
        data: 'Oat',
        textMixedProps: [
          StartEndProp(
            start: 0,
            end: 3,
            fills: [
              PaintModel.solid(
                id: 'text-fill',
                color: ColorRGB.fromHex('#111111'),
              ),
            ],
            fontName: FontName.robotoRegular,
          ),
        ],
      ).toJson(),
      'variables': variables,
    })..parentID = kRootNode;

    testWidgets('fontWeight and fill both follow their formulas', (
      tester,
    ) async {
      final selected = boolVariable('selected', false);
      final host = Host(
        text({
          'fontWeight': r'${= selected ? 700 : 400}',
          'fill': r"${= selected ? '#C8643B' : '#111111'}",
        }),
        variables: {'selected': selected},
      );
      await host.pump(tester);
      expect(
        (host.styled as TextNode).textMixedProps.single.fontName.weight,
        FontWeightNumeric.w400,
      );

      selected.set(selected.value.copyWith(value: true));
      await tester.pump();
      final StartEndProp span = (host.styled as TextNode).textMixedProps.single;
      expect(span.fontName.weight, FontWeightNumeric.w700);
      expect(span.fontName.family, 'Roboto');
      expect(span.fills.single.color, ColorRGB.fromHex('#C8643B'));

      final List<FontWeight?> weights = [];
      for (final RichText text in tester.widgetList<RichText>(
        find.byType(RichText),
      )) {
        text.text.visitChildren((span) {
          weights.add(span.style?.fontWeight);
          return true;
        });
      }
      expect(weights, contains(FontWeight.w700));
      expect(weights, isNot(contains(FontWeight.w400)));
    });

    test('parseFontWeight reads numbers, wNNN and names', () {
      expect(StyleBindings.parseFontWeight(700), FontWeightNumeric.w700);
      expect(StyleBindings.parseFontWeight(650.0), FontWeightNumeric.w700);
      expect(StyleBindings.parseFontWeight('400'), FontWeightNumeric.w400);
      expect(StyleBindings.parseFontWeight('w600'), FontWeightNumeric.w600);
      expect(StyleBindings.parseFontWeight('Bold'), FontWeightNumeric.w700);
      expect(
        StyleBindings.parseFontWeight('semi-bold'),
        FontWeightNumeric.w600,
      );
      expect(StyleBindings.parseFontWeight(1200), FontWeightNumeric.w900);
      expect(StyleBindings.parseFontWeight('heavyish'), isNull);
      expect(StyleBindings.parseFontWeight(null), isNull);
    });
  });

  group('icon', () {
    IconNode icon(IconModel model, Map<String, String> variables) =>
        IconNode(
            id: 'icon',
            name: 'Icon',
            basicBoxLocal: NodeBox(0, 0, 24, 24),
            icon: model,
          )
          ..variables.addAll(variables)
          ..parentID = kRootNode;

    testWidgets('A Material icon shows the icon name its formula gives', (
      tester,
    ) async {
      final selected = boolVariable('selected', false);
      final host = Host(
        icon(
          const MaterialIcon(
            name: 'star_border',
            codepoint: 0xe83a,
            style: MaterialIconStyle.filled,
            version: 19,
          ),
          {'icon': r"${= selected ? 'star' : 'star_border'}"},
        ),
        variables: {'selected': selected},
      );
      await host.pump(tester, build: false);
      expect(identical(host.styled, host.node), isTrue);

      selected.set(selected.value.copyWith(value: true));
      await tester.pump();
      final IconNode styled = host.styled as IconNode;
      final MaterialIcon shown = styled.properties.icon.icon! as MaterialIcon;
      expect(shown.name, 'star');
      expect(shown.style, MaterialIconStyle.filled);
      expect(shown.version, 1);
      expect(
        shown.toSvgUrl(),
        'https://fonts.gstatic.com/s/i/materialicons/star/v1/24px.svg',
      );
      expect((host.node as IconNode).properties.icon.icon!.name, 'star_border');
    });

    testWidgets('A Material Symbol keeps its style when renamed', (
      tester,
    ) async {
      final host = Host(
        icon(
          MaterialSymbol(
            name: 'favorite',
            codepoint: 0xe87d,
            fontFamily: 'MaterialSymbolsRounded',
            style: MaterialSymbolStyle.rounded,
          ),
          {'icon': r"${= 'home'}"},
        ),
      );
      await host.pump(tester, build: false);
      final MaterialSymbol shown =
          (host.styled as IconNode).properties.icon.icon! as MaterialSymbol;
      expect(shown.name, 'home');
      expect(shown.style, MaterialSymbolStyle.rounded);
    });
  });
}
