import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A unit after a field ("kWh") shows before anything is typed when the
/// decoration's affixesAlwaysVisible is on; Flutter's own suffix shows only
/// once the field is focused or has text.
Future<void> _pump(WidgetTester tester, InputDecorationModel decoration) async {
  final node = TextFieldNode(
    id: 'field',
    name: 'Field',
    basicBoxLocal: NodeBox(0, 0, 300, 60),
    properties: TextFieldProperties(decoration: decoration),
  );
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
          body: Center(
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
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
}

bool _shown(WidgetTester tester, String text) {
  final finder = find.text(text);
  if (finder.evaluate().isEmpty) return false;
  // Flutter keeps a hidden affix in the tree at zero opacity.
  final opacity = find.ancestor(
    of: finder,
    matching: find.byType(AnimatedOpacity),
  );
  if (opacity.evaluate().isEmpty) return true;
  return tester.widget<AnimatedOpacity>(opacity.first).opacity > 0;
}

void main() {
  testWidgets('an always-visible suffix shows on an empty field', (
    tester,
  ) async {
    await _pump(
      tester,
      InputDecorationModel(suffixText: 'kWh', affixesAlwaysVisible: true),
    );
    expect(_shown(tester, 'kWh'), isTrue);
  });

  testWidgets('by default the suffix waits for focus or text', (tester) async {
    await _pump(tester, InputDecorationModel(suffixText: 'kWh'));
    expect(_shown(tester, 'kWh'), isFalse);
  });

  test('the setting round-trips through JSON and is left out when off', () {
    final on = InputDecorationModel(affixesAlwaysVisible: true);
    expect(
      InputDecorationModel.fromJson(on.toJson()).affixesAlwaysVisible,
      isTrue,
    );
    expect(
      InputDecorationModel().toJson().containsKey('affixesAlwaysVisible'),
      isFalse,
    );
  });
}
