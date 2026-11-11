import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Observable<VariableData> variable(String name, Object value) => Observable(
  VariableData(
    id: name,
    name: name,
    type: switch (value) {
      bool() => VariableType.boolean,
      int() => VariableType.integer,
      num() => VariableType.decimal,
      _ => VariableType.text,
    },
    value: value,
  ),
);

/// A two-span heading: "Ship " and "faster".
TextNode heading(
  Map<String, String> variables, {
  String data = 'Ship faster',
  Map<String, dynamic> extra = const {},
}) => TextNode.fromJson({
  ...TextNode(
    id: 'heading',
    name: 'Heading',
    basicBoxLocal: NodeBox(0, 0, 400, 40),
    data: data,
    textMixedProps: [
      StartEndProp(
        start: 0,
        end: 5,
        fontSize: 66,
        fontName: const FontName(
          family: 'Roboto',
          weight: FontWeightNumeric.w700,
        ),
      ),
      StartEndProp(
        start: 5,
        end: data.length,
        fontSize: 66,
        fontName: const FontName(
          family: 'Roboto',
          weight: FontWeightNumeric.w400,
          style: 'Italic',
        ),
      ),
    ],
  ).toJson(),
  'variables': variables,
  ...extra,
})..parentID = kRootNode;

class Host {
  Host(
    this.node, {
    Map<String, Observable<VariableData>> variables = const {},
    Map<String, BaseCondition> conditions = const {},
  }) : context = CodelesslyContext.empty()
         ..variables.addAll(variables)
         ..conditions.addAll(conditions) {
    registry.setNodes({node.id: node});
    manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
  }

  final BaseNode node;
  final CodelesslyContext context;
  final NodeRegistry registry = NodeRegistry();
  late final PassiveNodeTransformerManager manager;
  late WidgetTester _tester;

  BaseNode get styled => manager.applyStyleOverrides(
    _tester.element(find.byKey(const Key('host'))),
    node,
  );

