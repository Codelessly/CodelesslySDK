import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRestore implements PurchaseService {
  final events = StreamController<PaywallResult>.broadcast();
  int restores = 0;
  @override
  Stream<PaywallResult> get updates => events.stream;
  @override
  Future<void> restore() async {
    restores++;
  }

  @override
  Future<List<PaywallProduct>> products(List<ProductSlot> slots) async => [];
  @override
  Future<void> purchase(PaywallProduct product) async {}
  @override
  Future<void> dispose() => events.close();
}

void main() {
  testWidgets('fallback has restore and real legal links but no purchase CTA', (
    tester,
  ) async {
    final service = FakeRestore();
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PaywallUnavailableFallback(
          onClose: () {},
          restoreService: service,
          termsUrl: Uri.parse('https://example.org/terms'),
          privacyUrl: Uri.parse('https://example.org/privacy'),
          openLegal: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      ),
    );
    expect(find.text('Restore purchases'), findsOneWidget);
    expect(find.text('Terms of service'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.textContaining('Buy'), findsNothing);
    await tester.tap(find.text('Terms of service'));
    await tester.tap(find.text('Privacy policy'));
    await tester.pump();
    expect(opened.map((uri) => uri.path), ['/terms', '/privacy']);
    await tester.tap(find.text('Restore purchases'));
    await tester.pump();
    expect(service.restores, 1);
    service.events.add(const PaywallResult(PaywallOutcome.restoreNothing));
    await tester.pump();
    expect(find.text('No purchases found'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await service.dispose();
  });

  testWidgets('missing legal URLs never launch placeholder links', (
    tester,
  ) async {
    var launches = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PaywallUnavailableFallback(
          onClose: () {},
          openLegal: (_) async {
            launches++;
            return true;
          },
        ),
      ),
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Terms of service'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Privacy policy'))
          .onPressed,
      isNull,
    );
    expect(launches, 0);
  });
}
