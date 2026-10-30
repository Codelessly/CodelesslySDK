import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/load_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);

  Future<void> mount(WidgetTester tester) async {
    final modal = ModalNode(
      id: 'modal',
      name: 'Modal',
      basicBoxLocal: NodeBox(0, 0, 120, 40),
      trigger: 'trigger',
      content: 'content',
    );
    final trigger = FilledButtonNode(
      id: 'trigger',
      name: 'Trigger',
      basicBoxLocal: NodeBox(0, 0, 120, 40),
      properties: ButtonProperties(
        label: 'Open',
        buttonType: ButtonTypeEnum.filled,
        labelStyle: TextProp.general(
          fontName: const FontName(
            family: 'TabsFixture',
            style: 'Normal',
            weight: FontWeightNumeric.w400,
          ),
        ),
      ),
    );
    final content = ColumnNode.fromJson({
      'id': 'content',
      'name': 'Content',
      'type': 'column',
      'basicBoxLocal': [0, 0, 200, 100],
      'verticalFit': 'shrinkWrap',
      'horizontalFit': 'shrinkWrap',
      'crossAxisAlignment': 'center',
      'children': ['close'],
    });
    content.parentID = modal.id;
    final close = FilledButtonNode(
      id: 'close',
      name: 'Close',
      basicBoxLocal: NodeBox(0, 0, 120, 40),
      properties: ButtonProperties(
        label: 'Close',
        buttonType: ButtonTypeEnum.filled,
        labelStyle: TextProp.general(
          fontName: const FontName(
            family: 'TabsFixture',
            style: 'Normal',
            weight: FontWeightNumeric.w400,
          ),
        ),
      ),
      reactions: [
        Reaction(
          action: CloseModalAction(),
          trigger: TriggerModel(type: TriggerType.click),
        ),
      ],
    );
    final registry = NodeRegistry()
      ..setNodes({
        modal.id: modal,
        trigger.id: trigger,
        content.id: content,
        close.id: close,
      });
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Roboto'),
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  modal,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'modal'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('trigger opens arbitrary column content; closeModal closes it', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Close'), findsNothing);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    final dialogRect = tester.getRect(
      find.descendant(of: find.byType(Dialog), matching: find.byType(Material)).first,
    );
    final closeRect = tester.getRect(find.text('Close'));
    expect(dialogRect.width, lessThanOrEqualTo(560));
    expect(closeRect.center.dx, closeTo(dialogRect.center.dx, 24));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Close'), findsNothing);
  });

  testWidgets('closed and open dialog use real-font goldens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await mount(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/modal_closed.png'),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/modal_open.png'),
    );
  });

  testWidgets('barrier dismisses modal content', (tester) async {
    await mount(tester);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Close'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Close'), findsNothing);
  });
}
