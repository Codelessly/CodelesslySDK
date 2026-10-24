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

  testWidgets('a toast can have an orange Undo, a close button, a radius, '
      'a font size, a bound offset and the app font', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext context;
    final ctx = CodelesslyContext.empty()
      ..variables['isMobile'] = Observable(
        VariableData(
          id: 'isMobile',
          name: 'isMobile',
          type: VariableType.boolean,
          value: true,
        ),
      );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: ctx,
        child: MaterialApp(
          home: DefaultTextStyle(
            style: const TextStyle(fontFamily: 'AppBody'),
            child: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
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
            message: 'Session deleted',
            duration: 10000,
            backgroundColor: ColorRGBA.fromHex('#0E2233'),
            textColor: ColorRGBA.white,
            actionLabel: 'UNDO',
            actionColor: ColorRGBA.fromHex('#F2542D'),
            showClose: true,
            cornerRadius: 8,
            fontSize: 13,
            offset: r'${= isMobile ? 72 : 16}',
          ),
          trigger: TriggerModel(type: TriggerType.click),
        ),
      ],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final Text message = tester.widget<Text>(find.text('Session deleted'));
    expect(message.style!.fontSize, 13);
    expect(message.style!.fontFamily, 'AppBody');
    expect(message.style!.color, Colors.white);

    final ButtonStyle undo = tester
        .widget<TextButton>(
          find.byKey(const ValueKey('codelessly-toast-action')),
        )
        .style!;
    expect(
      undo.foregroundColor!.resolve({}),
      ColorRGBA.fromHex('#F2542D')!.toFlutterColor(),
    );

    final BoxDecoration decoration = tester
        .widgetList<Container>(
          find.ancestor(
            of: find.text('Session deleted'),
            matching: find.byType(Container),
          ),
        )
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .first;
    expect(decoration.borderRadius, BorderRadius.circular(8));
    expect(decoration.color, ColorRGBA.fromHex('#0E2233')!.toFlutterColor());

    // 72 px above the bottom, from the bound offset.
    final Positioned positioned = tester.widget<Positioned>(
      find
          .ancestor(
            of: find.text('Session deleted'),
            matching: find.byType(Positioned),
          )
          .first,
    );
    expect(positioned.bottom, 72);

    // The close button hides it.
    await tester.tap(find.byKey(const ValueKey('codelessly-toast-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Session deleted'), findsNothing);
  });

  testWidgets('an existing toast keeps its look without the new fields', (
    tester,
  ) async {
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
    AppToast.show(context, ShowToastAction(message: 'Saved'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<Text>(find.text('Saved')).style!.fontSize, 14);
    expect(find.byKey(const ValueKey('codelessly-toast-close')), findsNothing);
    final Positioned positioned = tester.widget<Positioned>(
      find
          .ancestor(of: find.text('Saved'), matching: find.byType(Positioned))
          .first,
    );
    expect(positioned.bottom, 104);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  test('a toast can set its font family and weight', () {
    const TextStyle app = TextStyle(fontFamily: 'Mono', fontSize: 14);
    final TextStyle plain = AppToast.fontOf(
      ShowToastAction(message: 'Saved'),
      app,
    );
    expect(plain.fontFamily, 'Mono');
    expect(plain.fontWeight, FontWeight.w600);

    final TextStyle custom = AppToast.fontOf(
      ShowToastAction(
        message: 'Saved',
        fontFamily: 'Brand Sans',
        fontWeight: FontWeightNumeric.w500,
      ),
      app,
    );
    expect(custom.fontFamily, 'Brand Sans');
    expect(custom.fontWeight, FontWeight.w500);
    expect(custom.fontSize, 14);
  });
}
