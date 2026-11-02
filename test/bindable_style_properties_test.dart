import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Observable<VariableData> variable(
  String name,
  Object? value,
  VariableType type,
) => Observable(VariableData(id: name, name: name, value: value, type: type));

/// A context with a `pal` palette, a `pass` and a `width`.
CodelesslyContext bindingsContext() => CodelesslyContext.empty()
  ..variables['pal'] = variable('pal', {
    'ink': '#1F2B2E',
    'line': '#D9D2C3',
    'paper': '#FBF8F3',
  }, VariableType.map)
  ..variables['pass'] = variable('pass', {
    'accent': '#C8643B',
    'cancelled': true,
    'codeType': 'pdf417',
    'used': true,
    'tilt': -4.6,
  }, VariableType.map)
  ..variables['width'] = variable('width', 680, VariableType.decimal);

Future<BuildContext> pumpWith(
  WidgetTester tester,
  CodelesslyContext codelesslyContext, [
  Widget? child,
]) async {
  late BuildContext context;
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext,
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (c) {
                context = c;
                return child ?? const SizedBox();
              },
            ),
          ),
        ),
      ),
    ),
  );
  return context;
}

PassiveNodeTransformerManager managerFor(BaseNode node) {
  node.parentID = kRootNode;
  final NodeRegistry registry = NodeRegistry()..setNodes({node.id: node});
  return PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
}

