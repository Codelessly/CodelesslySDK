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
      reactions: [setLast(r'${result.key} ${result.shift}')],
    )..parentID = kRootNode;
    final AutoPlaceholderNode body = AutoPlaceholderNode(
      id: 'body',
      name: 'body',
      basicBoxLocal: NodeBox(0, 0, 390, 844),
      children: const [],
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.expanded,
    )..parentID = 'canvas';
    final registry = NodeRegistry()
      ..setNodes({canvas.id: canvas, body.id: body});
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
            builder: (context) => manager.buildWidgetFromNode(
              canvas,
              context,
              settings: const WidgetBuildSettings(debugLabel: 'test'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(last.value.value, 'ArrowLeft false');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(last.value.value, 'r true');
  });

  testWidgets('canvas key down reactions match combinations and their when', (
    tester,
  ) async {
    Reaction setLast(String value, String key, {String? when}) => Reaction(
      action: SetVariableAction(
        variable: VariableData(id: 'last', name: 'last'),
        newValue: value,
      ),
      trigger: TriggerModel(type: TriggerType.keyDown, key: key, when: when),
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
      reactions: [
        setLast('save', 'Meta+s'),
        setLast('s', 's'),
        setLast('down', 'ArrowDown', when: r'${= armed}'),
      ],
    )..parentID = kRootNode;
    final AutoPlaceholderNode body = AutoPlaceholderNode(
      id: 'body',
      name: 'body',
      basicBoxLocal: NodeBox(0, 0, 390, 844),
      children: const [],
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.expanded,
    )..parentID = 'canvas';
    final registry = NodeRegistry()
      ..setNodes({canvas.id: canvas, body.id: body});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final Observable<VariableData> last = Observable(
      VariableData(id: 'last', name: 'last'),
    );
    final Observable<VariableData> armed = Observable(
      VariableData(
        id: 'armed',
        name: 'armed',
        type: VariableType.boolean,
        value: false,
      ),
    );
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
      ..variables['last'] = last
      ..variables['armed'] = armed;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: Builder(
            builder: (context) => manager.buildWidgetFromNode(
              canvas,
              context,
              settings: const WidgetBuildSettings(debugLabel: 'test'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pumpAndSettle();
    expect(last.value.value, 's');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(last.value.value, 'save');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(last.value.value, 'save');

    armed.value = armed.value.copyWith(value: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(last.value.value, 'down');
  });
}
