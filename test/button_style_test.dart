import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

ButtonNode button(ButtonProperties properties) => (switch (properties.buttonType) {
  ButtonTypeEnum.elevated => ElevatedButtonNode.new,
  ButtonTypeEnum.text => TextButtonNode.new,
  ButtonTypeEnum.outlined => OutlinedButtonNode.new,
  ButtonTypeEnum.icon => IconButtonNode.new,
  ButtonTypeEnum.filled || ButtonTypeEnum.filledTonal => FilledButtonNode.new,
})(
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
        home: Material(
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

  test('Every text-bearing property is listened to, reactions are not', () {
    final ButtonNode node = button(ButtonProperties(label: r'${a} items'))
      ..reactions.add(
        Reaction(
          trigger: TriggerModel(type: TriggerType.click),
          action: SetVariableAction(
            variable: VariableData(id: 'b', name: 'b'),
            newValue: r'${c}',
          ),
        ),
      );
    expect(inlineTextTemplatesOf(node), [r'${a} items']);
    expect(
      inlineTextTemplatesOf(
        TabBarNode(
          id: 'tabs',
          name: 'Tabs',
          basicBoxLocal: NodeBox(0, 0, 100, 40),
          properties: TabBarProperties(
            tabs: [
              TabItem(id: 'a', label: r'${a}'),
              TabItem(id: 'b', label: 'Plain'),
            ],
          ),
        ),
      ),
      [r'${a}'],
    );
    expect(
      inlineTextTemplatesOf(
        TextFieldNode(
          id: 'field',
          name: 'Field',
          basicBoxLocal: NodeBox(0, 0, 200, 48),
          properties: TextFieldProperties(
            decoration: InputDecorationModel(hintText: r'Search ${scope}'),
          ),
        ),
      ),
      [r'Search ${scope}'],
    );
  });

  test('A cloud list listens to the values its query reads', () {
    final ListViewNode list =
        ListViewNode(
          id: 'tasks',
          name: 'Tasks',
          basicBoxLocal: NodeBox(0, 0, 300, 400),
          properties: ListViewProperties(),
          children: [],
        )..setQueryableMixin(
          useCloudDatabase: true,
          collectionPath: r'projects/${projectId}/tasks',
          limit: null,
          whereFilters: [
            const WhereQueryFilter(
              field: 'projectId',
              operator: WhereQueryOperator.equal,
              value: r'${projectId}',
            ),
            const WhereQueryFilter(
              field: 'completed',
              operator: WhereQueryOperator.equal,
              value: r"${= filter == 'completed'}",
            ),
            const WhereQueryFilter(
              field: 'priority',
              operator: WhereQueryOperator.equal,
              value: 'high',
            ),
          ],
          orderByFilters: [],
        );
    final List<String> templates = inlineTextTemplatesOf(list);
    final Set<String> paths = {
      for (final String template in templates) ...{
        ...variablePathRegex
            .allMatches(template)
            .map((match) => match.namedGroup('value'))
            .nonNulls,
        ...FormulaEvaluator.referencedPathsInText(template),
      },
    };
    expect(paths, containsAll(<String>['projectId', 'filter']));
    expect(templates.any((template) => template.contains('high')), isFalse);
  });

  testWidgets('A text field hint with a variable re-renders', (tester) async {
    final Observable<VariableData> scope = Observable(
      VariableData(id: 'scope', name: 'scope', value: 'tasks'),
    );
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
      ..variables['scope'] = scope;
    await pumpNode(
      tester,
      TextFieldNode(
        id: 'field',
        name: 'Field',
        basicBoxLocal: NodeBox(0, 0, 200, 48),
        properties: TextFieldProperties(
          decoration: InputDecorationModel(hintText: r'Search ${scope}'),
        ),
      )..parentID = kRootNode,
      codelesslyContext: codelesslyContext,
    );
    expect(find.text('Search tasks'), findsOneWidget);
    scope.set(scope.value.copyWith(value: 'projects'));
    await tester.pump();
    expect(find.text('Search projects'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('Text button background', () {
    test('is transparent when no button color is set', () {
      final ButtonNode node = ButtonNode.fromJson({
        ...button(ButtonProperties(buttonType: ButtonTypeEnum.text)).toJson(),
      });
      expect(node.properties.buttonColor, isNull);
      expect(background(styleOf(node)), Colors.transparent);
    });

    test('is black when black is set, also read from JSON', () {
      final ButtonNode node = button(
        ButtonProperties(
          buttonType: ButtonTypeEnum.text,
          buttonColor: ColorRGBA.black,
        ),
      );
      expect(background(styleOf(node)), const Color(0xFF000000));
      final ButtonNode read = ButtonNode.fromJson(node.toJson());
      expect(read.properties.buttonColor, ColorRGBA.black);
      expect(background(styleOf(read)), const Color(0xFF000000));
    });

    test('old JSON without the key keeps every type as it rendered', () {
      for (final ButtonTypeEnum type in ButtonTypeEnum.values) {
        final Map json = button(ButtonProperties(buttonType: type)).toJson();
        (json['properties'] as Map).remove('buttonColor');
        final ButtonNode node = ButtonNode.fromJson(json);
        expect(node.properties.buttonColor, isNull, reason: '$type');
        expect(
          node.properties.effectiveButtonColor,
          type == ButtonTypeEnum.text ? ColorRGBA.transparent : ColorRGBA.black,
          reason: '$type',
        );
      }
    });

    testWidgets('renders black and unset text buttons at every size', (
      tester,
    ) async {
      for (final Size size in const [
        Size(390, 844),
        Size(834, 1194),
        Size(1440, 900),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final ColorRGBA? color in [null, ColorRGBA.black]) {
          await pumpNode(
            tester,
            button(
              ButtonProperties(
                buttonType: ButtonTypeEnum.text,
                label: 'Go',
                buttonColor: color,
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          final Rect box = tester.getRect(find.byType(TextButton));
          expect(box.size, const Size(160, 48));
          final Color? fill = tester
              .widget<TextButton>(find.byType(TextButton))
              .style
              ?.backgroundColor
              ?.resolve(const <WidgetState>{});
          expect(
            fill,
            color == null ? Colors.transparent : const Color(0xFF000000),
          );
        }
      }
    });

    test('converting to a text button keeps an unset color unset', () {
      final ButtonNode node = button(ButtonProperties());
      convertNodeToButtonType(ButtonTypeEnum.text, node);
      expect(node.properties.buttonColor, isNull);
      final ButtonNode converted = ButtonNode.fromJson({
        ...node.toJson(),
        'type': 'textButton',
        'properties': node.properties.toJson(),
      });
      expect(background(styleOf(converted)), Colors.transparent);
      final ButtonNode black = button(
        ButtonProperties(buttonColor: ColorRGBA.black),
      );
      convertNodeToButtonType(ButtonTypeEnum.text, black);
      expect(black.properties.buttonColor, ColorRGBA.black.copyWith(a: 0.1));
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
