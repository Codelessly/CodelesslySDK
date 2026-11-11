# 16. Paywalls

[Guide](README.md) · Previous: [Troubleshooting and FAQ](15-troubleshooting.md) · Next: [Presenting, automations and host features](17-presenting-and-automations.md)

A paywall is a layout designed in the Codelessly Editor and published at a **placement**: a name your app shows
it at (`onboarding`, `settings`), with the **product slots** it sells (`monthly`, `annual`). Your app calls one
method; Codelessly resolves the placement, reads the prices from the App Store or Google Play, runs the purchase,
verifies it on Codelessly's server and tells you how it ended.

## Set up

Managed paywalls come with the project's cloud services:

```dart
final codelessly = await codelesslyWithToken('YOUR_PROJECT_TOKEN', cloudServices: true);
```

That is all the setup. It adds `Services.paywalls` (placements resolved by Codelessly's paywall server, with its
experiments and audiences) and `Services.purchases` (StoreKit and Play Billing through the `in_app_purchase`
plugin, connected to the store only when a paywall first needs it). Every store product the paywall sells must
exist in App Store Connect or the Play Console and in the project's products. The App Store needs StoreKit 2
(iOS 15 or later).

Purchases waiting for verification are journaled in the services' `localStorage`, in memory by default. To keep
them across restarts, build the services by hand ([Cloud data and services](09-cloud-data-and-services.md)) with
`codelesslyCloudServices(..., functions: FirebaseFunctions.instanceFor(app: app), localStorage: await
PreferencesLocalStorage.open())`. Either way the store delivers an unfinished transaction again on the next
start: Codelessly completes a transaction only after its server verified it.

## Show a paywall

`codelessly.paywall.present` shows the paywall as a full-screen route on the nearest `Navigator` and completes
when it's gone:

```dart
Future<void> openProFeature(BuildContext context, Codelessly codelessly) async {
  final result = await codelessly.paywall.present(context, placement: 'onboarding');
  if (!context.mounted) return;
  switch (result.outcome) {
    case PaywallOutcome.purchased || PaywallOutcome.restored:
      // result.entitlementId: the entitlement Codelessly verified ('pro').
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProScreen()));
    case PaywallOutcome.failed:
      debugPrint('Paywall failed: ${result.error}');
    default:
      // closed (dismissed) or skipped (a holdout, nothing published there).
      break;
  }
}
```

With one project, `Codelessly.instance.paywall.present(...)` does the same for the default instance.

| `result.outcome` | When |
|---|---|
| `purchased` | A purchase was verified. `entitlementId` is what it grants. |
| `restored` | A restore found a verified purchase. |
| `closed` | The user dismissed it: its close button, or back. |
| `skipped` | Nothing to show: an experiment's holdout, a user the placement doesn't target, or no paywall there. |
| `failed` | It couldn't be shown (no `Navigator`, a server error). `error` says why. |

A purchase that is canceled or fails keeps the paywall open, with the error in `${paywall.error}`, so the user
can try again. A restore that finds nothing keeps it open too (`${paywall.restoreResult}` is `nothing`).

`present` also takes `data` (the layout's `data.<key>`), `locale` (default: the app's) and `appVersion`, which
the paywall server can target.

## Design the layout

A paywall layout uses `paywall` actions and reads the paywall's values:

