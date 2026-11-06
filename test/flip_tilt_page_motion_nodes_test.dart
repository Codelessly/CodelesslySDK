import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The 3D node fields reach the runtime through the transformers: a frame
// with `flip` turns its two children into faces, `tilt` wraps a node, a
// page view's `pageMotion` turns its pages, and bindings read `flip`,
// `tilt` and `pageOffset`.

Observable<VariableData> _variable(String name, VariableType type, value) =>
    Observable(VariableData(id: name, name: name, type: type, value: value));

Future<CodelesslyContext> _pump(
  WidgetTester tester,
  Map<String, BaseNode> nodes,
  BaseNode root, {
  Map<String, Observable<VariableData>> variables = const {},
}) async {
  final NodeRegistry registry = NodeRegistry()..setNodes(nodes);
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
    ..variables.addAll(variables);
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext,
      child: MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 400,
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                root,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return codelesslyContext;
}

RectangleNode _face(String id, String parent, String color) =>
    RectangleNode(
        id: id,
        name: id,
        basicBoxLocal: NodeBox(0, 0, 200, 300),
        fills: [PaintModel.solid(id: '$id-fill', color: ColorRGB.fromHex(color))],
      )
      ..parentID = parent;

void main() {
  testWidgets('a frame with a flip turns over its two faces', (tester) async {
    final FrameNode card = FrameNode.fromJson({
      ...FrameNode(
        id: 'card',
        name: 'Card',
        basicBoxLocal: NodeBox(0, 0, 200, 300),
        children: ['front', 'back'],
      ).toJson(),
      'flip': const FlipModel(variable: 'showBack').toJson(),
      'motion': const MotionModel(perspective: 2, durationMs: 300).toJson(),
    })..parentID = kRootNode;
    final CodelesslyContext context = await _pump(
      tester,
      {
        'card': card,
        'front': _face('front', 'card', '#FF0000'),
        'back': _face('back', 'card', '#0000FF'),
      },
      card,
      variables: {
        'showBack': _variable('showBack', VariableType.boolean, false),
      },
    );
    expect(find.byType(NodeFlip), findsOneWidget);
    // Both faces hide when turned away; the back is turned in advance.
    expect(find.byType(BackfaceHidden), findsNWidgets(2));
    final NodeFlipState state = tester.state<NodeFlipState>(
      find.byType(NodeFlip),
    );
    expect(state.flipped, isFalse);

    await tester.tap(find.byType(NodeFlip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(state.progress, inExclusiveRange(0.1, 0.9));
    await tester.pumpAndSettle();
    expect(state.flipped, isTrue);
    expect('${context.variables['showBack']!.value.value}', 'true');

    // A button elsewhere setting the variable turns it back.
    final Observable<VariableData> v = context.variables['showBack']!;
    v.set(v.value.copyWith(value: false));
    await tester.pumpAndSettle();
    expect(state.flipped, isFalse);
  });

  testWidgets('a bound flip.flipped turns the card', (tester) async {
    final FrameNode card = FrameNode.fromJson({
      ...FrameNode(
        id: 'card',
        name: 'Card',
        basicBoxLocal: NodeBox(0, 0, 200, 300),
        children: ['front', 'back'],
      ).toJson(),
      'flip': const FlipModel(tapToFlip: false).toJson(),
      'variables': {'flip.flipped': r'${answered}'},
    })..parentID = kRootNode;
    final CodelesslyContext context = await _pump(
      tester,
      {
        'card': card,
        'front': _face('front', 'card', '#FF0000'),
        'back': _face('back', 'card', '#0000FF'),
      },
      card,
      variables: {
        'answered': _variable('answered', VariableType.boolean, false),
      },
    );
    final NodeFlipState state = tester.state<NodeFlipState>(
      find.byType(NodeFlip),
    );
    final Observable<VariableData> v = context.variables['answered']!;
    v.set(v.value.copyWith(value: true));
    await tester.pumpAndSettle();
    expect(state.flipped, isTrue);
    expect(state.progress, 1);
  });

  testWidgets('a node with a tilt is wrapped and children read tilt.x', (
    tester,
  ) async {
    final FrameNode frame = FrameNode.fromJson({
      ...FrameNode(
        id: 'tilted',
        name: 'Tilted',
        basicBoxLocal: NodeBox(0, 0, 200, 200),
        children: ['label'],
      ).toJson(),
      'tilt': const TiltModel().toJson(),
    })..parentID = kRootNode;
    final TextNode label = TextNode(
      id: 'label',
      name: 'label',
      basicBoxLocal: NodeBox(0, 0, 200, 40),
      textMixedProps: [StartEndProp(start: 0, end: 14, fontSize: 16)],
      data: r'tilt ${tilt.x}',
    )..parentID = 'tilted';
    await _pump(tester, {'tilted': frame, 'label': label}, frame);
    expect(find.byType(NodeTilt), findsOneWidget);
    expect(find.textContaining('tilt 0'), findsOneWidget);
  });

  testWidgets('bindings read the predefined 3D values', (tester) async {
    late BuildContext inner;
    await tester.pumpWidget(
      MotionValuesScope(
        values: const {
          'flip': {'flipped': true, 'progress': 0.75},
          'pageOffset': -1.5,
        },
        child: Builder(
          builder: (context) {
            inner = context;
            return const SizedBox();
          },
        ),
      ),
    );
    final ScopedValues values = ScopedValues.of(inner);
    String read(String text) => PropertyValueDelegate.substituteVariables(
      text,
      scopedValues: values,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
    );
    expect(read(r'${flip.progress}'), '0.75');
    expect(read(r'${flip.flipped}'), 'true');
    expect(read(r'${pageOffset}'), '-1.5');
    // Outside a tilt it reads rest.
    expect(read(r'${tilt.x}'), '0.0');
  });

  testWidgets('a page view with page motion turns the pages beside the '
      'current one', (tester) async {
    final PageViewNode pager = PageViewNode(
      id: 'pager',
      name: 'Pager',
      basicBoxLocal: NodeBox(0, 0, 400, 300),
      properties: PageViewProperties(
        itemCount: 4,
        viewportFraction: 0.5,
        pageMotion: const MotionModel(rotateY: -50, scale: 0.8),
      ),
      children: ['page'],
    )..parentID = kRootNode;
    final RectangleNode page = _face('page', 'pager', '#00AA00');
    await _pump(tester, {'pager': pager, 'page': page}, pager);
    expect(find.byType(PageMotionItem), findsWidgets);
    final List<PageMotionItem> items = tester
        .widgetList<PageMotionItem>(find.byType(PageMotionItem))
        .toList();
    expect(items.first.motion?.rotateY, -50);
  });
}
