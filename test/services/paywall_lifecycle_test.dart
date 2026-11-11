import 'dart:async';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import '../app/paywall_test.dart' show Backend, Store;

class _EntitlementBackend extends Backend {
  Set<String> grants = {};
  @override
  Future<Set<String>> entitlements() async => {...grants};
}

class _DelayedCache extends MemoryKeyValueCache {
  final readStarted = Completer<String>();
  final pendingRead = Completer<Object?>();
  @override
  Future<Object?> read(String key) {
    readStarted.complete(key);
    return pendingRead.future;
  }
}

/// Valid auth implementation with a stream that permits exactly one listener.
class _SingleSubscriptionAuth extends MemoryAuthService {
  _SingleSubscriptionAuth(AppUser user) : _current = user;
  AppUser? _current;
  final events = StreamController<AppUser?>();
  var subscriptions = 0;
  @override
  AppUser? get currentUser => _current;
  @override
  Stream<AppUser?> get userChanges {
    subscriptions++;
    return events.stream;
  }

  void emit(AppUser? user) {
    _current = user;
    events.add(user);
  }
}

class _Profiles extends BackendCloudDatabase {
  _Profiles() : super(backend: MemoryDocumentBackend());
  final streams = <String, StreamController<Json?>>{};
  final cancelled = <String>[];
  @override
  Stream<Json?> watchDocument(String path, String id) =>
      streams.putIfAbsent(id, () => StreamController<Json?>.broadcast(onCancel: () => cancelled.add(id))).stream;
  Future<void> closeStreams() async {
    for (final stream in streams.values) {
      await stream.close();
    }
    dispose();
  }
}

