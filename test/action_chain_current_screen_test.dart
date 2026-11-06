import 'dart:async';

import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Darkroom's toasts: "Notes saved" shows, then a delayed action hides it.
/// If the screen that showed it is replaced meanwhile by one that isn't
/// linked to it (opened directly, then replaced), the hide still runs on
/// the screen the app shows now instead of being dropped.
void main() {
  Future<BuildContext?> afterScreenChange(
    WidgetTester tester,
    Widget next,
  ) async {
    final GlobalKey a = GlobalKey();
    await tester.pumpWidget(ActionChainHost(child: SizedBox(key: a)));
    final BuildContext trigger = a.currentContext!;
    final Completer<void> delay = Completer<void>();
    BuildContext? found = trigger;
    ActionChain.run(() {
      // An action after a delay, in the same chain.
      unawaited(
        delay.future.then((_) => found = ActionChain.contextFor(trigger)),
      );
    }, context: trigger);
    await tester.pumpWidget(next);
    delay.complete();
    await tester.pump();
    return found;
  }

  testWidgets(
    'a chain whose screens are all gone finishes on the current screen',
    (tester) async {
      final GlobalKey b = GlobalKey();
      final BuildContext? found = await afterScreenChange(
        tester,
        ActionChainHost(
          key: const ValueKey('next screen'),
          child: SizedBox(key: b),
        ),
      );
      expect(found, isNotNull);
      expect(found!.mounted, isTrue);
    },
  );

  testWidgets('with no screen left at all, nothing is returned', (
    tester,
  ) async {
    expect(await afterScreenChange(tester, const SizedBox()), isNull);
  });
}
