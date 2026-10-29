import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'placement widget calls presenter only once and ignores disposed results',
    (tester) async {
      final result = Completer<PaywallResult>();
      var calls = 0;
      var callbacks = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CodelesslyPaywallPlacement(
            placement: 'onboarding_end',
            presenter: (_, placement) {
              expect(placement, 'onboarding_end');
              calls++;
              return result.future;
            },
            onResult: (_) => callbacks++,
          ),
        ),
      );
      await tester.pump();
      expect(calls, 1);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      result.complete(const PaywallResult(PaywallOutcome.closed));
      await tester.pump();
      expect(callbacks, 0);
    },
  );

  testWidgets(
    'placement route returns cancelled on user back without purchase sheet',
    (tester) async {
      final key = GlobalKey<NavigatorState>();
      final pending = Completer<PaywallResult>();
      PaywallResult? returned;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          home: Builder(
            builder: (context) => TextButton(
              child: const Text('Open'),
              onPressed: () async => returned = await Navigator.of(context)
                  .push(
                    paywallRoute(
                      placement: 'onboarding_end',
                      presenter: (context, placement) => pending.future,
                    ),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await key.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(returned?.outcome, PaywallOutcome.cancelled);
      pending.complete(const PaywallResult(PaywallOutcome.failed));
      await tester.pump();
      expect(returned?.outcome, PaywallOutcome.cancelled);
    },
  );
}
