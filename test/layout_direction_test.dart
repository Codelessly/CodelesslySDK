import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Right-to-left layouts: a node's `layoutDirection` binding mirrors its
/// subtree (freeform children, rows, padding, margins and text alignment),
/// and text nodes take bound font families and sizes.

RectangleNode rect(String id, NodeBox box, {String parent = 'frame'}) =>
    RectangleNode(
      id: id,
      name: id,
      basicBoxLocal: box,
      edgePins: EdgePinsModel(
        left: box.x,
        top: box.y,
        right: null,
        bottom: null,
      ),
      positioningMode: PositioningMode.align,
      horizontalFit: SizeFit.fixed,
      verticalFit: SizeFit.fixed,
    )..parentID = parent;

BaseNode withVariables(BaseNode node, Map<String, String> variables) {
  final BaseNode copy = NodeJsonConverter().fromJson({
    ...node.toJson(),
    'variables': variables,
  })!;
  return copy..parentID = node.parentID;
}

FrameNode frame(
  List<BaseNode> children, {
  EdgeInsetsModel padding = EdgeInsetsModel.zero,
}) => FrameNode(
  id: 'frame',
  name: 'frame',
  basicBoxLocal: NodeBox(0, 0, 400, 200),
  children: [for (final child in children) child.id],
  horizontalFit: SizeFit.fixed,
  verticalFit: SizeFit.fixed,
  padding: padding,
  edgePins: EdgePinsModel.standard,
  clipsContent: false,
)..parentID = kRootNode;

Finder rectOf(String id) => find.byKey(
  ValueKey(
    'Rectangle Transformer of ${RectangleNode(id: id, name: id, basicBoxLocal: NodeBox(0, 0, 1, 1)).debugLabel}',
  ),
);

Observable<VariableData> textVariable(String name, String value) => Observable(
  VariableData(id: name, name: name, type: VariableType.text, value: value),
);