void main() {
  test('anonymous identity changes and repeated signed-out auth errors fail closed', () async {
    final auth = _SingleSubscriptionAuth(const AppUser(uid: 'guest-one', isAnonymous: true));
    final backend = Backend();
    final runtime = PaywallRuntime(backend: backend, purchases: Store.new, platform: 'ios');
    final app = Codelessly(config: CodelesslyConfig(services:
      Services(auth: auth, paywalls: runtime, analytics: const NoAnalytics())));
    expect(app.appVariables.read('auth.isSignedIn'), false);
    await pumpEventQueue();
    final session = runtime.session(backend.resolved);
    runtime.entitlements.value = {'guest-grant'};
    auth.emit(const AppUser(uid: 'guest-two', isAnonymous: true));
    await pumpEventQueue();
    expect(session.isDisposed, true);
    expect(runtime.entitlements.value, isEmpty);
    expect(app.appVariables.read('auth.uid'), '');
    auth.emit(null);
    await pumpEventQueue();
    runtime.entitlements.value = {'stale-grant'};
    auth.events.addError(StateError('auth unavailable'));
    await pumpEventQueue();
    expect(runtime.entitlements.value, isEmpty);
    app.dispose();
    runtime.dispose();
    await auth.events.close();
  });
  test('a second session cannot remove another session\'s verified grant', () async {
    final stores = <Store>[];
    final backend = Backend();
    final runtime = PaywallRuntime(
      backend: backend,
      purchases: () {
        final store = Store();
        stores.add(store);
        return store;
      },
      platform: 'ios',
    )..scopeToUser('one');
    addTearDown(runtime.dispose);
    final first = runtime.session(backend.resolved);
    final second = runtime.session(backend.resolved);
    await first.load();
    await second.load();
    stores.first.events.add(const PaywallResult(PaywallOutcome.purchased, entitlementId: 'pro'));
    expect((await first.result).outcome, PaywallOutcome.purchased);
    await pumpEventQueue();
    expect(runtime.entitlements.value, {'pro'});
    second.selectProduct('monthly');
    expect(runtime.entitlements.value, {'pro'});
    stores.last.events.add(const PaywallResult(PaywallOutcome.restored, entitlementId: 'other'));
    await second.result;
    await pumpEventQueue();
    expect(runtime.entitlements.value, {'pro', 'other'});
    first.dispose();
    second.dispose();
  });
  test('a stale session snapshot cannot resurrect a revoked entitlement', () async {
    final backend = _EntitlementBackend()..grants = {'pro'};
    final runtime = PaywallRuntime(backend: backend, purchases: Store.new, platform: 'ios')..scopeToUser('one');
    addTearDown(runtime.dispose);
    await runtime.refreshEntitlements();
    final session = runtime.session(backend.resolved);
    await session.load();
    expect(session.entitlements, {'pro'});
    backend.grants = {};
    await runtime.refreshEntitlements();
    expect(runtime.entitlements.value, isEmpty);
    session.selectProduct('monthly');
    expect(runtime.entitlements.value, isEmpty, reason: 'selection is not a new verified grant');
    session.dispose();
  });
  test('a completed session remains tracked until disposal across account changes', () async {
    final store = Store();
    final backend = Backend();
    final runtime = PaywallRuntime(backend: backend, purchases: () => store, platform: 'ios')..scopeToUser('one');
    addTearDown(runtime.dispose);
    final session = runtime.session(backend.resolved);
    await session.load();
    store.events.add(const PaywallResult(PaywallOutcome.purchased, entitlementId: 'pro'));
    await session.result;
    await pumpEventQueue();
    expect(session.isDisposed, false, reason: 'presentation may still be loading or dismissing');
    runtime.scopeToUser('two');
    expect(session.isDisposed, true);
    expect(store.disposed, true);
    expect(runtime.entitlements.value, isEmpty);
  });
  for (final dispose in [false, true]) {
    test(dispose ? 'runtime disposal discards an in-flight cached placement' : 'account switch discards an in-flight cached placement', () async {
      final backend = Backend()..failure = StateError('offline');
      final cache = _DelayedCache();
      final runtime = PaywallRuntime(backend: backend, purchases: Store.new, platform: 'ios', cache: cache, projectId: 'sandbox')..scopeToUser('one');
      addTearDown(runtime.dispose);
      final pending = runtime.resolve('onboarding', locale: 'en', appVersion: '1');
      expect(await cache.readStarted.future, contains('.one.'));
      if (dispose) {
        runtime.dispose();
      } else {
        runtime.scopeToUser('two');
      }
      cache.pendingRead.complete({'expires': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch, ...backend.resolved.toCacheJson()});
      expect(await pending, isNull);
    });
  }
  test('one auth subscription drives account scope; errors cannot revive an old profile', () async {
    const first = AppUser(uid: 'one', displayName: 'Ada');
    const second = AppUser(uid: 'two', displayName: 'Grace');
    final auth = _SingleSubscriptionAuth(first);
    final profiles = _Profiles();
    final runtime = PaywallRuntime(backend: Backend(), purchases: Store.new, platform: 'ios');
    final app = Codelessly(
      config: CodelesslyConfig(
        services: Services(auth: auth, cloud: profiles, paywalls: runtime, analytics: const NoAnalytics()),
      ),
    );
    addTearDown(() async {
      app.dispose();
      await pumpEventQueue();
      runtime.dispose();
      await auth.events.close();
      await profiles.closeStreams();
    });
    expect(app.appVariables.read('auth.displayName'), 'Ada');
    auth.emit(first);
    await pumpEventQueue();
    expect(auth.subscriptions, 1);
    profiles.streams['one']!.add({'plan': 'annual'});
    await pumpEventQueue();
    expect(app.appVariables.read('auth.profile.plan'), 'annual');
    runtime.entitlements.value = {'pro'};
    expect(app.appVariables.read('entitlements.pro'), true);
    auth.events.addError(StateError('authentication stream failed'));
    await pumpEventQueue();
    expect(app.appVariables.read('auth.isSignedIn'), false);
    expect(app.appVariables.read('entitlements.pro'), isNull);
    expect(profiles.cancelled, contains('one'));
    profiles.streams['one']!.add({'plan': 'stale'});
    await pumpEventQueue();
    expect(app.appVariables.read('auth.isSignedIn'), false);
    expect(app.appVariables.read('auth.uid'), '');
    expect(app.appVariables.read('auth.profile.plan'), isNull);
    auth.emit(second);
    await pumpEventQueue();
    profiles.streams['two']!.add({'plan': 'monthly'});
    await pumpEventQueue();
    expect(app.appVariables.read('auth.uid'), 'two');
    expect(app.appVariables.read('auth.displayName'), 'Grace');
    expect(app.appVariables.read('auth.profile.plan'), 'monthly');
    expect(auth.subscriptions, 1);
  });
}
