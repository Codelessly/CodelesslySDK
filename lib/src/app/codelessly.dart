import 'dart:async';
import 'dart:convert' show jsonEncode;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart' show CombinedMapView;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext, GlobalKey, Rect;

import '../features/data/app_data_sources.dart';
import '../render/components.dart' show ComponentRegistry;
import '../features/first_party.dart' show AuthScope, kFirstPartyFeatures;
import '../runtime/actions/app_events.dart';
import '../runtime/actions/feature.dart';
import '../runtime/actions/runner.dart' show CoreActions;
import '../runtime/actions/context.dart' show AppFunction;
import '../runtime/contracts.dart';
import '../runtime/expressions/scopes.dart';
import '../services/services.dart';
import 'automations.dart';
import 'host_lifecycle.dart';
import 'config.dart';
import 'fonts.dart';
import 'hosted_plugins.dart';
import 'loader.dart';
import 'managed_components.dart';
import 'navigation.dart';
import 'paywalls.dart';
import 'persisted_variables.dart';
import 'presenter.dart';
import 'site_files.dart';
import 'runtime.dart';

/// The publish model's key holding the project's paywall setup
/// ([PaywallConfig] JSON), next to its `apis`.
const kPublishModelPaywallKey = 'paywall';

/// A published Codelessly project: loads and caches its publish model and
/// layouts, registers their fonts, and holds the app's data the layouts
/// read. [CodelesslyWidget]s show its layouts.
///
/// Instances are explicit: create one per project (or per publish source)
/// and pass it to the widgets, or put it above them with a
/// [CodelesslyScope]. [Codelessly.instance] is an optional default, for apps
/// with one project.
///
/// ```dart
/// // A published slug, over HTTP.
/// final codelessly = Codelessly(config: const CodelesslyConfig(slug: 'my-project'));
///
/// // A bundle shipped with the app, offline.
/// final offline = Codelessly.asset('assets/my_project.json.gz');
/// ```
///
/// A project token is read from Firebase: `codelesslyWithToken` in
/// `package:codelessly_sdk/firebase.dart`.
///
/// Nothing loads until [initialize] is called; a [CodelesslyWidget] calls
/// it when first built. It notifies its listeners when [status] changes
/// and when a new publish arrives.
///
/// Call [dispose] when the app is done with it.
class Codelessly extends ChangeNotifier {
  /// A project loaded by [loader]; without one, [config]'s
  /// [CodelesslyConfig.slug] is fetched from Codelessly's storage.
  ///
  /// [cache] keeps the publish (default: in memory, for this run), [fonts]
  /// fetches the layouts' fonts (default: over HTTP), and [data] is what
  /// layouts read as `data.<key>`.
  ///
  /// With [managedComponents] (Firestore's on a Firebase app), the layouts'
  /// linked, Codelessly-managed components take the newer same-major
  /// versions their channel offers when a layout loads
  /// ([ManagedComponentResolver]); without it they show the version they
  /// were published with.
  Codelessly({
    this.config = const CodelesslyConfig(),
    PublishLoader? loader,
    PublishCache? cache,
    FontFetcher? fonts,
    Map<String, Object?> data = const {},
    ManagedComponentSource? managedComponents,
    ComponentRegistry? components,
    PluginSource? plugins,
  })  : loader = loader ?? _defaultLoader(config),
        cache = cache ?? MemoryPublishCache(),
        // A declared font (its url a path relative to the site) is read
        // through the loader's files, when it has them.
        fonts = CodelesslyFonts(fetcher: siteFontFetcher(fonts ?? HttpFontFetcher())),
        data = MapValueScope(values: {'data': data}),
        components = components ?? ComponentRegistry() {
    if (managedComponents != null) {
      managed = ManagedComponentResolver(source: managedComponents, cache: this.cache);
    }
    final l = this.loader;
    if (this.fonts.fetcher case final SiteFontFetcher site) site.files = l is PublishAssetSource ? l as PublishAssetSource : null;
    pluginSource = plugins ?? (l is PluginSource ? l as PluginSource : null);
    // Node types the installed features implement as data (hosted plugins
    // installed in the app's runner).
    for (final f in features) {
      for (final d in f.components) {
        this.components.define(d);
      }
    }
    _ownComponents.addAll(this.components.types);
    this.components.onMissing = _componentMissing;
    this.components.addListener(_declarationsChanged);
  }

  /// A definition arrived or changed its declaration: the loaded layouts
  /// that call it are decoded again, so their calls' props are typed by the
  /// declaration as it is now (the screens on show read their values through
  /// the new declaration already).
  void _declarationsChanged() {
    final types = components.changed;
    if (types.isEmpty || _layouts.isEmpty) return;
    final catalog = _layoutCatalog;
    for (final e in _layouts.entries.toList()) {
      if (!e.value.document.nodes.values.any((n) => types.contains(n.type))) continue;
      _layouts[e.key] = PublishLayout.fromJson(e.value.toJson(), catalog: catalog);
    }
  }

