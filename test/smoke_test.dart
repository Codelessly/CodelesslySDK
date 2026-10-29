import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

/// Hosts [child] with a [CodelesslyContext] that has [functions], so
/// reactions with a call-function action can be observed.
Widget hostWithContext(
  Widget child, {
  Map<String, CodelesslyFunction> functions = const {},
}) => ChangeNotifierProvider<CodelesslyContext>.value(
  value: CodelesslyContext.empty()..functions = {...functions},
  child: host(child),
);

/// A Cupertino icon renders from the bundled font; Material icons load SVGs
/// over the network, which widget tests cannot reach.
final heartIcon = MultiSourceIconModel(
  size: 18,
  icon: CupertinoIcon(codepoint: CupertinoIcons.heart.codePoint, name: 'heart'),
);

Reaction callFunction(TriggerType type, String name) => Reaction(
  action: CallFunctionAction(name: name),
  trigger: TriggerModel(type: type),
);

PassiveNodeTransformerManager managerFor(List<BaseNode> nodes) {
  final registry = NodeRegistry()
    ..setNodes({for (final node in nodes) node.id: node});
  return PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
}

void main() {
  const settings = WidgetBuildSettings(debugLabel: 'test');

  testWidgets('radio renders inside a RadioGroup', (tester) async {
    final node = RadioNode(
      id: 'r',
      name: 'r',
      basicBoxLocal: NodeBox(0, 0, 40, 40),
      value: 'a',
      groupValue: 'b',
      properties: RadioProperties(
        innerRadius: 5,
        backgroundColor: ColorRGBA.white,
        side: const BorderSideModel(width: 2),
      ),
    );
    String? changed;
    await tester.pumpWidget(
      host(
        PassiveRadioWidget(
          node: node,
          onChanged: (_, v) => changed = v,
          settings: settings,
        ),
      ),
    );
    expect(find.byType(RadioGroup<String>), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(Radio<String>));
    expect(changed, 'a');
  });

  testWidgets('slider renders every shape and indicator mode', (tester) async {
    for (final track in SliderTrackShapeEnum.values) {
      for (final indicator in SliderValueIndicatorShape.values) {
        final node = SliderNode(
          id: 's',
          name: 's',
          basicBoxLocal: NodeBox(0, 0, 300, 48),
          value: 20,
          properties: SliderProperties(
            trackShape: track,
            valueIndicatorShape: indicator,
            showValueIndicator: ShowValueIndicatorC.alwaysVisible,
            secondaryTrackValue: 50,
            padding: const EdgeInsetsModel.all(4),
          ),
        );
        await tester.pumpWidget(
          host(
            TransformerSlider(
              node: node,
              value: 20,
              onChanged: (_) {},
              settings: settings,
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$track $indicator');
      }
    }
  });

  testWidgets('a rectangular slider thumb takes its size', (tester) async {
    final node = SliderNode(
      id: 's',
      name: 's',
      basicBoxLocal: NodeBox(0, 0, 300, 48),
      value: 20,
      properties: SliderProperties(
        thumbShape: SliderThumbShapeEnum.rectangle,
        thumbWidth: 18,
        thumbHeight: 24,
        thumbBorderColor: ColorRGBA.white,
        thumbGripColor: ColorRGBA.white,
      ),
    );
    await tester.pumpWidget(
      host(
        TransformerSlider(
          node: node,
          value: 20,
          onChanged: (_) {},
          settings: settings,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final SliderThemeData theme = tester
        .widget<SliderTheme>(find.byType(SliderTheme).last)
        .data;
    final shape = theme.thumbShape! as RectSliderThumbShape;
    expect(shape.getPreferredSize(true, false), const Size(18, 24));
    expect(shape.gripColor, isNotNull);
  });

  testWidgets('badge renders every type, alone and on a child', (tester) async {
    final child = IconNode(
      id: 'icon',
      name: 'Icon',
      basicBoxLocal: NodeBox(0, 0, 24, 24),
      icon: heartIcon.icon,
    );
    for (final type in BadgeType.values) {
      for (final childID in [null, 'icon', 'missing']) {
        final node = BadgeNode(
          id: 'badge',
          name: 'Badge',
          basicBoxLocal: NodeBox(0, 0, 48, 48),
          childID: childID,
          properties: BadgeProperties(
            badgeType: type,
            label: '1200',
            maxCount: 99,
            backgroundColor: ColorRGBA.black,
            textColor: ColorRGBA.white,
            alignment: BadgeAlignment.bottomLeft,
            offsetX: 2,
            offsetY: 2,
            smallSize: 8,
            largeSize: 18,
            padding: const EdgeInsetsModel.symmetric(horizontal: 6),
          ),
        );
        final manager = managerFor([node, child]);
        await tester.pumpWidget(
          hostWithContext(
            PassiveBadgeWidget(
              node: node,
              settings: settings,
              manager: manager,
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$type $childID');
        expect(find.byType(Badge), findsOneWidget);
        expect(
          find.text('99+'),
          type == BadgeType.count ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(Icon),
          childID == 'icon' ? findsOneWidget : findsNothing,
          reason: '$type $childID',
        );
      }
    }
  });

  testWidgets('hidden badge renders nothing but its child', (tester) async {
    final node = BadgeNode(
      id: 'badge',
      name: 'Badge',
      basicBoxLocal: NodeBox(0, 0, 48, 48),
      properties: BadgeProperties(label: '3', isLabelVisible: false),
    );
    await tester.pumpWidget(
      hostWithContext(
        PassiveBadgeWidget(
          node: node,
          settings: settings,
          manager: managerFor([node]),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('chip renders every type', (tester) async {
    for (final type in ChipType.values) {
      for (final selected in [false, true]) {
        final node = ChipNode(
          id: 'chip',
          name: 'Chip',
          basicBoxLocal: NodeBox(0, 0, 160, 32),
          properties: ChipProperties(
            chipType: type,
            label: 'Label',
            icon: heartIcon,
            deleteIcon: heartIcon,
            deleteIconColor: ColorRGBA.black,
            selected: selected,
            showCheckmark: !selected,
            checkmarkColor: ColorRGBA.white,
            backgroundColor: ColorRGBA.white,
            selectedColor: ColorRGBA.black,
            borderColor: ColorRGBA.black,
            borderWidth: 2,
            cornerRadius: 16,
            elevation: 2,
            shadowColor: ColorRGBA.black,
            padding: const EdgeInsetsModel.all(4),
            labelPadding: const EdgeInsetsModel.symmetric(horizontal: 4),
            tooltip: 'Tooltip',
          ),
        );
        await tester.pumpWidget(
          hostWithContext(PassiveChipWidget(node: node, settings: settings)),
        );
        expect(tester.takeException(), isNull, reason: '$type $selected');
        expect(find.text('Label'), findsOneWidget);
      }
    }
  });

  testWidgets('chip presses and selections fire their reactions', (
    tester,
  ) async {
    for (final type in [ChipType.action, ChipType.filter]) {
      final calls = <String>[];
      final node = ChipNode(
        id: 'chip',
        name: 'Chip',
        basicBoxLocal: NodeBox(0, 0, 120, 32),
        reactions: [
          callFunction(TriggerType.click, 'click'),
          callFunction(TriggerType.changed, 'changed'),
        ],
        properties: ChipProperties(chipType: type, label: 'Tap'),
      );
      await tester.pumpWidget(
        hostWithContext(
          PassiveChipWidget(node: node, settings: settings),
          functions: {
            'click': (context, reference, params) => calls.add('click'),
            'changed': (context, reference, params) => calls.add('changed'),
          },
        ),
      );
      await tester.tap(find.text('Tap'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        calls,
        type == ChipType.filter ? ['changed', 'click'] : ['click'],
        reason: '$type',
      );
    }
  });

  testWidgets('segmented button renders and reports selection changes', (
    tester,
  ) async {
    final node = SegmentedButtonNode(
      id: 'segmented',
      name: 'Segmented',
      basicBoxLocal: NodeBox(0, 0, 300, 40),
      properties: SegmentedButtonProperties(
        segments: [
          const ButtonSegmentModel(value: 'day', label: 'Day'),
          const ButtonSegmentModel(value: 'week', label: 'Week'),
          ButtonSegmentModel(value: 'month', icon: heartIcon, tooltip: 'M'),
          const ButtonSegmentModel(value: 'off', label: 'Off', enabled: false),
        ],
        selected: const ['day'],
        selectedIcon: heartIcon,
        borderColor: ColorRGBA.black,
        borderWidth: 2,
        selectedBackgroundColor: ColorRGBA.black,
        backgroundColor: ColorRGBA.white,
        selectedForegroundColor: ColorRGBA.white,
        foregroundColor: ColorRGBA.black,
      ),
    );
    Set<String>? changed;
    await tester.pumpWidget(
      host(
        TransformerSegmentedButton(
          node: node,
          settings: settings,
          selected: const {'day'},
          onSelectionChanged: (_, selection) => changed = selection,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(SegmentedButton<String>), findsOneWidget);
    await tester.tap(find.text('Week'));
    expect(changed, {'week'});
  });

  testWidgets('segmented button selection fires its changed reaction', (
    tester,
  ) async {
    final calls = <String>[];
    final node = SegmentedButtonNode(
      id: 'segmented',
      name: 'Segmented',
      basicBoxLocal: NodeBox(0, 0, 300, 40),
      reactions: [callFunction(TriggerType.changed, 'changed')],
      properties: SegmentedButtonProperties(
        multiSelectionEnabled: true,
        selected: const ['option1'],
      ),
    );
    await tester.pumpWidget(
      hostWithContext(
        PassiveSegmentedButtonWidget(node: node, settings: settings),
        functions: {
          'changed': (context, reference, params) => calls.add('changed'),
        },
      ),
    );
    await tester.tap(find.text('Option 2'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(calls, ['changed']);
  });

  testWidgets('segmented button tolerates selections it cannot show', (
    tester,
  ) async {
    for (final properties in [
      SegmentedButtonProperties(),
      SegmentedButtonProperties(selected: const ['option1', 'option2']),
      SegmentedButtonProperties(selected: const ['missing']),
      SegmentedButtonProperties(segments: const []),
      SegmentedButtonProperties(
        segments: const [ButtonSegmentModel(value: 'bare')],
        direction: AxisC.vertical,
        showSelectedIcon: false,
      ),
    ]) {
      final node = SegmentedButtonNode(
        id: 'segmented',
        name: 'Segmented',
        basicBoxLocal: NodeBox(0, 0, 300, 120),
        properties: properties,
      );
      await tester.pumpWidget(
        host(
          TransformerSegmentedButton(
            node: node,
            settings: settings,
            selected: properties.selected.toSet(),
            onSelectionChanged: (_, _) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: '$properties');
    }
  });

  test('segmented button reads bound selections', () {
    expect(PassiveSegmentedButtonWidget.parseSelection(null), isNull);
    expect(PassiveSegmentedButtonWidget.parseSelection(['a', 1]), {'a', '1'});
    expect(PassiveSegmentedButtonWidget.parseSelection('["a","b"]'), {
      'a',
      'b',
    });
    expect(PassiveSegmentedButtonWidget.parseSelection('[a, b]'), {'a', 'b'});
    expect(PassiveSegmentedButtonWidget.parseSelection('[]'), isEmpty);
    expect(PassiveSegmentedButtonWidget.parseSelection('a'), {'a'});
  });

  // The editor measures wrap-content nodes offscreen, under loose constraints
  // and without a Material ancestor.
  testWidgets('badge, chip and segmented button wrap their content', (
    tester,
  ) async {
    const measure = WidgetBuildSettings(
      debugLabel: 'test',
      withMargins: false,
      withConstraints: false,
      withAlignment: false,
      isPreview: true,
    );
    final nodes = <BaseNode>[
      BadgeNode(
        id: 'badge',
        name: 'Badge',
        basicBoxLocal: NodeBox(0, 0, 48, 48),
        horizontalFit: SizeFit.shrinkWrap,
        verticalFit: SizeFit.shrinkWrap,
        properties: BadgeProperties(label: '3'),
      ),
      for (final type in ChipType.values)
        ChipNode(
          id: 'chip-${type.name}',
          name: 'Chip',
          basicBoxLocal: NodeBox(0, 0, 100, 32),
          horizontalFit: SizeFit.shrinkWrap,
          verticalFit: SizeFit.shrinkWrap,
          properties: ChipProperties(chipType: type, label: 'Label'),
        ),
      SegmentedButtonNode(
        id: 'segmented',
        name: 'Segmented',
        basicBoxLocal: NodeBox(0, 0, 200, 40),
        horizontalFit: SizeFit.shrinkWrap,
        verticalFit: SizeFit.shrinkWrap,
        properties: SegmentedButtonProperties(
          segments: const [
            ButtonSegmentModel(value: 'a', label: 'A'),
            ButtonSegmentModel(value: 'b', label: 'B'),
          ],
          selected: const ['a'],
        ),
      ),
    ];
    final manager = managerFor(nodes);
    for (final node in nodes) {
      final key = GlobalKey();
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: CodelesslyContext.empty(),
          // MaterialApp without a Scaffold: localizations but no Material.
          child: MaterialApp(
            home: Center(
              child: Builder(
                builder: (context) => KeyedSubtree(
                  key: key,
                  child: manager.buildWidgetByID(
                    node.id,
                    context,
                    settings: measure,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: node.id);
      final size = tester.getSize(find.byKey(key));
      expect(size.width, lessThan(300), reason: '${node.id} $size');
      expect(size.height, lessThan(100), reason: '${node.id} $size');
    }
  });
}
