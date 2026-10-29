import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  PaywallAnalyticsEvent event(int index) => PaywallAnalyticsEvent(
    id: 'event-$index',
    name: 'paywall_view',
    placement: 'onboarding_end',
    releaseId: 'release_hash',
    variant: 'default',
    at: DateTime.now().millisecondsSinceEpoch,
  );

  test('consent gate and revocation clear queue', () async {
    final queue = PaywallAnalyticsQueue(
      projectId: 'test',
      uid: 'user',
      send: (_) async => throw StateError('offline'),
    );
    await queue.record(event(1));
    expect(await queue.pending, 0);
    await queue.setConsent(true);
    await queue.record(event(1));
    expect(await queue.pending, 1);
    await queue.setConsent(false);
    expect(await queue.pending, 0);
    queue.dispose();
  });

  test(
    'offline restart retains one stable ID and retries exactly once',
    () async {
      final offline = PaywallAnalyticsQueue(
        projectId: 'test',
        uid: 'user',
        send: (_) async => throw StateError('offline'),
      );
      await offline.setConsent(true);
      await offline.record(event(2));
      await offline.record(event(2));
      expect(await offline.pending, 1);
      offline.dispose();
      final delivered = <String>[];
      final online = PaywallAnalyticsQueue(
        projectId: 'test',
        uid: 'user',
        send: (item) async => delivered.add(item.id),
      );
      await online.setConsent(true);
      expect(delivered, ['event-2']);
      expect(await online.pending, 0);
      online.dispose();
    },
  );

  test('queue keeps latest 100 and never stores receipt data', () async {
    final queue = PaywallAnalyticsQueue(
      projectId: 'test',
      uid: 'user',
      send: (_) async => throw StateError('offline'),
    );
    await queue.setConsent(true);
    for (var i = 0; i < 105; i++) {
      await queue.record(event(i));
    }
    expect(await queue.pending, 100);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('codelessly.paywall.events.test.user')!;
    expect(raw.join(), isNot(contains('receipt')));
    expect(raw.first, contains('event-5'));
    queue.dispose();
  });
}
