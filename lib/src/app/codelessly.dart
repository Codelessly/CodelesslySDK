import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/foundation.dart';

import '../runtime/contracts.dart';
import '../runtime/expressions/scopes.dart';
import '../services/services.dart';
import 'config.dart';
import 'fonts.dart';
import 'loader.dart';
import 'navigation.dart';
import 'persisted_variables.dart';
import 'runtime.dart';

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
  Codelessly({
    this.config = const CodelesslyConfig(),
    PublishLoader? loader,
    PublishCache? cache,
    FontFetcher? fonts,
    Map<String, Object?> data = const {},
  })  : loader = loader ?? _defaultLoader(config),
        cache = cache ?? MemoryPublishCache(),
        fonts = CodelesslyFonts(fetcher: fonts ?? HttpFontFetcher()),
        data = MapValueScope(values: {'data': data});

  /// A [Codelessly] showing [bundle] (a publish shipped with the app, or a
  /// test's), offline.
  factory Codelessly.fromBundle(
    PublishBundle bundle, {
    CodelesslyConfig config = const CodelesslyConfig(),
    FontFetcher? fonts,
    Map<String, Object?> data = const {},
  }) =>
      Codelessly(config: config, loader: MemoryPublishLoader(bundle), fonts: fonts, data: data);

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
  late final CodelesslyServices services = config.services ?? Services();

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
  late final VariableScope appVariables = VariableScope(const [], parent: _storage);

  /// `storage`: what the app keeps on the device ([Services.storage], the
  /// `setStorage` action's), read live as `storage.<key>`.
  late final _StorageScope _storage = _StorageScope(services, parent: _serviceValues);

  late final _ServiceValuesScope _serviceValues = _ServiceValuesScope(services, parent: data);

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

  Future<void>? _initializing;

  /// Loads the publish model: from the cache when it has one (then
  /// refreshed from the loader in the background), else from the loader.
  /// Safe to call again: later calls wait for the first.
  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
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
    await cache.write(key, fresh.toJson());
    if (old != null) {
      // Layouts republished since: drop them, they reload when shown.
      _layouts.removeWhere((id, l) {
        final t = fresh.layouts[id]?.lastUpdated;
        return t != null && (l.lastUpdated == null || l.lastUpdated!.isBefore(t));
      });
      notifyListeners();
    }
  }

  void _configureServices(PublishModel model) {
    final s = services;
    if (s is Services && model.apis.isNotEmpty) {
      s.config = ServiceConfig.fromJson({...s.config.toJson(), 'apis': {...?s.config.toJson()['apis'] as Map?, ...model.apis}});
    }
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

  Future<PublishLayout> _loadLayout(PublishModel model, String layoutId) async {
    final key = publishSource.layoutPath(config.uniqueId, layoutId);
    final wanted = model.layouts[layoutId]?.lastUpdated;
    PublishLayout? cached;
    try {
      final json = await cache.read(key);
      if (json != null) cached = PublishLayout.fromJson(json);
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
    _layouts[layoutId] = layout;
    final fontsOf = {
      ...model.fontsOf(layoutId),
      for (final f in layout.fonts) ?model.fonts[f],
    };
    if (fontsOf.isNotEmpty) {
      await fonts.load(fontsOf).timeout(config.fontTimeout, onTimeout: () {});
    }
    return layout;
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
    _watching?.cancel();
    _watching = null;
    route.dispose();
    for (final p in _persistedApp) {
      p.dispose();
    }
    appVariables.dispose();
    _storage.dispose();
    _serviceValues.dispose();
    data.dispose();
    if (identical(_instance, this)) _instance = null;
    super.dispose();
  }
}

/// Live account/profile and verified entitlement values, owned by the app.
/// No app variables or persisted preview fixtures are declared for services.
class _ServiceValuesScope extends ValuesScope {
  _ServiceValuesScope(CodelesslyServices services, {ValueScope? parent})
      : _services = services is Services ? services : null,
        super({
          'auth': authValue(services is Services ? services.auth.currentUser : null),
          'entitlements': const <String, Object?>{},
        }, parent) {
    final s = _services;
    if (s == null) return;
    final current = s.auth.currentUser;
    _scopeAccount(current == null || current.isAnonymous ? null : current.uid);
    _auth = s.watchAuth().listen(
      (value) {
        if (_disposed) return;
        _scopeAccount(value['isSignedIn'] == true ? value['uid'] as String? : null);
        set('auth', value);
      },
      onError: (Object error, StackTrace stack) {
        if (_disposed) return;
        _scopeAccount(null);
        set('auth', authValue(null));
        s.analytics.logError(error, stackTrace: stack, type: 'auth_scope');
      },
    );
    s.paywalls?.entitlements.addListener(_entitlementsChanged);
    _entitlementsChanged();
  }

  final Services? _services;
  StreamSubscription<Map<String, Object?>>? _auth;
  bool _disposed = false;
  String? _uid;
  bool _accountInitialized = false;

  void _scopeAccount(String? uid) {
    if (_accountInitialized && _uid == uid) return;
    _accountInitialized = true;
    _uid = uid;
    final runtime = _services?.paywalls;
    runtime?.scopeToUser(uid);
    if (runtime != null) unawaited(runtime.refreshEntitlements());
  }

  void _entitlementsChanged() {
    if (!_disposed) {
      set('entitlements', {for (final e in _services?.paywalls?.entitlements.value ?? <String>{}) e: true});
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _auth?.cancel();
    _services?.paywalls?.entitlements.removeListener(_entitlementsChanged);
    super.dispose();
  }
}

/// `storage` in expressions: the app's [LocalStorage] values by key,
/// notifying its readers when any changes.
class _StorageScope extends NamedScope {
  _StorageScope(CodelesslyServices services, {super.parent})
      : _store = services is Services ? services.storage : null {
    _store?.addListener(_storeChanged);
  }

  final LocalStorage? _store;

  void _storeChanged() => changed(const ['storage']);

  @override
  bool declares(String name) => name == 'storage';

  @override
  Object? valueOf(String name, ValueScope reader) => _store?.getAll() ?? const <String, Object?>{};

  @override
  void dispose() {
    _store?.removeListener(_storeChanged);
    super.dispose();
  }
}

/// The variable scope a publish can keep the app's variables
/// under, in each layout's `variables`.
const String kV1AppVariablesScope = 'app_variables';

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
}
