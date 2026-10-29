import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

SignatureNormalizedNode normalized({
  List<List<List<double>>> strokes = const [],
  SignatureNormalizedProperties? properties,
  Map<String, String> bindings = const {},
}) => SignatureNormalizedNode(
  id: 'normalized',
  name: 'Normalized',
  basicBoxLocal: NodeBox(0, 0, 320, 140),
  strokes: strokes,
  properties: properties ?? SignatureNormalizedProperties(),
)..variables.addAll(bindings);

Future<void> pump(
  WidgetTester tester,
  BaseNode node,
  CodelesslyContext runtime,
) async {
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: runtime,
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
}

SignatureNormalizedPainter painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((paint) => paint.painter)
    .whereType<SignatureNormalizedPainter>()
    .single;

void main() {
  testWidgets('pixel signature remains a separate pixel-space transformer', (
    tester,
  ) async {
    final node = SignatureNode(
      id: 'pixel',
      name: 'Pixel',
      basicBoxLocal: NodeBox(0, 0, 320, 140),
      properties: SignatureProperties(),
      value: [
        [
          [32, 70],
          [160, 70],
        ],
      ],
    );
    await pump(tester, node, CodelesslyContext.empty());
    expect(find.byType(TransformerSignature), findsOneWidget);
    expect(
      tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<SignaturePainter>()
          .single
          .strokes
          .first
          .first,
      const Offset(32, 70),
    );
    expect(find.byType(PassiveSignatureNormalizedWidget), findsNothing);
  });

  testWidgets(
    'normalized strokes scale with paint size and style stays ink only',
    (tester) async {
      final node = normalized(
        strokes: [
          [
            [0.1, 0.5],
            [0.5, 1.0],
          ],
        ],
        properties: SignatureNormalizedProperties(strokeWidth: 4),
      );
      await pump(tester, node, CodelesslyContext.empty());
      expect(find.byType(TransformerSignature), findsNothing);
      expect(painter(tester).strokes, [
        [
          [0.1, 0.5],
          [0.5, 1.0],
        ],
      ]);
      expect(painter(tester).strokeWidth, 4);
      final picture = ui.PictureRecorder();
      final canvas = Canvas(picture);
      painter(tester).paint(canvas, const Size(320, 140));
      expect(
        SignatureNormalizedPainter.scaledPoints(
          painter(tester).strokes.single,
          const Size(320, 140),
        ),
        [const Offset(32, 70), const Offset(160, 140)],
      );
      painter(tester).paint(canvas, const Size(640, 280));
      expect(
        SignatureNormalizedPainter.scaledPoints(
          painter(tester).strokes.single,
          const Size(640, 280),
        ),
        [const Offset(64, 140), const Offset(320, 280)],
      );
      picture.endRecording().dispose();
    },
  );

  testWidgets('draw writes normalized binding and external clear redraws', (
    tester,
  ) async {
    final variable = Observable(
      VariableData(
        id: 'sig',
        name: 'sig',
        value: '[]',
        type: VariableType.list,
      ),
    );
    await pump(
      tester,
      normalized(bindings: {'value': r'${sig}'}),
      CodelesslyContext.empty()..variables['sig'] = variable,
    );
    final start = tester.getTopLeft(
      find.byType(PassiveSignatureNormalizedWidget),
    );
    await tester.dragFrom(start + const Offset(32, 70), const Offset(128, 0));
    await tester.pumpAndSettle();
    final strokes = variable.value.getValue() as List;
    expect(strokes, hasLength(1));
    expect((strokes.first as List).first[0], closeTo(.1, .01));
    expect((strokes.first as List).first[1], closeTo(.5, .01));
    variable.value = variable.value.copyWith(value: '[]');
    await tester.pumpAndSettle();
    expect(painter(tester).strokes, isEmpty);
  });

  testWidgets('readOnly binding disables input but replays stored strokes', (
    tester,
  ) async {
    final variable = Observable(
      VariableData(
        id: 'locked',
        name: 'locked',
        value: 'true',
        type: VariableType.boolean,
      ),
    );
    await pump(
      tester,
      normalized(
        strokes: [
          [
            [.25, .25],
          ],
        ],
        bindings: {'readOnly': r'${locked}'},
      ),
      CodelesslyContext.empty()..variables['locked'] = variable,
    );
    final start = tester.getTopLeft(
      find.byType(PassiveSignatureNormalizedWidget),
    );
    await tester.dragFrom(start + const Offset(32, 70), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(painter(tester).strokes, [
      [
        [.25, .25],
      ],
    ]);
  });
}
