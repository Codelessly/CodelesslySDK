import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Lamplight's scene card button reads "Applied" once its scene is on:
// `"variables": {"data": "${= active ? 'Applied' : 'Apply'}"}` on the label.
// The binding was stored and never read: the label kept its "Apply".

TextNode _label(Map<String, String> variables) => TextNode(
  id: 'label',
  name: 'Label',
  basicBoxLocal: NodeBox(0, 0, 60, 18),
  data: 'Apply',
  horizontalFit: SizeFit.shrinkWrap,
  verticalFit: SizeFit.shrinkWrap,
  textMixedProps: [
    StartEndProp(
      start: 0,
      end: 5,
      fontSize: 14,
      fontName: const FontName(
        family: 'Roboto',
        weight: FontWeightNumeric.w500,
      ),
    ),
  ],
  variables: variables,
)..parentID = kRootNode;

Observable<VariableData> _variable(String name, Object value) => Observable(
  VariableData(
    id: name,
    name: name,
    type: value is bool ? VariableType.boolean : VariableType.text,
    value: value,
  ),
);

Future<void> _pump(
  WidgetTester tester,
  TextNode node,
  CodelesslyContext context, {
  bool preview = false,
}) async {
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: context,
      child: MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: Builder(
            builder: (context) => manager.buildWidgetFromNode(
              node,
              context,
              settings: preview
                  ? const WidgetBuildSettings(
                      debugLabel: 'canvas',
                      isPreview: true,
                      withReactions: false,
                    )
                  : const WidgetBuildSettings(debugLabel: 'runtime'),
            ),
          ),
        ),
      ),
    ),
  );
}

String _shown(WidgetTester tester) =>
    tester.widget<RichText>(find.byType(RichText)).text.toPlainText();

void main() {
  testWidgets('a data binding replaces the text and follows its formula', (
    tester,
  ) async {
    final active = _variable('active', false);
    final context = CodelesslyContext.empty()..variables['active'] = active;
    await _pump(
      tester,
      _label({'data': r"${= active ? 'Applied' : 'Apply'}"}),
      context,
    );
    expect(_shown(tester), 'Apply');
    final double narrow = tester.getSize(find.byType(RichText)).width;

    active.set(active.value.copyWith(value: true));
    await tester.pump();
    expect(_shown(tester), 'Applied');
    // A text that hugs its width grows with the longer label, in the first
    // span's style.
    expect(tester.getSize(find.byType(RichText)).width, greaterThan(narrow));
    final TextStyle style = tester
        .widget<RichText>(find.byType(RichText))
        .text
        .getSpanForPosition(const TextPosition(offset: 3))!
        .style!;
    expect(style.fontSize, 14);
    expect(style.fontWeight, FontWeight.w500);
  });

  testWidgets('a bare variable path binds the data too', (tester) async {
    final context = CodelesslyContext.empty()
      ..variables['label'] = _variable('label', 'Turn on');
    await _pump(tester, _label({'data': 'label'}), context);
    expect(_shown(tester), 'Turn on');
  });

  testWidgets('on the design canvas too', (tester) async {
    final context = CodelesslyContext.empty();
    // The canvas's values, as the editor gives them.
    VariablePreview.scopeResolver = (_) => ScopedValues.preview(
      variables: {'active': _variable('active', true).value},
      codelesslyContext: context,
    );
    addTearDown(() => VariablePreview.scopeResolver = null);
    await _pump(
      tester,
      _label({'data': r"${= active ? 'Applied' : 'Apply'}"}),
      context,
      preview: true,
    );
    expect(_shown(tester), 'Applied');
  });

  test('the style patch carries the data and one span over it', () {
    final TextNode node = _label({'data': r'${item.label}'});
    final Map<String, dynamic> patch = {};
    StyleBindings.addTo(
      patch,
      node,
      scopedValues: ScopedValues.preview(variables: const {}),
    );
    expect(patch['data'], r'${item.label}');
    final List spans = patch['textMixedProps'] as List;
    expect(spans, hasLength(1));
    expect(spans.single['start'], 0);
    expect(spans.single['end'], r'${item.label}'.length);
    expect(spans.single['fontSize'], 14);
  });

  test('without the binding nothing changes', () {
    final Map<String, dynamic> patch = {};
    StyleBindings.addTo(
      patch,
      _label({}),
      scopedValues: ScopedValues.preview(variables: const {}),
    );
    expect(patch, isEmpty);
  });
}
