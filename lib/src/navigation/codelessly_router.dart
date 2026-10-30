import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:navigation_utils/navigation_utils.dart';

import '../../codelessly_sdk.dart';
import '../functions/action_chain.dart';
import '../ui/codelessly_loading_screen.dart';
import 'browser_history.dart';

/// The screens of a Codelessly app as pages of a [Router], built on
/// NavigationUtils, so the app navigates the way a website does: every screen
/// has a URL, the browser's back and forward buttons move through the screens
/// the app opened, and a reload or a shared link opens the same screen with
/// the same back stack.
///
/// Show it as the app's router, which owns the browser's address:
///
/// ```dart
/// final router = CodelesslyRouter(controller: controller, basePath: '/my-app');
/// MaterialApp.router(routerConfig: router.config());
/// ```
///
/// Or embed it, e.g. a preview inside another app, without touching the
/// address with `router.config(syncWithBrowser: false)`.
///
/// Navigation actions of the app's screens go through the router whenever a
/// screen is shown by one (see [CodelesslyRouterDelegate.maybeOf]).
class CodelesslyRouter {
  /// Shows the app's screens. Its layouts load through copies of it, one per
  /// screen.
  final CodelesslyWidgetController controller;

  /// The router delegate: the stack of screens.
  final CodelesslyRouterDelegate delegate;

  /// Reads and writes the browser's address.
  final CodelesslyRouteInformationParser parser;

  /// Creates a router for the app [controller] loads. [basePath] prefixes
  /// every URL, such as `/my-app` for a site served under it. Screens with
  /// a URL path are at `[basePath]/[path]`; others at `[basePath]/[canvasId]`;
  /// the app's entry screen at [basePath].
  ///
  /// When the router doesn't sync with the browser, it first shows
  /// [initialLocation], such as `/guide/bat-star`, above the entry screen
  /// as a link would; else the screen of [controller]'s layout ID alone;
  /// else the entry screen.
  CodelesslyRouter({
    required this.controller,
    String basePath = '',
    String? initialLocation,
    List<NavigatorObserver> observers = const [],
    @visibleForTesting void Function(int delta)? historyGo,
    @visibleForTesting Object? Function()? historyState,
  }) : _historyGo = historyGo,
       _historyState = historyState ?? browserHistoryState,
       delegate = CodelesslyRouterDelegate(
         controller: controller,
         initialLocation: initialLocation,
         observers: observers,
       ),
       parser = CodelesslyRouteInformationParser(basePath: basePath) {
    parser.delegate = delegate;
  }

  CodelesslyRouteInformationProvider? _provider;

  final void Function(int delta)? _historyGo;

  final Object? Function() _historyState;

  /// The [RouterConfig] for `MaterialApp.router(routerConfig: ...)`.
  ///
  /// When [syncWithBrowser] is true, the router owns the browser's address
  /// and history: use it for the app's root router only. Otherwise the
  /// screens keep their history in memory, for an app embedded in another.
  RouterConfig<DefaultRoute> config({bool syncWithBrowser = true}) {
    if (!syncWithBrowser) {
      return RouterConfig(routerDelegate: delegate);
    }
    final CodelesslyRouteInformationProvider provider = _provider ??=
        CodelesslyRouteInformationProvider(
          delegate: delegate,
          historyGo: _historyGo,
          // A reload starts with the address and the state the browser
          // kept with its history entry: the stack of screens it showed.
          initialRouteInformation: RouteInformation(
            uri: Uri.parse(
              WidgetsBinding.instance.platformDispatcher.defaultRouteName,
            ),
            state: _historyState(),
          ),
        );
    delegate.syncsWithBrowser = true;
    return RouterConfig(
      routerDelegate: delegate,
      routeInformationParser: parser,
      routeInformationProvider: provider,
      backButtonDispatcher: RootBackButtonDispatcher(),
    );
  }

