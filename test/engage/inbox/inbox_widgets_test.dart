import 'package:codelessly_sdk/src/engage/host.dart';
import 'package:codelessly_sdk/src/engage/inbox/inbox.dart';
import 'package:flutter/material.dart';
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
    CodelesslyInbox.layoutBuilder = null;
  });

  Widget app(Widget home, {Brightness brightness = Brightness.light}) =>
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: home,
      );

  CodelesslyInbox make({InboxUrlOpener? openUrl}) =>
      CodelesslyInbox(host, openUrl: openUrl, flushDelay: Duration.zero);

  List<String> names() => [for (final e in host.tracked) e.name];

  for (final brightness in Brightness.values) {
    testWidgets('renders every card type in ${brightness.name} mode', (
      tester,
    ) async {
      server.cards['ana'] = [
        card('p', title: 'Pinned news', pinned: true),
        card(
          'ann',
          type: 'announcement',
          title: 'Big sale',
          actions: [
            {
              'id': 'shop',
              'label': 'Shop now',
              'kind': 'url',
              'value': 'https://x.co',
            },
            {'id': 'no', 'label': 'Later', 'kind': 'dismiss', 'value': ''},
          ],
        ),
        card(
          'cap',
          type: 'captioned',
          title: 'Photo',
          imageUrl: 'https://x.co/a.png',
        ),
        card(
          'img',
          type: 'image',
          title: 'Banner',
          imageUrl: 'https://x.co/b.png',
        ),
        card('cls', title: 'Thumb', imageUrl: 'https://x.co/c.png', read: true),
      ];
      final inbox = make();
      await tester.pumpWidget(
        app(
          Scaffold(body: CodelesslyInboxView(inbox: inbox)),
          brightness: brightness,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('PINNED'), findsOneWidget);
      expect(find.text('Pinned news'), findsOneWidget);
      expect(find.text('Big sale'), findsOneWidget);
      expect(find.text('Shop now'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Photo'), findsOneWidget);
      expect(find.byType(InboxNetworkImage), findsWidgets);
      expect(find.text('12h'), findsWidgets);
      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp('Unread')), findsWidgets);
      expect(find.byIcon(Icons.broken_image_outlined), findsWidgets);
      semantics.dispose();
      expect(tester.takeException(), isNull);
      expect(names().first, 'inbox_opened');
      expect(names().where((n) => n == 'inbox_card_impression'), isNotEmpty);
      inbox.dispose();
    });
  }

  testWidgets('remote config drives texts and colors; empty state', (
    tester,
  ) async {
    server.config = {
      ...server.config,
      'ui': {
        'emptyTitle': 'Nothing yet',
        'emptyBody': 'Check back soon',
        'backgroundColor': '#102030',
      },
    };
    final inbox = make();
    await tester.pumpWidget(
      app(Scaffold(body: CodelesslyInboxView(inbox: inbox))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nothing yet'), findsOneWidget);
    expect(find.text('Check back soon'), findsOneWidget);
    final box = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(CodelesslyInboxView),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(box.color.toARGB32(), 0xFF102030);
    inbox.dispose();
  });

  testWidgets('impressions are logged once, for cards on screen only', (
    tester,
  ) async {
    server.cards['ana'] = [
      for (var i = 0; i < 20; i++) card('c$i', title: 'Card $i'),
    ];
    final inbox = make();
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(Scaffold(body: CodelesslyInboxView(inbox: inbox))),
    );
    await tester.pumpAndSettle();
    final seen = host.tracked
        .where((e) => e.name == 'inbox_card_impression')
        .map((e) => e.properties['card_id'])
        .toList();
    expect(seen, isNotEmpty);
    expect(seen.length, lessThan(20));
    expect(seen.toSet().length, seen.length);
    await tester.pumpWidget(
      app(Scaffold(body: CodelesslyInboxView(inbox: inbox))),
    );
    await tester.pumpAndSettle();
    expect(
      host.tracked.where((e) => e.name == 'inbox_card_impression').length,
      seen.length,
    );
    inbox.dispose();
  });

  testWidgets('taps open URLs through the app; buttons; swipe to dismiss', (
    tester,
  ) async {
    server.cards['ana'] = [
      card(
        'a',
        title: 'Order shipped',
        tap: {'id': 'tap', 'kind': 'deeplink', 'value': 'myapp://orders/42'},
      ),
      card(
        'b',
        title: 'Promo',
        actions: [
          {
            'id': 'go',
            'label': 'Open',
            'kind': 'url',
            'value': 'https://x.co/p',
          },
        ],
      ),
      card('c', title: 'Swipe me'),
    ];
    final opened = <String>[];
    final inbox = make(openUrl: (u) => opened.add('$u'));
    await tester.pumpWidget(
      app(Scaffold(body: CodelesslyInboxView(inbox: inbox))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Order shipped'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Open'));
    await tester.pumpAndSettle();
    expect(opened, ['myapp://orders/42', 'https://x.co/p']);
    expect(inbox.unreadCount.value, 1);

    await tester.drag(find.text('Swipe me'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Swipe me'), findsNothing);
    expect(
      server.tracked['ana']!.map((e) => e['op']),
      containsAll(['click', 'dismiss']),
    );
    expect(tester.takeException(), isNull);
    inbox.dispose();
  });

  testWidgets('the view callback can take over a tap', (tester) async {
    server.cards['ana'] = [
      card(
        'a',
        title: 'Custom',
        tap: {'id': 'tap', 'kind': 'custom', 'value': 'open_settings'},
      ),
    ];
    final keys = <String?>[];
    final inbox = make();
    await tester.pumpWidget(
      app(
        Scaffold(
          body: CodelesslyInboxView(
            inbox: inbox,
            onCardTap: (tap) {
              keys.add(tap.key);
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(keys, ['open_settings']);
    inbox.dispose();
  });

  testWidgets('pull to refresh forces a refresh', (tester) async {
    server.cards['ana'] = [card('a', title: 'First')];
    final inbox = make();
    await tester.pumpWidget(
      app(Scaffold(body: CodelesslyInboxView(inbox: inbox))),
    );
    await tester.pumpAndSettle();
    host.clock = host.clock.add(const Duration(seconds: 30));
    server.cards['ana']!.add(card('b', title: 'Second'));
    await tester.fling(find.text('First'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
    inbox.dispose();
  });

  testWidgets('the badge shows the unread count and follows it', (
    tester,
  ) async {
    server.cards['ana'] = [card('a'), card('b')];
    final inbox = make();
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Center(
            child: CodelesslyInboxBadge(
              inbox: inbox,
              child: const Icon(Icons.notifications),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    final semantics = tester.ensureSemantics();
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('2 unread messages')), findsOneWidget);
    semantics.dispose();
    await inbox.markAllRead();
    await tester.pump();
    expect(find.text('2'), findsNothing);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    inbox.dispose();
  });

  testWidgets('the full-screen presenter, with mark all read', (tester) async {
    server.cards['ana'] = [card('a', title: 'Hello')];
    server.config = {
      ...server.config,
      'ui': {'title': 'Updates'},
    };
    final inbox = make();
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCodelesslyInbox(context, inbox),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Updates'), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
    await tester.tap(find.byTooltip('Mark all as read'));
    await tester.pumpAndSettle();
    expect(inbox.unreadCount.value, 0);
    expect(find.byTooltip('Mark all as read'), findsNothing);
    inbox.dispose();
  });

  testWidgets('a Codelessly layout can draw cards and the inbox', (
    tester,
  ) async {
    server.cards['ana'] = [
      card('a', title: 'Laid out', layoutId: 'card_layout'),
    ];
    final requests = <InboxLayoutRequest>[];
    CodelesslyInbox.layoutBuilder = (context, request) {
      requests.add(request);
      if (request.layoutId != 'card_layout') return null;
      final c = request.data['card'] as Map;
      return TextButton(
        onPressed: () => request.perform('dismiss', {'cardId': c['id']}),
        child: Text('layout:${c['title']}'),
      );
    };
    final inbox = make();
    await tester.pumpWidget(
      app(Scaffold(body: CodelesslyInboxView(inbox: inbox))),
    );
    await tester.pumpAndSettle();
    expect(find.text('layout:Laid out'), findsOneWidget);
    await tester.tap(find.text('layout:Laid out'));
    await tester.pumpAndSettle();
    expect(inbox.currentCards, isEmpty);
    expect(requests.first.card!.id, 'a');
    inbox.dispose();
    CodelesslyInbox.layoutBuilder = null;
  });

  testWidgets('cards stay readable on a tablet', (tester) async {
    server.cards['ana'] = [card('a', title: 'Wide')];
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final inbox = make();
    await tester.pumpWidget(
      app(Scaffold(body: CodelesslyInboxView(inbox: inbox))),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(CodelesslyInboxCard)).width,
      lessThanOrEqualTo(680),
    );
    inbox.dispose();
  });

  testWidgets('unavailable backend shows the empty state without errors', (
    tester,
  ) async {
    host.handlers.clear();
    final inbox = make();
    await tester.pumpWidget(
      app(Scaffold(body: CodelesslyInboxView(inbox: inbox))),
    );
    await tester.pumpAndSettle();
    expect(find.text("You're all caught up"), findsOneWidget);
    expect(tester.takeException(), isNull);
    inbox.dispose();
  });
}
