import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePurchaseService implements PurchaseService {
  final events = StreamController<PaywallResult>.broadcast();
  final items = const [
    PaywallProduct(
      slot: 'annual',
      storeId: 'com.example.annual',
      price: '€39,99',
      currency: 'EUR',
      period: 'year',
      pricePerMonth: '€3,33',
      savingsPercent: 33,
      trial: '7 days',
      eligibleForTrial: true,
    ),
    PaywallProduct(
      slot: 'monthly',
      storeId: 'com.example.monthly',
      price: '€4,99',
      currency: 'EUR',
      period: 'month',
    ),
  ];
  String? purchased;
  bool restored = false;

  @override
  Stream<PaywallResult> get updates => events.stream;
  @override
  Future<List<PaywallProduct>> products(List<ProductSlot> slots) async =>
      items.where((item) => slots.any((slot) => slot.id == item.slot)).toList();
  @override
  Future<void> purchase(PaywallProduct product) async {
    purchased = product.storeId;
  }

  @override
  Future<void> restore() async {
    restored = true;
  }

  @override
  Future<void> dispose() => events.close();
}

void main() {
  late FakePurchaseService store;
  late PaywallController controller;
  setUp(() async {
    store = FakePurchaseService();
    controller = PaywallController(
      service: store,
      slots: const [
        ProductSlot(
          id: 'annual',
          iosProductId: 'com.example.annual',
          androidProductId: 'com.example.annual',
        ),
        ProductSlot(
          id: 'monthly',
          iosProductId: 'com.example.monthly',
          androidProductId: 'com.example.monthly',
        ),
      ],
    );
    await controller.load();
  });
  tearDown(() async {
    controller.dispose();
    await store.dispose();
  });

  test('published JSON action selects localized store product bindings', () {
    final actionJson = const PaywallAction(
      PaywallOperation.selectProduct,
      slot: 'monthly',
    ).toAction().toJson();
    final action = ActionModel.fromJson(actionJson) as CallFunctionAction;
    controller.selectProduct(action.params['slot'] as String);
    expect(controller.variables['product']['price'], '€4,99');
    expect(controller.variables['product']['currency'], 'EUR');
    controller.selectProduct('annual');
    expect(controller.variables['product']['pricePerMonth'], '€3,33');
    expect(controller.variables['product']['eligibleForTrial'], true);
    expect(controller.variables['product']['trial'], '7 days');
    final scope = ScopedValues.preview(
      variables: {},
      data: controller.variables,
    );
    expect(
      PropertyValueDelegate.substituteVariables(
        r'Pay ${product.price} per ${product.period}',
        scopedValues: scope,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
      ),
      'Pay €39,99 per year',
    );
  });

  test(
    'purchase starts, then verified success grants entitlement and result',
    () async {
      await controller.purchase();
      expect(controller.purchasing, true);
      expect(store.purchased, 'com.example.annual');
      store.events.add(
        const PaywallResult(
          PaywallOutcome.purchased,
          productId: 'com.example.annual',
        ),
      );
      expect((await controller.result).outcome, PaywallOutcome.purchased);
      expect(controller.variables['entitlements']['com.example.annual'], true);
      expect(
        PropertyValueDelegate.getVariableValueFromPath<bool>(
          r'${entitlements.annual}',
          scopedValues: ScopedValues.preview(
            variables: {},
            data: controller.variables,
          ),
        ),
        true,
      );
      expect(controller.purchasing, false);
    },
  );

  test('cancel leaves paywall visible and purchase retry possible', () async {
    await controller.purchase();
    store.events.add(const PaywallResult(PaywallOutcome.cancelled));
    await Future<void>.delayed(Duration.zero);
    expect(controller.purchasing, false);
    expect(controller.entitlements, isEmpty);
    await controller.purchase(slot: 'monthly');
    expect(store.purchased, 'com.example.monthly');
    controller.close();
    expect((await controller.result).outcome, PaywallOutcome.closed);
  });

  test('error populates reactive state, retry clears it', () async {
    await controller.purchase();
    store.events.add(
      const PaywallResult(PaywallOutcome.failed, error: 'Store unavailable'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.variables['paywall']['error'], 'Store unavailable');
    await controller.purchase();
    expect(controller.variables['paywall']['error'], '');
  });

  test('restore returns verified entitlement', () async {
    await controller.restore();
    expect(store.restored, true);
    expect(controller.variables['paywall']['restoring'], true);
    store.events.add(
      const PaywallResult(
        PaywallOutcome.restored,
        productId: 'com.example.annual',
      ),
    );
    expect((await controller.result).outcome, PaywallOutcome.restored);
    expect(controller.variables['entitlements']['com.example.annual'], true);
  });

  test(
    'fixture placement and layout JSON drive localized text and purchase',
    () async {
      final json = jsonDecode(
        File('test/paywall/fixtures/paywall.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final placement = PaywallPlacement.fromJson(
        json['placement'] as Map<String, dynamic>,
      );
      final layout = json['layout'] as Map<String, dynamic>;
      expect(placement.layoutId, 'onboarding_annual_v1');
      final headline = PropertyValueDelegate.substituteVariables(
        layout['headline'] as String,
        scopedValues: ScopedValues.preview(
          variables: {},
          data: controller.variables,
        ),
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
      );
      expect(headline, 'Upgrade to Pro for €39,99 / year');
      final action =
          ActionModel.fromJson(layout['cta'] as Map) as CallFunctionAction;
      expect(action.name, 'paywall.purchase');
      await controller.purchase(slot: action.params['slot'] as String);
      expect(store.purchased, 'com.example.annual');
    },
  );

  test('placement JSON carries published layout and slots', () {
    final placement = PaywallPlacement.fromJson({
      'id': 'onboarding_end',
      'layoutId': 'layout_annual',
      'productSlots': ['annual'],
    });
    expect(placement.toJson()['layoutId'], 'layout_annual');
  });
}