  /// Releases the router's resources.
  void dispose() {
    _provider?.dispose();
    delegate.dispose();
  }
}

/// The browser history entry of a stack of screens: what a reload, or the
/// browser's back and forward buttons, restore.
@immutable
class CodelesslyHistoryEntry {
  /// The key of the entry's data in [RouteInformation.state].
  static const String stateKey = 'codelessly';

  /// The locations of the screens, bottom first, such as
  /// `['/', '/guide/bat-star?tab=map']`.
  final List<String> stack;

  /// How many entries back the browser holds the stack below this one's top
  /// screen, which going back in the app returns to. Null when no entry is
  /// known to hold it.
  final int? back;

  /// Creates a [CodelesslyHistoryEntry].
  const CodelesslyHistoryEntry(this.stack, [this.back]);

  /// Reads the entry an app stored in [state]; null when it holds none.
  static CodelesslyHistoryEntry? fromState(Object? state) {
    if (state is! Map) return null;
    final Object? entry = state[stateKey];
    if (entry is! Map || entry['stack'] is! List) return null;
    final List<String> stack = [
      for (final Object? location in entry['stack'] as List)
        if (location is String && location.startsWith('/')) location,
    ];
    if (stack.isEmpty) return null;
    final Object? back = entry['back'];
    return CodelesslyHistoryEntry(stack, back is num ? back.toInt() : null);
  }

  /// The state to store with a browser history entry.
  Map<String, Object?> toState() => {
    stateKey: {'stack': stack, 'back': back},
  };
}

/// A route read from the browser's address, with the history entry it was
/// stored with, if any.
class CodelesslyLinkRoute extends DefaultRoute {
  /// The stack of screens of the browser's history entry.
  final CodelesslyHistoryEntry? entry;

  /// Creates a [CodelesslyLinkRoute].
  CodelesslyLinkRoute({
    required super.path,
    super.queryParameters,
    this.entry,
  });
}

/// Maps the browser's address to the screen stack and back, under a base
/// path such as a site's `/<slug>`.
class CodelesslyRouteInformationParser extends DefaultRouteInformationParser {
  /// The path every URL of the app starts with, without a trailing slash;
  /// empty for an app at the root.
  final String basePath;

  /// The delegate whose stack [restoreRouteInformation] stores.
  late CodelesslyRouterDelegate delegate;

  /// Creates a [CodelesslyRouteInformationParser].
  CodelesslyRouteInformationParser({String basePath = ''})
    : basePath = _trimBase(basePath);

  static String _trimBase(String path) {
    final String trimmed = path.trim();
    if (trimmed.isEmpty || trimmed == '/') return '';
    final String withSlash = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return withSlash.endsWith('/')
        ? withSlash.substring(0, withSlash.length - 1)
        : withSlash;
  }

  /// [uri]'s location in the app: its path without [basePath], and its
  /// query. A URL outside [basePath] is the entry screen.
  String locationOf(Uri uri) {
    String path = uri.path.isEmpty ? '/' : uri.path;
    if (basePath.isNotEmpty) {
      if (path == basePath) {
        path = '/';
      } else if (path.startsWith('$basePath/')) {
        path = path.substring(basePath.length);
      } else {
        path = '/';
      }
    }
    return Uri(
      path: path,
      queryParameters: uri.queryParameters.isEmpty
          ? null
          : uri.queryParameters,
    ).toString();
  }

  /// The URL of [location], a location in the app.
  Uri urlOf(String location) {
    final Uri uri = Uri.parse(location);
    final String path = uri.path == '/' || uri.path.isEmpty
        ? (basePath.isEmpty ? '/' : basePath)
        : '$basePath${uri.path}';
    return Uri(
      path: path,
      queryParameters: uri.queryParameters.isEmpty
          ? null
          : uri.queryParameters,
    );
  }

