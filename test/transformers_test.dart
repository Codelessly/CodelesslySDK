import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Nodes that build without children or remote data.
List<BaseNode> standaloneNodes() => [
  ButtonNode.empty(),
  CheckboxNode.empty(),
  DividerNode.empty(),
  FloatingActionButtonNode.empty(),
  // A Cupertino icon renders from the bundled font; Material icons load
  // SVGs over the network, which widget tests cannot reach.
  IconNode(
    id: 'icon',
    name: 'Icon',
    basicBoxLocal: NodeBox(0, 0, 24, 24),
    icon: CupertinoIcon(
      codepoint: CupertinoIcons.heart.codePoint,
      name: 'heart',
    ),
  ),
  ProgressBarNode.empty(),
  RadioNode.empty(),
  SliderNode.empty(),
  SwitchNode.empty(),
  ListTileNode.empty(),
  ExpansionTileNode.empty(),
  TextNode(
    id: 'text',
    name: 'Text',
    basicBoxLocal: NodeBox(0, 0, 100, 20),
    characters: 'Hello',
  ),
  BadgeNode.empty(),
  for (final type in ChipType.values)
    ChipNode.fromProperties(ChipProperties(chipType: type)),
  SegmentedButtonNode.empty(),
  SignatureNode.empty(),
  AccordionNode(
    id: 'accordion',
    name: 'Accordion',
    basicBoxLocal: NodeBox(0, 0, 200, 100),
    children: const [],
    properties: AccordionProperties(isExpanded: true),
  ),
];

void main() {
  for (final node in standaloneNodes()) {
    testWidgets('${node.type} builds without errors', (tester) async {
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
    });
  }
}
