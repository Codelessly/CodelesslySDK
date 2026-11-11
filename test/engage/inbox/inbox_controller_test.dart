import 'dart:async';

import 'package:codelessly_sdk/src/engage/host.dart';
import 'package:codelessly_sdk/src/engage/inbox/inbox.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_inbox_server.dart';

void main() {
  late MemoryEngageHost host;
  late FakeInboxServer server;

  setUp(() {
    host = MemoryEngageHost(
      identity: const EngageIdentity(anonymousId: 'anon', userId: 'ana'),
    );
    server = FakeInboxServer(host)..install();
  });

  CodelesslyInbox make({
    InboxUrlOpener? openUrl,
    InboxCustomActionHandler? onCustomAction,
    InboxCardTapHandler? onCardTap,
    int pageSize = 20,
  }) => CodelesslyInbox(
    host,
    openUrl: openUrl,
    onCustomAction: onCustomAction,
    onCardTap: onCardTap,
    pageSize: pageSize,
    flushDelay: Duration.zero,
  );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  List<String> names() => [for (final e in host.tracked) e.name];
  int listCalls() => host.calls.where((c) => c.$1 == 'inbox/list').length;

  test(
    'fetches cards, counts unread and keeps control cards out of the list',
    () async {
      server.cards['ana'] = [
        card('a', pinned: true),
        card('b', read: true),
        card('c'),
        card('ctl', type: 'control'),
      ];
      server.config = {
        ...server.config,
        'ui': {'title': 'Updates', 'accentColor': '#FF0000'},
      };
      final inbox = make();
      final seen = <List<String>>[];
      inbox.cards.listen((c) => seen.add([for (final x in c) x.id]));
      await settle();
      expect(inbox.currentCards.map((c) => c.id), ['a', 'b', 'c']);
      expect(inbox.unreadCount.value, 2);
      expect(inbox.state.value.pinned.single.id, 'a');
      expect(inbox.config.ui.title, 'Updates');
      expect(inbox.config.ui.accentColor!.toARGB32(), 0xFFFF0000);
      expect(seen.last, ['a', 'b', 'c']);
      expect(inbox.currentCards.first.extras['sku'], 'a1');

      inbox.opened();
      expect(names(), ['inbox_opened', 'inbox_control_impression']);
      inbox.dispose();
    },
  );

  test(
    'refresh follows the configured interval, minimum gap and change token',
    () async {
      server.cards['ana'] = [card('a')];
      final inbox = make();
      await settle();
      expect(listCalls(), 1);
      await inbox.refresh();
      expect(listCalls(), 1, reason: 'fresh cards are not refetched');
      await inbox.refresh(force: true);
      expect(listCalls(), 1, reason: 'forced refreshes keep the minimum gap');
      host.clock = host.clock.add(const Duration(seconds: 11));
      await inbox.refresh(force: true);
      expect(listCalls(), 2);
      expect(host.calls.last.$2['since'], isNotNull);
      expect(
        inbox.currentCards.single.id,
        'a',
        reason: 'not modified keeps cards',
      );
      host.clock = host.clock.add(const Duration(minutes: 6));
      server.cards['ana']!.add(card('b'));
      await inbox.refresh();
      expect(inbox.currentCards.map((c) => c.id), ['a', 'b']);
      inbox.dispose();
    },
  );

  test(
    'read, unread, dismiss, impressions and clicks reach the server once',
    () async {
      server.cards['ana'] = [
        card('a'),
        card('b'),
        card('c', dismissible: false),
      ];
      final inbox = make();
      await settle();
      final a = inbox.currentCards[0];
      await inbox.markRead(a);
      expect(inbox.unreadCount.value, 2);
      expect(inbox.currentCards[0].read, isTrue);
      await inbox.markUnread(inbox.currentCards[0]);
      expect(inbox.unreadCount.value, 3);
      inbox.logImpression(a);
      inbox.logImpression(a);
      await inbox.dismiss(inbox.currentCards[1]);
      await inbox.dismiss(inbox.currentCards[1]); // c: not dismissible
      expect(inbox.currentCards.map((c) => c.id), ['a', 'c']);
      expect(inbox.unreadCount.value, 2);
      inbox.logClick(a);
      await inbox.flush();
      await settle();
      expect(
        [for (final e in server.tracked['ana']!) '${e['cardId']}:${e['op']}'],
        ['a:read', 'a:unread', 'a:impression', 'b:dismiss', 'a:click'],
      );
      expect(names(), [
        'inbox_card_read',
        'inbox_card_impression',
        'inbox_card_dismissed',
        'inbox_card_clicked',
      ]);
      expect(host.tracked.first.properties['card_id'], 'a');
      expect(inbox.unreadCount.value, 1);
      inbox.dispose();
    },
  );

  test('mark all read', () async {
    server.cards['ana'] = [card('a'), card('b')];
    final inbox = make();
    await settle();
    await inbox.markAllRead();
    expect(inbox.unreadCount.value, 0);
    expect(inbox.currentCards.every((c) => c.read), isTrue);
    expect(host.calls.last.$1, 'inbox/readAll');
    expect(names(), ['inbox_all_read']);
    inbox.dispose();
  });

  test(
    'taps: the app callback first, then open URL, custom key or dismiss',
    () async {
      server.cards['ana'] = [
        card(
          'a',
          tap: {'id': 'tap', 'kind': 'url', 'value': 'https://example.com/x'},
          actions: [
            {
              'id': 'go',
              'label': 'Go',
              'kind': 'custom',
              'value': 'start_tour',
            },
            {'id': 'no', 'label': 'Later', 'kind': 'dismiss', 'value': ''},
          ],
        ),
        card(
          'b',
          tap: {'id': 'tap', 'kind': 'deeplink', 'value': 'myapp://orders/1'},
        ),
      ];
      final opened = <Uri>[];
      final custom = <String>[];
      var intercept = false;
      final inbox = make(
        openUrl: opened.add,
        onCustomAction: (key, card) => custom.add('$key@${card.id}'),
        onCardTap: (tap) => intercept && tap.card.id == 'b',
      );
      await settle();
      final a = inbox.currentCards[0];
      await inbox.handleTap(a);
      expect(opened.single.toString(), 'https://example.com/x');
      await inbox.handleTap(a, action: a.actions[0]);
      expect(custom, ['start_tour@a']);
      intercept = true;
      await inbox.handleTap(inbox.currentCards[1]);
      expect(opened.length, 1, reason: 'the app handled it');
      final viewTaps = <InboxCardTap>[];
      await inbox.handleTap(
        inbox.currentCards[1],
        onTap: (t) {
          viewTaps.add(t);
          return true;
        },
      );
      expect(viewTaps.single.uri.toString(), 'myapp://orders/1');
      await inbox.perform('click', {'cardId': 'a', 'actionId': 'no'});
      expect(inbox.currentCards.map((c) => c.id), ['b']);
      expect(
        names().where((n) => n == 'inbox_card_clicked').length,
        4,
        reason: 'dismiss actions are dismissals, not clicks',
      );
      expect(host.tracked[1].properties['action_id'], 'go');
      inbox.dispose();
    },
  );

  test('without a backend the inbox is empty, unavailable and quiet', () async {
    host.handlers.clear();
    final inbox = make();
    await settle();
    expect(inbox.state.value.available, isFalse);
    expect(inbox.currentCards, isEmpty);
    expect(inbox.unreadCount.value, 0);
    await inbox.markAllRead();
    await inbox.perform('refresh');
    await inbox.perform('click', {'cardId': 'missing'});
    inbox.dispose();
    await inbox.refresh();
  });

  test('server errors land in state, never in the app', () async {
    server.failWith = StateError('boom');
    final inbox = make();
    await settle();
    expect(inbox.state.value.error, contains('boom'));
    expect(inbox.state.value.loading, isFalse);
    inbox.dispose();
  });

  test('offline: cached cards show, changes queue and replay later', () async {
    server.cards['ana'] = [card('a'), card('b')];
    final first = make();
    await settle();
    first.dispose();

    server.failWith = const EngageUnavailable();
    final inbox = make();
    expect(inbox.state.value.fromCache, isTrue);
    expect(inbox.currentCards.map((c) => c.id), ['a', 'b']);
    await settle();
    expect(inbox.state.value.available, isTrue);
    await inbox.markRead(inbox.currentCards[0]);
    await inbox.dismiss(inbox.currentCards[1]);
    await settle();
    expect(server.tracked['ana'], isNull);
    expect(inbox.currentCards.map((c) => c.id), ['a']);
    inbox.dispose();

    // A new session, still offline: the queue survived on the device.
    final again = make();
    expect(again.currentCards.map((c) => c.id), ['a']);
    expect(again.currentCards.single.read, isTrue);
    server.failWith = null;
    host.clock = host.clock.add(const Duration(minutes: 10));
    await again.refresh(force: true);
    await settle();
    expect(
      [for (final e in server.tracked['ana']!) '${e['cardId']}:${e['op']}'],
      ['a:read', 'b:dismiss'],
    );
    expect(again.currentCards.map((c) => c.id), ['a']);
    expect(again.unreadCount.value, 0);
    again.dispose();
  });

  test(
    'an identity change clears the screen and the previous user\'s cache',
    () async {
      server.cards['ana'] = [card('ana-1')];
      server.cards['bo'] = [card('bo-1'), card('bo-2')];
      final inbox = make();
      await settle();
      expect(inbox.currentCards.single.id, 'ana-1');
      expect(
        host.storage.getAll().keys.where((k) => k.contains('.ana')),
        isNotEmpty,
      );

      // Ana's late response must never land on Bo's screen.
      host.clock = host.clock.add(const Duration(minutes: 10));
      server.gate = Completer<void>();
      final late = inbox.refresh(force: true);
      host.identity = const EngageIdentity(anonymousId: 'anon', userId: 'bo');
      expect(inbox.currentCards, isEmpty);
      expect(inbox.unreadCount.value, 0);
      server.gate!.complete();
      server.gate = null;
      await late;
      await settle();
      await settle();
      expect(inbox.currentCards.map((c) => c.id), ['bo-1', 'bo-2']);
      expect(
        host.storage.getAll().keys.where((k) => k.contains('.ana')),
        isEmpty,
      );
      inbox.dispose();
    },
  );

  test('expired cards hide on the device without a refresh', () async {
    server.cards['ana'] = [
      card('a', expiresAt: '2026-01-01T00:05:00.000Z'),
      card('b'),
    ];
    final inbox = make();
    await settle();
    expect(inbox.currentCards.length, 2);
    host.clock = host.clock.add(const Duration(minutes: 6));
    await inbox.markRead(inbox.currentCards[1]);
    expect(inbox.currentCards.map((c) => c.id), ['b']);
    inbox.dispose();
  });

  test('pages load on demand', () async {
    server.cards['ana'] = [for (var i = 0; i < 5; i++) card('c$i')];
    final inbox = make(pageSize: 2);
    await settle();
    expect(inbox.currentCards.length, 2);
    expect(inbox.state.value.hasMore, isTrue);
    expect(
      inbox.unreadCount.value,
      5,
      reason: 'the server counts unseen pages',
    );
    await inbox.loadMore();
    await inbox.perform('loadMore');
    expect(inbox.currentCards.length, 5);
    expect(inbox.state.value.hasMore, isFalse);
    inbox.dispose();
  });

  test('cards round-trip and bind as layout values', () {
    final c = InboxCard.fromJson(
      card(
        'x',
        actions: [
          {'id': 'a', 'label': 'A', 'kind': 'deeplink', 'value': 'app://a'},
        ],
      ),
    )!;
    expect(InboxCard.fromJson(c.toJson()), c);
    final v = c.toValue();
    expect(v['unread'], isTrue);
    expect((v['action1'] as Map)['label'], 'A');
    expect(v['action2'], isNull);
    expect(InboxCard.fromJson({'no': 'id'}), isNull);
    expect(InboxCardType.parse('nope'), InboxCardType.classic);
    expect(const InboxState().toValue()['empty'], isTrue);
  });
}