  @override
  Future<DefaultRoute> parseRouteInformation(
    RouteInformation routeInformation,
  ) {
    final Object? state = routeInformation.state;
    final Uri location = Uri.parse(locationOf(routeInformation.uri));
    return SynchronousFuture(
      CodelesslyLinkRoute(
        path: location.path,
        queryParameters: location.queryParameters,
        entry: CodelesslyHistoryEntry.fromState(state),
      ),
    );
  }

  @override
  RouteInformation? restoreRouteInformation(DefaultRoute configuration) {
    final CodelesslyHistoryEntry entry = delegate.historyEntry;
    return RouteInformation(
      uri: urlOf(entry.stack.last),
      state: entry.toState(),
    );
  }
}

/// Reports the screen stack to the browser: a screen the app opens adds a
/// history entry, and going back in the app goes back in the browser, so the
/// browser's back and forward buttons and the app's own agree.
class CodelesslyRouteInformationProvider
    extends PlatformRouteInformationProvider {
  /// The delegate whose changes are reported.
  final CodelesslyRouterDelegate delegate;

  /// Moves through the browser's history: `history.go` on the web, none
  /// elsewhere.
  final void Function(int delta)? historyGo;

  /// Creates a [CodelesslyRouteInformationProvider].
  CodelesslyRouteInformationProvider({
    required this.delegate,
    required super.initialRouteInformation,
    void Function(int delta)? historyGo,
  }) : historyGo = historyGo ?? (kIsWeb ? browserHistoryGo : null);

  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {
    final CodelesslyHistoryChange change = delegate.takeHistoryChange();
    if (change case CodelesslyHistoryBack(:final int delta)
        when historyGo != null) {
      // The browser already holds the screen below: go back to it. The
      // browser then reports that entry, whose stack is the one shown.
      historyGo!(delta);
      return;
    }
    super.routerReportsNewRouteInformation(
      routeInformation,
      type: change is CodelesslyHistoryPush
          ? RouteInformationReportingType.navigate
          : RouteInformationReportingType.neglect,
    );
  }
}

/// How the browser's history records a change of the screen stack.
sealed class CodelesslyHistoryChange {
  const CodelesslyHistoryChange();
}

/// A new history entry: a screen opened, or the stack reset.
class CodelesslyHistoryPush extends CodelesslyHistoryChange {
  /// Creates a [CodelesslyHistoryPush].
  const CodelesslyHistoryPush();
}

/// The current history entry changes in place, e.g. as the browser reports
/// an entry it moved to.
class CodelesslyHistoryReplace extends CodelesslyHistoryChange {
  /// Creates a [CodelesslyHistoryReplace].
  const CodelesslyHistoryReplace();
}

/// Going back [delta] entries, to one that holds the stack shown.
class CodelesslyHistoryBack extends CodelesslyHistoryChange {
  /// The (negative) number of entries to move.
  final int delta;

  /// Creates a [CodelesslyHistoryBack].
  const CodelesslyHistoryBack(this.delta);
}

/// The stack of screens of a Codelessly app, as a NavigationUtils router
/// delegate. Each screen (layout) of the published app is a route: at its
/// URL path when it has one (`/guide/:id`), at its canvas id otherwise
/// (`/<canvasId>`), and the entry screen at `/`. The route's query and path
/// parameters are the screen's parameters (`${route.name}`).
class CodelesslyRouterDelegate extends DefaultRouterDelegate {
  /// The key [globalData] holds the parameters a screen was opened with
  /// under, keeping their types (lists, maps, numbers) for the screen.
  static const String paramsKey = 'codelessly.params';

  /// The app's controller. Each screen loads its layout through a copy.
  final CodelesslyWidgetController controller;

  /// The screen to show first when no browser gives one, such as
  /// `/guide/bat-star`, above the entry screen. When null, the screen of
  /// [controller]'s layout ID, else the entry screen.
  final String? initialLocation;

