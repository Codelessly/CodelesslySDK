import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A 300×100 signature box bound to the `sig` variable.
Future<CodelesslyContext> pumpPad(
  WidgetTester tester, {
  Object? initial = const [],
  bool readOnly = false,
}) async {
  final ctx = CodelesslyContext.empty()
    ..variables['sig'] = Observable(
      VariableData(id: 'sig', name: 'sig', type: VariableType.list),
    );
  if (initial != null) {
    ctx.variables['sig']!.value = ctx.variables['sig']!.value.copyWith(
      value: initial,
    );
  }
  final SignatureNormalizedNode pad =
      SignatureNormalizedNode(
          id: 'pad',
          name: 'pad',
          basicBoxLocal: NodeBox(0, 0, 300, 100),
          properties: SignatureNormalizedProperties(readOnly: readOnly),
        )
        ..parentID = kRootNode
        ..variables['value'] = r'${sig}';
  final registry = NodeRegistry()..setNodes({'pad': pad});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: ctx,
      child: MaterialApp(
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                pad,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return ctx;
}

List<List<List<double>>> painted(WidgetTester tester) =>
    (tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(PassiveSignatureNormalizedWidget),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter
            as SignatureNormalizedPainter)
        .strokes;

void main() {
  test('stored normalized points scale to pixel-space paint positions', () {
    expect(
      SignatureNormalizedPainter.scaledPoints([
        [0.1, 0.2],
        [1, 0],
      ], const Size(300, 100)),
      [const Offset(30, 20), const Offset(300, 0)],
    );
  });

  test('a signature node round-trips through JSON', () {
    final node = SignatureNormalizedNode(
      id: 'pad',
      name: 'Signature',
      basicBoxLocal: NodeBox(0, 0, 300, 100),
      properties: SignatureNormalizedProperties(
        inkColor: ColorRGBA.white,
        readOnly: true,
      ),
    );
    final json = node.toJson();
    expect(json['type'], 'signature');
    expect(json['signatureKind'], 'normalized');
    final back =
        NodeJsonConverter.instance.fromJson(json)! as SignatureNormalizedNode;
    expect(back.properties.readOnly, isTrue);
    expect(back.properties.inkColor, ColorRGBA.white);
    expect(back.properties.strokeWidth, 2.6);
  });

  testWidgets('drawing writes normalized strokes to the bound variable', (
    tester,
  ) async {
    final ctx = await pumpPad(tester);
    await tester.dragFrom(const Offset(30, 50), const Offset(150, 20));
    await tester.pumpAndSettle();

    final strokes = ctx.variables['sig']!.value.getValue() as List;
    expect(strokes, hasLength(1));
    expect(strokes.first.first[0], closeTo(0.1, 0.01));
    expect(strokes.first.first[1], closeTo(0.5, 0.01));
    expect(strokes.first.last[0], closeTo(0.6, 0.02));
    expect(strokes.first.length, greaterThan(2));
    expect(painted(tester), hasLength(1));

    await tester.dragFrom(const Offset(200, 80), const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(ctx.variables['sig']!.value.getValue(), hasLength(2));

    // Clearing the variable clears the box.
    ctx.variables['sig']!.value = ctx.variables['sig']!.value.copyWith(
      value: const [],
    );
    await tester.pumpAndSettle();
    expect(painted(tester), isEmpty);
  });

  testWidgets('a read-only box replays a signature and ignores the pen', (
    tester,
  ) async {
    final ctx = await pumpPad(
      tester,
      readOnly: true,
      initial: [
        [
          [0.1, 0.5],
          [0.9, 0.5],
        ],
      ],
    );
    expect(painted(tester), hasLength(1));
    await tester.dragFrom(const Offset(30, 20), const Offset(150, 20));
    await tester.pumpAndSettle();
    expect(ctx.variables['sig']!.value.getValue(), hasLength(1));
  });
}
