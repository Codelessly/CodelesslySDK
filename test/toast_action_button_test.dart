import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('a toast action can be a styled button with its own font size', (
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
          trigger: TriggerModel(type: TriggerType.click),
          action: ShowToastAction(
            message: 'Alert dismissed',
            actionLabel: 'UNDO',
            actions: [ShowToastAction(message: 'Restored')],
            actionStyle: TextStyleModel(fontSize: 17),
            actionBackgroundColor: ColorRGBA.fromHex('#FFFBF2'),
            actionBorder: BorderSideModel(
              color: ColorRGBA.fromHex('#1F2A44')!,
              width: 2.5,
            ),
            actionShadows: [
              Effect(
                id: 'shadow',
                type: EffectType.dropShadow,
                offset: Vec(3, 3),
                radius: 0,
                color: ColorRGBA.fromHex('#1F2A44'),
              ),
            ],
            actionCornerRadius: 6,
          ),
        ),
      ],
    );
    await tester.pump();
    final Finder button = find.byKey(const ValueKey('codelessly-toast-action'));
    final ButtonStyle style = tester.widget<TextButton>(button).style!;
    expect(style.backgroundColor!.resolve({}), const Color(0xFFFFFBF2));
    expect(style.side!.resolve({})!.width, 2.5);
    expect(style.textStyle!.resolve({})!.fontSize, 17);
    final DecoratedBox shadow = tester.widget<DecoratedBox>(
      find.ancestor(of: button, matching: find.byType(DecoratedBox)).first,
    );
    expect((shadow.decoration as BoxDecoration).boxShadow, isNotEmpty);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });
}
