import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('showToast shows the message with variables, then hides it', (
    tester,
  ) async {
    late BuildContext context;
    final ctx = CodelesslyContext.empty()
      ..variables['drink'] = Observable(
        VariableData(id: 'drink', name: 'drink', value: 'Cortado'),
      );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: ctx,
        child: MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    final reactions = [
      Reaction(
        action: ShowToastAction(
          message: r'Added ${drink} to your order',
          duration: 1000,
        ),
        trigger: TriggerModel(type: TriggerType.click),
      ),
    ];
    FunctionsRepository.triggerAction(
      context,
      TriggerType.click,
      reactions: reactions,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Added Cortado to your order'), findsOneWidget);

    // A second toast replaces the first.
    FunctionsRepository.triggerAction(
      context,
      TriggerType.click,
      reactions: [
        Reaction(
          action: ShowToastAction(message: 'Second', duration: 500),
          trigger: TriggerModel(type: TriggerType.click),
        ),
      ],
    );
    await tester.pump();
    expect(find.text('Added Cortado to your order'), findsNothing);
    expect(find.text('Second'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Second'), findsNothing);
  });

  group('a styled toast', () {
    const Color ink = Color(0xFF1F2B2E);
    const Color paper = Color(0xFFF3ECDD);
    const Color seaGlass = Color(0xFF9CC5B5);
    const Color coral = Color(0xFFD9573B);

    ShowToastAction styled() => ActionModel.fromJson({
      'type': 'showToast',
      'message': 'Ochre sea star added',
      'actionLabel': 'View',
      'duration': 4000,
      'backgroundColor': '#1F2B2E',
      'textColor': '#F3ECDD',
      'actionColor': '#9CC5B5',
      'showClose': true,
      'cornerRadius': 4,
      'border': {'color': '#1F2B2E', 'width': 1.5},
      'shadows': [
        {
          'type': 'dropShadow',
          'radius': 0,
          'spread': 0,
          'color': '#1F2B2E',
          'offset': {'x': 4, 'y': 4},
        },
      ],
      'maxWidth': 480,
      'messageStyle': {
        'fontFamily': 'Work Sans',
        'fontWeight': 'w600',
        'fontSize': 13,
      },
      'actionStyle': {'fontFamily': 'Work Sans', 'fontWeight': 'w600'},
      'icon': {
        'type': 'icon',
        'show': true,
        'color': '#D9573B',
        'icon': {
          'type': 'CUPERTINO_ICON',
          'name': 'star_fill',
          'codepoint': 0xf4b8,
          'fontFamily': 'CupertinoIcons',
        },
      },
      'iconSize': 34,
      'bottomOffset': 24,
      'bottomOffsets': {'mobile': 84},
    }) as ShowToastAction;

    Future<BuildContext> pumpHost(WidgetTester tester, Size size) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      late BuildContext context;
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: CodelesslyContext.empty(),
          child: MaterialApp(
            home: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      return context;
    }

    TextStyle styleOf(WidgetTester tester, String text) => tester
        .widget<RichText>(
          find.descendant(of: find.text(text), matching: find.byType(RichText)),
        )
        .text
        .style!;

    testWidgets('takes its colors, fonts, radius, border, shadow and icon', (
      tester,
    ) async {
      final BuildContext context = await pumpHost(tester, const Size(390, 844));
      AppToast.show(context, styled());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final Container box = tester.widget<Container>(
        find.byKey(const ValueKey('codelessly-toast')),
      );
      final BoxDecoration decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, ink);
      expect(decoration.borderRadius, BorderRadius.circular(4));
      expect(
        decoration.border,
        const Border.fromBorderSide(BorderSide(color: ink, width: 1.5)),
      );
      // The shadow is drawn around the clip that rounds the toast.
      final BoxDecoration outer =
          tester
                  .widget<DecoratedBox>(
                    find
                        .ancestor(
                          of: find.byKey(const ValueKey('codelessly-toast')),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(outer.boxShadow, const [
        BoxShadow(color: ink, offset: Offset(4, 4)),
      ]);
      expect(box.constraints!.maxWidth, 480);

      final String? workSans = TextUtils.retrieveTextStyle(
        fontName: const FontName(
          family: 'Work Sans',
          weight: FontWeightNumeric.w600,
        ),
      ).fontFamily;
      final TextStyle message = styleOf(tester, 'Ochre sea star added');
      expect(message.color, paper);
      expect(message.fontSize, 13);
      expect(message.fontFamily, workSans);
      // The button has its own color, not the message's.
      final TextStyle action = styleOf(tester, 'View');
      expect(action.color, seaGlass);
      expect(action.fontFamily, workSans);

      // The icon takes its own color and the toast's icon size.
      final SvgIcon icon = tester.widget<SvgIcon>(
        find.descendant(
          of: find.byKey(const ValueKey('codelessly-toast')),
          matching: find.byType(SvgIcon),
        ),
      );
      expect(icon.color, coral);
      expect(icon.size, 34);

      // Above a mobile tab bar.
      expect(
        tester.getRect(find.byKey(const ValueKey('codelessly-toast'))).bottom,
        844 - 84,
      );

      // The close button dismisses it.
      final Finder close = find.byKey(const ValueKey('codelessly-toast-close'));
      expect(tester.widget<IconButton>(close).color, paper);
      await tester.tap(close);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Ochre sea star added'), findsNothing);
    });

    testWidgets('sits at the offset of the screen size', (tester) async {
      final BuildContext context = await pumpHost(
        tester,
        const Size(1440, 900),
      );
      AppToast.show(context, styled());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.getRect(find.byKey(const ValueKey('codelessly-toast'))).bottom,
        900 - 24,
      );
      AppToast.hide();
      await tester.pumpAndSettle();
    });
  });

  testWidgets('a toast button can be tapped from the first frame', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    late BuildContext context;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    FunctionsRepository.triggerAction(
      context,
      TriggerType.click,
      reactions: [
        Reaction(
          action: ShowToastAction(
            message: 'Sighting deleted',
            actionLabel: 'Undo',
            actions: [ShowToastAction(message: 'Restored')],
          ),
          trigger: TriggerModel(type: TriggerType.click),
        ),
      ],
    );
    // Its semantics don't change once it shows (the web engine keeps a new
    // node's stacking only while its siblings stay the same).
    await tester.pump();
    expect(
      tester.getSemantics(find.bySemanticsLabel('Undo')),
      matchesSemantics(
        label: 'Undo',
        isButton: true,
        hasTapAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 6));
    handle.dispose();
  });
}
