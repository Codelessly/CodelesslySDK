// The code samples of the SDK's README and developer guide
// (CodelesslySDK/docs/guide), kept here so they're analyzed with the
// example: a sample that stops compiling fails `flutter analyze`.
//
// Nothing here runs in the example app.
// ignore_for_file: unused_element, unreachable_from_main
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/firebase.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

// ---------------------------------------------------------------------
// Quickstart: the three ways to load a project.
// ---------------------------------------------------------------------

/// A published slug, over HTTP.
void quickstartSlug() {
  final codelessly = Codelessly(config: const CodelesslyConfig(slug: 'my-project'));

  runApp(MaterialApp(home: CodelesslyWidget(codelessly: codelessly)));
}

/// A project token, on Firebase, with live updates.
Future<void> quickstartToken() async {
  WidgetsFlutterBinding.ensureInitialized();
  final codelessly = await codelesslyWithToken('YOUR_PROJECT_TOKEN');

  runApp(MaterialApp(home: CodelesslyWidget(codelessly: codelessly)));
}

/// A bundle shipped with the app, offline.
void quickstartAsset() {
  final codelessly = Codelessly.asset('assets/my_project.json.gz');

  runApp(MaterialApp(home: CodelesslyWidget(codelessly: codelessly)));
}

/// A bundle in memory (decoded JSON), offline.
void quickstartMemory(Map<String, Object?> json) {
  final codelessly = Codelessly.fromBundle(PublishBundle.fromJson(json));

  runApp(MaterialApp(home: CodelesslyWidget(codelessly: codelessly)));
}

// ---------------------------------------------------------------------
// Embedding.
// ---------------------------------------------------------------------

/// One layout, by id.
Widget embedLayout(Codelessly codelessly) => CodelesslyWidget(
      codelessly: codelessly,
      layoutId: 'profile-card',
    );

/// Everything a CodelesslyWidget takes.
Widget embedEverything(Codelessly codelessly, CodelesslyWidgetController controller) => CodelesslyWidget(
      codelessly: codelessly,
      controller: controller,
      // A layout id, a custom id, or the id of one of its canvases.
      layoutId: 'profile-card',
      // Show this canvas whatever the width (no breakpoints).
      canvasId: null,
      // `${route.userId}` in the layout.
      params: const {'userId': 'u_42'},
      // `${data.user.name}` in the layout.
      data: const {
        'user': {'name': 'Ada', 'plan': 'pro'},
      },
      sizing: CanvasSizing.fill,
      loadingBuilder: (context) => const Center(child: CircularProgressIndicator()),
      errorBuilder: (context, error) => Center(child: Text('Could not load: $error')),
      layoutBuilder: (context, layout) => SafeArea(child: layout),
      onNavigate: (context, request) => false,
    );

/// The instance comes from above: a scope.
Widget embedWithScope(Codelessly codelessly) => CodelesslyScope(
      codelessly: codelessly,
      child: const Column(
        children: [
          Expanded(child: CodelesslyWidget(layoutId: 'header')),
          Expanded(child: CodelesslyWidget(layoutId: 'feed')),
        ],
      ),
    );

/// The instance is the app's default.
void embedWithDefault(Codelessly codelessly) {
  Codelessly.setDefault(codelessly);

  runApp(const MaterialApp(home: CodelesslyWidget(layoutId: 'home')));
}

/// A card at its design size.
Widget sizingDesign(Codelessly codelessly) => Center(
      child: CodelesslyWidget(
        codelessly: codelessly,
        layoutId: 'upgrade-dialog',
        sizing: CanvasSizing.design,
      ),
    );

/// A layout in a fixed box: its canvas is picked by the box's width.
Widget sizingBox(Codelessly codelessly) => SizedBox(
      width: 390,
      height: 240,
      child: CodelesslyWidget(codelessly: codelessly, layoutId: 'promo-banner'),
    );

/// A layout in a scroll view: full width, its own height.
Widget sizingInList(Codelessly codelessly) => ListView(
      children: [
        const ListTile(title: Text('A Flutter widget')),
        CodelesslyWidget(codelessly: codelessly, layoutId: 'promo-banner'),
        const ListTile(title: Text('Another Flutter widget')),
      ],
    );