  /// Resolves the layouts' managed components at load; null: each shows its
  /// published snapshot.
  ManagedComponentResolver? managed;

  /// Where the hosted plugins the publish lists (`model.plugins`) come from:
  /// the loader's (a bundle's embedded versions, `plugins/{id}/versions/{n}`
  /// over HTTP or in Firestore), unless the app gives another. Null: none
  /// are installed (their node types render as empty boxes).
  late final PluginSource? pluginSource;

  final List<CodelesslyFeature> _hosted = [];
  final List<HostedPluginLoad> _pluginLoads = [];

  /// What loading each plugin the publish lists gave: installed, or skipped
  /// and why.
  List<HostedPluginLoad> get hostedPlugins => List.unmodifiable(_pluginLoads);

  /// The runner the screens run reactions with: [CodelesslyConfig.actions],
  /// with the action types of the hosted plugins installed (when it is a
  /// [CoreActions]).
  ActionRunner get actions {
    final a = config.actions;
    if (_hosted.isEmpty || a is! CoreActions) return a;
    return _actions ??= CoreActions(handlers: a.handlers, features: [...a.features, ..._hosted]);
  }

  ActionRunner? _actions;

  /// Installs the hosted plugins [model] lists that aren't yet: through the
  /// loader's [pluginSource], the cache, their digests, the SDK version and
  /// the app's catalog (loadHostedPlugins); their node types become component
  /// definitions, their action types join [actions], their declarations the
  /// catalog layouts decode with. A plugin that fails a check is skipped and
  /// logged (`plugin_skipped`).
  Future<void> _installPlugins(PublishModel model) async {
    final source = pluginSource;
    final installed = {for (final l in _pluginLoads) (l.ref.id, l.ref.version)};
    final refs = [
      for (final r in model.plugins)
        if (!installed.contains((r.id, r.version))) r,
    ];
    if (source == null || refs.isEmpty) return;
    final loads = await loadHostedPlugins(refs, source: source, host: config.catalog, cache: cache);
    for (final load in loads) {
      _pluginLoads.add(load);
      switch (load) {
        case HostedPluginInstalled(:final feature):
          _hosted.add(feature);
          _actions = null;
          for (final d in feature.components) {
            final type = d.componentType;
            if (type == null) continue;
            _ownComponents.add(type);
            components.define(d);
          }
        case HostedPluginSkipped(:final ref, :final reason):
          final s = services;
          if (s is Services) {
            s.analytics.logError(PublishLoadException('plugin_skipped: ${ref.id} ${ref.version}: $reason'), type: 'plugin_skipped');
          }
      }
    }
  }

  /// The project's component definitions (docs/design/06 §4): what a call
  /// node in a layout renders, as ordinary boxes of the screen's tree.
  ///
  /// The published ones (`PublishModel.components`) load with the screens
  /// that call them ([loadLayout] loads a layout's closure before it shows),
  /// each cached on its own by its digest, and a republished one replaces
  /// its definition: every instance on screen updates in place. An app may
  /// also define its own (a site's files, an editor's store) with
  /// [ComponentRegistry.define]; one it defined before loading wins over the
  /// published one of the same type. A call to a type no one defines renders
  /// as the call's empty box, is listed in [ComponentRegistry.missing] and
  /// logged (`component_missing`); it renders when the definition arrives.
  final ComponentRegistry components;

  /// Types the app defined itself (before any publish loaded): never
  /// replaced by a published definition.
  final Set<String> _ownComponents = {};

  /// The published definitions loaded, by type.
  final Map<String, PublishComponent> _published = {};
  final Map<String, Future<PublishComponent?>> _componentLoads = {};

  /// The published components loaded so far, by type.
  Map<String, PublishComponent> get publishedComponents => Map.unmodifiable(_published);

  /// A [Codelessly] showing [bundle] (a publish shipped with the app, or a
  /// test's), offline.
  factory Codelessly.fromBundle(
    PublishBundle bundle, {
    CodelesslyConfig config = const CodelesslyConfig(),
    FontFetcher? fonts,
    Map<String, Object?> data = const {},
    ComponentRegistry? components,
  }) =>
      Codelessly(config: config, loader: MemoryPublishLoader(bundle), fonts: fonts, data: data, components: components);

  /// A [Codelessly] showing the bundle in asset [asset] (`.json` or
  /// `.json.gz`).
  factory Codelessly.asset(
    String asset, {
    CodelesslyConfig config = const CodelesslyConfig(),
    FontFetcher? fonts,
    Map<String, Object?> data = const {},
  }) =>
      Codelessly(config: config, loader: AssetPublishLoader(asset), fonts: fonts, data: data);

