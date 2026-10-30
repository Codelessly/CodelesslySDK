import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A screen's "Key Down" actions run for keys pressed while it shows, with
/// the key and modifiers in `${result}`.
void main() {
  test('key labels', () {
    expect(keyTriggerLabel(LogicalKeyboardKey.keyR), 'r');
    expect(keyTriggerLabel(LogicalKeyboardKey.arrowLeft), 'ArrowLeft');
    expect(keyTriggerLabel(LogicalKeyboardKey.delete), 'Delete');
    expect(keyTriggerLabel(LogicalKeyboardKey.escape), 'Escape');
    expect(keyTriggerLabel(LogicalKeyboardKey.space), 'Space');
  });

  testWidgets('a key down reaction reads the key and its modifiers', (
    tester,
  ) async {
    final Observable<VariableData> last = await pumpScreen(
      tester,
      r'${result.key} ${result.shift}',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(last.value.value, 'ArrowLeft false');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(last.value.value, 'r true');
  });

  testWidgets('while typing only Escape reaches the screen, marked typing', (
    tester,
  ) async {
    final Observable<VariableData> last = await pumpScreen(
      tester,
      r'${result.key} ${result.typing}',
      withField: true,
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pumpAndSettle();
    expect(last.value.value, isNot(startsWith('j')));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(last.value.value, 'Escape true');
  });
}

/// Shows a screen whose "Key Down" action sets `last` to [value], with a
/// text field under it when [withField].
Future<Observable<VariableData>> pumpScreen(
  WidgetTester tester,
  String value, {
  bool withField = false,
}) async {
  Reaction setLast(String value, {String? key}) => Reaction(
    action: SetVariableAction(
      variable: VariableData(id: 'last', name: 'last'),
      newValue: value,
    ),
    trigger: TriggerModel(type: TriggerType.keyDown, key: key),
  );
  final CanvasNode canvas = CanvasNode(
    id: 'canvas',
    name: 'canvas',
    basicBoxLocal: NodeBox(0, 0, 390, 844),
    children: ['body'],
    properties: CanvasProperties(
      bodyId: 'body',
      safeArea: const SafeAreaModel.all(false),
    ),
    reactions: [setLast(value)],
  )..parentID = kRootNode;
  final AutoPlaceholderNode body = AutoPlaceholderNode(
    id: 'body',
    name: 'body',
    basicBoxLocal: NodeBox(0, 0, 390, 844),
    children: const [],
    horizontalFit: SizeFit.expanded,
    verticalFit: SizeFit.expanded,
  )..parentID = 'canvas';
  final registry = NodeRegistry()..setNodes({canvas.id: canvas, body.id: body});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  final Observable<VariableData> last = Observable(
    VariableData(id: 'last', name: 'last'),
  );
  final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
    ..variables['last'] = last;
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Column(
            children: [
              Expanded(
                child: manager.buildWidgetFromNode(
                  canvas,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
              if (withField) const Material(child: TextField()),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return last;
}
