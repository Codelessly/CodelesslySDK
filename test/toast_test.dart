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

  testWidgets('a toast takes its accent edge, radius and width', (
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
            message: 'Alert rules saved',
            duration: 1000,
            accentColor: const ColorRGBA(r: 1, g: 0.83, b: 0, a: 1),
            cornerRadius: 4,
            maxWidth: 460,
          ),
          trigger: TriggerModel(type: TriggerType.click),
        ),
      ],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    final Container plate = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('Alert rules saved'),
            matching: find.byType(Container),
          )
          .first,
    );
    final BoxDecoration decoration = plate.decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(4));
    final border = decoration.border! as BorderDirectional;
    expect(border.start.width, 4);
    expect(plate.constraints!.maxWidth, 460);
    await tester.pump(const Duration(seconds: 2));
  });
}