  /// Whether the browser's address and history follow the stack, as for the
  /// app's root router (see [CodelesslyRouter.config]).
  bool syncsWithBrowser = false;

  /// The Codelessly instance whose app this shows.
  Codelessly get codelessly => controller.effectiveCodelessly;

  /// The published app, once loaded.
  SDKPublishModel? get publishModel => _model;
  SDKPublishModel? _model;

  /// A location the browser reported before the app loaded.
  DefaultRoute? _pendingRoute;

  DataManager? _dataManager;
  StreamSubscription<SDKPublishModel?>? _modelSubscription;
  StreamSubscription<CStatus>? _statusSubscription;

  /// How many entries back the browser holds the stack below the top screen
  /// (see [CodelesslyHistoryEntry.back]).
  int? _back;

  CodelesslyHistoryChange _change = const CodelesslyHistoryReplace();

  /// What the action that opened a screen hands it, by its location, until
  /// the screen shows.
  final Map<String, ({List<BuildContext> openerHosts, ActionChain? chain})>
  _handoffs = {};

  /// Creates a [CodelesslyRouterDelegate].
  CodelesslyRouterDelegate({
    required this.controller,
    this.initialLocation,
    super.observers,
  }) : super(navigationDataRoutes: []) {
    onUnknownRoute = _buildNotFoundPage;
    pageOverride = _buildLoadingPage;
    _statusSubscription = codelessly.statusStream.listen((_) => _watchModel());
    _watchModel();
  }

  /// The nearest [CodelesslyRouterDelegate] that shows [context]'s screen,
  /// or null when no Codelessly router shows it.
  static CodelesslyRouterDelegate? maybeOf(BuildContext context) {
    final RouterDelegate<Object?>? delegate = Router.maybeOf(
      context,
    )?.routerDelegate;
    return delegate is CodelesslyRouterDelegate ? delegate : null;
  }

  /// The browser history entry of the stack shown.
  CodelesslyHistoryEntry get historyEntry => CodelesslyHistoryEntry([
    for (final DefaultRoute route in routes) locationOfRoute(route),
    if (routes.isEmpty) _pendingLocation ?? '/',
  ], _back);

  String? get _pendingLocation {
    final DefaultRoute? pending = _pendingRoute;
    return pending == null ? null : locationOfRoute(pending);
  }

  /// How the latest change should be reported to the browser; read once.
  CodelesslyHistoryChange takeHistoryChange() {
    final CodelesslyHistoryChange change = _change;
    _change = const CodelesslyHistoryReplace();
    return change;
  }

  /// The location of [route] in the app, such as `/guide/bat-star?tab=map`.
  static String locationOfRoute(DefaultRoute route) => Uri(
    path: route.path.isEmpty ? '/' : route.path,
    queryParameters: route.queryParameters.isEmpty
        ? null
        : route.queryParameters,
  ).toString();

  void _watchModel() {
    final DataManager? dataManager = codelessly.maybeDataManager;
    if (identical(dataManager, _dataManager)) return;
    _dataManager = dataManager;
    unawaited(_modelSubscription?.cancel());
    _modelSubscription = dataManager?.publishModelStream.listen(_setModel);
    _setModel(dataManager?.publishModel);
  }

  void _setModel(SDKPublishModel? model) {
    if (model == null || identical(model, _model)) return;
    final bool firstLoad = _model == null;
    _model = model;
    navigationDataRoutes = _buildRoutes(model);
    if (!firstLoad) {
      _change = const CodelesslyHistoryReplace();
      notifyListeners();
      return;
    }
    pageOverride = null;
    final DefaultRoute? pending = _pendingRoute;
    _pendingRoute = null;
    if (pending != null) {
      unawaited(setNewRoutePath(pending));
    } else if (routes.isEmpty) {
      final String? link = initialLocation;
      final String? screen = controller.layoutID;
      if (link != null) {
        _restore([if (_canonical(link) != '/') '/', link], fromLink: true);
      } else {
        _restore([
          (screen == null ? null : locationFor(screen, const {})) ?? '/',
        ]);
      }
    } else {
      notifyListeners();
    }
  }

