import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

ButtonNode button(ButtonProperties properties) => ButtonNode(
  id: 'button',
  name: 'Button',
  basicBoxLocal: NodeBox(0, 0, 160, 48),
  properties: properties,
)..parentID = kRootNode;

/// Pumps [node] through the passive manager, as a layout renders it.
Future<void> pumpNode(
  WidgetTester tester,
  BaseNode node, {
  CodelesslyContext? codelesslyContext,
}) async {
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext ?? CodelesslyContext.empty(),
      child: MaterialApp(
        home: Align(
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
  );
}

ButtonStyle styleOf(ButtonNode node) => createMasterButtonStyle(
  node,
  scopedValues: ScopedValues.preview(variables: const {}),
);

Color? background(ButtonStyle style) =>
    style.backgroundColor?.resolve(const <WidgetState>{});

void main() {
  group('A label with inline variables or formulas re-renders', () {
    for (final String label in [r'${count} tasks', r'${= count * 2} tasks']) {
      testWidgets(label, (tester) async {
        final Observable<VariableData> count = Observable(
          VariableData(
            id: 'count',
            name: 'count',
            type: VariableType.integer,
            value: 1,
          ),
        );
        final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
          ..variables['count'] = count;
        await pumpNode(
          tester,
          button(ButtonProperties(label: label)),
          codelesslyContext: codelesslyContext,
        );
        final int factor = label.contains('*') ? 2 : 1;
        expect(find.text('${1 * factor} tasks'), findsOneWidget);

        count.set(count.value.copyWith(value: 3));
        await tester.pump();
        expect(find.text('${3 * factor} tasks'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  test('Chip, badge, tab and segment labels are listened to', () {
    expect(
      inlineTextTemplatesOf(
        TabBarNode(
          id: 'tabs',
          name: 'Tabs',
          basicBoxLocal: NodeBox(0, 0, 100, 40),
          properties: TabBarProperties(
            tabs: [TabItem(id: 'a', label: r'${a}')],
          ),
        ),
      ),
      [r'${a}'],
    );
  });

  group('Text button background', () {
    test('is transparent when no button color is set', () {
      final ButtonNode node = ButtonNode.fromJson({
        ...button(ButtonProperties(buttonType: ButtonTypeEnum.text)).toJson(),
      });
      expect(node.properties.buttonColor, ColorRGBA.black);
      expect(background(styleOf(node)), Colors.transparent);
    });

    test('uses a button color that is set', () {
      final node = button(
        ButtonProperties(
          buttonType: ButtonTypeEnum.text,
          buttonColor: ColorRGBA.fromHex('#C8643B')!,
        ),
      );
      expect(background(styleOf(node)), const Color(0xFFC8643B));
    });

    test('elevated buttons keep the black default', () {
      final node = button(ButtonProperties());
      expect(background(styleOf(node)), const Color(0xFF000000));
    });
  });

  group('Outlined button', () {
    test('is transparent and draws its border color', () {
      final node = button(
        ButtonProperties(
          buttonType: ButtonTypeEnum.outlined,
          borderColor: ColorRGBA.fromHex('#2255AA')!,
          borderWidth: 2,
        ),
      );
      final ButtonStyle style = styleOf(node);
      expect(background(style), Colors.transparent);
      final BorderSide? side = style.side?.resolve(const <WidgetState>{});
      expect(side?.color, const Color(0xFF2255AA));
      expect(side?.width, 2);
    });
  });

  group('Shape', () {
    test('rounded rectangle uses the corner radius', () {
      final node = button(
        ButtonProperties(
          shape: CShapeBorder.roundedRectangle,
          cornerRadius: const CornerRadius.all(RadiusModel.circular(12)),
        ),
      );
      final shape = styleOf(
        node,
      ).shape?.resolve(const <WidgetState>{}) as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(12));
    });

    test('rectangle has sharp corners, as the editor draws it', () {
      final node = button(
        ButtonProperties(
          shape: CShapeBorder.rectangle,
          cornerRadius: const CornerRadius.all(RadiusModel.circular(12)),
        ),
      );
      final shape = styleOf(
        node,
      ).shape?.resolve(const <WidgetState>{}) as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.zero);
    });
  });

  for (final Size size in const [
    Size(390, 844),
    Size(834, 1194),
    Size(1440, 900),
  ]) {
    testWidgets('A text button paints no fill at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpNode(
        tester,
        button(ButtonProperties(buttonType: ButtonTypeEnum.text, label: 'Go')),
      );
      expect(tester.takeException(), isNull);
      final Finder finder = find.byType(TextButton);
      expect(tester.getSize(finder), const Size(160, 48));
      final Material material = tester.widget<Material>(
        find.descendant(of: finder, matching: find.byType(Material)).first,
      );
      expect(material.color, Colors.transparent);
    });
  }
}
