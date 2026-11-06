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

  testWidgets('while typing only Escape and shortcuts reach the screen', (
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

    // A shortcut with Command/Control also reaches it (⌘↵ submits).
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(last.value.value, 'Enter true');
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

  // A letter names a key, not a character: `f` and `F` are the same key,
  // and match it with or without Shift. A reaction for Shift+F names Shift.
  for (final TriggerType type in [TriggerType.keyDown, TriggerType.keyPress]) {
    testWidgets('${type.name} letters match the key without case', (
      tester,
    ) async {
      Reaction count(String key, int by) => Reaction(
        action: SetVariableAction(
          variable: VariableData(
            id: 'count',
            name: 'count',
            type: VariableType.integer,
          ),
          newValue: '$by',
          numberOperation: NumberOperation.add,
        ),
        trigger: TriggerModel(type: type, key: key),
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
          count('f', 1),
          count('F', 10),
          if (type == TriggerType.keyDown) count('Shift+F', 100),
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
      final Observable<VariableData> count0 = Observable(
        VariableData(
          id: 'count',
          name: 'count',
          type: VariableType.integer,
          value: 0,
        ),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: CodelesslyContext.empty()..variables['count'] = count0,
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

      // F alone: the reactions for `f` and for `F`, not Shift+F.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(count0.value.value.toString(), '11');

      // Shift+F: `f` and `F` again, and Shift+F.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(
        count0.value.value.toString(),
        type == TriggerType.keyDown ? '122' : '22',
      );
    });
  }
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