  /// One route per screen: its URL path, the entry screen at `/`, and its
  /// canvas and layout ids, which links written before screens had paths
  /// use. Routes with more fixed segments come first, so `/guide/new` wins
  /// over `/guide/:id`.
  List<NavigationData> _buildRoutes(SDKPublishModel model) {
    final Map<String, String> patterns = {};
    void add(String pattern, String layoutId) =>
        patterns.putIfAbsent('/${CanvasLocation.segmentsOf(pattern).join('/')}', () => layoutId);

    final String? entry = model.resolveLayoutId(model.entryLayoutId);
    if (entry != null) add('', entry);
    final List<String> layoutIds = CanvasLocation.layoutIdsOf(model).toList();
    for (final String layoutId in layoutIds) {
      final String? path = CanvasLocation.layoutPathOf(model, layoutId);
      if (path != null) add(path, layoutId);
    }
    for (final String layoutId in layoutIds) {
      for (final String canvasId in CanvasLocation.canvasIdsOf(
        model,
        layoutId,
      )) {
        add(canvasId, layoutId);
      }
      add(layoutId, layoutId);
    }

    int literals(String pattern) => CanvasLocation.segmentsOf(
      pattern,
    ).where((segment) => !segment.startsWith(':')).length;
    final List<String> ordered = patterns.keys.toList()
      ..sort((a, b) => literals(b).compareTo(literals(a)));
    return [
      for (final String pattern in ordered)
        NavigationData(
          url: pattern,
          metadata: {'layoutId': patterns[pattern]},
          builder: (context, route, globalData) =>
              _buildScreen(patterns[pattern]!, route, globalData),
        ),
    ];
  }

  Widget _buildScreen(
    String layoutId,
    DefaultRoute route,
    Map<String, dynamic> globalData,
  ) {
    final Map<String, String> fromUrl = {
      ...route.queryParameters,
      ...route.pathParameters,
    };
    final Object? typed = globalData[paramsKey];
    // A parameter keeps the type it was opened with while the URL still
    // says the same; one edited in the address is the URL's text.
    final Map<String, dynamic> params = {
      for (final MapEntry(:String key, :String value) in fromUrl.entries)
        key: typed is Map &&
                typed.containsKey(key) &&
                CanvasLocation.stringOf(typed[key]) == value
            ? typed[key]
            : value,
    };
    final String location = locationOfRoute(route);
    return CodelesslyScreen(
      key: ValueKey(location),
      router: this,
      layoutId: layoutId,
      location: location,
      params: params,
      fromLink: route.metadata?['link'] == true,
    );
  }

  Page<dynamic> _buildLoadingPage(String name) => MaterialPage<void>(
    name: name,
    child: Builder(
      builder: (context) =>
          controller.loadingBuilder?.call(context) ??
          const CodelesslyLoadingScreen(),
    ),
  );

  Page<dynamic> _buildNotFoundPage(DefaultRoute route) => MaterialPage<void>(
    key: ValueKey('not-found:${route.path}'),
    name: route.name,
    child: _ScreenNotFound(
      onHome: () => resetTo(const ['/']),
    ),
  );

  /// The location of screen [destinationId] (a canvas or layout id) opened
  /// with [params]: its URL path with [params] filled in, else its id with
  /// [params] as the query. Null when the app has no such screen.
  String? locationFor(String destinationId, Map<String, dynamic> params) {
    final SDKPublishModel? model = _model;
    if (model == null || model.resolveLayoutId(destinationId) == null) {
      return null;
    }
    final String location =
        CanvasLocation.locationOf(model, destinationId, params) ??
        CanvasLocation.fill(destinationId, params)!;
    return _canonical('/$location');
  }

