import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

void main() {
  test(
    'StoreKit2 offer checks device eligibility before showing free trial',
    () async {
      final product = AppStoreProduct2Details(
        id: 'annual',
        title: 'Annual',
        description: '',
        price: '€39,99',
        rawPrice: 39.99,
        currencyCode: 'EUR',
        currencySymbol: '€',
        sk2Product: SK2Product(
          id: 'annual',
          displayName: 'Annual',
          description: '',
          displayPrice: '€39,99',
          price: 39.99,
          type: SK2ProductType.autoRenewable,
          priceLocale: SK2PriceLocale(currencyCode: 'EUR', currencySymbol: '€'),
          subscription: SK2SubscriptionInfo(
            subscriptionGroupID: 'pro',
            subscriptionPeriod: const SK2SubscriptionPeriod(
              value: 1,
              unit: SK2SubscriptionPeriodUnit.year,
            ),
            promotionalOffers: [
              SK2SubscriptionOffer(
                price: 0,
                type: SK2SubscriptionOfferType.introductory,
                period: const SK2SubscriptionPeriod(
                  value: 7,
                  unit: SK2SubscriptionPeriodUnit.day,
                ),
                periodCount: 1,
                paymentMode: SK2SubscriptionOfferPaymentMode.freeTrial,
              ),
            ],
          ),
        ),
      );
      final eligible = await StoreProductMetadata(
        appleTrialEligibility: (_) async => true,
      ).fromDetails('annual', product);
      expect(eligible.period, '1 year');
      expect(eligible.trial, '7 days');
      expect(eligible.eligibleForTrial, true);
      final notEligible = await StoreProductMetadata(
        appleTrialEligibility: (_) async => false,
      ).fromDetails('annual', product);
      expect(notEligible.trial, isNull);
    },
  );

  test('Play offer pricing phases expose trial and recurring period', () async {
    const wrapper = ProductDetailsWrapper(
      productId: 'annual',
      name: 'Annual',
      title: 'Annual',
      description: '',
      productType: ProductType.subs,
      subscriptionOfferDetails: [
        SubscriptionOfferDetailsWrapper(
          basePlanId: 'annual',
          offerTags: [],
          offerIdToken: 'offer',
          pricingPhases: [
            PricingPhaseWrapper(
              billingCycleCount: 1,
              billingPeriod: 'P7D',
              formattedPrice: '€0',
              priceAmountMicros: 0,
              priceCurrencyCode: 'EUR',
              recurrenceMode: RecurrenceMode.finiteRecurring,
            ),
            PricingPhaseWrapper(
              billingCycleCount: 0,
              billingPeriod: 'P1Y',
              formattedPrice: '€39,99',
              priceAmountMicros: 39990000,
              priceCurrencyCode: 'EUR',
              recurrenceMode: RecurrenceMode.infiniteRecurring,
            ),
          ],
        ),
      ],
    );
    final product = GooglePlayProductDetails.fromProductDetails(wrapper).single;
    final metadata = await const StoreProductMetadata().fromDetails(
      'annual',
      product,
    );
    expect(metadata.period, '1 year');
    expect(metadata.trial, '1 × 7 days');
    expect(metadata.eligibleForTrial, true);
  });

  test(
    'annual savings uses numeric store prices and rejects currency mismatch',
    () {
      const annual = PaywallProduct(
        slot: 'annual',
        storeId: 'annual',
        price: '€39,99',
        currency: 'EUR',
        period: '1 year',
        rawPrice: 39.99,
      );
      const monthly = PaywallProduct(
        slot: 'monthly',
        storeId: 'monthly',
        price: '€4,99',
        currency: 'EUR',
        period: '1 month',
        rawPrice: 4.99,
      );
      expect(
        StoreProductMetadata.savingsPercent(annual: annual, monthly: monthly),
        33,
      );
      expect(
        StoreProductMetadata.savingsPercent(
          annual: annual,
          monthly: const PaywallProduct(
            slot: 'monthly',
            storeId: 'usd',
            price: r'$4.99',
            currency: 'USD',
            period: '1 month',
            rawPrice: 4.99,
          ),
        ),
        isNull,
      );
    },
  );
}
