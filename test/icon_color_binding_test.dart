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

  group('through the node manager', () {
    Future<Observable<VariableData>> pumpManaged(
      WidgetTester tester,
      IconNode node,
    ) async {
      node.parentID = kRootNode;
      final Observable<VariableData> trade = Observable(
        VariableData(id: 'trade', name: 'trade', value: ''),
      );
      final registry = NodeRegistry()..setNodes({node.id: node});
      final manager = PassiveNodeTransformerManager(
        registry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: CodelesslyContext.empty()..variables['trade'] = trade,
          child: MaterialApp(
            home: Center(
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  node,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        ),
      );
      return trade;
    }

    int? painted(WidgetTester tester) =>
        tester.widget<Icon>(find.byType(Icon)).color?.toARGB32();

    for (final property in ['fill', 'iconColor']) {
      testWidgets('a bound $property follows its variable', (tester) async {
        final trade = await pumpManaged(
          tester,
          icon({property: r"${= isNotEmpty(trade) ? '#E85B08' : '#4A5D72'}"}),
        );
        expect(painted(tester), 0xFF4A5D72);

        trade.set(trade.value.copyWith(value: 'electrical'));
        await tester.pump();
        expect(painted(tester), 0xFFE85B08);

        trade.set(trade.value.copyWith(value: ''));
        await tester.pump();
        expect(painted(tester), 0xFF4A5D72);
      });
    }
    testWidgets('an icon in the shape insertTree stores follows a bound fill', (
      tester,
    ) async {
      // The stored shape lib.mjs icons get after fixIcons (list_ui.mjs).
      final IconNode node = IconNode.fromJson({
        'id': 'icon',
        'name': 'Icon construction',
        'type': 'icon',
        'basicBoxLocal': NodeBox(0, 0, 18, 18).toJson(),
        'properties': {
          'icon': {
            'icon': {
              // A Cupertino icon paints from its font, without loading an
              // SVG; a Material one gets the same color, as an SVG tint.
              'type': 'CUPERTINO_ICON',
              'name': 'battery_full',
              'codepoint': 0xf113,
            },
            'show': true,
            'color': ColorRGBA.fromHex('#FF4A5D72')!.toJson(),
            'size': 18,
            'type': 'icon',
          },
        },
        'variables': {
          'fill': r"${= isNotEmpty(trade) ? '#E85B08' : '#4A5D72'}",
        },
      });
      final trade = await pumpManaged(tester, node);
      expect(painted(tester), 0xFF4A5D72);
      trade.set(trade.value.copyWith(value: 'electrical'));
      await tester.pump();
      expect(painted(tester), 0xFFE85B08);
    });
  });
}