  static Codelessly? _instance;

  /// The default instance, used by widgets given none (and with no
  /// [CodelesslyScope] above them). Set it with [Codelessly.setDefault].
  static Codelessly get instance =>
      _instance ??
      (throw StateError('No default Codelessly instance: call Codelessly.setDefault, '
          'or pass a Codelessly to the widget.'));

  /// The default instance, if one is set.
  static Codelessly? get maybeInstance => _instance;

  /// Makes [codelessly] the default instance (null clears it).
  static void setDefault(Codelessly? codelessly) => _instance = codelessly;

  /// Without a loader: a slug's bundle from Codelessly's storage. A project
  /// id or token needs Firestore: `codelesslyWithToken`, `codelesslyOnFirebase`
  /// (or a FirestorePublishLoader) from package:codelessly_sdk/firebase.dart.
  static PublishLoader _defaultLoader(CodelesslyConfig config) {
    final slug = config.slug;
    if (slug == null) return _NoLoader(config.projectId != null || config.authToken != null);
    return HttpPublishLoader.firebaseStorage(projectId: slug, bucket: kCodelesslyStorageBucket, bundle: true);
  }

  /// How this instance runs: its project and its runtime plugins.
  final CodelesslyConfig config;

  /// The services the layouts use: [CodelesslyConfig.services], else
  /// [Services] with their defaults. A [Services]' config follows the
  /// publish model (its APIs).
  late final CodelesslyServices services = config.services ?? (_ownedServices = Services());
  Services? _ownedServices;

  /// Where the publish model and the layouts come from.
  final PublishLoader loader;

  /// Where they're kept once loaded; [initialize] opens on a cached model
  /// and refreshes it in the background.
  final PublishCache cache;

  /// Registers the layouts' fonts with the engine.
  final CodelesslyFonts fonts;

  /// The app's data, read by layouts as `data.<key>`. [setData] changes it.
  final MapValueScope data;

  /// Which publish this shows ([CodelesslyConfig.publishSource]).
  PublishSource get publishSource => config.publishSource;

  /// The app's variables: shared by every screen, over [data] and under
  /// each screen's own scope, so a value one screen sets the next one reads.
  /// Declared from the publish model's `variables` (and a publish's
  /// `app_variables` scope, [declareAppVariables]).
  late final VariableScope appVariables = VariableScope(const [], parent: _featureScopes.build(features, data));

  /// The feature layers this instance runs: those of its action runner
  /// ([CoreActions.features]; `CodelesslyActions` installs the first-party
  /// ones), or the first-party ones under a runner of another kind. Their
  /// scopes (`auth`, `storage`, `speech`...) sit under [appVariables].
  List<CodelesslyFeature> get features => switch (config.actions) {
        final CoreActions actions => actions.features,
        _ => kFirstPartyFeatures,
      };

  late final FeatureScopeHost _featureScopes = FeatureScopeHost(services);

  /// The live data the whole app shares: `loadCloudData` actions with
  /// `scope: app` open one subscription here, on first use, and every
  /// screen of every [CodelesslyWidget] showing this project shares it
  /// (its app variable reads the same values everywhere). Closed by
  /// [dispose].
  AppDataSources get appData => _appData ??= AppDataSources(appVariables, onError: (error, stack) {
        final s = services;
        if (s is Services) s.analytics.logError(error, stackTrace: stack, type: 'app_data');
      });
  AppDataSources? _appData;

  /// `usage`: the per-user counters of [automations] (the engage feature's
  /// scope; without it, counted but not read by layouts).
  late final ValuesScope _usage = () {
    appVariables; // The feature scopes are built with it.
    return switch (_featureScopes['usage']) {
      final ValuesScope usage => usage,
      _ => _detachedUsage = ValuesScope({'usage': CodelesslyAutomations.emptyUsage}),
    };
  }();
  ValuesScope? _detachedUsage;

  /// Makes completed native auth operations visible to the next action in
  /// the same chain, without waiting for the asynchronous auth/profile stream.
  void refreshAuthValues(AuthOperation operation) {
    appVariables; // The feature scopes are built with it.
    if (_featureScopes['auth'] case final AuthScope auth) auth.refreshAuth(operation);
  }

  final List<PersistedVariable> _persistedApp = [];

  /// Declares [variables] in [appVariables], each once: a persisted one
  /// starts from its last value and keeps every change.
  void declareAppVariables(Iterable<Variable> variables) {
    final s = services;
    final storage = s is Services ? s.storage : null;
    for (final v in variables) {
      if (appVariables.declares(v.name)) continue;
      appVariables.define(v);
      if (v.persists) _persistedApp.add(PersistedVariable.attach(appVariables, v, storage));
    }
  }

