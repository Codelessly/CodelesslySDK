import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// A node's `transitionMs` eases its bound text and icon colors as it eases
// a solid fill: a palette shifting from dusk to night recolors labels and
// icons over 900 ms. Under muted tickers (the design canvas) they jump.

const Color dusk = Color(0xFF2A211B);
const Color night = Color(0xFFE9E2D6);

String hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

Observable<VariableData> ink(Color color) => Observable(
  VariableData(
    id: 'ink',
    name: 'ink',
    type: VariableType.text,
    value: hex(color),
  ),
);

TextNode label({int transitionMs = 900, String binding = 'textColor'}) =>
    TextNode(
        id: 'label',
        name: 'Label',
        basicBoxLocal: NodeBox(0, 0, 120, 20),
        data: 'Living room',
        textMixedProps: [
          StartEndProp(
            start: 0,
            end: 11,
            fontSize: 14,
            fills: [
              PaintModel.solid(id: 'p', color: ColorRGB.fromHex('#111111')),
            ],
          ),
        ],
      )
      ..variables[binding] = r'${ink}'
      ..transitionMs = transitionMs;

IconNode glyph({int transitionMs = 900}) =>
    IconNode(
        id: 'icon',
        name: 'Icon',
        basicBoxLocal: NodeBox(0, 0, 24, 24),
        // No icon source: an empty box, nothing loaded from the network.
        icon: CupertinoIcon(name: 'unknown', codepoint: 0),
        color: const Color(0xFF111111).toColorRGBA(),
      )
      ..variables['iconColor'] = r'${ink}'
      ..transitionMs = transitionMs;

Future<void> host(
  WidgetTester tester,
  CodelesslyContext context,
  Widget child, {
  bool ticking = true,
}) => tester.pumpWidget(
  TickerMode(
    enabled: ticking,
    child: ChangeNotifierProvider<CodelesslyContext>.value(
      value: context,
      child: MaterialApp(
        home: Material(child: Center(child: child)),
      ),
    ),
  ),
);

Color? textColor(WidgetTester tester) {
  final RichText rich = tester.widget<RichText>(find.byType(RichText).first);
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

Color? iconColor(WidgetTester tester) =>
    tester.widget<SvgIcon>(find.byType(SvgIcon)).color;

bool between(Color? c, Color a, Color b) {
  if (c == null) return false;
  bool inRange(double v, double x, double y) =>
      v > (x < y ? x : y) + 0.01 && v < (x < y ? y : x) - 0.01;
  return inRange(c.r, a.r, b.r) && inRange(c.g, a.g, b.g);
}

void main() {
  for (final String binding in const ['textColor', 'fill']) {
    testWidgets('a text bound by $binding eases to its new color', (
      tester,
    ) async {
      final Observable<VariableData> variable = ink(dusk);
      final context = CodelesslyContext.empty()..variables['ink'] = variable;
      final TextNode node = label(binding: binding);
      final registry = NodeRegistry()
        ..setNodes({node.id: node..parentID = kRootNode});
      final manager = PassiveNodeTransformerManager(
        registry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
      await host(
        tester,
        context,
        Builder(
          builder: (context) => manager.buildWidgetFromNode(
            node,
            context,
            settings: const WidgetBuildSettings(debugLabel: 'test'),
          ),
        ),
      );
      expect(textColor(tester), dusk);

      variable.value = variable.value.copyWith(value: hex(night));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        between(textColor(tester), dusk, night),
        isTrue,
        reason: '${textColor(tester)}',
      );
      await tester.pumpAndSettle();
      expect(textColor(tester), night);
    });
  }

  testWidgets('a text widget rebuilt with a new bound color eases to it', (
    tester,
  ) async {
    final Observable<VariableData> variable = ink(dusk);
    final context = CodelesslyContext.empty()..variables['ink'] = variable;
    Widget text() => PassiveTextWidget(
      node: label(),
      settings: const WidgetBuildSettings(debugLabel: 'test'),
    );
    await host(tester, context, text());
    expect(textColor(tester), dusk);
    variable.value = variable.value.copyWith(value: hex(night));
    await host(tester, context, text());
    await tester.pump(const Duration(milliseconds: 150));
    expect(
      between(textColor(tester), dusk, night),
      isTrue,
      reason: '${textColor(tester)}',
    );
    await tester.pumpAndSettle();
    expect(textColor(tester), night);
  });

  testWidgets('without a transition a bound text color jumps', (tester) async {
    final Observable<VariableData> variable = ink(dusk);
    final context = CodelesslyContext.empty()..variables['ink'] = variable;
    Widget text() => PassiveTextWidget(
      node: label(transitionMs: 0),
      settings: const WidgetBuildSettings(debugLabel: 'test'),
    );
    await host(tester, context, text());
    variable.value = variable.value.copyWith(value: hex(night));
    await host(tester, context, text());
    expect(textColor(tester), night);
  });

  testWidgets('under muted tickers a text shows its new color at once', (
    tester,
  ) async {
    final Observable<VariableData> variable = ink(dusk);
    final context = CodelesslyContext.empty()..variables['ink'] = variable;
    Widget text() => PassiveTextWidget(
      node: label(),
      settings: const WidgetBuildSettings(debugLabel: 'test'),
    );
    await host(tester, context, text(), ticking: false);
    variable.value = variable.value.copyWith(value: hex(night));
    await host(tester, context, text(), ticking: false);
    expect(textColor(tester), night);
  });

  testWidgets('an icon bound by iconColor eases to its new color', (
    tester,
  ) async {
    final Observable<VariableData> variable = ink(dusk);
    final context = CodelesslyContext.empty()..variables['ink'] = variable;
    await host(tester, context, PassiveIconWidget(node: glyph()));
    expect(iconColor(tester), dusk);

    variable.value = variable.value.copyWith(value: hex(night));
    await host(tester, context, PassiveIconWidget(node: glyph()));
    await tester.pump(const Duration(milliseconds: 150));
    expect(
      between(iconColor(tester), dusk, night),
      isTrue,
      reason: '${iconColor(tester)}',
    );
    await tester.pumpAndSettle();
    expect(iconColor(tester), night);
  });

  testWidgets('under muted tickers an icon shows its new color at once', (
    tester,
  ) async {
    final Observable<VariableData> variable = ink(dusk);
    final context = CodelesslyContext.empty()..variables['ink'] = variable;
    await host(
      tester,
      context,
      PassiveIconWidget(node: glyph()),
      ticking: false,
    );
    variable.value = variable.value.copyWith(value: hex(night));
    await host(
      tester,
      context,
      PassiveIconWidget(node: glyph()),
      ticking: false,
    );
    expect(iconColor(tester), night);
  });
}
