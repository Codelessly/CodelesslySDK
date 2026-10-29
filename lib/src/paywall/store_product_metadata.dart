import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

import 'paywall_controller.dart';

/// Conversion of store metadata to display bindings; does not confer eligibility.
class StoreProductMetadata {
  /// StoreKit2 eligibility requires an on-device query; Play requires an
  /// account-specific eligible offer returned by Billing for this account.
  final Future<bool> Function(String productId)? appleTrialEligibility;

  const StoreProductMetadata({this.appleTrialEligibility});

  Future<PaywallProduct> fromDetails(
    String slot,
    ProductDetails details,
  ) async {
    String period = '';
    String? trial;
    String? introOffer;
    var eligible = false;
    if (details is AppStoreProduct2Details) {
      final subscription = details.sk2Product.subscription;
      if (subscription != null) {
        period = _period(
          subscription.subscriptionPeriod.value,
          subscription.subscriptionPeriod.unit.name,
        );
        final introductory = subscription.promotionalOffers.where(
          (offer) => offer.type == SK2SubscriptionOfferType.introductory,
        );
        if (introductory.isNotEmpty && appleTrialEligibility != null) {
          eligible = await appleTrialEligibility!(details.id);
          if (eligible) {
            final offer = introductory.first;
            introOffer = _period(
              offer.period.value * offer.periodCount,
              offer.period.unit.name,
            );
            if (offer.paymentMode ==
                SK2SubscriptionOfferPaymentMode.freeTrial) {
              trial = introOffer;
            }
          }
        }
      }
    } else if (details is AppStoreProductDetails) {
      final subscription = details.skProduct;
      if (subscription.subscriptionPeriod != null) {
        period = _period(
          subscription.subscriptionPeriod!.numberOfUnits,
          subscription.subscriptionPeriod!.unit.name,
        );
      }
      final offer = subscription.introductoryPrice;
      if (offer != null && appleTrialEligibility != null) {
        eligible = await appleTrialEligibility!(details.id);
        if (eligible) {
          introOffer = _period(
            offer.subscriptionPeriod.numberOfUnits * offer.numberOfPeriods,
            offer.subscriptionPeriod.unit.name,
          );
          if (offer.paymentMode == SKProductDiscountPaymentMode.freeTrail) {
            trial = introOffer;
          }
        }
      }
    } else if (details is GooglePlayProductDetails &&
        details.subscriptionIndex != null) {
      final offer = details
          .productDetails
          .subscriptionOfferDetails![details.subscriptionIndex!];
      if (offer.pricingPhases.isNotEmpty) {
        final recurring = offer.pricingPhases.last;
        period = _isoPeriod(recurring.billingPeriod);
        final introductory = offer.pricingPhases.first;
        if (offer.pricingPhases.length > 1) {
          // Play Billing returns offers eligible for the current account.
          eligible = true;
          introOffer =
              '${introductory.billingCycleCount} × ${_isoPeriod(introductory.billingPeriod)}';
          if (introductory.priceAmountMicros == 0) trial = introOffer;
        }
      }
    }
    return PaywallProduct(
      slot: slot,
      storeId: details.id,
      price: details.price,
      currency: details.currencyCode,
      period: period,
      introOffer: introOffer,
      trial: trial,
      eligibleForTrial: eligible,
      rawPrice: details.rawPrice,
      currencySymbol: details.currencySymbol,
    );
  }

  static String _period(int value, String unit) =>
      '$value ${value == 1 ? unit : '${unit}s'}';
  static String _isoPeriod(String value) {
    final match = RegExp(r'^P(\d+)([DWMY])$').firstMatch(value);
    if (match == null) return value;
    return _period(
      int.parse(match[1]!),
      {'D': 'day', 'W': 'week', 'M': 'month', 'Y': 'year'}[match[2]]!,
    );
  }

  /// Computes a comparable annual-vs-monthly savings percentage in one currency.
  static int? savingsPercent({
    required PaywallProduct annual,
    required PaywallProduct monthly,
  }) {
    if (annual.currency != monthly.currency ||
        annual.rawPrice == null ||
        monthly.rawPrice == null ||
        monthly.rawPrice! <= 0) {
      return null;
    }
    return (100 * (1 - annual.rawPrice! / (12 * monthly.rawPrice!)))
        .round()
        .clamp(0, 100);
  }
}