/// The instance's status, for the app's own loading UI.
Widget statusBuilder(Codelessly codelessly) => ListenableBuilder(
      listenable: codelessly,
      builder: (context, _) => switch (codelessly.status) {
        CEmpty() || CLoading() => const LinearProgressIndicator(),
        CLoaded() => const SizedBox.shrink(),
        CError(:final message) => Text(message),
      },
    );

// ---------------------------------------------------------------------
// The controller.
// ---------------------------------------------------------------------

class ControllerExample extends StatefulWidget {
  const ControllerExample({super.key, required this.codelessly});

  final Codelessly codelessly;

  @override
  State<ControllerExample> createState() => _ControllerExampleState();
}

class _ControllerExampleState extends State<ControllerExample> {
  final controller = CodelesslyWidgetController(layoutId: 'cart');

  @override
  void initState() {
    super.initState();
    // Notifies when the layout loads, fails, or its canvas changes.
    controller.addListener(() => debugPrint('loaded: ${controller.isLoaded}, canvas: ${controller.canvasId}'));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Expanded(child: CodelesslyWidget(codelessly: widget.codelessly, controller: controller)),
          Row(
            children: [
              // Read the screen's values: variables, route params, data.
              TextButton(
                onPressed: () => debugPrint('${controller.read('count')} ${controller.read('route.id')}'),
                child: const Text('Read'),
              ),
              // Change a variable of the screen.
              TextButton(onPressed: () => controller.setVariable('count', 0), child: const Text('Reset')),
              // Run a node's reactions, as a tap would.
              TextButton(onPressed: () => controller.trigger('checkout-button', 'click'), child: const Text('Tap')),
              // Show another layout in the same widget.
              TextButton(onPressed: () => controller.layoutId = 'checkout', child: const Text('Checkout')),
            ],
          ),
        ],
      );
}

// ---------------------------------------------------------------------
// Loading modes and caching.
// ---------------------------------------------------------------------

/// The editor's preview instead of the publish, with a token.
Future<Codelessly> loadPreview() => codelesslyWithToken(
      'YOUR_PROJECT_TOKEN',
      config: const CodelesslyConfig(publishSource: PublishSource.preview),
    );

/// The pieces of `codelesslyWithToken`, assembled by hand.
Future<Codelessly> loadTokenByHand() async {
  final app = await codelesslyFirebaseApp();
  return codelesslyOnFirebase(
    firestore: FirebaseFirestore.instanceFor(app: app),
    config: const CodelesslyConfig(authToken: 'YOUR_PROJECT_TOKEN'),
  );
}

/// A token, with Codelessly cloud data, accounts and files.
Future<Codelessly> loadTokenWithCloud() => codelesslyWithToken('YOUR_PROJECT_TOKEN', cloudServices: true);

/// A self-hosted mirror: one bundle file per project.
Codelessly loadSelfHostedBundle() => Codelessly(
      loader: HttpPublishLoader(
        projectId: 'my-project',
        baseUrl: 'https://cdn.example.com/codelessly',
        bundle: true, // GET https://cdn.example.com/codelessly/publish/my-project.json
        headers: const {'Authorization': 'Bearer <token>'},
      ),
    );

/// Every layout loaded up front; no live updates.
Codelessly loadPreloaded() => Codelessly(
      config: const CodelesslyConfig(slug: 'my-project', preload: true, liveUpdates: false),
    );

/// Load before the first frame, and handle a failure.
Future<void> loadEagerly(Codelessly codelessly) async {
  try {
    await codelessly.initialize();
  } on PublishLoadException catch (e) {
    debugPrint('Could not load the project: ${e.message}');
  }
}

/// A [PublishCache] that keeps the last publish between runs, in the
/// platform's preferences.
class PreferencesPublishCache implements PublishCache {
  PreferencesPublishCache(this.storage);

  /// `await PreferencesLocalStorage.open(prefix: 'codelessly.cache.')`.
  final PreferencesLocalStorage storage;

  @override
  Future<Json?> read(String key) async {
    final value = storage.get(key);
    return value is String ? (jsonDecode(value) as Map).cast<String, Object?>() : null;
  }