  final Map<String, VariableScope> _pageVariables = {};
  final List<PersistedVariable> _persistedPages = [];

  /// Page variables shared by its layouts, below each canvas's variables
  /// and above the app's. Leaving a screen must not reset the page state.
  VariableScope pageVariables(String pageId, Iterable<Variable> variables) {
    final scope = _pageVariables.putIfAbsent(pageId, () => VariableScope(const [], parent: appVariables));
    final current = services;
    final storage = current is Services ? current.storage : null;
    for (final variable in variables) {
      if (scope.declares(variable.name)) continue;
      scope.define(variable);
      if (variable.persists) _persistedPages.add(PersistedVariable.attach(scope, variable, storage));
    }
    return scope;
  }

  void _declareModelVariables(PublishModel model) => declareAppVariables([
        for (final json in model.variables.values)
          if (Variable.fromJson(json) case final Variable v) v,
      ]);

  CStatus _status = const CEmpty();

  /// Where loading the publish model is: [CEmpty], [CLoading], [CLoaded]
  /// or [CError]. Listeners are notified when it changes.
  CStatus get status => _status;

  PublishModel? _model;

  /// The publish model, once loaded.
  PublishModel? get publishModel => _model;

  final Map<String, PublishLayout> _layouts = {};
  final Map<String, Future<PublishLayout>> _loading = {};

  /// Layouts loaded so far, by id.
  Map<String, PublishLayout> get layouts => Map.unmodifiable(_layouts);

  /// The screen shown last (by any [CodelesslyWidget] of this instance).
  final ValueNotifier<CodelesslyRoute?> route = ValueNotifier(null);

  /// The local storage key the site's theme mode is kept under
  /// ([setThemeMode] with `persist`).
  static const String themeModeStorageKey = 'codelessly.themeMode';

  /// The theme mode chosen while the app runs (a `setThemeMode` action, or
  /// the app's own [setThemeMode]), else the one kept from an earlier visit;
  /// null: the site's own (`theme.mode`, else `system`). Every screen of
  /// this instance listens to it.
  late final ValueNotifier<ThemeMode?> themeModeChoice = ValueNotifier(_storedThemeMode());

  /// The theme mode the screens show: the choice ([themeModeChoice]), else
  /// the published theme's `mode`, else `system` (the device's setting), as
  /// `MaterialApp.themeMode`. A layout with a theme of its own reads its
  /// own `mode` when nothing was chosen.
  ThemeMode get themeMode => themeModeChoice.value ?? _model?.theme.mode ?? ThemeMode.system;

  /// Shows every screen of this instance in [mode] (the `setThemeMode`
  /// action): their named colors, text styles and controls redraw at once
  /// and `${theme.mode}` / `${theme.isDark}` change. With [persist] the
  /// choice is kept in the services' local storage, so a reload starts in
  /// it; null [mode] forgets the choice (the site's own mode again).
  void setThemeMode(ThemeMode? mode, {bool persist = false}) {
    themeModeChoice.value = mode;
    final s = services;
    if (!persist || s is! Services) return;
    if (mode == null) {
      unawaited(s.storage.remove(themeModeStorageKey));
    } else {
      unawaited(s.storage.put(themeModeStorageKey, mode.name));
    }
  }

  ThemeMode? _storedThemeMode() {
    final s = services;
    if (s is! Services) return null;
    try {
      return ThemeMode.tryParse(s.storage.get(themeModeStorageKey));
    } catch (_) {
      return null;
    }
  }

  /// Its paywalls: [CodelesslyPaywalls.present] shows the paywall published
  /// at a placement and returns how it ended.
  ///
  /// ```dart
  /// final result = await codelessly.paywall.present(context, placement: 'onboarding');
  /// if (result.outcome == PaywallOutcome.purchased) unlockPro();
  /// ```
  late final CodelesslyPaywalls paywall = CodelesslyPaywalls(this);

  /// Shows its layouts above the host app, one at a time
  /// ([CodelesslyPresenter.present]); a `CodelesslyPresenterHost` around the app
  /// leads it to the app's navigator.
  late final CodelesslyPresenter presenter = CodelesslyPresenter(this);

  /// Its automations and app events: started by a `CodelesslyPresenterHost` (or
  /// [CodelesslyAutomations.start]).
  late final CodelesslyAutomations automations = CodelesslyAutomations(this, _usage, lifecycle: WidgetsLifecycleSource.instance);