Future<void> pump(
  WidgetTester tester,
  BaseNode root,
  List<BaseNode> nodes, {
  Map<String, Observable<VariableData>> variables = const {},
}) async {
  final registry = NodeRegistry()
    ..setNodes({
      for (final node in [root, ...nodes]) node.id: node,
    });
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty()..variables.addAll(variables),
      child: MaterialApp(
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
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
  expect(tester.takeException(), isNull);
}

void main() {
  test('parseLayoutDirection reads rtl and ltr, nothing else', () {
    final parse = PassiveNodeTransformerManager.parseLayoutDirection;
    expect(parse('rtl'), TextDirection.rtl);
    expect(parse(' RTL '), TextDirection.rtl);
    expect(parse('right-to-left'), TextDirection.rtl);
    expect(parse(true), TextDirection.rtl);
    expect(parse('ltr'), TextDirection.ltr);
    expect(parse('inherit'), isNull);
    expect(parse(''), isNull);
    expect(parse(null), isNull);
  });

  testWidgets('freeform children keep their distance from the end edge', (
    tester,
  ) async {
    final child = rect('child', NodeBox(20, 30, 100, 40));
    await pump(tester, frame([child]), [child]);
    expect(tester.getRect(rectOf('child')).left, 20);

    final rtl = withVariables(frame([child]), {'layoutDirection': 'rtl'});
    await pump(tester, rtl, [child]);
    final Rect r = tester.getRect(rectOf('child'));
    expect(r.left, 400 - 20 - 100);
    expect(r.top, 30);
  });

  testWidgets('a bound direction follows its variable', (tester) async {
    final child = rect('child', NodeBox(0, 0, 50, 50));
    final dir = textVariable('dir', 'ltr');
    final root = withVariables(frame([child]), {
      'layoutDirection': r"${= dir == 'rtl' ? 'rtl' : 'ltr'}",
    });
    await pump(tester, root, [child], variables: {'dir': dir});
    expect(tester.getRect(rectOf('child')).left, 0);

    dir.value = dir.value.copyWith(value: 'rtl');
    await tester.pump();
    expect(tester.getRect(rectOf('child')).left, 350);
  });

  testWidgets('padding mirrors: left padding becomes start padding', (
    tester,
  ) async {
    final child = rect('child', NodeBox(30, 0, 50, 50));
    final root = withVariables(
      frame([child], padding: const EdgeInsetsModel.only(left: 30)),
      {'layoutDirection': 'rtl'},
    );
    await pump(tester, root, [child]);
    // 30 of padding on the right, the child at the start of the inner box.
    expect(tester.getRect(rectOf('child')).right, 400 - 30);
  });

  testWidgets('rows run from the end edge right to left', (tester) async {
    final a = rect('a', NodeBox(0, 0, 50, 20), parent: 'row');
    final b = rect('b', NodeBox(50, 0, 80, 20), parent: 'row');
    final RowColumnNode row = RowColumnNode(
      id: 'row',
      name: 'row',
      basicBoxLocal: NodeBox(0, 0, 300, 20),
      children: const ['a', 'b'],
      rowColumnType: RowColumnType.row,
      mainAxisAlignment: MainAxisAlignmentC.start,
    )..parentID = kRootNode;
    await pump(tester, row, [a, b]);
    expect(tester.getRect(rectOf('a')).left, 0);
    expect(tester.getRect(rectOf('b')).left, 50);

    await pump(tester, withVariables(row, {'layoutDirection': 'rtl'}), [a, b]);
    expect(tester.getRect(rectOf('a')).right, 300);
    expect(tester.getRect(rectOf('b')).right, 250);
  });

  group('text', () {
    TextNode text(Map<String, String> variables) => TextNode.fromJson({
      ...TextNode(
        id: 'text',
        name: 'Text',
        basicBoxLocal: NodeBox(0, 0, 200, 20),
        data: 'שלום',
        textAlignHorizontal: TextAlignHorizontalEnum.left,
        textMixedProps: [
          StartEndProp(
            start: 0,
            end: 4,
            fontSize: 14,
            fills: [
              PaintModel.solid(id: 'f', color: ColorRGB.fromHex('#111111')),
            ],
            fontName: FontName.robotoRegular,
          ),
        ],
      ).toJson(),
      'variables': variables,
    })..parentID = kRootNode;

    testWidgets('left-aligned text lines up with the start edge', (
      tester,
    ) async {
      await pump(tester, text({'layoutDirection': 'rtl'}), []);
      final RenderParagraph paragraph = tester.renderObject(
        find.byType(RichText).first,
      );
      expect(paragraph.textAlign, TextAlign.start);
      expect(paragraph.textDirection, TextDirection.rtl);
    });

    testWidgets('a wide left-aligned text sits at the start edge in RTL', (
      tester,
    ) async {
      await pump(tester, text({'layoutDirection': 'rtl'}), []);
      final Rect box = tester.getRect(find.byType(TextNodeBox).first);
      final Rect line = tester.getRect(find.byType(RichText).first);
      expect(line.right, moreOrLessEquals(box.right));
    });

    testWidgets('textAlign follows its binding', (tester) async {
      final rtl = textVariable('rtl', 'false');
      final node = text({
        'textAlign': r"${= rtl == 'true' ? 'right' : 'center'}",
      });
      await pump(tester, node, [], variables: {'rtl': rtl});
      RenderParagraph paragraph() =>
          tester.renderObject(find.byType(RichText).first);
      expect(paragraph().textAlign, TextAlign.center);

      rtl.value = rtl.value.copyWith(value: 'true');
      await tester.pump();
      // Right, which an LTR text keeps on the right (not mapped to end).
      expect(paragraph().textAlign, TextAlign.end);
      expect(
        TextNodeBox.alignmentOf(node, TextAlignHorizontalEnum.right),
        const AlignmentDirectional(1, -1),
      );
    });

    testWidgets('a text field takes bound fonts for its input and hint', (
      tester,
    ) async {
      final query = textVariable('query', 'hello');
      final TextFieldNode field = TextFieldNode.fromJson({
        ...TextFieldNode(
          id: 'field',
          name: 'Field',
          basicBoxLocal: NodeBox(0, 0, 300, 48),
          properties: TextFieldProperties(),
        ).toJson(),
        'variables': {
          'fontFamily': r"${= textDirectionOf(query) == 'rtl' ? 'IBM Plex Sans Arabic' : 'IBM Plex Sans'}",
          'fontSize': r'${= 17}',
        },
      })..parentID = kRootNode;
      final registry = NodeRegistry()..setNodes({field.id: field});
      final manager = PassiveNodeTransformerManager(
        registry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
      final context = CodelesslyContext.empty()..variables['query'] = query;
      late BuildContext host;
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: context,
          child: MaterialApp(
            home: Builder(
              builder: (c) {
                host = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      TextFieldProperties props() => (manager.applyStyleOverrides(
        host,
        field,
      ) as TextFieldNode).properties;
      expect(props().inputStyle.fontName.family, 'IBM Plex Sans');
      expect(props().inputStyle.fontSize, 17);
      expect(props().decoration.hintStyle.fontName.family, 'IBM Plex Sans');

      query.value = query.value.copyWith(value: 'شكرا');
      expect(props().inputStyle.fontName.family, 'IBM Plex Sans Arabic');
      expect(
        props().decoration.hintStyle.fontName.family,
        'IBM Plex Sans Arabic',
      );
    });

    testWidgets('fontFamily and fontSize follow their bindings', (
      tester,
    ) async {
      final lang = textVariable('lang', 'en');
      final node = text({
        'fontFamily': r"${= lang == 'he' ? 'IBM Plex Sans Hebrew' : 'Roboto'}",
        'fontSize': r"${= lang == 'he' ? 18 : 14}",
        'fontWeight': r'${= 700}',
      });
      final registry = NodeRegistry()..setNodes({node.id: node});
      final manager = PassiveNodeTransformerManager(
        registry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
      final context = CodelesslyContext.empty()..variables['lang'] = lang;
      late BuildContext host;
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: context,
          child: MaterialApp(
            home: Builder(
              builder: (c) {
                host = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      TextNode styled() => manager.applyStyleOverrides(host, node) as TextNode;
      expect(styled().textMixedProps.first.fontName.family, 'Roboto');
      expect(styled().textMixedProps.first.fontSize, 14);

      lang.value = lang.value.copyWith(value: 'he');
      final StartEndProp span = styled().textMixedProps.first;
      expect(span.fontName.family, 'IBM Plex Sans Hebrew');
      expect(span.fontName.weight, FontWeightNumeric.w700);
      expect(span.fontSize, 18);
    });
  });
}