  @override
  Future<void> write(String key, Json value) => storage.put(key, jsonEncode(value));

  @override
  Future<void> clear() => storage.clear();
}

Future<Codelessly> loadWithDiskCache() async {
  final cache = PreferencesPublishCache(await PreferencesLocalStorage.open(prefix: 'codelessly.cache.'));
  return Codelessly(config: const CodelesslyConfig(slug: 'my-project'), cache: cache);
}

/// Start again: forget the loaded publish and the cache.
Future<void> reload(Codelessly codelessly) async {
  await codelessly.reset(clearCache: true);
  await codelessly.initialize();
}

/// A bundle downloaded by the app itself.
Future<Codelessly> loadDownloadedBundle(Uint8List bytes) async {
  // JSON, gzipped or not.
  final bundle = decodeBundle(bytes);
  return Codelessly.fromBundle(bundle);
}

// ---------------------------------------------------------------------
// Data and variables.
// ---------------------------------------------------------------------

/// Data for every screen of the instance.
void dataForTheInstance() {
  final codelessly = Codelessly(
    config: const CodelesslyConfig(slug: 'my-project'),
    data: const {
      'user': {'name': 'Ada'},
    },
  );

  // Later: the screens that read `data.cart` update.
  codelessly.setData('cart', [
    {'title': 'Tea', 'price': 4.5},
  ]);
}

/// Data for one widget, changing with the app's state.
class DataExample extends StatelessWidget {
  const DataExample({super.key, required this.codelessly, required this.unread});

  final Codelessly codelessly;
  final int unread;

  @override
  Widget build(BuildContext context) => CodelesslyWidget(
        codelessly: codelessly,
        layoutId: 'inbox-header',
        // Rebuilding with new data updates the layout in place.
        data: {'unread': unread},
      );
}

/// Two widgets of one instance: the badge and the list read the same
/// `cards` app variable, loaded once by a "Load cloud data" action with the
/// app scope, live on both.
Widget sharedLiveData(Codelessly codelessly) => Scaffold(
      appBar: AppBar(actions: [
        SizedBox(width: 56, height: 56, child: CodelesslyWidget(codelessly: codelessly, layoutId: 'badge')),
      ]),
      body: CodelesslyWidget(codelessly: codelessly, layoutId: 'list'),
    );

/// Tests: formulas that read the clock (`now()`, `timeAgo(date)`) see a
/// fixed time, moved by hand.
void pinnedClock() {
  FormulaClock.pinned = DateTime(2026, 11, 11, 15);
  // ...pump the screen, then:
  FormulaClock.pinned = DateTime(2026, 11, 11, 15, 5);
  FormulaClock.minutes.tick(); // `timeAgo` bindings now read 5 minutes later
  FormulaClock.pinned = null;
}

/// What the app keeps on the device (`${storage.<key>}`, persisted
/// variables), kept between runs.
Future<Codelessly> persistentStorage() async {
  final storage = await PreferencesLocalStorage.open(prefix: 'codelessly.my-project.');
  return Codelessly(
    config: CodelesslyConfig(slug: 'my-project', services: Services(storage: storage)),
  );
}

// ---------------------------------------------------------------------
// Actions and functions.
// ---------------------------------------------------------------------

Codelessly functions(BuildContext appContext) => Codelessly(
      config: CodelesslyConfig(
        slug: 'my-project',
        functions: {
          // A "call function" action named `addToCart`, with its params
          // already evaluated.
          'addToCart': (context, params) async {
            final id = params['productId'] as String?;
            debugPrint('add $id to the cart');
            // Change a variable of the screen that called.
            context.setVariable('cartCount', 3);
            // The result is `${result}` for the next action of the chain.
            return {'ok': true};
          },
          'signOut': (context, params) => Navigator.of(appContext).popUntil((route) => route.isFirst),
        },
      ),
    );

/// Layouts shown as designed: no bindings, no actions.
Codelessly staticLayouts() => Codelessly(
      config: const CodelesslyConfig(
        slug: 'my-project',
        expressions: NoopExpressionEngine(),
        actions: NoopActionRunner(),
      ),
    );

