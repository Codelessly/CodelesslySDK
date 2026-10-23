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
  final SignatureNode pad =
      SignatureNode(
          id: 'pad',
          name: 'pad',
          basicBoxLocal: NodeBox(0, 0, 300, 100),
          properties: SignatureProperties(readOnly: readOnly),
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

SignatureStrokes painted(WidgetTester tester) => (tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(PassiveSignatureWidget),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter as SignaturePainter)
    .strokes;

void main() {
  test('strokes parse from bound data and ignore junk', () {
    expect(
      parseSignatureStrokes([
        [
          [0.1, 0.2],
          [1, 0],
        ],
        'junk',
        [],
        [
          ['x', 1],
        ],
      ]),
      [
        [
          [0.1, 0.2],
          [1.0, 0.0],
        ],
      ],
    );
    expect(parseSignatureStrokes(null), isEmpty);
  });

  test('a signature node round-trips through JSON', () {
    final node = SignatureNode(
      id: 'pad',
      name: 'Signature',
      basicBoxLocal: NodeBox(0, 0, 300, 100),
      properties: SignatureProperties(
        inkColor: ColorRGBA.white,
        readOnly: true,
      ),
    );
    final json = node.toJson();
    expect(json['type'], 'signature');
    final back = NodeJsonConverter.instance.fromJson(json)! as SignatureNode;
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

    final strokes = parseSignatureStrokes(ctx.variables['sig']!.value.getValue());
    expect(strokes, hasLength(1));
    expect(strokes.first.first[0], closeTo(0.1, 0.01));
    expect(strokes.first.first[1], closeTo(0.5, 0.01));
    expect(strokes.first.last[0], closeTo(0.6, 0.02));
    expect(strokes.first.length, greaterThan(2));
    expect(painted(tester), hasLength(1));

    await tester.dragFrom(const Offset(200, 80), const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(
      parseSignatureStrokes(ctx.variables['sig']!.value.getValue()),
      hasLength(2),
    );

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
    expect(
      parseSignatureStrokes(ctx.variables['sig']!.value.getValue()),
      hasLength(1),
    );
  });
}
