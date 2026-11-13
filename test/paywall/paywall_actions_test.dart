import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

// A paywall action's slot can be bound (`${sel}`: the plan the screen
// selected): purchase and selectProduct act on the evaluated slot, not on
// the raw `${...}` text.


class _Store implements PurchaseService {
  final _updates = StreamController<PaywallResult>.broadcast();
  final bought = <String>[];

  @override
  Stream<PaywallResult> get updates => _updates.stream;

  @override
  Future<List<PaywallProduct>> products(List<ProductSlot> slots) async => [
        for (final s in slots) PaywallProduct(slot: s.id, storeId: 'store.${s.id}', price: r'$1', currency: 'USD'),
      ];

  @override
  Future<void> purchase(PaywallProduct product) async {
    bought.add(product.slot);
    _updates.add(PaywallResult(PaywallOutcome.purchased, productId: product.storeId, entitlementId: 'plus'));
  }

  @override
  Future<void> restore() async {}

  @override
  Future<void> dispose() => _updates.close();
}

void main() {
  group('a product slot named by a binding', () {
    Future<(PaywallSession, _Store, List<Object>)> run(Map<String, Object?> action) async {
      final store = _Store();
      final session = PaywallSession(
        service: store,
        slots: const [ProductSlot('monthly'), ProductSlot('yearly'), ProductSlot('lifetime')],
      );
      await session.load();
      final scope = VariableScope(const [Variable(name: 'sel', type: VariableType.text, value: 'lifetime')]);
      final errors = <Object>[];
      final context = RuntimeActionContext(scope: scope, paywall: session, onError: (error, _, _) => errors.add(error));
      await const CodelesslyActions().run(
        Node.fromJson({
          'type': 'box',
          'actions': [
            {
              'trigger': {'type': 'click'},
              'actions': [action],
            },
          ],
        }, id: 'buy')!,
        'click',
        context,
      );
      scope.dispose();
      return (session, store, errors);
    }

    test('a purchase action buys the product slot its binding names', () async {
      final (session, store, errors) = await run({'type': 'paywall', 'operation': 'purchase', 'slot': r'${sel}'});
      expect(errors, isEmpty);
      expect(store.bought, ['lifetime']);
      expect(session.selectedSlot, 'lifetime');
    });
  });
}
