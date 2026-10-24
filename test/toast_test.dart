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

  testWidgets('a toast with showCloseButton closes from its close button', (
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
    FunctionsRepository.triggerAction(
      context,
      TriggerType.click,
      reactions: [
        Reaction(
          action: ShowToastAction(
            message: '#025 deleted',
            duration: 10000,
            actionLabel: 'Undo',
            showCloseButton: true,
            actionColor: ColorRGBA.fromHex('#FF6A13'),
            cornerRadius: 10,
          ),
          trigger: TriggerModel(type: TriggerType.click),
        ),
      ],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('#025 deleted'), findsOneWidget);

    // The action label takes actionColor.
    final TextButton undo = tester.widget(
      find.byKey(const ValueKey('codelessly-toast-action')),
    );
    expect(
      undo.style?.foregroundColor?.resolve(<WidgetState>{}),
      const Color(0xFFFF6A13),
    );
    // The toast is a rounded rectangle of cornerRadius.
    final Container box = tester.widget(
      find
          .ancestor(
            of: find.text('#025 deleted'),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      (box.decoration! as BoxDecoration).borderRadius,
      BorderRadius.circular(10),
    );

    await tester.tap(find.byKey(const ValueKey('codelessly-toast-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('#025 deleted'), findsNothing);
  });
}