  static String _canonical(String location) {
    final Uri uri = Uri.parse(location.startsWith('/') ? location : '/$location');
    return locationOfRoute(
      DefaultRoute(path: _canonicalPath(uri.path), queryParameters: uri.queryParameters),
    );
  }

  /// [path] without a trailing slash, as NavigationUtils keys its routes.
  static String _canonicalPath(String path) {
    if (path.isEmpty) return '/';
    return path.length > 1 && path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
  }

  /// The route of [location] with the typed [params] the screen gets.
  DefaultRoute _routeFor(
    String location, {
    Map<String, dynamic>? params,
    bool fromLink = false,
  }) {
    final Uri uri = Uri.parse(location);
    final DefaultRoute link = DefaultRoute(
      path: uri.path.isEmpty ? '/' : uri.path,
      queryParameters: uri.queryParameters,
    );
    final DefaultRoute route =
        NavigationUtils.mapNavigationDataToDefaultRoute(
          routes: navigationDataRoutes,
          route: link,
        ) ??
        link;
    if (params != null) globalData[route.path] = {paramsKey: params};
    return route.copyWith(
      metadata: {...?route.metadata, if (fromLink) 'link': true},
    );
  }

  /// Opens the screen at [location] (see [locationFor]) above the current
  /// one, as a new browser history entry. Completes with what the screen
  /// passes back when it closes.
  ///
  /// A chain triggered on the screen can finish on the hosts in
  /// [openerHosts] after the screen closes (see [ActionChainOpener]).
  Future<Object?> pushLocation(
    String location, {
    Map<String, dynamic> params = const {},
    List<BuildContext> openerHosts = const [],
  }) {
    _handoffs[_canonical(location)] = (openerHosts: openerHosts, chain: null);
    _change = const CodelesslyHistoryPush();
    final Uri uri = Uri.parse(location);
    // The same screen with other parameters updates the top screen in
    // place: like a replace, the stack below it is where it was.
    final bool inPlace =
        routes.isNotEmpty && routes.last.path == _canonicalPath(uri.path);
    _back = !inPlace ? -1 : (_back == null ? null : _back! - 1);
    return push(
      uri.path,
      queryParameters: uri.queryParameters,
      data: {paramsKey: params},
    );
  }

  /// Shows the screen at [location] in place of the current one, as a new
  /// browser history entry: going back in the app skips the screen it
  /// replaced, while the browser's back button still returns to it.
  ///
  /// The new screen takes over [chain]: the actions after the one that
  /// replaced the screen run with it (see [ActionChainAdopter]).
  Future<Object?> replaceLocation(
    String location, {
    Map<String, dynamic> params = const {},
    ActionChain? chain,
  }) {
    _handoffs[_canonical(location)] = (openerHosts: const [], chain: chain);
    _change = const CodelesslyHistoryPush();
    _back = _back == null ? null : _back! - 1;
    final Uri uri = Uri.parse(location);
    return pushReplacement(
      uri.path,
      queryParameters: uri.queryParameters,
      data: {paramsKey: params},
    );
  }

  /// Clears the stack and shows [locations], bottom first, as a new browser
  /// history entry. [params] are the typed parameters of each location.
  void resetTo(
    List<String> locations, {
    List<Map<String, dynamic>> params = const [],
  }) {
    assert(locations.isNotEmpty);
    _change = const CodelesslyHistoryPush();
    _back = null;
    _replaceStack([
      for (int i = 0; i < locations.length; i++)
        _routeFor(locations[i], params: i < params.length ? params[i] : null),
    ]);
  }

  /// Whether the app can go back from its top screen.
  bool get canGoBack => routes.length > 1;

  @override
  void pop([dynamic result, bool apply = true, bool all = false]) {
    // A pop the app asks for (not one of the steps of another change).
    if (apply && routes.length > 1) {
      final int? back = _back;
      _change = back != null
          ? CodelesslyHistoryBack(back)
          : const CodelesslyHistoryPush();
      // Unknown until the browser reports the entry it went back to.
      _back = null;
    }
    super.pop(result, apply, all);
  }

