// A project's automations: app-level triggers that run actions with no
// screen of their own, their conditions, how-often limits and the usage
// counters they read, deterministic (a fake clock, the test's timers).

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'present_support.dart';

void main() {
  late List<Json> calls;
  late DateTime now;

  Json seen(String what, [Json more = const {}]) => {
        'type': 'callFunction',
        'name': 'seen',
        'params': {'what': what, ...more},
      };

  Codelessly app(List<Automation> automations, {List<PublishLayout>? layouts, LocalStorage? storage}) {
    final c = Codelessly.fromBundle(
      bundleOf(layouts ?? [screen('home')], automations: automations),
      config: CodelesslyConfig(
        services: Services(storage: storage ?? MemoryLocalStorage(), analytics: const NoAnalytics()),
        functions: {
          'seen': (context, params) {
            calls.add(params);
            return null;
          },
        },
      ),
      fonts: const NoFontFetcher(),
    );
    c.automations.clock = () => now;
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    calls = [];
    now = DateTime.utc(2026, 11, 11, 9);
  });

  List<Object?> whats() => [for (final c in calls) c['what']];

  testWidgets('an app-start automation runs once per user, and the launch is counted on the device', (tester) async {
    final storage = MemoryLocalStorage();
    final automations = [
      Automation(id: 'welcome', trigger: AutomationTrigger.appStart, maxRuns: 1, actions: [
        ActionDef.fromJson(seen('welcome', {'first': r'${usage.isFirstLaunch}'}))!,
      ]),
      Automation(id: 'every-start', trigger: AutomationTrigger.sessionStart, actions: [
        ActionDef.fromJson(seen('session', {'n': r'${usage.sessions}'}))!,
      ]),
    ];
    final first = app(automations, storage: storage);
    await first.automations.start();
    await tester.pump();
    expect(calls, [
      {'what': 'welcome', 'first': true},
      {'what': 'session', 'n': 1},
    ]);
    expect(first.automations.usage['launches'], 1);
    expect((storage.get('codelessly.usage.device') as Map)['automations'], {
      'welcome': {'count': 1, 'last': now.millisecondsSinceEpoch},
      'every-start': {'count': 1, 'last': now.millisecondsSinceEpoch},
    });

    // The next launch, on the same device.
    calls.clear();
    now = now.add(const Duration(days: 1));
    final second = app(automations, storage: storage);
    await second.automations.start();
    await tester.pump();
    expect(calls, [
      {'what': 'session', 'n': 2},
    ]);
    expect(second.automations.usage['isFirstLaunch'], isFalse);
    expect(second.automations.usage['launches'], 2);
    // Every layout reads it too.
    expect(second.appVariables.read('usage.automations.welcome.count'), 1);
  });

  testWidgets('an app event runs the automations listening for it, when their condition holds', (tester) async {
    final c = app([
      Automation(
        id: 'rate-us',
        event: 'order_completed',
        when: r'usage.events.order_completed.count >= 3 && event.props.total > 20',
        maxRuns: 1,
        actions: [ActionDef.fromJson(seen('rate', {'total': r'${result.total}', 'name': r'${event.name}'}))!],
      ),
    ]);
    final heard = <String>[];
    c.events.listen((e) => heard.add(e.name));
    await c.automations.start();
    c.emit('order_completed', {'total': 50});
    c.emit('order_completed', {'total': 10});
    await tester.pump();
    expect(calls, isEmpty);
    c.emit('order_completed', {'total': 10});
    await tester.pump();
    expect(calls, isEmpty, reason: 'the third order is too small');
    c.emit('order_completed', {'total': 30});
    c.emit('order_completed', {'total': 99});
    await tester.pump();
    expect(calls, [
      {'what': 'rate', 'total': 30, 'name': 'order_completed'},
    ]);
    expect(heard, List.filled(5, 'order_completed'));
    expect(c.automations.usage['events'], {
      'order_completed': {'count': 5, 'last': now.millisecondsSinceEpoch},
    });
  });

  testWidgets('events fired before the app starts wait for it', (tester) async {
    final c = app([
      Automation(id: 'early', event: 'opened', actions: [ActionDef.fromJson(seen('opened'))!]),
    ]);
    c.emit('opened');
    expect(calls, isEmpty);
    await c.automations.start();
    await tester.pump();
    expect(whats(), ['opened']);
  });

  testWidgets('a layout fires app events, and an automation presents a layout', (tester) async {
    setSize(tester);
    final c = app(
      [
        Automation(id: 'thanks', event: 'checkout', actions: [
          ActionDef.fromJson({'type': 'openModal', 'to': 'thanks', 'params': {'total': r'${result.total}'}})!,
        ]),
      ],
      layouts: [
        screen('home', width: 400, height: 800, onClick: [
          {'type': 'emitEvent', 'event': 'checkout', 'props': {'total': r'${= 2 * 21}'}},
        ]),
        screen('thanks', variables: [const Variable(name: 'total', type: VariableType.integer, value: 0)], onClick: [
          seen('thanks', {'total': r'${total}'}),
          {'type': 'closeModal'},
        ]),
      ],
    );
    final heard = <AppEvent>[];
    c.events.listen(heard.add);
    await tester.pumpWidget(hostApp(c, home: CodelesslyWidget(codelessly: c, layoutId: 'home')));
    await settle(tester);
    await tester.tapAt(const Offset(200, 100));
    await settle(tester);
    expect(heard.single.props, {'total': 42});
    // The automation presented "thanks" with the event's total as a param.
    expect(find.byType(CodelesslyWidget), findsNWidgets(2));
    await tester.tapAt(const Offset(200, 400));
    await settle(tester);
    expect(calls, [
      {'what': 'thanks', 'total': 42},
    ]);
    expect(find.byType(CodelesslyWidget), findsOneWidget);
  });

  testWidgets('an automation can be limited to once every n days, and once per session', (tester) async {
    final c = app([
      Automation(id: 'weekly', event: 'tick', everyDays: 7, actions: [ActionDef.fromJson(seen('weekly'))!]),
      Automation(id: 'session', event: 'tick', maxPerSession: 2, actions: [ActionDef.fromJson(seen('session'))!]),
    ]);
    await c.automations.start();
    c.emit('tick');
    await tester.pump();
    now = now.add(const Duration(days: 6));
    c.emit('tick');
    await tester.pump();
    now = now.add(const Duration(days: 1));
    c.emit('tick');
    await tester.pump();
    expect(whats(), ['weekly', 'session', 'session', 'weekly']);
    expect(c.automations.usage['automations'], {
      'weekly': {'count': 2, 'last': now.millisecondsSinceEpoch, 'session': 2},
      'session': {'count': 2, 'last': now.subtract(const Duration(days: 1)).millisecondsSinceEpoch, 'session': 2},
    });
  });

  testWidgets('resuming runs resume automations, and a long time in the background starts a new session', (tester) async {
    final c = app([
      Automation(id: 'resume', trigger: AutomationTrigger.resume, actions: [
        ActionDef.fromJson(seen('resume', {'away': r'${result.awayMs}'}))!,
      ]),
      Automation(id: 'session', trigger: AutomationTrigger.sessionStart, actions: [
        ActionDef.fromJson(seen('session', {'n': r'${usage.sessions}'}))!,
      ]),
      Automation(id: 'once', trigger: AutomationTrigger.sessionStart, maxPerSession: 1, event: '', actions: [
        ActionDef.fromJson(seen('once'))!,
      ]),
    ]);
    await c.automations.start();
    await tester.pump();
    expect(whats(), ['session', 'once']);
    calls.clear();
    c.automations.handleLifecycle(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 5));
    c.automations.handleLifecycle(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls, [
      {'what': 'resume', 'away': 300000},
    ]);
    calls.clear();
    c.automations.handleLifecycle(AppLifecycleState.hidden);
    now = now.add(const Duration(minutes: 31));
    c.automations.handleLifecycle(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls, [
      {'what': 'resume', 'away': 1860000},
      {'what': 'session', 'n': 2},
      {'what': 'once'},
    ]);
    expect(c.automations.usage['isFirstSession'], isFalse);
  });

  testWidgets('interval automations run only in the foreground, and a delay waits and checks its condition again', (tester) async {
    final c = app([
      Automation(id: 'poll', trigger: AutomationTrigger.interval, intervalMs: 10000, actions: [
        ActionDef.fromJson(seen('poll', {'tick': r'${result.tick}'}))!,
      ]),
      Automation(id: 'later', event: 'go', delayMs: 3000, maxRuns: 1, actions: [ActionDef.fromJson(seen('later'))!]),
    ]);
    await c.automations.start();
    await tester.pump(const Duration(seconds: 25));
    expect(calls, [
      {'what': 'poll', 'tick': 1},
      {'what': 'poll', 'tick': 2},
    ]);
    c.automations.handleLifecycle(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 60));
    expect(calls, hasLength(2));
    c.automations.handleLifecycle(AppLifecycleState.resumed);
    calls.clear();
    c.emit('go');
    c.emit('go'); // already waiting: not twice
    await tester.pump(const Duration(seconds: 2));
    expect(whats(), isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(whats(), ['later']);
    c.automations.handleLifecycle(AppLifecycleState.paused);
  });

  testWidgets('showing a screen runs the automations for it', (tester) async {
    setSize(tester);
    final c = app(
      [
        Automation(id: 'tour', trigger: AutomationTrigger.screenShown, screen: 'settings', maxRuns: 1, actions: [
          ActionDef.fromJson(seen('tour', {'layout': r'${result.layoutId}'}))!,
        ]),
      ],
      layouts: [screen('home', width: 400, height: 800), screen('settings', width: 400, height: 800)],
    );
    final controller = CodelesslyWidgetController(layoutId: 'home');
    addTearDown(controller.dispose);
    await tester.pumpWidget(hostApp(c, home: CodelesslyWidget(codelessly: c, controller: controller)));
    await settle(tester);
    expect(calls, isEmpty);
    controller.layoutId = 'settings';
    await settle(tester);
    controller.layoutId = 'home';
    await settle(tester);
    controller.layoutId = 'settings';
    await settle(tester);
    expect(calls, [
      {'what': 'tour', 'layout': 'settings'},
    ]);
  });

  testWidgets('automation counters are kept per user', (tester) async {
    final auth = MemoryAuthService();
    final storage = MemoryLocalStorage();
    final c = Codelessly.fromBundle(
      bundleOf([screen('home')], automations: [
        Automation(id: 'hello', trigger: AutomationTrigger.sessionStart, maxRuns: 1, actions: [
          ActionDef.fromJson(seen('hello', {'uid': r'${auth.uid}'}))!,
        ]),
      ]),
      config: CodelesslyConfig(
        services: Services(storage: storage, auth: auth, analytics: const NoAnalytics()),
        functions: {
          'seen': (context, params) {
            calls.add(params);
            return null;
          },
        },
      ),
      fonts: const NoFontFetcher(),
    );
    addTearDown(c.dispose);
    await c.automations.start();
    await tester.pump();
    await auth.signUp(email: 'ana@example.com', password: 'secret123');
    await tester.pump();
    await tester.pump();
    expect(calls.length, 2);
    expect(calls.first, {'what': 'hello', 'uid': ''});
    expect(calls.last['uid'], isNotEmpty);
    expect(storage.getAll().keys.where((k) => k.startsWith('codelessly.usage.')), hasLength(2));
  });
}