  Future<void> pump(WidgetTester tester, {bool isPreview = false}) async {
    _tester = tester;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: context,
        child: MaterialApp(
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: Builder(
                key: const Key('host'),
                builder: (context) => manager.buildWidgetFromNode(
                  node,
                  context,
                  settings: WidgetBuildSettings(
                    debugLabel: 'test',
                    isPreview: isPreview,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The leaf spans of the node's text, with the style each inherits.
List<(String, TextStyle)> leaves(WidgetTester tester) {
  final List<(String, TextStyle)> out = [];
  void visit(InlineSpan span, TextStyle inherited) {
    final TextStyle style = inherited.merge(span.style);
    if (span is TextSpan) {
      if (span.text case final String text when text.isNotEmpty) {
        out.add((text, style));
      }
      for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
        visit(child, style);
      }
    }
  }

  for (final RichText text in tester.widgetList<RichText>(
    find.byType(RichText),
  )) {
    visit(text.text, const TextStyle());
  }
  return out;
}

String shownText(WidgetTester tester) =>
    leaves(tester).map((leaf) => leaf.$1).join();

void main() {
  group('text style bindings', () {
    testWidgets('font size, letter spacing, line height, family and '
        'alignment follow a formula, on every span', (tester) async {
      final isMobile = variable('isMobile', false);
      final host = Host(
        heading({
          'fontSize': r'${= isMobile ? 40 : 66}',
          'letterSpacing': r"${= isMobile ? '-1%' : -2}",
          'lineHeight': r"${= isMobile ? '110%' : 70}",
          'fontFamily': r"${= isMobile ? 'Inter' : 'Roboto'}",
          'textAlign': r"${= isMobile ? 'center' : 'left'}",
        }),
        variables: {'isMobile': isMobile},
      );
      await host.pump(tester);
      TextNode styled = host.styled as TextNode;
      expect(styled.textMixedProps.map((p) => p.fontSize), [66, 66]);
      expect(
        styled.textMixedProps.map((p) => p.letterSpacing),
        everyElement(const LetterSpacing.pixels(-2)),
      );
      expect(
        styled.textMixedProps.map((p) => p.lineHeight),
        everyElement(const LineHeight.pixels(70)),
      );
      expect(styled.textAlignHorizontal, TextAlignHorizontalEnum.left);
      expect(leaves(tester).map((leaf) => leaf.$2.fontSize), everyElement(66));

      isMobile.set(isMobile.value.copyWith(value: true));
      await tester.pump();
      styled = host.styled as TextNode;
      expect(styled.textMixedProps.map((p) => p.fontSize), [40, 40]);
      expect(
        styled.textMixedProps.map((p) => p.letterSpacing),
        everyElement(const LetterSpacing.percent(-1)),
      );
      expect(
        styled.textMixedProps.map((p) => p.lineHeight),
        everyElement(const LineHeight.percent(110)),
      );
      // The family changes; each span keeps its weight and style.
      expect(styled.textMixedProps.map((p) => p.fontName), [
        const FontName(family: 'Inter', weight: FontWeightNumeric.w700),
        const FontName(
          family: 'Inter',
          weight: FontWeightNumeric.w400,
          style: 'Italic',
        ),
      ]);
      expect(styled.textAlignHorizontal, TextAlignHorizontalEnum.center);

      final List<TextStyle> styles = [
        for (final leaf in leaves(tester)) leaf.$2,
      ];
      expect(styles.map((s) => s.fontSize), everyElement(40));
      expect(styles.map((s) => s.letterSpacing), everyElement(-0.4));
      expect(styles.map((s) => s.height), everyElement(closeTo(1.1, 1e-9)));
      expect(
        styles.map((s) => s.fontFamily),
        everyElement(startsWith('Inter')),
      );
      expect(
        tester.widget<RichText>(find.byType(RichText)).textAlign,
        TextAlign.center,
      );
      expect(shownText(tester), 'Ship faster');
    });

    testWidgets('a condition sets the font size', (tester) async {
      final compact = variable('compact', false);
      final host = Host(
        heading({}),
        variables: {'compact': compact},
        conditions: {
          for (final (String id, ValueModel value) in [
            ('size', DoubleValue(name: 'fontSize', value: 32)),
            ('align', StringValue(name: 'textAlign', value: 'right')),
          ])
            id: ConditionGroup(
              id: id,
              ifCondition: Condition(
                id: '$id-if',
                mode: ConditionMode.ifMode,
                expression: Expression(
                  leftPart: VariablePart(valueString: r'${compact}'),
                  operator: ConditionOperation.equalsTo,
                  rightPart: RawValuePart('true'),
                ),
                actions: [
                  SetValueAction(nodeID: 'heading', values: [value]),
                ],
              ),
            ),
        },
      );
      await host.pump(tester);
      expect(leaves(tester).map((leaf) => leaf.$2.fontSize), everyElement(66));

      compact.set(compact.value.copyWith(value: true));
      await tester.pump();
      expect(leaves(tester).map((leaf) => leaf.$2.fontSize), everyElement(32));
      expect(
        (host.styled as TextNode).textAlignHorizontal,
        TextAlignHorizontalEnum.right,
      );
    });

    testWidgets('an unbound text keeps its own style', (tester) async {
      final host = Host(heading({}));
      await host.pump(tester);
      expect(identical(host.styled, host.node), isTrue);
    });

    test('letter spacing reads pixels, percent, em and JSON', () {
      expect(
        StyleBindings.parseLetterSpacing(-1.5),
        const LetterSpacing.pixels(-1.5),
      );
      expect(
        StyleBindings.parseLetterSpacing('2px'),
        const LetterSpacing.pixels(2),
      );
      expect(
        StyleBindings.parseLetterSpacing('-2%'),
        const LetterSpacing.percent(-2),
      );
      expect(
        StyleBindings.parseLetterSpacing('-0.02em'),
        const LetterSpacing.percent(-2),
      );
      expect(
        StyleBindings.parseLetterSpacing({'value': 5, 'unit': 'percent'}),
        const LetterSpacing.percent(5),
      );
      expect(StyleBindings.parseLetterSpacing('wide'), isNull);
    });

    test('line height reads multipliers, pixels, percent, auto and JSON', () {
      expect(StyleBindings.parseLineHeight(28), const LineHeight.pixels(28));
      expect(StyleBindings.parseLineHeight(1.1), const LineHeight.percent(110));
      expect(StyleBindings.parseLineHeight(4.5), const LineHeight.pixels(4.5));
      expect(
        StyleBindings.parseLineHeight('28px'),
        const LineHeight.pixels(28),
      );
      expect(
        StyleBindings.parseLineHeight('120%'),
        const LineHeight.percent(120),
      );
      expect(
        StyleBindings.parseLineHeight('1.2x'),
        const LineHeight.percent(120),
      );
      expect(
        StyleBindings.parseLineHeight('1.5em'),
        const LineHeight.percent(150),
      );
      expect(StyleBindings.parseLineHeight('auto'), LineHeight.auto);
      expect(StyleBindings.parseLineHeight(0), LineHeight.auto);
      expect(
        StyleBindings.parseLineHeight({'value': 140, 'unit': 'percent'}),
        const LineHeight.percent(140),
      );
      expect(StyleBindings.parseLineHeight(-3), isNull);
      expect(StyleBindings.parseLineHeight('tall'), isNull);
    });

    test('text align reads names', () {
      expect(
        StyleBindings.parseTextAlign('Center'),
        TextAlignHorizontalEnum.center,
      );
      expect(
        StyleBindings.parseTextAlign('justify'),
        TextAlignHorizontalEnum.justified,
      );
      expect(StyleBindings.parseTextAlign('end'), TextAlignHorizontalEnum.end);
      expect(StyleBindings.parseTextAlign('middle'), isNull);
    });
  });

  group('margin binding', () {
    RectangleNode box(String binding) => RectangleNode.fromJson({
      ...RectangleNode(
        id: 'toolbar',
        name: 'Toolbar',
        basicBoxLocal: NodeBox(0, 0, 100, 40),
        fills: [PaintModel.solid(id: 'f', color: ColorRGB.fromHex('#222222'))],
      ).toJson(),
      'variables': {'margin': binding},
    })..parentID = kRootNode;

    EdgeInsets? margin(WidgetTester tester) => tester
        .widgetList<Padding>(
          find.ancestor(
            of: find.byType(DecoratedBox).first,
            matching: find.byType(Padding),
          ),
        )
        .map((padding) => padding.padding)
        .whereType<EdgeInsets>()
        .firstOrNull;

    for (final (String binding, EdgeInsets expected) in [
      (r'${= isMobile ? 32 : 44}', const EdgeInsets.all(32)),
      (
        r'${= isMobile ? [16, 8] : 0}',
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      (
        r'${= isMobile ? [1, 2, 3, 4] : 0}',
        const EdgeInsets.fromLTRB(1, 2, 3, 4),
      ),
      (
        r'${= isMobile ? {"top": 32} : {"top": 44}}',
        const EdgeInsets.only(top: 32),
      ),
    ]) {
      testWidgets('reads $binding', (tester) async {
        final host = Host(
          box(binding),
          variables: {'isMobile': variable('isMobile', true)},
        );
        await host.pump(tester);
        expect((host.styled).margin.flutterEdgeInsets, expected);
        expect(margin(tester), expected);
      });
    }
  });

  testWidgets('a span draws its decoration in its color and thickness', (
    tester,
  ) async {
    final TextNode node = TextNode.fromJson({
      'id': 'old-price',
      'name': 'Old price',
      'type': 'text',
      'basicBoxLocal': [0, 0, 60, 20],
      'data': r'$29',
      'textMixedProps': [
        {
          'start': 0,
          'end': 3,
          'textDecoration': 'strikethrough',
          'decorationColor': '#F87171',
          'decorationThickness': 2,
          'decorationStyle': 'dashed',
        },
      ],
    })..parentID = kRootNode;
    await Host(node).pump(tester);
    final TextStyle style = leaves(tester).single.$2;
    expect(style.decoration, TextDecoration.lineThrough);
    expect(style.decorationColor, const Color(0xFFF87171));
    expect(style.decorationThickness, 2);
    expect(style.decorationStyle, TextDecorationStyle.dashed);
  });

  group('inline code', () {
    const Map<String, dynamic> code = {
      'inlineCode': {
        'fontFamily': 'Courier',
        'color': '#4ADE80',
        'background': '#141C17',
        'fontSizeScale': 0.5,
      },
    };

    testWidgets('draws bound text between backticks as code', (tester) async {
      final host = Host(
        heading(
          {},
          data: r'${note}',
          extra: {
            ...code,
            // One range over the whole binding.
            'textMixedProps': [
              {'start': 0, 'end': 7, 'fontSize': 66},
            ],
          },
        ),
        variables: {
          'note': variable('note', 'Retries honor `Retry-After` now'),
        },
      );
      await host.pump(tester);
      expect(shownText(tester), 'Retries honor Retry-After now');
      final List<(String, TextStyle)> parts = leaves(tester);
      final (String, TextStyle) codePart = parts.firstWhere(
        (leaf) => leaf.$1 == 'Retry-After',
      );
      expect(codePart.$2.fontFamily, 'Courier');
      expect(codePart.$2.color, const Color(0xFF4ADE80));
      expect(codePart.$2.backgroundColor, const Color(0xFF141C17));
      expect(codePart.$2.fontSize, 33);
      final (String, TextStyle) prose = parts.firstWhere(
        (leaf) => leaf.$1.startsWith('Retries'),
      );
      expect(prose.$2.fontSize, 66);
      expect(prose.$2.backgroundColor, isNull);
    });

    testWidgets('a segment can span styled ranges', (tester) async {
      // "Ship " | "faster": the code runs from "ip" into "fas".
      final host = Host(heading({}, data: 'Sh`ip fas`ter', extra: code));
      await host.pump(tester);
      expect(shownText(tester), 'Ship faster');
      final List<String> codeParts = [
        for (final leaf in leaves(tester))
          if (leaf.$2.backgroundColor != null) leaf.$1,
      ];
      expect(codeParts.join(), 'ip fas');
      // Each piece keeps its span's weight.
      expect(
        leaves(tester).firstWhere((leaf) => leaf.$1 == 'ip').$2.fontWeight,
        FontWeight.w700,
      );
    });

    testWidgets('paddingSpaces pads each segment in its code style', (
      tester,
    ) async {
      // "Sh`ip " | "fas`ter": one pad where the code starts, one where it
      // ends, across styled ranges; none inside.
      final host = Host(
        heading(
          {},
          data: 'Sh`ip fas`ter, `x`',
          extra: {
            'inlineCode': {
              ...code['inlineCode'] as Map,
              'paddingSpaces': 1,
            },
          },
        ),
      );
      await host.pump(tester);
      expect(shownText(tester), 'Sh ip fas ter,  x ');
      final List<String> codeParts = [
        for (final leaf in leaves(tester))
          if (leaf.$2.backgroundColor != null) leaf.$1,
      ];
      expect(codeParts.join(), ' ip fas  x ');
      expect(
        const InlineCodeStyle(paddingSpaces: 1).toJson(),
        {'paddingSpaces': 1},
      );
      expect(InlineCodeStyle.fromJson({'paddingSpaces': 2}).paddingSpaces, 2);
    });

    testWidgets('backticks stay without the option', (tester) async {
      await Host(heading({}, data: 'Use `x` here')).pump(tester);
      expect(shownText(tester), 'Use `x` here');
    });

    testWidgets('shows on the design canvas too', (tester) async {
      await Host(heading({}, data: 'Run `npm i` first', extra: code))
          .pump(tester, isPreview: true);
      expect(shownText(tester), 'Run npm i first');
    });

    test('an unpaired backtick stays', () {
      expect(InlineCode.strip('a `b` c `d'), 'a b c `d');
      expect(InlineCode.codeSegments('a `b` c `d'), [(3, 4)]);
      expect(InlineCode.strip('``'), '');
    });
  });

  group('count up', () {
    TextNode price() => TextNode.fromJson({
      'id': 'price',
      'name': 'Price',
      'type': 'text',
      'basicBoxLocal': [0, 0, 120, 40],
      'data': r'$${price}/mo',
      'textMixedProps': [
        {'start': 0, 'end': 12, 'fontSize': 40},
      ],
      'countUp': {'durationMs': 400, 'curve': 'linear'},
    })..parentID = kRootNode;

    testWidgets('counts from the old number to the new one', (tester) async {
      final price0 = variable('price', 29);
      final host = Host(price(), variables: {'price': price0});
      await host.pump(tester);
      expect(shownText(tester), r'$29/mo');

      price0.set(price0.value.copyWith(value: 23));
      await tester.pump();
      expect(shownText(tester), r'$29/mo');
      await tester.pump(const Duration(milliseconds: 200));
      expect(shownText(tester), r'$26/mo');
      // 24.5 rounds up.
      await tester.pump(const Duration(milliseconds: 100));
      expect(shownText(tester), r'$25/mo');
      await tester.pump(const Duration(milliseconds: 150));
      expect(shownText(tester), r'$23/mo');
      // Settled: the plain text.
      await tester.pumpAndSettle();
      expect(shownText(tester), r'$23/mo');
    });

    testWidgets('a change mid-count starts from the value shown', (
      tester,
    ) async {
      final price0 = variable('price', 0);
      final host = Host(price(), variables: {'price': price0});
      await host.pump(tester);
      price0.set(price0.value.copyWith(value: 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(shownText(tester), r'$50/mo');
      price0.set(price0.value.copyWith(value: 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(shownText(tester), r'$25/mo');
      await tester.pumpAndSettle();
      expect(shownText(tester), r'$0/mo');
    });

    testWidgets('the design canvas shows the final text', (tester) async {
      await Host(
        price(),
        variables: {'price': variable('price', 29)},
      ).pump(tester, isPreview: true);
      expect(find.byType(CountUpText), findsNothing);
    });

    test('numbers keep their formatting', () {
      final TextNumber grouped = TextNumber.allIn(r'$1,299.00 a year').single;
      expect(grouped.value, 1299);
      expect(grouped.format(1023.456), '1,023.46');
      expect(grouped.format(999), '999.00');
      final TextNumber plain = TextNumber.allIn('Save 20%').single;
      expect(plain.format(12.6), '13');
      expect(TextNumber.allIn('-3 to 4').map((n) => n.value), [-3, 4]);
    });

    test('replaceRange replaces across spans', () {
      const InlineSpan span = TextSpan(
        children: [
          TextSpan(text: r'$2'),
          TextSpan(text: '9/mo'),
        ],
      );
      expect(
        CountUpText.replaceRange(span, 1, 3, '23').toPlainText(),
        r'$23/mo',
      );
    });
  });
}