void main() {
  group('icon color', () {
    testWidgets('an icon paints the color a palette path gives it', (
      tester,
    ) async {
      for (final (String binding, int argb) in [
        (r'${pal.ink}', 0xFF1F2B2E),
        (r'${pass.accent}', 0xFFC8643B),
      ]) {
        final IconNode node = IconNode(
          id: 'icon',
          name: 'Icon',
          basicBoxLocal: NodeBox(0, 0, 24, 24),
          icon: CupertinoIcon(name: 'battery_full', codepoint: 0xf113),
          color: ColorRGBA.black,
        )..variables['iconColor'] = binding;
        await pumpWith(
          tester,
          bindingsContext(),
          PassiveIconWidget(key: ValueKey(binding), node: node),
        );
        expect(
          tester.widget<Icon>(find.byType(Icon)).color?.toARGB32(),
          argb,
          reason: binding,
        );
      }
    });
  });

  group('switch', () {
    SwitchNode switchNode({bool value = false, Map<String, String>? vars}) =>
        SwitchNode.fromJson({
          'id': 'switch',
          'name': 'Switch',
          'type': 'switch',
          'basicBoxLocal': [0, 0, 59, 40],
          'value': value,
          'properties': <String, dynamic>{},
          'variables': ?vars,
        });

    testWidgets('paints the colors its bindings give it', (tester) async {
      final SwitchNode node = switchNode(
        value: true,
        vars: {
          'activeTrackColor': r'${pal.ink}',
          'inactiveTrackColor': r'${pal.line}',
          'activeThumbColor': r'${pal.paper}',
          'inactiveThumbColor': r'${= 1 > 2 ? "#000000" : "#C8643B"}',
        },
      );
      await pumpWith(
        tester,
        bindingsContext(),
        PassiveSwitchWidget(
          node: node,
          settings: const WidgetBuildSettings(debugLabel: 'test'),
        ),
      );
      final Switch widget = tester.widget<Switch>(find.byType(Switch));
      expect(widget.value, isTrue);
      expect(widget.activeTrackColor?.toARGB32(), 0xFF1F2B2E);
      expect(widget.inactiveTrackColor?.toARGB32(), 0xFFD9D2C3);
      expect(widget.activeThumbColor?.toARGB32(), 0xFFFBF8F3);
      expect(widget.inactiveThumbColor?.toARGB32(), 0xFFC8643B);
    });

    testWidgets('keeps its own colors without bindings', (tester) async {
      await pumpWith(
        tester,
        bindingsContext(),
        PassiveSwitchWidget(
          node: switchNode(),
          settings: const WidgetBuildSettings(debugLabel: 'test'),
        ),
      );
      final Switch widget = tester.widget<Switch>(find.byType(Switch));
      expect(widget.activeTrackColor?.toARGB32(), Colors.black.toARGB32());
    });

    testWidgets('a switch inserted on draws on in a preview too', (
      tester,
    ) async {
      for (final bool isPreview in [false, true]) {
        final SwitchNode node = switchNode(value: true);
        final PassiveNodeTransformerManager manager = managerFor(node);
        await pumpWith(
          tester,
          bindingsContext(),
          Builder(
            key: ValueKey(isPreview),
            builder: (context) =>
                PassiveSwitchTransformer(manager.getNode, manager).buildWidget(
                  node,
                  context,
                  WidgetBuildSettings(debugLabel: 'test', isPreview: isPreview),
                ),
          ),
        );
        expect(
          tester.widget<Switch>(find.byType(Switch)).value,
          isTrue,
          reason: 'isPreview: $isPreview',
        );
      }
    });

    testWidgets('a preview switch still toggles', (tester) async {
      await pumpWith(
        tester,
        bindingsContext(),
        PreviewSwitchWidget(
          node: switchNode(value: true),
          settings: const WidgetBuildSettings(
            debugLabel: 'test',
            isPreview: true,
          ),
        ),
      );
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });
  });

  group('text decoration', () {
    TextNode text(String binding) => TextNode.fromJson({
      'id': 'text',
      'name': 'Text',
      'type': 'text',
      'basicBoxLocal': [0, 0, 80, 20],
      'data': 'LHR',
      'textMixedProps': [
        {'start': 0, 'end': 3},
      ],
      'variables': {'textDecoration': binding},
    });

    testWidgets('a bound decoration styles every span', (tester) async {
      final BuildContext context = await pumpWith(tester, bindingsContext());
      for (final (String binding, TextDecorationEnum expected) in [
        (
          r'${= pass.cancelled ? "lineThrough" : "none"}',
          TextDecorationEnum.strikethrough,
        ),
        (
          r'${= pass.cancelled ? "underline" : "none"}',
          TextDecorationEnum.underline,
        ),
        (
          r'${= pass.cancelled ? "strikethrough" : "none"}',
          TextDecorationEnum.strikethrough,
        ),
      ]) {
        final TextNode node = text(binding);
        final TextNode styled =
            managerFor(node).applyStyleOverrides(context, node) as TextNode;
        expect(styled.textMixedProps.single.textDecoration, expected);
      }

      // `none` turns a static decoration off.
      final TextNode struck = TextNode.fromJson({
        ...text(r'${= pass.cancelled ? "none" : "underline"}').toJson(),
        'textMixedProps': [
          {'start': 0, 'end': 3, 'textDecoration': 'strikethrough'},
        ],
      });
      expect(
        (managerFor(struck).applyStyleOverrides(
          context,
          struck,
        ) as TextNode).textMixedProps.single.textDecoration,
        TextDecorationEnum.none,
      );

      // Something that names no decoration changes nothing.
      final TextNode unknown = text(r'${= "wavy"}');
      expect(
        identical(
          managerFor(unknown).applyStyleOverrides(context, unknown),
          unknown,
        ),
        isTrue,
      );
    });

    testWidgets('the rendered text is struck through', (tester) async {
      final TextNode node = text(
        r'${= pass.cancelled ? "lineThrough" : "none"}',
      );
      final PassiveNodeTransformerManager manager = managerFor(node);
      await pumpWith(
        tester,
        bindingsContext(),
        Builder(
          builder: (context) => manager.buildWidgetFromNode(
            node,
            context,
            settings: const WidgetBuildSettings(debugLabel: 'test'),
          ),
        ),
      );
      final RichText rich = tester.widget<RichText>(
        find.byType(RichText).first,
      );
      final List<TextDecoration?> decorations = [];
      rich.text.visitChildren((span) {
        if (span is TextSpan && span.text != null) {
          decorations.add(span.style?.decoration);
        }
        return true;
      });
      expect(decorations, isNotEmpty);
      expect(decorations, everyElement(TextDecoration.lineThrough));
    });
  });

  group('notch offsets', () {
    FrameNode ticket(Map<String, String> variables) =>
        NodeJsonConverter().fromJson({
              'type': 'frame',
              'id': 'ticket',
              'name': 'Ticket',
              'children': <String>[],
              'basicBoxLocal': [0, 0, 680, 420],
              'fills': [
                {'type': 'solid', 'color': '#FFFFFF'},
              ],
              'notches': [
                {'offset': 146, 'relative': false, 'radius': 10},
                {'offset': 120, 'relative': false, 'fromEnd': true},
              ],
              'variables': variables,
            })!
            as FrameNode;

    testWidgets('a notch offset follows its formula', (tester) async {
      final BuildContext context = await pumpWith(tester, bindingsContext());
      final FrameNode node = ticket({
        'notch-offset-0': r'${= 146 * width / 340}',
      });
      final FrameNode styled =
          managerFor(node).applyStyleOverrides(context, node) as FrameNode;
      expect(styled.notches[0].offset, 292);
      expect(styled.notches[0].relative, isFalse);
      expect(styled.notches[0].radius, 10);
      // The other notch keeps its offset.
      expect(styled.notches[1], node.notches[1]);
    });

    testWidgets('notchOffset moves every notch; an index wins', (tester) async {
      final BuildContext context = await pumpWith(tester, bindingsContext());
      final FrameNode node = ticket({
        'notchOffset': r'${= width / 4}',
        'notch-offset-1': r'${= 60}',
      });
      final FrameNode styled =
          managerFor(node).applyStyleOverrides(context, node) as FrameNode;
      expect(styled.notches.map((n) => n.offset), [170, 60]);

      // A binding that gives no number keeps the notch.
      final FrameNode broken = ticket({'notch-offset-0': r'${missing.value}'});
      expect(
        identical(
          managerFor(broken).applyStyleOverrides(context, broken),
          broken,
        ),
        isTrue,
      );
    });

    test('notchedPath cuts the notch at the bound offset', () {
      final List<NotchModel> notches = [
        const NotchModel(offset: 292, relative: false, radius: 10),
      ];
      final Path path = notchedPath(
        const Size(680, 420),
        BorderRadius.zero,
        notches,
      );
      expect(path.contains(const Offset(3, 292)), isFalse);
      expect(path.contains(const Offset(3, 146)), isTrue);
    });
  });

  group('barcode', () {
    BarcodeNode code(Map<String, String> variables) => BarcodeNode(
      id: 'barcode',
      name: 'Barcode',
      basicBoxLocal: NodeBox(0, 0, 300, 90),
      data: 'M1DOE/JANE',
      properties: BarcodeProperties(symbology: BarcodeSymbology.qrCode),
    )..variables.addAll(variables);

    BarcodePainter painterOf(WidgetTester tester) =>
        tester
                .widget<CustomPaint>(
                  find
                      .descendant(
                        of: find.byType(PassiveBarcodeWidget),
                        matching: find.byType(CustomPaint),
                      )
                      .first,
                )
                .painter!
            as BarcodePainter;

    testWidgets('draws the symbology its binding names', (tester) async {
      for (final (String binding, BarcodeSymbology expected) in [
        (r'${pass.codeType}', BarcodeSymbology.pdf417),
        (r'${= pass.used ? "aztec" : "qrCode"}', BarcodeSymbology.aztec),
        (r'${= "not a code"}', BarcodeSymbology.qrCode),
      ]) {
        await pumpWith(
          tester,
          bindingsContext(),
          PassiveBarcodeWidget(
            key: ValueKey(binding),
            node: code({'symbology': binding}),
            settings: const WidgetBuildSettings(debugLabel: 'test'),
          ),
        );
        expect(painterOf(tester).symbology, expected, reason: binding);
      }
    });

    testWidgets('fades with its opacity binding', (tester) async {
      final BarcodeNode node = code({'opacity': r'${= pass.used ? 0.3 : 1}'});
      final PassiveNodeTransformerManager manager = managerFor(node);
      final BuildContext context = await pumpWith(tester, bindingsContext());
      final BaseNode styled = manager.applyStyleOverrides(context, node);
      expect((styled as BarcodeNode).opacity, closeTo(0.3, 1e-9));

      await pumpWith(
        tester,
        bindingsContext(),
        Builder(
          builder: (context) => manager.buildWidgetFromNode(
            node,
            context,
            settings: const WidgetBuildSettings(debugLabel: 'test'),
          ),
        ),
      );
      final Iterable<Opacity> fades = tester.widgetList<Opacity>(
        find.ancestor(
          of: find.byType(PassiveBarcodeWidget),
          matching: find.byType(Opacity),
        ),
      );
      expect(fades.map((o) => o.opacity), contains(closeTo(0.3, 1e-9)));
    });
  });

  group('rotation', () {
    testWidgets('a bound rotation keeps its fractional degrees', (
      tester,
    ) async {
      final RectangleNode node = RectangleNode.fromJson({
        ...RectangleNode(
          id: 'stamp',
          name: 'Stamp',
          basicBoxLocal: NodeBox(0, 0, 120, 40),
        ).toJson(),
        'variables': {'rotation': r'${pass.tilt}'},
      });
      final BuildContext context = await pumpWith(tester, bindingsContext());
      final BaseNode styled = managerFor(node)
          .applyStyleOverrides(context, node);
      expect(styled.rotationDegrees, -4.6);
    });

    testWidgets('a static fractional rotation is drawn exactly', (
      tester,
    ) async {
      final RectangleNode node = RectangleNode.fromJson({
        ...RectangleNode(
          id: 'stamp',
          name: 'Stamp',
          basicBoxLocal: NodeBox(0, 0, 120, 40),
        ).toJson(),
        'rotation': -4.6,
      });
      expect(node.rotationDegrees, -4.6);
      final BuildContext context = await pumpWith(tester, bindingsContext());
      final Widget rotated = managerFor(node)
          .applyWidgetRotation(context, node, const SizedBox());
      expect(rotated, isA<Transform>());
      final Matrix4 transform = (rotated as Transform).transform;
      // The rotation matrix's [0][1] entry is -sin(angle).
      expect(
        transform.entry(0, 1),
        closeTo(-math.sin(-4.6 * math.pi / 180), 1e-9),
      );
    });
  });
}