  /// Shows layout [layoutId] above the host app, from anywhere (no
  /// [CodelesslyWidget] on the current screen needed), and completes with
  /// what closed it: its close modal action's result, null when dismissed.
  /// See [CodelesslyPresenter.present].
  ///
  /// ```dart
  /// final answer = await codelessly.present('rate-us', params: {'orders': 3});
  /// if (answer case {'rating': final int stars}) saveRating(stars);
  /// ```
  Future<Object?> present(
    String layoutId, {
    ModalPresentation presentation = ModalPresentation.dialog,
    Map<String, Object?> params = const {},
    Map<String, Object?> data = const {},
    bool dismissible = true,
    int priority = 0,
    Rect? anchor,
    GlobalKey? anchorKey,
    PopoverPlacement placement = PopoverPlacement.belowCenter,
    bool bottom = false,
    OpenModalAction? modal,
    BuildContext? context,
  }) =>
      presenter.present(layoutId,
          presentation: presentation,
          params: params,
          data: data,
          dismissible: dismissible,
          priority: priority,
          anchor: anchor,
          anchorKey: anchorKey,
          placement: placement,
          bottom: bottom,
          modal: modal,
          context: context);

  /// Fires app event [name] with [props] on the app's event bus: the
  /// project's automations listening for it run, and [events] hears it.
  /// Layouts fire them with `emitEvent` actions.
  void emit(String name, [Map<String, Object?> props = const {}]) {
    AppEventBus.register(services, automations);
    automations.emit(name, props);
  }

  /// Every app event: the host's [emit]s and the layouts' `emitEvent`s.
  Stream<AppEvent> get events => automations.events;

  final Map<String, AppFunction> _registered = {};

  /// The functions call function actions call, by name: the ones
  /// [registerFunction] added, over [CodelesslyConfig.functions]. Live:
  /// a screen already shown sees later registrations.
  late final Map<String, AppFunction> functions = CombinedMapView([_registered, config.functions]);

  /// Registers [function] as the handler of call function actions named
  /// [name] (over the config's of that name), e.g. from a widget that has
  /// the BuildContext a share sheet needs.
  void registerFunction(String name, AppFunction function) => _registered[name] = function;

  /// Removes what [registerFunction] registered as [name].
  void unregisterFunction(String name) => _registered.remove(name);

  Future<void>? _initializing;

