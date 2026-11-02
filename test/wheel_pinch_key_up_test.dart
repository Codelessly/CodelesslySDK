import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Wheel and pinch reactions (zooming a floor plan at the pointer), drag and
/// pointer results with screen position and modifiers, and screen key up.
Reaction setLast(TriggerType type, String value, {String? key}) => Reaction(
  action: SetVariableAction(
    variable: VariableData(id: 'last', name: 'last'),
    newValue: value,
  ),
  trigger: TriggerModel(type: type, key: key),
);

Future<Observable<VariableData>> pump(WidgetTester tester, Widget child) async {
  final Observable<VariableData> last = Observable(
    VariableData(id: 'last', name: 'last'),
  );
  final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
    ..variables['last'] = last;
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext,
      child: MaterialApp(home: Align(alignment: Alignment.topLeft, child: child)),
    ),
  );
  return last;
}

Widget box(ReactionDragDetector Function(Widget child) wrap) =>
    Padding(padding: const EdgeInsets.only(left: 50, top: 20), child: wrap(const SizedBox(width: 300, height: 200)));

void main() {
  testWidgets('a wheel reaction reads the scroll, pointer and modifiers', (tester) async {
    final last = await pump(
      tester,
      box((child) => ReactionDragDetector(
        onDrag: const [],
        onDragEnd: const [],
        onPointerDown: const [],
        onPointerUp: const [],
        onWheel: [setLast(TriggerType.wheel, r'${result.deltaY} ${result.x} ${result.y} ${result.ctrl}')],
        child: child,
      )),
    );
    final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(const Offset(150, 70)));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -120)));
    await tester.pumpAndSettle();
    expect(last.value.value, '-120.0 100.0 50.0 false');
  });

  testWidgets('a pinch reports step and total scale; one finger still drags', (tester) async {
    final last = await pump(
      tester,
      box((child) => ReactionDragDetector(
        onDrag: [setLast(TriggerType.drag, r'drag ${result.dx} ${result.globalX}')],
        onDragEnd: const [],
        onPointerDown: const [],
        onPointerUp: const [],
        onPinch: [setLast(TriggerType.pinch, r'pinch ${= round(result.totalScale, 2)}')],
        child: child,
      )),
    );
    final TestGesture one = await tester.startGesture(const Offset(100, 100));
    await one.moveBy(const Offset(30, 0));
    await one.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(last.value.value, startsWith('drag '));
    expect(last.value.value, endsWith(' 160.0'));
    await one.up();

    final TestGesture a = await tester.startGesture(const Offset(100, 100));
    final TestGesture b = await tester.startGesture(const Offset(200, 100), pointer: 7);
    await tester.pump();
    for (int i = 0; i < 5; i++) {
      await a.moveBy(const Offset(-10, 0));
      await b.moveBy(const Offset(10, 0));
      await tester.pump();
    }
    expect(last.value.value, 'pinch 2');
    await a.up();
    await b.up();
  });

  testWidgets('pointer down carries screen position and the button', (tester) async {
    final last = await pump(
      tester,
      box((child) => ReactionDragDetector(
        onDrag: const [],
        onDragEnd: const [],
        onPointerDown: [setLast(TriggerType.pointerDown, r'${result.x},${result.y} ${result.globalX},${result.globalY} ${result.button} ${result.shift}')],
        onPointerUp: const [],
        child: child,
      )),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tapAt(const Offset(70, 40));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(last.value.value, '20.0,20.0 70.0,40.0 primary true');
  });

  testWidgets('a screen key up reaction runs when the key is released', (tester) async {
    final CanvasNode canvas = CanvasNode(
      id: 'canvas',
      name: 'canvas',
      basicBoxLocal: NodeBox(0, 0, 390, 844),
      children: ['body'],
      properties: CanvasProperties(bodyId: 'body', safeArea: const SafeAreaModel.all(false)),
      reactions: [
        setLast(TriggerType.keyDown, r'down ${result.key}', key: 'Space'),
        setLast(TriggerType.keyUp, r'up ${result.key}', key: 'Space'),
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
    final registry = NodeRegistry()..setNodes({canvas.id: canvas, body.id: body});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    late Observable<VariableData> last;
    last = await pump(
      tester,
      Builder(
        builder: (context) => manager.buildWidgetFromNode(
          canvas,
          context,
          settings: const WidgetBuildSettings(debugLabel: 'test'),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(last.value.value, 'down Space');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(last.value.value, 'up Space');
  });
}