/// Only navigation and links run.
Codelessly navigationOnly() => Codelessly(
      config: const CodelesslyConfig(slug: 'my-project', actions: NavigationActionRunner()),
    );

// ---------------------------------------------------------------------
// Navigation.
// ---------------------------------------------------------------------

/// A whole project as the app: its screens are the app's routes.
Widget navigationWholeApp(Codelessly codelessly) => MaterialApp(
      onGenerateRoute: CodelesslyWidget.onGenerateRoute(codelessly),
    );

/// The project's screens in a navigator of their own, inside the app.
Widget navigationNested(Codelessly codelessly) => Navigator(
      onGenerateRoute: CodelesslyWidget.onGenerateRoute(
        codelessly,
        template: CodelesslyWidget(
          errorBuilder: (context, error) => Center(child: Text('$error')),
        ),
      ),
    );

/// The app routes some destinations itself.
Widget navigationHandler(Codelessly codelessly) => CodelesslyWidget(
      codelessly: codelessly,
      layoutId: 'home',
      onNavigate: (context, request) {
        if (request.type == NavigationType.push && request.destinationId == 'settings') {
          Navigator.of(context).pushNamed('/settings', arguments: request.params);
          return true; // Handled: the SDK does nothing more.
        }
        return false; // The SDK navigates.
      },
    );

/// Open one screen of the project from the app's own navigation.
void navigationPush(BuildContext context, Codelessly codelessly) {
  Navigator.of(context).push(
    CodelesslyWidget.route<void>(
      codelessly: codelessly,
      layoutId: 'product',
      params: const {'id': 'sku_123'},
    ),
  );
}

/// Follow the screen the project shows.
void navigationListen(Codelessly codelessly) {
  codelessly.route.addListener(() {
    final route = codelessly.route.value;
    debugPrint('now on ${route?.layoutId} (canvas ${route?.canvasId}) with ${route?.params}');
  });
}

/// A deep link: a screen by its path, id or name.
Widget navigationDeepLink(Codelessly codelessly) => CodelesslyWidget(
      codelessly: codelessly,
      initialScreen: '/guide/kraken?tab=habitat',
    );

// ---------------------------------------------------------------------
// Cloud services.
// ---------------------------------------------------------------------

/// The services of a project on Codelessly's Firebase, by hand.
Future<Codelessly> cloudServicesByHand(String projectId) async {
  final app = await codelesslyFirebaseApp();
  final firestore = FirebaseFirestore.instanceFor(app: app);
  final services = codelesslyCloudServices(
    projectId: projectId,
    firestore: firestore,
    auth: FirebaseAuth.instanceFor(app: app),
    storage: FirebaseStorage.instanceFor(app: app),
    localStorage: await PreferencesLocalStorage.open(prefix: 'codelessly.$projectId.'),
  );
  return codelesslyOnFirebase(
    firestore: firestore,
    config: CodelesslyConfig(projectId: projectId, authToken: 'YOUR_PROJECT_TOKEN', services: services),
  );
}

/// The app's own services: analytics and links.
class MyAnalytics implements AnalyticsService {
  @override
  void logEvent(String name, [Map<String, Object?> parameters = const {}]) => debugPrint('event $name $parameters');

  @override
  void logScreen(String name, {String? layoutId}) => debugPrint('screen $name');

  @override
  void logError(Object error,
          {StackTrace? stackTrace, String? message, String? type, Map<String, Object?> context = const {}}) =>
      debugPrint('error $type: $error');
}

class InAppLinks implements LinkOpener {
  @override
  Future<bool> open(String url) async {
    debugPrint('open $url in the app');
    return true;
  }
}

Codelessly ownServices() => Codelessly(
      config: CodelesslyConfig(
        slug: 'my-project',
        services: Services(analytics: MyAnalytics(), links: InAppLinks()),
      ),
    );

/// Cloud data in memory: a backend-free app, a demo, a test.
Codelessly memoryCloud() => Codelessly(
      config: CodelesslyConfig(
        slug: 'my-project',
        services: Services(cloud: BackendCloudDatabase(backend: MemoryDocumentBackend())),
      ),
    );

