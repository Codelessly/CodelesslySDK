import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Reaction reaction(TriggerModel trigger, String function) => Reaction(
  trigger: trigger,
  action: CallFunctionAction(name: function),
);

CanvasNode canvas(List<Reaction> reactions) => CanvasNode(
  id: 'canvas',
  name: 'canvas',
  basicBoxLocal: NodeBox(0, 0, 390, 844),
  children: const ['body'],
  properties: CanvasProperties(bodyId: 'body'),
  reactions: reactions,
);

Future<List<String>> pumpCanvas(
  WidgetTester tester,
  List<Reaction> reactions,
) async {
  final calls = <String>[];
  final codelesslyContext = CodelesslyContext.empty()
    ..functions = {
      for (final name in ['tick', 'next', 'previous'])
        name: (context, reference, params) => calls.add(name),
    };
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext,
      child: MaterialApp(
        home: ActionChainHost(
          child: PassiveCanvasWidget(
            node: canvas(reactions),
            settings: const WidgetBuildSettings(debugLabel: 'test'),
            builder: (_) => const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return calls;
}

void main() {
  test('Triggers keep their interval and key through JSON', () {
    final timer = TriggerModel(type: TriggerType.timer, intervalMs: 250);
    expect(timer.toJson(), {'type': 'timer', 'intervalMs': 250});
    expect(TriggerModel.fromJson(timer.toJson()), timer);
    final key = TriggerModel(type: TriggerType.keyPress, key: 'Arrow Right');
    expect(TriggerModel.fromJson(key.toJson()).key, 'Arrow Right');
    expect(TriggerModel(type: TriggerType.timer).effectiveIntervalMs, 1000);
  });

  test('Canvases offer timer and key press, shapes offer swipes', () {
    expect(
      canvas([]).triggerTypes,
      containsAll([TriggerType.timer, TriggerType.keyPress]),
    );
    final frame = FrameNode(
      id: 'f',
      name: 'f',
      basicBoxLocal: NodeBox(0, 0, 1, 1),
      children: const [],
    );
    expect(frame.triggerTypes, containsAll(TriggerType.swipes));
  });

  test('Key labels match however they are spelled', () {
    expect(normalizeKeyLabel('Arrow Right'), normalizeKeyLabel('ArrowRight'));
    expect(normalizeKeyLabel('arrowright'), 'arrowright');
  });

  testWidgets('A timer reaction runs every interval until the canvas goes', (
    tester,
  ) async {
    final calls = await pumpCanvas(tester, [
      reaction(TriggerModel(type: TriggerType.timer, intervalMs: 200), 'tick'),
    ]);
    await tester.pump(const Duration(milliseconds: 650));
    expect(calls, ['tick', 'tick', 'tick']);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(calls, hasLength(3));
  });

  testWidgets('A key press reaction runs for its key only', (tester) async {
    final calls = await pumpCanvas(tester, [
      reaction(
        TriggerModel(type: TriggerType.keyPress, key: 'Arrow Right'),
        'next',
      ),
      reaction(
        TriggerModel(type: TriggerType.keyPress, key: 'ArrowLeft'),
        'previous',
      ),
    ]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pump();
    expect(calls, ['next', 'previous']);
  });

  testWidgets('Swipes report their direction; taps are not swipes', (
    tester,
  ) async {
    final swipes = <TriggerType>[];
    var taps = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SwipeDetector(
            onSwipe: swipes.add,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox(width: 300, height: 300),
            ),
          ),
        ),
      ),
    );
    final center = tester.getCenter(find.byType(SizedBox));
    await tester.dragFrom(center, const Offset(-120, 10));
    await tester.dragFrom(center, const Offset(0, 120));
    await tester.tap(find.byType(SizedBox));
    await tester.pump();
    expect(swipes, [TriggerType.swipeLeft, TriggerType.swipeDown]);
    expect(taps, 1);

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(center));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
    await tester.pump();
    expect(swipes.last, TriggerType.swipeUp);
  });
}