  @override
  Future<void> setNewRoutePath(DefaultRoute configuration) async {
    // The browser reported this location: reports keep its entry.
    _change = const CodelesslyHistoryReplace();
    if (_model == null) {
      _pendingRoute = configuration;
      notifyListeners();
      return;
    }
    final CodelesslyHistoryEntry? entry = configuration is CodelesslyLinkRoute
        ? configuration.entry
        : null;
    final String location = _canonical(locationOfRoute(configuration));
    if (entry != null && _canonical(entry.stack.last) == location) {
      _back = entry.back;
      _restore(entry.stack, fromLink: true);
      return;
    }
    // A link without a stack: opened directly, the screen shows above the
    // entry screen, so going back reaches the app's start. While the app
    // runs, the screen goes back to its earlier place in the stack, or
    // opens above the top.
    _back = null;
    final List<String> current = [for (final route in routes) locationOfRoute(route)];
    final int index = current.indexOf(location);
    if (current.isEmpty) {
      _restore([if (location != '/') '/', location], fromLink: true);
    } else if (index != -1) {
      _restore(current.sublist(0, index + 1), fromLink: true);
    } else {
      _restore([...current, location], fromLink: true);
    }
  }

  /// Shows [stack], keeping the screens it shares with the current stack
  /// from the bottom up as they are, with their state.
  void _restore(List<String> stack, {bool fromLink = false}) {
    final List<String> target = [for (final location in stack) _canonical(location)];
    final List<String> current = [for (final route in routes) locationOfRoute(route)];
    int common = 0;
    while (common < current.length &&
        common < target.length &&
        current[common] == target[common]) {
      common++;
    }
    if (common == current.length && common == target.length) {
      notifyListeners();
      return;
    }
    _replaceStack([
      ...routes.take(common),
      for (final String location in target.skip(common))
        _routeFor(location, fromLink: fromLink),
    ]);
  }

  /// Makes [stack] the stack, completing the screens it drops.
  void _replaceStack(List<DefaultRoute> stack) {
    int keep = 0;
    while (keep < routes.length &&
        keep < stack.length &&
        identical(routes[keep], stack[keep])) {
      keep++;
    }
    while (routes.length > keep) {
      super.pop(null, false, true);
    }
    setRoutes(stack.isEmpty ? [_routeFor('/')] : stack);
  }

  @override
  void onRouteChanged(DefaultRoute route) {
    super.onRouteChanged(route);
    final SDKPublishModel? model = _model;
    final Object? layoutId = route.metadata?['layoutId'];
    if (model == null || layoutId is! String) return;
    final List<String> canvasIds = CanvasLocation.canvasIdsOf(model, layoutId);
    codelessly.route.value = CodelesslyRoute(
      canvasIds.isEmpty ? layoutId : canvasIds.first,
      {...route.queryParameters, ...route.pathParameters},
      locationOfRoute(route).substring(1),
    );
  }

  @override
  void dispose() {
    unawaited(_modelSubscription?.cancel());
    unawaited(_statusSubscription?.cancel());
    super.dispose();
  }
}

/// The screen a [CodelesslyRouterDelegate] shows at a location, and the
/// parameters it was opened with.
class CodelesslyRouteScope extends InheritedWidget {
  /// The screen's layout.
  final String layoutId;

  /// The screen's location in the app, such as `/guide/bat-star?tab=map`.
  final String location;

  /// The parameters the screen was opened with (`${route.name}`).
  final Map<String, dynamic> params;

  /// Whether the screen was opened by a link (the browser's address)
  /// rather than by the app: its parameters then also set the variables
  /// they name.
  final bool fromLink;

