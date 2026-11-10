import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A link opens its screen above the entry screen, so the entry screen is
/// built beneath it. Its load actions run when it is first shown, not
/// right away: run then, they came after the top screen's and undid them
/// (the overlay's tab highlight went back to the entry screen's tab).
void main() {
  Widget screen(String id) => PassiveCanvasWidget(
    node: CanvasNode(
      id: id,
      name: id,
      basicBoxLocal: NodeBox(0, 0, 390, 844),
      children: const ['body'],
      properties: CanvasProperties(bodyId: 'body'),
      reactions: [
        Reaction(
          trigger: TriggerModel(type: TriggerType.load),
          action: CallFunctionAction(name: id),
        ),
      ],
    ),
    settings: const WidgetBuildSettings(debugLabel: 'test'),
    builder: (_) => const SizedBox.expand(),
  );

  testWidgets('a screen beneath another loads when it is shown', (
    tester,
  ) async {
    final loads = <String>[];
    final context = CodelesslyContext.empty()
      ..functions = {
        for (final id in ['entry', 'linked'])
          id: (context, reference, params) => loads.add(id),
      };
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: context,
        child: MaterialApp(
          navigatorKey: navigator,
          builder: (context, child) => ActionChainHost(child: child!),
          onGenerateRoute: (_) =>
              MaterialPageRoute(builder: (_) => const SizedBox()),
          onGenerateInitialRoutes: (_) => [
            MaterialPageRoute(builder: (_) => screen('entry')),
            MaterialPageRoute(builder: (_) => screen('linked')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(loads, ['linked']);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(loads, ['linked', 'entry']);

    // Shown again later: it doesn't load twice.
    navigator.currentState!.push(
      MaterialPageRoute(builder: (_) => const SizedBox()),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(loads, ['linked', 'entry']);
  });
}