// ---------------------------------------------------------------------
// Scripting.
// ---------------------------------------------------------------------

/// Scripts implemented in Dart instead of JavaScript, by script name.
Codelessly nativeScripts() => Codelessly(
      config: CodelesslyConfig(
        slug: 'my-project',
        services: Services(
          scripts: FunctionScriptRunner({
            'loanPayment': (args, host) {
              final principal = (args['principal'] as num).toDouble();
              return principal * 0.05;
            },
          }),
        ),
      ),
    );

/// No scripts at all: each run fails with `EngineUnavailable`.
Codelessly noScripts() => Codelessly(
      config: CodelesslyConfig(slug: 'my-project', services: Services(scripts: const NoScriptRunner())),
    );

// ---------------------------------------------------------------------
// Theming and fonts.
// ---------------------------------------------------------------------

/// Layouts follow the app's theme instead of the project's.
Codelessly hostTheme() => Codelessly(
      config: const CodelesslyConfig(slug: 'my-project', useHostTheme: true),
    );

/// Layouts follow the platform's text size, up to 1.3 times.
Codelessly textScale() => Codelessly(
      config: const CodelesslyConfig(slug: 'my-project', maxTextScaleFactor: 1.3),
    );

/// Fonts shipped with the app instead of downloaded.
class BundledFonts implements FontFetcher {
  const BundledFonts();

  @override
  Future<Uint8List?> fetch(PublishFont font) async {
    final style = '${font.weight}${font.italic ? 'i' : ''}';
    try {
      final data = await rootBundle.load('assets/fonts/${font.family}-$style.ttf');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return null; // The text falls back to the platform's font.
    }
  }
}

Codelessly bundledFonts() => Codelessly.asset('assets/my_project.json.gz', fonts: const BundledFonts());

/// No font downloads: the fonts are declared in the app's pubspec.
Codelessly noFontDownloads() => Codelessly.asset('assets/my_project.json.gz', fonts: const NoFontFetcher());

// ---------------------------------------------------------------------
// Custom widgets.
// ---------------------------------------------------------------------

/// The app's own widgets for the layout's `external` nodes, by builder id.
Widget externalComponents(Codelessly codelessly) => MaterialApp(
      // Above the navigator, so every screen the project pushes has them.
      builder: (context, child) => ExternalComponents(
        builders: {
          'map': (context) => const Placeholder(),
          'ad-banner': (context) => const SizedBox(height: 50, child: Center(child: Text('Ad'))),
        },
        child: child!,
      ),
      home: CodelesslyWidget(codelessly: codelessly),
    );

// ---------------------------------------------------------------------
// App identity.
// ---------------------------------------------------------------------

/// The window or tab title follows the screen shown.
CodelesslyAppIdentityUpdater appIdentity(Codelessly codelessly) => CodelesslyAppIdentityUpdater(
      codelessly,
      fallbackName: 'My app',
      onChanged: (identity) => debugPrint('${identity.title}: ${identity.description}'),
    )..attach();

// ---------------------------------------------------------------------
// The signed-in user, for layouts.
// ---------------------------------------------------------------------

/// Mirrors the signed-in user into the instance's data: `${data.auth.isSignedIn}`,
/// `${data.auth.email}`, `${data.auth.profile.<field>}`.
void mirrorAuth(Codelessly codelessly) {
  final services = codelessly.services;
  if (services is Services) {
    services.watchAuth().listen((auth) => codelessly.setData('auth', auth));
  }
}

// ---------------------------------------------------------------------
// More of the guide's samples.
// ---------------------------------------------------------------------

/// A project's layouts and canvases.
Future<void> listLayouts(Codelessly codelessly) async {
  await codelessly.initialize();
  for (final layout in codelessly.publishModel!.layouts.values) {
    debugPrint('${layout.id}: ${[for (final c in layout.canvases) '${c.name} (${c.id}, path ${c.path})']}');
  }
}

/// Save what an instance loaded as a bundle.
Future<String> saveBundle() async {
  final codelessly = Codelessly(config: const CodelesslyConfig(slug: 'my-project', preload: true));
  await codelessly.initialize();
  final bundle = PublishBundle(model: codelessly.publishModel!, layouts: codelessly.layouts);
  final json = jsonEncode(bundle.toJson()); // write it to a file
  return json;
}

