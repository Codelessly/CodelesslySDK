import 'dart:async';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart';

class Store implements PurchaseService {
  final events = StreamController<PaywallResult>.broadcast();
  bool disposed = false;
  Object? failure;
  Completer<List<PaywallProduct>>? pending;
  String? purchased;
  List<PaywallProduct> items = const [
    PaywallProduct(slot: 'annual', storeId: 'a', price: '€39,99', currency: 'EUR', eligibleForTrial: true),
    PaywallProduct(slot: 'monthly', storeId: 'm', price: '€4,99', currency: 'EUR'),
  ];
  @override
  Stream<PaywallResult> get updates => events.stream;
  @override
  Future<List<PaywallProduct>> products(List<ProductSlot> slots) async {
    if (failure != null) throw failure!;
    return pending == null ? items : pending!.future;
  }
  @override
  Future<void> purchase(PaywallProduct product) async => purchased = product.slot;
  @override
  Future<void> restore() async {}
  @override
  Future<void> dispose() async { disposed = true; await events.close(); }
}
class Backend implements PaywallBackend {
  Object? failure;
  Completer<ResolvedPaywall>? pending;
  final calls = <String>[];
  final resolved = const ResolvedPaywall(
    placement: PaywallPlacement('onboarding', layoutId: 'paywall', productSlots: ['annual', 'monthly']),
    slots: [ProductSlot('annual'), ProductSlot('monthly')],
  );
  @override
  Future<ResolvedPaywall> resolve(String placement, {required String locale, required String platform, required String appVersion}) async {
    calls.add('$placement/$locale/$platform/$appVersion');
    if (failure != null) throw failure!;
    return pending == null ? resolved : pending!.future;
  }
  @override
  Future<Set<String>> entitlements() async => {};
  @override
  Future<String?> verify(PendingPurchase purchase) async => 'pro';
  @override
  Future<void> recordEvent({required String eventId, required String name, required ResolvedPaywall paywall, String? slot}) async {}
}
Node actionNode(List<Json> values) => Node.fromJson({'type': 'box', 'actions': [
  {'trigger': {'type': 'click'}, 'actions': values}
]}, id: 'action')!;
PublishBundle bundle() {
  PublishLayout layout(String id, List<Json> click) => PublishLayout.fromJson({
    'schema': 2, 'id': id, 'roots': ['${id}Canvas'], 'nodes': {
      '${id}Canvas': {'type': 'canvas', 'slots': {'body': '${id}Body'}, 'layout': {'width': 390, 'height': 844}},
      '${id}Body': {'type': 'stack', 'layout': {'width': {'fill': 390}, 'height': {'fill': 844}}, 'children': ['${id}Button']},
      '${id}Button': {'type': 'box', 'decoration': {'fills': [{'color': '#FF334455'}]}, 'layout': {'width': 100, 'height': 50}, 'actions': [
        {'trigger': {'type': 'click'}, 'actions': click}
      ]},
    },
  });
  final home = layout('home', [{'type': 'paywall', 'operation': 'openPaywall', 'placement': 'onboarding'}]);
  final paywall = layout('paywall', [{'type': 'paywall', 'operation': 'purchase', 'slot': 'monthly'}]);
  return PublishBundle(model: PublishModel(projectId: 'p', entryLayoutId: 'home', layouts: {
    'home': PublishLayoutInfo.of(home), 'paywall': PublishLayoutInfo.of(paywall),
  }), layouts: {'home': home, 'paywall': paywall});
}
void main() {
  test('slot inventory stays store-backed across selection changes', () async {
    final store = Store();
    final session = PaywallSession(service: store, slots: const [ProductSlot('annual'), ProductSlot('monthly')]);
    await session.load(); session.selectProduct('monthly');
    expect((session.values['product'] as Map)['price'], '€4,99');
    expect(((session.values['products'] as Map)['annual'] as Map)['price'], '€39,99');
    session.dispose(); await store.dispose();
  });
  test('nested contexts retain opener/session and expose outcome to next action', () async {
    final scope = VariableScope([const Variable(name: 'outcome')]);
    final session = PaywallSession(service: Store(), slots: const []);
    String? placement;
    final context = RuntimeActionContext(scope: scope, paywall: session, openPaywall: (id) async {
      placement = id; return const PaywallResult(PaywallOutcome.restored, entitlementId: 'pro');
    });
    final nested = context.withScope(ValuesScope({}, scope));
    expect(nested.paywall, same(session));
    await const CodelesslyActions().trigger(actionNode([
      {'type': 'paywall', 'operation': 'openPaywall', 'placement': 'settings'},
      {'type': 'setVariable', 'variable': 'outcome', 'value': r'${result.outcome}'},
    ]), 'click', nested);
    expect(placement, 'settings'); expect(scope.read('outcome'), 'restored');
    session.dispose(); await session.service.dispose();
  });
  test('purchase chains await verification and stop on cancellation or failure', () async {
    for (final outcome in [PaywallOutcome.canceled, PaywallOutcome.failed, PaywallOutcome.purchased]) {
      final store = Store();
      final session = PaywallSession(service: store, slots: const [ProductSlot('annual')]);
      await session.load();
      final scope = VariableScope([const Variable(name: 'after', value: 'before')]);
      final errors = <Object>[];
      final context = RuntimeActionContext(scope: scope, paywall: session, onError: (e, _, _) => errors.add(e));
      final chain = const CodelesslyActions().trigger(actionNode([
        {'type': 'paywall', 'operation': 'purchase'},
        {'type': 'setVariable', 'variable': 'after', 'value': 'verified'},
      ]), 'click', context);
      await pumpEventQueue();
      expect(scope.read('after'), 'before');
      store.events.add(PaywallResult(outcome, entitlementId: outcome == PaywallOutcome.purchased ? 'pro' : null));
      await chain;
      expect(scope.read('after'), outcome == PaywallOutcome.purchased ? 'verified' : 'before');
      expect(errors.length, outcome == PaywallOutcome.failed ? 1 : 0);
      session.dispose(); await store.dispose();
    }
  });

  test('failed placement opening reports once, stops success chain and permits retry', () async {
    final scope = VariableScope([const Variable(name: 'after', value: 'before')]);
    final errors = <Object>[];
    var failed = true;
    final context = RuntimeActionContext(scope: scope, onError: (error, _, _) => errors.add(error), openPaywall: (_) async {
      if (failed) throw StateError('Placement unavailable');
      return const PaywallResult(PaywallOutcome.closed);
    });
    final button = actionNode([
      {'type': 'paywall', 'operation': 'openPaywall', 'placement': 'onboarding'},
      {'type': 'setVariable', 'variable': 'after', 'value': 'continued'},
    ]);
    await const CodelesslyActions().trigger(button, 'click', context);
    expect(errors, hasLength(1)); expect(scope.read('after'), 'before');
    failed = false;
    await const CodelesslyActions().trigger(button, 'click', context);
    expect(errors, hasLength(1)); expect(scope.read('after'), 'continued');
  });

  test('resolution, store and partial-inventory failures never present', () async {
    for (final mode in ['resolve', 'store', 'partial']) {
      final backend = Backend(); final store = Store();
      if (mode == 'resolve') backend.failure = StateError('offline');
      if (mode == 'store') store.failure = StateError('offline');
      if (mode == 'partial') store.items = [store.items.first];
      final runtime = PaywallRuntime(backend: backend, purchases: () => store, platform: 'ios');
      var presented = false;
      await expectLater(runtime.open('onboarding', locale: 'fr', appVersion: '1', present: (_, _) async {
        presented = true; return null;
      }), throwsStateError);
      expect(presented, false);
      if (mode != 'resolve') expect(store.disposed, true);
      runtime.dispose(); if (!store.disposed) await store.dispose();
    }
  });
  test('dismissal closes result and disposes session/adapter', () async {
    final store = Store(); final runtime = PaywallRuntime(backend: Backend(), purchases: () => store, platform: 'ios');
    late PaywallSession session;
    final result = await runtime.open('onboarding', locale: 'en', appVersion: '1', present: (_, value) async {
      session = value; return null;
    });
    expect(result.outcome, PaywallOutcome.closed); expect(session.isDisposed, true);
    expect((await session.result).outcome, PaywallOutcome.closed); expect(store.disposed, true); runtime.dispose();
  });
  test('account change discards an in-flight resolution', () async {
    final backend = Backend()..pending = Completer();
    final runtime = PaywallRuntime(backend: backend, purchases: Store.new, platform: 'ios')..scopeToUser('one');
    var shown = false;
    final open = runtime.open('onboarding', locale: 'en', appVersion: '1', present: (_, _) async { shown = true; return null; });
    runtime.scopeToUser('two'); backend.pending!.complete(backend.resolved);
    expect((await open).outcome, PaywallOutcome.closed); expect(shown, false); expect(runtime.entitlements.value, isEmpty); runtime.dispose();
  });
  test('account change during product loading prevents presentation', () async {
    final store = Store()..pending = Completer();
    final runtime = PaywallRuntime(backend: Backend(), purchases: () => store, platform: 'ios')..scopeToUser('one');
    var shown = false;
    final open = runtime.open('onboarding', locale: 'en', appVersion: '1', present: (_, _) async { shown = true; return null; });
    await pumpEventQueue(); runtime.scopeToUser('two'); store.pending!.complete(store.items);
    expect((await open).outcome, PaywallOutcome.closed); expect(shown, false); expect(store.disposed, true); runtime.dispose();
  });
  testWidgets('authored pop params close the paywall route without a result type error', (tester) async {
    final store = Store();
    final runtime = PaywallRuntime(backend: Backend(), purchases: () => store, platform: 'ios');
    final app = Codelessly(config: CodelesslyConfig(services: Services(paywalls: runtime)), loader: MemoryPublishLoader(bundle()), fonts: const NoFontFetcher());
    final controller = CodelesslyWidgetController();
    final errors = <Object>[];
    await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, controller: controller, onActionError: (error, _, _) => errors.add(error))));
    await settle(tester);
    final open = controller.trigger('homeButton', 'click');
    await settle(tester);
    final view = tester.widgetList<NodeView>(find.byType(NodeView)).last;
    final active = (view.tree.interactions as TreeReactions).contextFor(view.tree.boxOf('paywallButton')!);
    await active.navigate({'type': 'navigate', 'mode': 'pop', 'params': {'reason': 'later'}});
    await settle(tester); await open;
    expect(errors, isEmpty); expect(store.disposed, true);
    expect(tester.state<NavigatorState>(find.byType(Navigator)).canPop(), false);
    await tester.pumpWidget(const SizedBox()); controller.dispose(); app.dispose(); runtime.dispose();
  });

  for (final accountChange in [false, true]) {
    testWidgets(accountChange ? 'account change closes active route without grants' : 'native open binds account/products and purchase closes with verified grant', (tester) async {
      final store = Store(); final backend = Backend();
      final runtime = PaywallRuntime(backend: backend, purchases: () => store, platform: 'ios');
      final auth = MemoryAuthService(signedIn: const AppUser(uid: 'one', displayName: 'Ada'));
      final app = Codelessly(config: CodelesslyConfig(services: Services(auth: auth, paywalls: runtime)), loader: MemoryPublishLoader(bundle()), fonts: const NoFontFetcher());
      final controller = CodelesslyWidgetController();
      await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, controller: controller, paywallAppVersion: '42')));
      await settle(tester); expect(controller.read('auth.displayName'), 'Ada');
      final open = controller.trigger('homeButton', 'click'); await settle(tester);
      expect(backend.calls, ['onboarding/en-US/ios/42']);
      final shown = tester.widgetList<CodelesslyWidget>(find.byType(CodelesslyWidget)).last;
      final session = shown.paywall!;
      expect(session.products, hasLength(2));
      if (accountChange) {
        await auth.signOut();
      } else {
        final view = tester.widgetList<NodeView>(find.byType(NodeView)).last;
        final box = view.tree.boxOf('paywallButton')!;
        final active = (view.tree.interactions as TreeReactions).contextFor(box);
        runtime.entitlements.value = {'external'};
        expect(active.scope.read('entitlements.external'), true);
        runtime.entitlements.value = {};
        expect(active.scope.read('entitlements.external'), null);
        await tester.tapAt(box.localToGlobal(box.size.center(Offset.zero))); await settle(tester);
        expect(store.purchased, 'monthly');
        store.events.add(const PaywallResult(PaywallOutcome.purchased, entitlementId: 'pro'));
      }
      await settle(tester); await open;
      expect(tester.state<NavigatorState>(find.byType(Navigator)).canPop(), false);
      expect(session.isDisposed, true); expect(store.disposed, true);
      expect(controller.read('entitlements.pro'), accountChange ? null : true);
      await auth.signOut(); await settle(tester);
      expect(controller.read('auth.isSignedIn'), false); expect(controller.read('entitlements.pro'), null);
      await tester.pumpWidget(const SizedBox()); controller.dispose(); app.dispose(); runtime.dispose();
    });
  }
}