| Action operation | Does |
|---|---|
| `purchase` | Buys the selected product (or the action's `slot`). |
| `restore` | Restores purchases. |
| `selectProduct` | Selects the action's `slot`. |
| `closePaywall` | Dismisses the paywall (`closed`). |
| `openLegalLink` | Opens the action's `url`: an `https://` link, such as `${paywall.termsUrl}`. |

| Value | Is |
|---|---|
| `${product.price}`, `.period`, `.trial`, `.introOffer`, `.pricePerMonth`, `.savingsPercent`, `.slot` | The selected product, with the store's localized prices. |
| `${products}` | Every product, in slot order (the same fields). |
| `${productsBySlot.annual.price}` | A store-backed product looked up by its slot ID, independent of selection or ordering. |
| `${paywall.purchasing}`, `.restoring`, `.error`, `.restoreResult`, `.selectedProduct` | Progress, for spinners and messages. |
| `${paywall.placement}`, `.variant`, `.termsUrl`, `.privacyUrl` | Where it was shown, and the project's legal links. |
| `${entitlements.pro}` | True when the user holds the entitlement `pro`. |

Prices always come from the store; never type them into the layout. Store review requires a restore button and
links to your terms and privacy policy on a paywall.

## Events

Each paywall logs `paywall_view`, `paywall_product_selected`, `paywall_purchase_start`,
`paywall_purchase_success`, `paywall_purchase_fail`, `paywall_restore` and `paywall_close` to the services'
`analytics` ([Cloud data and services](09-cloud-data-and-services.md)), with the placement, variant and slot. With
managed paywalls they are also recorded on Codelessly's server.

## Without Codelessly's backend

An app that loads its project without cloud services (a slug, a bundle) can still show paywalls: the placements
come from the publish, and the purchases from `Services.purchases`, a `PurchaseService` of your own over your
store code (RevenueCat, StoreKit):

```dart
class MyPurchases implements PurchaseService {
  final _updates = StreamController<PaywallResult>.broadcast();

  @override
  Stream<PaywallResult> get updates => _updates.stream;

  @override
  Future<List<PaywallProduct>> products(List<ProductSlot> slots) async => [
        for (final slot in slots)
          PaywallProduct(slot: slot.id, storeId: slot.iosProductId, price: r'$4.99', currency: 'USD'),
      ];

  @override
  Future<void> purchase(PaywallProduct product) async {
    // Buy product.storeId with your store code, verify it, then:
    _updates.add(PaywallResult(PaywallOutcome.purchased, productId: product.storeId, entitlementId: 'pro'));
  }

  @override
  Future<void> restore() async => _updates.add(const PaywallResult(PaywallOutcome.restoreNothing));

  @override
  Future<void> dispose() => _updates.close();
}

Codelessly ownPurchases() => Codelessly(
      config: CodelesslyConfig(slug: 'my-project', services: Services(purchases: MyPurchases())),
    );
```

Report `purchased` or `restored` only for a purchase your server verified, with the entitlement it grants.

## Test store (web previews and demos)

The web has no App Store or Google Play, so a paywall there can't sell. For preview and demo sites, the SDK's
**test store** runs a paywall's whole flow on the web — products, trial, purchase, restore, cancel and decline —
from made-up data published with each product slot, **without charging and without ever granting a real
entitlement**.

Give each slot of the published `paywall` a `test` object, and the paywall `"testStore": true`:

```json
{
  "products": [
    {"id": "monthly", "iosProductId": "pro.monthly",
     "test": {"rawPrice": 4.99, "currency": "USD", "period": "month", "trialDays": 7, "entitlementId": "pro"}},
    {"id": "annual", "iosProductId": "pro.annual",
     "test": {"price": "$39.99", "rawPrice": 39.99, "currency": "USD", "period": "year", "entitlementId": "pro"}},
    {"id": "declined", "test": {"rawPrice": 1, "entitlementId": "pro", "outcome": "declined"}}
  ],
  "placements": [{"id": "onboarding", "layoutId": "paywall", "productSlots": ["annual", "monthly"]}],
  "testStore": true
}
```

`test` (`ProductTestData` in codelessly_api) has `price` (shown; derived from `rawPrice` when empty), `rawPrice`,
`currency`, `currencySymbol`, `period` (`week`, `month`, `year`, or empty for a one-time purchase), `trialDays`,
`entitlementId` (the test entitlement a purchase grants) and `outcome`: `purchased` (default), `declined` (the
purchase fails with code `payment-declined`) or `cancelled` (`purchase-cancelled`). Real stores ignore it.

When it runs is `Services(testStore:)`, a `TestStoreMode`:

- `auto` (default): on the web, when the published paywall has `"testStore": true`. Never on iOS, Android or
  desktop, which have a real store: there the flag changes nothing.
- `force`: always on the web, whatever the publish says (the editor's run preview); elsewhere only outside release
  builds (tests).
- `off`: never.

`codelesslyCloudServices(testStore:)` and `codelesslyWithToken(testStore:)` pass it on. While it's on
(`Services.usesTestStore`), `Services.paywalls` is the test store's `PaywallRuntime` and `Services.purchases` its
`TestPurchaseService`; `Services.paywallsChanged` notifies when that switches (the publish loaded or changed).

What it does:

- Products come from the slots' `test` data (a slot without it is unavailable, like a store product that isn't
  found), with `price`, `currency`, `period` (`1 month`), `trial` (`7 days`), `eligibleForTrial`, `pricePerMonth` and
  the yearly product's `savingsPercent` over a monthly one. Every one has `test: true` (`${product.test}`), so the
  layout can badge it.
- A purchase ends, after a short delay, as its `outcome` says. `purchase` with offer `trial` takes the trial (only
  while the user hasn't test-bought that slot), `standard` skips it.
- Restore restores the current user's earlier test purchases, or ends with `nothing-to-restore`.
- Test purchases are kept in `Services.storage` per user (`codelessly.test_store.v1.<uid>`, `anonymous` when
  signed out) and read back as the user's `entitlements`.

The guarantees: the test store's backend (`TestPaywallBackend`) resolves placements from the publish and never
contacts Codelessly's paywall server (no resolve, no verification, no events, nothing written to Firestore or
functions); its grants live only in the test store's own runtime and are dropped when it turns off; and the server
rejects test receipts anyway. Analytics events it logs carry `test: true`.

## Open a paywall from a screen

A layout opens a placement with the action `{"type": "paywall", "operation": "openPaywall", "placement":
"upgrade"}`. Its screen comes in as a navigation would: give the action a `routeTransition` (`{"preset":
"coverVertical", "durationMs": 520}`) or a `transition` with `transitionMs` / `reverseTransitionMs`, as on
`navigate`. A purchase, a restore or the paywall's close action pops it, so the transition plays in reverse. Its
bindings read `paywall.placement`, `paywall.termsUrl` / `privacyUrl` and, on the test store, `paywall.test`
(`true`), as a presented paywall's do. The action's `${result.outcome}` is how it ended.

## Embed a paywall

To show a paywall inside your own screen instead, give a `PaywallSession` to `CodelesslyWidget(paywall:)`. Its
`paywall` actions act on the session, and `session.result` completes like `present`'s result. Outside a paywall
(a layout shown without a session), `purchase`, `restore` and `selectProduct` actions fail.

A `PaywallRuntime` whose factory creates a separate purchase adapter for each session owns and disposes those
adapters by default. If its factory returns the app's shared `Services.purchases`, set
`ownsPurchaseServices: false`; `Services` retains ownership. `codelesslyPaywalls` configures this for the managed
shared store. Session disposal still removes its listeners and rejects stale account results.

## Test

Paywalls are tested like any screen ([Testing](14-testing.md)): give the instance a bundle whose layout is the
paywall and `Services(purchases: ...)` a fake `PurchaseService`, call `present`, and tap its buttons. The SDK's
own tests (`test/app/paywall_test.dart`) also fake the paywall server and the store; `Services(testStore:
TestStoreMode.force)` runs a published paywall on the test store (`test/app/test_store_paywall_test.dart`).
