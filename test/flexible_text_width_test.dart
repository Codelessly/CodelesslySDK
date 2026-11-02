import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

TextNode _text(String id, String chars, SizeFit fit, {int? maxLines}) => TextNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, 200, 20),
  data: chars,
  horizontalFit: fit,
  verticalFit: SizeFit.shrinkWrap,
  maxLines: maxLines,
  textMixedProps: [StartEndProp(start: 0, end: chars.length, fontSize: 14)],
)..parentID = 'row';

Future<void> pumpRow(WidgetTester tester, String label, double width) async {
  final label_ = _text('label', label, SizeFit.flexible, maxLines: 1);
  final badge = _text('badge', 'RUNNING', SizeFit.shrinkWrap);
  final row = RowColumnNode(
    id: 'row',
    name: 'Timer title',
    basicBoxLocal: NodeBox(0, 0, width, 20),
    children: const ['label', 'badge'],
    rowColumnType: RowColumnType.row,
    horizontalFit: SizeFit.fixed,
    verticalFit: SizeFit.shrinkWrap,
    spacing: 8,
  )..parentID = kRootNode;
  final registry = NodeRegistry()..setNodes({for (final n in <BaseNode>[row, label_, badge]) n.id: n});
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
                row,
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

void main() {
  testWidgets('a flexible text hugs its text, so a badge sits right after it', (tester) async {
    await pumpRow(tester, 'Tea', 300);
    final double labelRight = tester.getTopRight(find.text('Tea')).dx;
    final double badgeLeft = tester.getTopLeft(find.text('RUNNING')).dx;
    expect(badgeLeft - labelRight, closeTo(8, 1));
  });

  testWidgets('a long flexible text gives way to the badge', (tester) async {
    await pumpRow(tester, 'A very long timer label that will not fit here', 200);
    expect(tester.takeException(), isNull);
    expect(tester.getTopRight(find.text('RUNNING')).dx, lessThanOrEqualTo(200.5));
  });

  testWidgets('a scale-down text shrinks to fit instead of wrapping', (tester) async {
    final TextNode clock = TextNode(
      id: 'clock',
      name: 'Clock',
      basicBoxLocal: NodeBox(0, 0, 60, 30),
      data: '1:41:45',
      horizontalFit: SizeFit.fixed,
      verticalFit: SizeFit.shrinkWrap,
      maxLines: 1,
      overflow: TextOverflowC.scaleDown,
      textMixedProps: [StartEndProp(start: 0, end: 7, fontSize: 28)],
    )..parentID = kRootNode;
    expect(TextNode.fromJson(clock.toJson()).overflow, TextOverflowC.scaleDown);
    final registry = NodeRegistry()..setNodes({'clock': clock});
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
                  clock,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(FittedBox), findsOneWidget);
    expect(tester.getSize(find.text('1:41:45')).width, greaterThan(60));
    final Rect drawn = tester.getRect(find.byType(FittedBox));
    expect(drawn.width, lessThanOrEqualTo(60.5));
  });
}
