import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Reaction on(TriggerType type, String function) => Reaction(
  trigger: TriggerModel(type: type),
  action: CallFunctionAction(name: function),
);

RectangleNode box(List<Reaction> reactions) => RectangleNode(
  id: 'box',
  name: 'box',
  basicBoxLocal: NodeBox(0, 0, 100, 100),
  reactions: reactions,
)..parentID = kRootNode;

Future<CodelesslyContext> pumpNode(
  WidgetTester tester,
  BaseNode node,
  List<String> calls, {
  Map<String, Observable<VariableData>> variables = const {},
}) async {
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  final codelesslyContext = CodelesslyContext.empty()
    ..functions = {
      for (final name in ['tap', 'double', 'enter', 'exit', 'reset'])
        name: (context, reference, params) => calls.add(name),
    };
  codelesslyContext.variables.addAll(variables);
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext,
      child: MaterialApp(
        home: Material(
          child: ActionChainHost(
            child: Align(
              alignment: Alignment.topLeft,
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
    ),
  );
  return codelesslyContext;
}

SliderNode slider({
  SliderProperties? properties,
  List<Reaction> reactions = const [],
  Map<String, String> variables = const {},
  double width = 300,
  double height = 48,
}) => SliderNode(
  id: 'slider',
  name: 'slider',
  basicBoxLocal: NodeBox(0, 0, width, height),
  value: 0,
  properties: properties ?? SliderProperties(),
  reactions: reactions,
  variables: variables,
)..parentID = kRootNode;

void main() {
  testWidgets('A single tap still clicks when there is no double tap', (
    tester,
  ) async {
    final calls = <String>[];
    await pumpNode(tester, box([on(TriggerType.click, 'tap')]), calls);
    await tester.tapAt(const Offset(50, 50));
    await tester.pump();
    expect(calls, ['tap']);
    expect(
      find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onDoubleTap != null,
      ),
      findsNothing,
    );
  });

  testWidgets('Double tap runs its reaction; single taps still click', (
    tester,
  ) async {
    final calls = <String>[];
    await pumpNode(
      tester,
      box([on(TriggerType.click, 'tap'), on(TriggerType.doubleTap, 'double')]),
      calls,
    );
    await tester.tapAt(const Offset(50, 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(50, 50));
    await tester.pump();
    expect(calls, ['double']);

    // A lone tap waits out the double tap timeout, then clicks.
    await tester.pump(const Duration(seconds: 1));
    await tester.tapAt(const Offset(50, 50));
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
    expect(calls, ['double', 'tap']);
  });

  testWidgets('Cursor enter and exit run for a mouse, never for touch', (
    tester,
  ) async {
    final calls = <String>[];
    await pumpNode(
      tester,
      box([
        on(TriggerType.cursorEnter, 'enter'),
        on(TriggerType.cursorExit, 'exit'),
      ]),
      calls,
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(300, 300));
    await mouse.moveTo(const Offset(50, 50));
    await tester.pump();
    expect(calls, ['enter']);
    await mouse.moveTo(const Offset(300, 300));
    await tester.pump();
    expect(calls, ['enter', 'exit']);
    await mouse.removePointer();

    calls.clear();
    await tester.tapAt(const Offset(50, 50));
    await tester.pump();
    expect(calls, isEmpty);
  });

  testWidgets('Double tapping a slider can reset it', (tester) async {
    final calls = <String>[];
    await pumpNode(
      tester,
      slider(reactions: [on(TriggerType.doubleTap, 'reset')]),
      calls,
    );
    await tester.tapAt(const Offset(150, 24));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(150, 24));
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, ['reset']);
  });

  testWidgets('A vertical slider fills its box and drags along it', (
    tester,
  ) async {
    final calls = <String>[];
    await pumpNode(
      tester,
      slider(
        width: 48,
        height: 300,
        properties: SliderProperties(
          min: -8,
          max: 8,
          orientation: AxisC.vertical,
        ),
      ),
      calls,
    );
    expect(find.byType(RotatedBox), findsOneWidget);
    expect(tester.getSize(find.byType(Slider)), const Size(300, 48));
    final RenderBox rotated = tester.renderObject(find.byType(RotatedBox));
    expect(rotated.size, const Size(48, 300));

    // Tapping near the top of a vertical slider picks a high value.
    final values = <double>[];
    final Slider widget = tester.widget(find.byType(Slider));
    expect(widget.min, -8);
    expect(widget.max, 8);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: TransformerSlider(
              node: slider(
                width: 48,
                height: 300,
                properties: SliderProperties(
                  min: -8,
                  max: 8,
                  orientation: AxisC.vertical,
                ),
              ),
              settings: const WidgetBuildSettings(debugLabel: 'test'),
              onChanged: values.add,
              value: 0,
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(24, 40));
    await tester.pump();
    expect(values.last, greaterThan(4));

    // Dragging up from the bottom moves it up through the range.
    values.clear();
    await tester.dragFrom(const Offset(24, 280), const Offset(0, -260));
    await tester.pump();
    expect(values.first, lessThan(-4));
    expect(values.last, greaterThan(4));

    // Inverted, the top is the low end.
    values.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: TransformerSlider(
              node: slider(
                width: 48,
                height: 300,
                properties: SliderProperties(
                  min: -8,
                  max: 8,
                  orientation: AxisC.vertical,
                  inverted: true,
                ),
              ),
              settings: const WidgetBuildSettings(debugLabel: 'test'),
              onChanged: values.add,
              value: 0,
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(24, 40));
    await tester.pump();
    expect(values.last, lessThan(-4));
  });

  testWidgets('Slider min and max follow their bound variables', (
    tester,
  ) async {
    await pumpNode(
      tester,
      slider(variables: {'min': r'${low}', 'max': r'${high}'}),
      [],
      variables: {
        'low': Observable(
          VariableData(
            id: 'low',
            name: 'low',
            type: VariableType.integer,
            value: '-8',
          ),
        ),
        'high': Observable(
          VariableData(
            id: 'high',
            name: 'high',
            type: VariableType.integer,
            value: '8',
          ),
        ),
      },
    );
    final Slider widget = tester.widget(find.byType(Slider));
    expect(widget.min, -8);
    expect(widget.max, 8);
  });

  testWidgets('The slider thumb can carry a stroke', (tester) async {
    await pumpNode(
      tester,
      slider(
        properties: SliderProperties(
          thumbStrokeColor: ColorRGBA.white,
          thumbStrokeWidth: 2,
        ),
      ),
      [],
    );
    final SliderTheme theme = tester.widget(find.byType(SliderTheme).last);
    final shape = theme.data.thumbShape as StrokedSliderThumbShape;
    expect(shape.strokeWidth, 2);
    expect(shape.strokeColor, Colors.white);
    expect(tester.takeException(), isNull);
  });
}
