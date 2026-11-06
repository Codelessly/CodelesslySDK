import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A one-line field that hugs its height, padded on the node (12, 10), with
/// a 16 px font at 140% line height: 10 + 22.4 + 10 tall on every platform.
TextFieldNode _field() => TextFieldNode(
  id: 'field',
  name: 'Field',
  basicBoxLocal: NodeBox(0, 0, 300, 36),
  horizontalFit: SizeFit.fixed,
  verticalFit: SizeFit.shrinkWrap,
  padding: const EdgeInsetsModel.symmetric(horizontal: 12, vertical: 10),
  properties: TextFieldProperties(
    inputStyle: TextProp(fontSize: 16, lineHeight: const LineHeight.percent(140)),
    decoration: InputDecorationModel(
      border: const InputBorderModel(borderType: BorderTypeEnum.none),
      enabledBorder: const InputBorderModel(borderType: BorderTypeEnum.none),
      focusedBorder: const InputBorderModel(borderType: BorderTypeEnum.none),
    ),
  ),
);

Future<double> _height(WidgetTester tester) async {
  final TextFieldNode node = _field();
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
          body: Align(
            alignment: Alignment.topLeft,
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
  return tester.getSize(find.byType(InputDecorator)).height;
}

void main() {
  for (final TargetPlatform platform in [
    TargetPlatform.android,
    TargetPlatform.linux,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  ]) {
    testWidgets('a hugging field keeps its padding and line height on ${platform.name}', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        // Desktop's compact density took 8 px off: 34 instead of 42.4.
        expect(await _height(tester), closeTo(42.4, 0.6));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