  /// Creates a [CodelesslyRouteScope].
  const CodelesslyRouteScope({
    super.key,
    required this.layoutId,
    required this.location,
    required this.params,
    required this.fromLink,
    required super.child,
  });

  /// The scope of the screen [context] is in, if a router shows it.
  static CodelesslyRouteScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CodelesslyRouteScope>();

  @override
  bool updateShouldNotify(CodelesslyRouteScope oldWidget) =>
      location != oldWidget.location || params != oldWidget.params;
}

/// A screen of a [CodelesslyRouterDelegate]: the layout, loaded through a
/// copy of the router's controller, with its route parameters.
class CodelesslyScreen extends StatefulWidget {
  /// The router that shows this screen.
  final CodelesslyRouterDelegate router;

  /// The screen's layout.
  final String layoutId;

  /// The screen's location in the app.
  final String location;

  /// The parameters the screen was opened with.
  final Map<String, dynamic> params;

  /// Whether the screen was opened by a link (see
  /// [CodelesslyRouteScope.fromLink]).
  final bool fromLink;

  /// Creates a [CodelesslyScreen].
  const CodelesslyScreen({
    super.key,
    required this.router,
    required this.layoutId,
    required this.location,
    required this.params,
    required this.fromLink,
  });

  @override
  State<CodelesslyScreen> createState() => _CodelesslyScreenState();
}

class _CodelesslyScreenState extends State<CodelesslyScreen> {
  late final CodelesslyWidgetController controller = widget.router.controller
      .copyWith(
        layoutID: widget.layoutId,
        codelessly: widget.router.codelessly,
      );

  /// Whether another screen covers this one.
  bool covered = false;

  /// What the action that opened this screen handed it.
  late final ({List<BuildContext> openerHosts, ActionChain? chain})? handoff =
      widget.router._handoffs.remove(widget.location);

  @override
  void initState() {
    super.initState();
    controller.initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool isCurrent = ModalRoute.isCurrentOf(context) ?? true;
    final bool isTop =
        widget.router.routes.isNotEmpty &&
        CodelesslyRouterDelegate.locationOfRoute(widget.router.routes.last) ==
            widget.location;
    if (isCurrent && covered) {
      // Back on top after the screens above it closed: navigation
      // listeners hear of it again, as when it first showed.
      SchedulerBinding.instance.addPostFrameCallback((_) => _notifyShown());
    }
    covered = !isCurrent && !isTop;
  }

  void _notifyShown() {
    if (!mounted) return;
    final SDKPublishModel? model = widget.router.publishModel;
    final List<String> canvasIds = model == null
        ? const []
        : CanvasLocation.canvasIdsOf(model, widget.layoutId);
    final String? canvasId =
        (model == null
            ? null
            : CodelesslyWidget.canvasIDForWidth(
                widget.layoutId,
                model,
                MediaQuery.sizeOf(context).width,
              )) ??
        canvasIds.firstOrNull;
    widget.router.codelessly.notifyNavigationListeners(
      context,
      layoutId: widget.layoutId,
      canvasId: canvasId,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget screen = CodelesslyWidget(controller: controller);
    if (handoff?.chain case final ActionChain chain) {
      screen = ActionChainAdopter(chain: chain, child: screen);
    }
    if (handoff?.openerHosts case final hosts? when hosts.isNotEmpty) {
      screen = ActionChainOpener(openerHosts: hosts, child: screen);
    }
    return CodelesslyRouteScope(
      layoutId: widget.layoutId,
      location: widget.location,
      params: widget.params,
      fromLink: widget.fromLink,
      child: screen,
    );
  }
}

class _ScreenNotFound extends StatelessWidget {
  final VoidCallback onHome;

  const _ScreenNotFound({required this.onHome});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link_off_rounded, size: 32, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('This screen does not exist.'),
          const SizedBox(height: 12),
          TextButton(onPressed: onHome, child: const Text('Go to start')),
        ],
      ),
    ),
  );
}
