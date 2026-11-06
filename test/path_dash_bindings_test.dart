import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The Orrery's orbit lines and its planet page's orbit drawing are one
/// shape node each whose SVG path (and dash pattern) follow the data.
void main() {
  RectangleNode shape(Map<String, String> variables) => RectangleNode.fromJson({
    ...RectangleNode(
      id: 'orbit',
      name: 'Orbit',
      basicBoxLocal: NodeBox(0, 0, 100, 100),
      strokes: [
        PaintModel.solid(id: 'stroke', color: ColorRGB.fromHex('#8E2B1E')),
      ],
      strokeWeight: 1.5,
    ).toJson(),
    'path': 'M0 0 L10 0',
    'variables': variables,
  })..parentID = kRootNode;

  Future<BaseNode> styled(
    WidgetTester tester,
    RectangleNode node,
    Map<String, Object?> values,
  ) async {
    final CodelesslyContext context = CodelesslyContext.empty();
    for (final MapEntry<String, Object?> v in values.entries) {
      context.variables[v.key] = Observable(
        VariableData(
          id: v.key,
          name: v.key,
          type: VariableType.text,
          value: v.value,
        ),
      );
    }
    final NodeRegistry registry = NodeRegistry()..setNodes({node.id: node});
    final PassiveNodeTransformerManager manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    late BaseNode result;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: context,
        child: MaterialApp(
          home: Builder(
            builder: (c) {
              result = manager.applyStyleOverrides(c, node);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return result;
  }

  testWidgets('a bound path replaces the saved one', (tester) async {
    final BaseNode out = await styled(
      tester,
      shape({'path': r'${orbitPath}'}),
      {'orbitPath': 'M0 0 A50 40 0 0 0 100 0'},
    );
    expect((out as RectangleNode).path, 'M0 0 A50 40 0 0 0 100 0');
  });

  testWidgets('a bound dash pattern reads text or a list', (tester) async {
    final BaseNode text = await styled(
      tester,
      shape({'dashPattern': r'${dash}'}),
      {'dash': '4 2.5'},
    );
    expect((text as RectangleNode).dashPattern, [4, 2.5]);
    final BaseNode none = await styled(
      tester,
      shape({'dashPattern': r'${dash}'}),
      {'dash': 'soon'},
    );
    expect((none as RectangleNode).dashPattern, isEmpty);
  });
}