/// Debug builds follow the Editor's preview.
Future<Codelessly> previewInDebug() => codelesslyWithToken(
      'YOUR_PROJECT_TOKEN',
      config: const CodelesslyConfig(
        publishSource: kDebugMode ? PublishSource.preview : PublishSource.publish,
      ),
    );

/// Another Codelessly backend.
Future<Codelessly> stagingBackend(FirebaseOptions stagingOptions) async {
  final app = await codelesslyFirebaseApp(name: 'codelessly-staging', options: stagingOptions);
  return codelesslyWithToken(
    'YOUR_PROJECT_TOKEN',
    app: app,
    functionsBaseUrl: 'https://us-central1-<firebase-project>.cloudfunctions.net',
  );
}

Codelessly stagingSlug() => Codelessly(
      loader: HttpPublishLoader.firebaseStorage(projectId: 'my-project', bucket: '<bucket>', bundle: true),
    );

/// The project's theme, for the app's own widgets.
ThemeData projectTheme(Codelessly codelessly) => themeDataOf(codelessly.publishModel!.theme);

/// What layouts read as `theme` in dark mode: `theme.surface`,
/// `theme.colors.brandBlue`, `theme.text.title.fontSize`, `theme.isDark`.
Map<String, Object?> projectThemeValues(Codelessly codelessly) =>
    themeValues(codelessly.publishModel!.theme, dark: true);

/// API calls through a CORS proxy (the web).
Codelessly apiProxy() => Codelessly(
      config: CodelesslyConfig(
        slug: 'my-project',
        services: Services(api: HttpApiService(proxy: Uri.parse('https://example.com/api/proxy'))),
      ),
    );

/// A layout under an overlay.
Widget layoutOverlay(Codelessly codelessly) => CodelesslyWidget(
      codelessly: codelessly,
      layoutId: 'home',
      layoutBuilder: (context, layout) => Stack(
        children: [
          Positioned.fill(child: layout),
          const Positioned(right: 12, bottom: 12, child: Text('beta')),
        ],
      ),
    );

/// Recording a function's calls (tests).
Codelessly recordingFunctions(List<Map<String, Object?>> calls) => Codelessly(
      config: CodelesslyConfig(slug: 'my-project', functions: {'onTap': (context, params) => calls.add(params)}),
    );

/// A function reading the screen that called it.
Codelessly functionReadingScope() => Codelessly(
      config: CodelesslyConfig(
        slug: 'my-project',
        functions: {
          'track': (context, params) {
            final screen = context.scope.read('route.id');
            debugPrint('called from $screen with $params');
            return null;
          },
        },
      ),
    );

/// The URL path of a navigation's destination, for the app's own router.
String? locationOfRequest(Codelessly codelessly, NavigationRequest request) =>
    CanvasLocation.locationOf(codelessly.publishModel!, request.destinationId, request.params);

/// A function that opens a route of the app without making the chain wait for it.
Codelessly functionOpeningRoute(GlobalKey<NavigatorState> navigatorKey) => Codelessly(
      config: CodelesslyConfig(
        slug: 'my-project',
        functions: {
          'onNextButtonClicked': (context, params) {
            navigatorKey.currentState!.pushNamed('/next'); // a GlobalKey<NavigatorState> of your app
            return null;
          },
        },
      ),
    );

// ---------------------------------------------------------------------
// Paywalls.
// ---------------------------------------------------------------------

/// Managed paywalls come with the project's cloud services: placements,
/// store prices, purchases verified by Codelessly.
Future<Codelessly> paywallSetup() => codelesslyWithToken('YOUR_PROJECT_TOKEN', cloudServices: true);

/// The paywall published at `onboarding`; the Pro screen once it's bought.
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

class ProScreen extends StatelessWidget {
  const ProScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Pro')));
}

/// Without Codelessly's backend: the placements come from the publish and the
/// purchases from your own store code (RevenueCat, StoreKit). Report
/// [PaywallOutcome.purchased] only once your server verified the purchase.
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
