import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  for (final (wire, expected) in [
    ('gaugeRadial', PassiveRadialGaugeWidget),
    ('gaugeMeter', PassiveGaugeWidget),
    ('barChart', PassiveBarChartWidget),
  ]) {
    testWidgets('$wire deserializes and dispatches to its own SDK renderer', (
      tester,
    ) async {
      final source = switch (wire) {
        'gaugeRadial' => GaugeNode.empty(),
        'gaugeMeter' => GaugeMeterNode.empty(),
        _ => BarChartNode.empty(),
      };
      final node = NodeJsonConverter.instance.fromJson(source.toJson())!;
      final registry = NodeRegistry()..setNodes({node.id: node});
      final manager = PassiveNodeTransformerManager(
        registry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: CodelesslyContext.empty(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  node,
                  context,
                  settings: const WidgetBuildSettings(
                    debugLabel: 'gauge routing',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(node.type, wire);
      expect(
        find.byWidgetPredicate((widget) => widget.runtimeType == expected),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