  /// Loads the publish model: from the cache when it has one (then
  /// refreshed from the loader in the background), else from the loader.
  /// Safe to call again: later calls wait for the first.
  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    // `emitEvent` actions reach this instance's app events.
    AppEventBus.register(services, automations);
    _setStatus(const CLoading());
    final key = publishSource.modelPath(config.uniqueId);
    PublishModel? cached;
    try {
      final json = await cache.read(key);
      if (json != null) cached = PublishModel.fromJson(json);
    } catch (_) {
      cached = null;
    }
    if (cached != null) {
      _model = cached;
      _configureServices(cached);
      _declareModelVariables(cached);
      await _installPlugins(cached);
      _setStatus(const CLoaded());
      unawaited(_refresh(key).catchError((Object _) {}));
    } else {
      try {
        await _refresh(key);
        _setStatus(const CLoaded());
      } catch (e) {
        _initializing = null;
        _setStatus(CError('Could not load the publish model', e));
        rethrow;
      }
    }
    _watch();
    if (config.preload) {
      await Future.wait([
        for (final id in _model!.layouts.keys)
          if (!_model!.disabledLayouts.contains(id)) loadLayout(id).then<void>((_) {}, onError: (_) {}),
      ]);
    }
  }

  StreamSubscription<PublishModel>? _watching;

  /// Follows a [LivePublishLoader]'s model ([CodelesslyConfig.liveUpdates]).
  void _watch() {
    final l = loader;
    if (!config.liveUpdates || l is! LivePublishLoader || _watching != null) return;
    final key = publishSource.modelPath(config.uniqueId);
    _watching = l.watchModel(publishSource).listen(
          (fresh) => unawaited(_apply(key, fresh).catchError((Object _) {})),
          // A failed watch (offline, rules) leaves the loaded model on screen.
          onError: (Object _) {},
        );
  }

  Future<void> _refresh(String key) async => _apply(key, await loader.loadModel(publishSource));

  Future<void> _apply(String key, PublishModel fresh) async {
    final old = _model;
    if (old != null && jsonEquality.equals(old.toJson(), fresh.toJson())) return;
    _model = fresh;
    _configureServices(fresh);
    _declareModelVariables(fresh);
    await _installPlugins(fresh);
    await cache.write(key, fresh.toJson());
    if (old != null) {
      // Layouts republished since: drop them, they reload when shown.
      _layouts.removeWhere((id, l) {
        final t = fresh.layouts[id]?.lastUpdated;
        return t != null && (l.lastUpdated == null || l.lastUpdated!.isBefore(t));
      });
      // Components republished since: load them again now; each instance
      // on screen updates in place when its definition is replaced.
      await Future.wait([
        for (final e in _published.entries)
          if (fresh.components[e.key] case final PublishComponentInfo info when _republished(e.value, info))
            _loadComponent(fresh, e.key).then<void>((_) {}, onError: (Object _) {}),
      ]);
      notifyListeners();
    }
  }

  /// A [Services]' config follows the model: its APIs (added to the app's)
  /// and its paywall setup (the model's `paywall`: product slots,
  /// placements, legal links), which replaces the app's.
  void _configureServices(PublishModel model) {
    final s = services;
    final paywall = model.extra[kPublishModelPaywallKey];
    if (s is! Services || (model.apis.isEmpty && paywall is! Map)) return;
    final current = s.config.toJson();
    s.config = ServiceConfig.fromJson({
      ...current,
      if (model.apis.isNotEmpty) 'apis': {...?current['apis'] as Map?, ...model.apis},
      if (paywall is Map) 'paywall': paywall,
    });
  }

  /// The id of the layout [id] names (a layout id, custom id or canvas
  /// id); null when it names none, or before the model is loaded.
  String? resolveLayoutId(String? id) => _model?.resolveLayoutId(id);

  /// Layout [layoutId], if loaded.
  PublishLayout? layout(String layoutId) => _layouts[layoutId];

  /// Loads layout [id] (a layout id, custom id or canvas id) and its fonts.
  /// A cached copy is used while it's as new as the model says; a loading
  /// failure falls back to any cached copy.
  Future<PublishLayout> loadLayout(String id) async {
    await initialize();
    final model = _model!;
    final layoutId = model.resolveLayoutId(id);
    if (layoutId == null) throw PublishLoadException('No layout [$id] in project [${model.projectId}]');
    final loaded = _layouts[layoutId];
    if (loaded != null) return loaded;
    return _loading[layoutId] ??= _loadLayout(model, layoutId).whenComplete(() {
      _loading.remove(layoutId);
    });
  }

  /// What layouts decode with: the installed features' catalog, and the
  /// project's components' declarations (so a call's props are typed).
  Catalog get _layoutCatalog {
    var c = config.catalog;
    for (final f in _hosted) {
      c = c + f.catalog;
    }
    return components.isEmpty ? c : c + components.catalog;
  }

  /// Whether [loaded] is older than the model's entry for it says.
  static bool _republished(PublishComponent loaded, PublishComponentInfo info) {
    if (info.digest.isNotEmpty) return info.digest != loaded.digest;
    if (info.version != 0 && info.version != loaded.version) return true;
    final t = info.lastUpdated;
    return t != null && (loaded.lastUpdated == null || loaded.lastUpdated!.isBefore(t));
  }

  /// Loads published component [type] (its definition, as the publish model
  /// lists it) and defines it in [components]; resolves to it, or to null
  /// when it can't be loaded (logged as `component_missing`). Loads its
  /// closure too: the components it calls.
  Future<PublishComponent?> loadComponent(String type) async {
    await initialize();
    final model = _model!;
    final loaded = await _loadComponent(model, type);
    if (loaded != null) await _loadClosure(model, [loaded.document]);
    return loaded;
  }

  /// The component types [document] calls that the app doesn't define
  /// itself: types the model lists, and any UpperCamelCase type the installed
  /// features don't declare.
  Iterable<String> _callsIn(PublishModel model, LayoutDocument document) => {
        for (final n in document.nodes.values)
          if (!_ownComponents.contains(n.type) &&
              (model.components.containsKey(n.type) || (isComponentTypeName(n.type) && config.catalog.widget(n.type) == null)))
            n.type,
      };

  /// Loads every published component [documents] call, and every one those
  /// call, in parallel by depth, before a screen of them shows. A component
  /// that fails stays missing (its calls render empty) and is logged.
  Future<void> _loadClosure(PublishModel model, Iterable<LayoutDocument> documents, [Iterable<String> listed = const []]) async {
    final seen = <String>{};
    var next = {...listed.where((t) => !_ownComponents.contains(t)), for (final d in documents) ..._callsIn(model, d)};
    while (next.isNotEmpty) {
      seen.addAll(next);
      final loaded = await Future.wait([for (final t in next) _loadComponent(model, t)]);
      next = {
        for (final c in loaded.nonNulls) ..._callsIn(model, c.document),
      }..removeAll(seen);
    }
  }

  Future<PublishComponent?> _loadComponent(PublishModel model, String type) {
    if (_ownComponents.contains(type)) return Future.value(null);
    final info = model.components[type];
    final current = _published[type];
    if (current != null && (info == null || !_republished(current, info))) return Future.value(current);
    return _componentLoads[type] ??= _fetchComponent(model, type, info).whenComplete(() {
      _componentLoads.remove(type);
    });
  }

  Future<PublishComponent?> _fetchComponent(PublishModel model, String type, PublishComponentInfo? info) async {
    final key = publishSource.componentPath(config.uniqueId, type);
    PublishComponent? cached;
    try {
      final json = await cache.read(key);
      if (json != null) cached = PublishComponent.fromJson(json, catalog: config.catalog, id: type);
      if (cached != null && (!cached.isComponent || !componentIntact(cached))) cached = null;
    } catch (_) {
      cached = null;
    }
    PublishComponent? component;
    if (cached != null && (info == null || !_republished(cached, info))) {
      component = cached;
    } else {
      try {
        final fetched = await loader.loadComponent(publishSource, type);
        if (!fetched.isComponent) throw PublishLoadException('Component [$type] is not a component definition');
        if (!componentIntact(fetched)) {
          throw PublishLoadException('Component [$type] does not match its digest (${fetched.digest})');
        }
        component = fetched;
        await cache.write(key, fetched.toJson());
      } catch (e, stack) {
        // Offline, or a failed fetch: the cached copy, however old.
        component = cached;
        if (component == null) {
          _logComponentError(type, e, stack);
          return null;
        }
      }
    }
    final files = loader;
    if (files is PublishAssetSource && siteImagesIn(component.document.toJson()).isNotEmpty) {
      final json = await resolveSiteImages(component.toJson(), files as PublishAssetSource,
          onMissing: (path, e) => _logSiteFileMissing(path, e));
      component = PublishComponent.fromJson(json, catalog: config.catalog, id: type);
    }
    _published[type] = component;
    if (!_ownComponents.contains(type)) components.define(component.document);
    final fonts = {
      for (final f in [...?info?.fonts, ...component.fonts]) ?model.fonts[f],
    };
    if (fonts.isNotEmpty) await this.fonts.load(fonts).timeout(config.fontTimeout, onTimeout: () {});
    return component;
  }

  /// [layout] with the images it names by a path relative to the site
  /// (`images/hero.jpg`) read through the loader's files: their URL, or
  /// their bytes as a `data:` URL. Itself when the loader has no files or
  /// the layout names none.
  Future<PublishLayout> _withSiteImages(PublishLayout layout, Catalog catalog) async {
    final files = loader;
    if (files is! PublishAssetSource) return layout;
    final json = layout.toJson();
    if (siteImagesIn(json['nodes']).isEmpty) return layout;
    final resolved = await resolveSiteImages(json, files as PublishAssetSource, onMissing: _logSiteFileMissing);
    return PublishLayout.fromJson(resolved, catalog: catalog);
  }

  /// A file the site names that its loader does not have: logged
  /// (`site_file_missing`); the image draws nothing.
  void _logSiteFileMissing(String path, Object error) {
    final s = services;
    if (s is Services) {
      s.analytics.logError(PublishLoadException('site_file_missing: $path', error), type: 'site_file_missing');
    }
  }

  void _logComponentError(String type, Object error, [StackTrace? stack]) {
    final s = services;
    if (s is Services) {
      s.analytics.logError(PublishLoadException('component_missing: $type could not be loaded', error), stackTrace: stack, type: 'component_missing');
    }
  }

  /// A call rendered without its definition: logged, and fetched when the
  /// publish lists it (the call renders when it arrives).
  void _componentMissing(String type, String path) {
    final model = _model;
    if (model != null && model.components.containsKey(type) && !_ownComponents.contains(type)) {
      if (_published.containsKey(type) || _componentLoads.containsKey(type)) return;
      scheduleMicrotask(() => unawaited(loadComponent(type).then<void>((_) {}, onError: (Object _) {})));
      return;
    }
    scheduleMicrotask(() => _logComponentError(type, 'the call at "$path" names a component no one defines'));
  }

  Future<PublishLayout> _loadLayout(PublishModel model, String layoutId) async {
    final key = publishSource.layoutPath(config.uniqueId, layoutId);
    final wanted = model.layouts[layoutId]?.lastUpdated;
    PublishLayout? cached;
    try {
      final json = await cache.read(key);
      if (json != null) cached = PublishLayout.fromJson(json, catalog: _layoutCatalog);
    } catch (_) {
      cached = null;
    }
    PublishLayout layout;
    final fresh = cached != null &&
        (wanted == null || (cached.lastUpdated != null && !cached.lastUpdated!.isBefore(wanted)));
    if (fresh) {
      layout = cached;
    } else {
      try {
        layout = await loader.loadLayout(publishSource, layoutId);
        if (layout.id.isEmpty) layout = layout.copyWith(document: layout.document.copyWith(id: layoutId));
        await cache.write(key, layout.toJson());
      } catch (e) {
        if (cached == null) rethrow;
        layout = cached;
      }
    }
    // The components it calls (listed by the model, and found in it), and
    // those they call, before it shows.
    await _loadClosure(model, [layout.document], model.layouts[layoutId]?.components ?? const []);
    // A loader decodes with the standard catalog; the installed features may
    // declare more (a native plugin's types), and the components their
    // parameters: decode again with theirs.
    final catalog = _layoutCatalog;
    if (!(layout.document.catalog?.includes(catalog) ?? false)) {
      layout = PublishLayout.fromJson(layout.toJson(), catalog: catalog);
    }
    layout = await _withSiteImages(layout, catalog);
    final resolver = managed;
    if (resolver != null) {
      // Never fails: an instance whose update fails keeps its snapshot.
      layout = await resolver.resolve(layout, projectId: model.projectId, theme: layout.theme ?? model.theme);
    }
    _layouts[layoutId] = layout;
    final fontsOf = {
      ...model.fontsOf(layoutId),
      for (final f in layout.fonts) ?model.fonts[f],
    };
    // The layout's characters: on the web those beyond a Google Font's
    // `latin` subset come in a file of their own, for the fonts it lists and
    // those asked for when first drawn.
    // Not waited for: the screen shows at once, the characters' text lays
    // out again when their file arrives.
    if (kIsWeb) unawaited(fonts.addText(jsonEncode(layout.toJson())));
    if (fontsOf.isNotEmpty) {
      await fonts.load(fontsOf).timeout(config.fontTimeout, onTimeout: () {});
    }
    return layout;
  }

  /// Asks again which versions the managed components' channels offer (a
  /// release or a rollback since): loaded layouts that show managed
  /// components reload when next shown.
  void refreshManagedComponents() {
    final resolver = managed;
    if (resolver == null) return;
    resolver.refresh();
    _layouts.removeWhere((_, l) => managedInstancesOf(l.document).isNotEmpty);
    notifyListeners();
  }

  /// Sets app data [key] (read by layouts as `data.<key>`).
  void setData(String key, Object? value) {
    final current = {...?(data.values['data'] as Map?)?.cast<String, Object?>()};
    current[key] = value;
    data.set('data', current);
  }

  /// Forgets the loaded publish (and, with [clearCache], the cached one);
  /// the next [initialize] loads it again.
  Future<void> reset({bool clearCache = false}) async {
    await _watching?.cancel();
    _watching = null;
    _initializing = null;
    _model = null;
    _layouts.clear();
    if (clearCache) await cache.clear();
    _setStatus(const CEmpty());
  }

  void _setStatus(CStatus s) {
    _status = s;
    notifyListeners();
  }

  @override
  void dispose() {
    components.removeListener(_declarationsChanged);
    if (components.onMissing == _componentMissing) components.onMissing = null;
    automations.dispose();
    presenter.dismissAll();
    _watching?.cancel();
    _watching = null;
    route.dispose();
    themeModeChoice.dispose();
    _appData?.dispose();
    for (final p in _persistedApp) {
      p.dispose();
    }
    for (final persisted in _persistedPages) {
      persisted.dispose();
    }
    for (final scope in _pageVariables.values) {
      scope.dispose();
    }
    appVariables.dispose();
    _featureScopes.dispose();
    _detachedUsage?.dispose();
    data.dispose();
    // Lazy expression scopes must detach while the service notifiers live.
    unawaited(_ownedServices?.dispose());
    if (identical(_instance, this)) _instance = null;
    super.dispose();
  }
}

/// The variable scope a publish can keep the app's variables
/// under, in each layout's `variables`.
const String kV1AppVariablesScope = 'app_variables';

/// The variables shared by every layout of the same source page.
const String kPageVariablesScope = 'page_variables';

/// The storage bucket Codelessly publishes to.
const String kCodelesslyStorageBucket = 'codeless-app.appspot.com';

class _NoLoader implements PublishLoader {
  _NoLoader(this.hasProject);

  /// Whether the config names a project (by id or token) but no loader.
  final bool hasProject;

  PublishLoadException get _error => PublishLoadException(hasProject
      ? 'A project id or token is read from Firestore: create the instance with codelesslyWithToken or '
          'codelesslyOnFirebase (package:codelessly_sdk/firebase.dart), or pass a FirestorePublishLoader'
      : 'No project: configure a projectId, a slug or a loader');

  @override
  Future<PublishModel> loadModel(PublishSource source) => Future.error(_error);

  @override
  Future<PublishLayout> loadLayout(PublishSource source, String layoutId) => Future.error(_error);

  @override
  Future<PublishComponent> loadComponent(PublishSource source, String type) => Future.error(_error);
}
