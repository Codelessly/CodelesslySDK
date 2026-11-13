// The project's automations at run time (DESIGN.md: automations): app-level
// triggers (app start, session start, resume, app events, intervals, screens
// shown) that run a chain of actions with no screen of their own, under a
// condition and how-often limits, with per-user usage counters kept on the
// device. Also the app's event bus (Codelessly.emit, emitEvent actions).
import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart'
    show Automation, AutomationTrigger, Node, PublishModelAutomations, Reaction, Trigger, TriggerType;
import 'package:flutter/widgets.dart';

import '../runtime/actions/app_events.dart';
import '../features/context.dart';
import '../runtime/contracts.dart' show ValueScope;
import '../runtime/expressions/formula.dart' show FormulaEvaluator;
import '../runtime/expressions/scopes.dart';
import '../services/services.dart' show LocalStorage, Services;
import 'codelessly.dart';

/// The local storage key prefix of the usage counters.
const String kUsageStorageKey = 'codelessly.usage';

/// Runs a [Codelessly]'s automations ([Codelessly.automations]) and carries
/// its app events.
///
/// [start] (called by a `CodelesslyPresenterHost`, or by the app) loads the
/// project, counts the launch and the session for the current user, and runs
/// the `appStart` and `sessionStart` automations; from then on it follows
/// the app's lifecycle (`resume`, a new session after [sessionTimeout] in
/// the background, `interval`s only in the foreground), the screens shown
/// (`screenShown`) and the app events ([emit]).
///
/// `${usage}` (in every layout and automation) is what it counts for the
/// signed-in user (or the device, signed out), kept in the app's local
/// storage: `launches`, `sessions`, `firstSeen`, `lastSeen`,
/// `isFirstLaunch`, `isFirstSession`, `events.<name>.count`/`.last`,
/// `automations.<id>.count`/`.last`/`.session`.
class CodelesslyAutomations with WidgetsBindingObserver implements AppEventBus {
  CodelesslyAutomations(this.codelessly, this._usage);

  final Codelessly codelessly;
  final ValuesScope _usage;

  /// The time now; tests replace it.
  DateTime Function() clock = DateTime.now;

  /// How long the app must have been in the background for its return to
  /// start a new session.
  Duration sessionTimeout = const Duration(minutes: 30);

  /// What `${usage}` reads before any counting.
  static const Map<String, Object?> emptyUsage = {
    'launches': 0,
    'sessions': 0,
    'isFirstLaunch': false,
    'isFirstSession': false,
    'events': <String, Object?>{},
    'automations': <String, Object?>{},
  };

  final StreamController<AppEvent> _events = StreamController.broadcast();

  /// Every app event fired ([emit], `emitEvent` actions, and the runtime's
  /// own `resume`).
  Stream<AppEvent> get events => _events.stream;

  Future<void>? _starting;
  bool _ready = false, _disposed = false, _observing = false;
  List<Automation> _automations = const [];
  final List<AppEvent> _early = [];
  final List<Timer> _intervals = [];
  final Set<String> _running = {};
  final Set<String> _launched = {};
  final Map<String, Map<String, int>> _sessionRuns = {};
  Map<String, Object?> _record = {};
  String _userKey = '';
  DateTime? _backgroundedAt;
  bool _foreground = true;
  Listenable? _authWatch;

  /// Whether [start] has finished: automations run.
  bool get isStarted => _ready;

  /// The automations it runs (the publish model's).
  List<Automation> get automations => _automations;

  /// Starts it (once; later calls wait for the first). Never throws: a
  /// project that doesn't load has no automations.
  Future<void> start() => _starting ??= _start();

  Future<void> _start() async {
    AppEventBus.register(codelessly.services, this);
    try {
      await codelessly.initialize();
    } catch (_) {
      // Its listener below starts them once a publish arrives.
    }
    if (_disposed) return;
    _automations = codelessly.publishModel?.automations ?? const [];
    codelessly.addListener(_modelChanged);
    codelessly.route.addListener(_routeChanged);
    _authWatch = watchName(codelessly.appVariables, 'auth');
    _authWatch?.addListener(_authChanged);
    try {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    } catch (_) {
      // No binding (a headless test): the app calls handleLifecycle.
    }
    _switchUser(_currentUserKey(), startSession: true);
    _ready = true;
    final start = _event('appStart');
    _runAll(AutomationTrigger.appStart, start);
    _runAll(AutomationTrigger.sessionStart, _event('sessionStart'));
    _startIntervals();
    for (final e in [..._early]) {
      _handle(e);
    }
    _early.clear();
    final shown = codelessly.route.value;
    if (shown != null) _routeChanged();
  }

  AppEvent _event(String name, [Map<String, Object?> props = const {}]) => AppEvent(name, props: props, at: clock());

  // --- events --------------------------------------------------------------------

  /// Fires app event [name] with [props]: it is counted in
  /// `usage.events.<name>`, the automations listening for it run, and
  /// [events] hears it. Before [start] finishes, it waits for it.
  @override
  void emit(String name, [Map<String, Object?> props = const {}]) {
    if (_disposed || name.trim().isEmpty) return;
    final event = _event(name.trim(), Map.unmodifiable(props));
    _events.add(event);
    if (!_ready) {
      _early.add(event);
      return;
    }
    _handle(event);
  }

  void _handle(AppEvent event) {
    final events = {...?(_record['events'] as Map?)?.cast<String, Object?>()};
    final previous = (events[event.name] as Map?)?.cast<String, Object?>() ?? const {};
    events[event.name] = {'count': ((previous['count'] as num?) ?? 0).toInt() + 1, 'last': event.at.millisecondsSinceEpoch};
    _record = {..._record, 'events': events};
    _save();
    _runAll(AutomationTrigger.event, event, (a) => a.event == event.name);
  }

  // --- lifecycle -----------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => handleLifecycle(state);

  /// The app's lifecycle moved to [state] (the binding's observer calls it).
  void handleLifecycle(AppLifecycleState state) {
    if (_disposed || !_ready) return;
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden || AppLifecycleState.detached:
        if (!_foreground) return;
        _foreground = false;
        _backgroundedAt = clock();
        _record = {..._record, 'lastSeen': _backgroundedAt!.millisecondsSinceEpoch};
        _save();
        _stopIntervals();
      case AppLifecycleState.resumed:
        if (_foreground) return;
        _foreground = true;
        final away = _backgroundedAt == null ? Duration.zero : clock().difference(_backgroundedAt!);
        _backgroundedAt = null;
        final resume = _event('resume', {'awayMs': away.inMilliseconds});
        _events.add(resume);
        _runAll(AutomationTrigger.resume, resume);
        if (away >= sessionTimeout) {
          _newSession();
          _runAll(AutomationTrigger.sessionStart, _event('sessionStart', {'awayMs': away.inMilliseconds}));
        }
        _startIntervals();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _startIntervals() {
    _stopIntervals();
    for (final a in _automations) {
      if (!a.enabled || a.trigger != AutomationTrigger.interval) continue;
      var tick = 0;
      _intervals.add(Timer.periodic(Duration(milliseconds: a.intervalMs), (_) {
        tick++;
        _runOne(a, _event('interval', {'tick': tick}));
      }));
    }
  }

  void _stopIntervals() {
    for (final t in _intervals) {
      t.cancel();
    }
    _intervals.clear();
  }

  void _modelChanged() {
    final fresh = codelessly.publishModel?.automations ?? const <Automation>[];
    if (_listEquals(fresh, _automations)) return;
    _automations = fresh;
    if (_ready && _foreground) _startIntervals();
  }

  static bool _listEquals(List<Automation> a, List<Automation> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _routeChanged() {
    final r = codelessly.route.value;
    if (r == null || !_ready) return;
    final event = _event('screenShown', {'layoutId': r.layoutId, 'canvasId': r.canvasId, 'params': r.params});
    _runAll(AutomationTrigger.screenShown, event, (a) {
      final screen = a.screen.trim();
      return screen.isEmpty ||
          screen == r.layoutId ||
          screen == r.canvasId ||
          codelessly.resolveLayoutId(screen) == r.layoutId;
    });
  }

  // --- usage ---------------------------------------------------------------------

  /// What `${usage}` reads now.
  Map<String, Object?> get usage => (_usage['usage'] as Map?)?.cast<String, Object?>() ?? emptyUsage;

  String _currentUserKey() {
    final auth = codelessly.appVariables.read('auth');
    final uid = auth is Map ? '${auth['uid'] ?? ''}' : '';
    return uid.isEmpty ? 'device' : 'u.$uid';
  }

  void _authChanged() {
    if (!_ready || _disposed) return;
    final key = _currentUserKey();
    if (key == _userKey) return;
    // A user signed in (or out) for the first time this run: their session
    // starts.
    if (_switchUser(key, startSession: true)) _runAll(AutomationTrigger.sessionStart, _event('sessionStart'));
  }

  LocalStorage? get _storage {
    final s = codelessly.services;
    return s is Services ? s.storage : null;
  }

  /// Switches the counters to [key]'s user and counts their launch and
  /// session, once per run; whether it counted them.
  bool _switchUser(String key, {required bool startSession}) {
    _userKey = key;
    final stored = _storage?.get('$kUsageStorageKey.$key');
    _record = stored is Map ? {...stored.cast<String, Object?>()} : {};
    final counted = _launched.add(key);
    if (counted) {
      final now = clock().millisecondsSinceEpoch;
      _record = {
        ..._record,
        'launches': _int(_record['launches']) + 1,
        'firstSeen': _record['firstSeen'] ?? now,
        'lastSeen': now,
      };
      if (startSession) _newSession(save: false);
    }
    _save();
    return counted;
  }

  void _newSession({bool save = true}) {
    _record = {..._record, 'sessions': _int(_record['sessions']) + 1, 'lastSeen': clock().millisecondsSinceEpoch};
    _sessionRuns[_userKey] = {};
    if (save) _save();
  }

  static int _int(Object? v) => v is num ? v.toInt() : 0;

  void _save() {
    final storage = _storage;
    if (storage != null) unawaited(storage.put('$kUsageStorageKey.$_userKey', _record).catchError((Object _) {}));
    final runs = _sessionRuns[_userKey] ?? const {};
    final automations = {
      for (final e in ((_record['automations'] as Map?)?.cast<String, Object?>() ?? const {}).entries)
        e.key: {...?(e.value as Map?)?.cast<String, Object?>(), 'session': runs[e.key] ?? 0},
    };
    _usage.set('usage', {
      ...emptyUsage,
      ..._record,
      'isFirstLaunch': _int(_record['launches']) == 1,
      'isFirstSession': _int(_record['sessions']) == 1,
      'automations': automations,
    });
  }

  // --- running -------------------------------------------------------------------

  void _runAll(AutomationTrigger trigger, AppEvent event, [bool Function(Automation a)? matches]) {
    for (final a in _automations) {
      if (a.trigger == trigger && (matches == null || matches(a))) _runOne(a, event);
    }
  }

  /// Whether [a] may run now, by how often it ran.
  bool _due(Automation a) {
    if (!a.enabled || _disposed) return false;
    final stats = ((_record['automations'] as Map?)?[a.id] as Map?)?.cast<String, Object?>() ?? const {};
    if (a.maxRuns > 0 && _int(stats['count']) >= a.maxRuns) return false;
    if (a.maxPerSession > 0 && (_sessionRuns[_userKey]?[a.id] ?? 0) >= a.maxPerSession) return false;
    final last = stats['last'];
    if (a.everyDays > 0 && last is num) {
      final since = clock().millisecondsSinceEpoch - last.toInt();
      if (since < a.everyDays * Duration.millisecondsPerDay) return false;
    }
    return true;
  }

  void _runOne(Automation a, AppEvent event) {
    if (_running.contains(a.id) || !_due(a)) return;
    _running.add(a.id);
    unawaited(_run(a, event).whenComplete(() => _running.remove(a.id)));
  }

  Future<void> _run(Automation a, AppEvent event) async {
    if (a.delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: a.delayMs));
      if (!_due(a)) return;
    }
    final scope = ValuesScope({'event': event.toJson()}, codelessly.appVariables);
    final config = codelessly.config;
    final context = RuntimeActionContext(
      scope: scope,
      expressions: config.expressions,
      services: codelessly.services,
      ui: codelessly.presenter.actionUi(priority: a.priority),
      functions: codelessly.functions,
      refreshAuthValues: codelessly.refreshAuthValues,
      onError: (error, stack, action) => _report(error, stack, 'Automation ${a.id}: ${action ?? ''} failed'),
    );
    try {
      if (!_holds(a, scope, event)) return;
      _recordRun(a);
      final node = Node(
        id: 'automation:${a.id}',
        type: 'box',
        name: a.name.isEmpty ? a.id : a.name,
        actions: [Reaction(id: a.id, trigger: const Trigger(TriggerType.load), actions: a.actions)],
      );
      await config.actions.trigger(node, TriggerType.load.name, context, event: {'result': event.props});
    } catch (error, stack) {
      _report(error, stack, 'Automation ${a.id} failed');
    } finally {
      context.dispose();
      scope.dispose();
    }
  }

  bool _holds(Automation a, ValueScope scope, AppEvent event) {
    final when = a.when.trim();
    if (when.isEmpty) return true;
    final reading = ValuesScope({'result': event.props}, scope);
    try {
      final expressions = codelessly.config.expressions;
      final value = FormulaEvaluator.exactExpression(when) != null
          ? expressions.evaluate(when, reading)
          : expressions.evaluate('\${= $when}', reading);
      return value == true;
    } catch (error, stack) {
      _report(error, stack, 'Automation ${a.id}: its condition failed');
      return false;
    } finally {
      reading.dispose();
    }
  }

  void _recordRun(Automation a) {
    final all = {...?(_record['automations'] as Map?)?.cast<String, Object?>()};
    final stats = (all[a.id] as Map?)?.cast<String, Object?>() ?? const {};
    all[a.id] = {'count': _int(stats['count']) + 1, 'last': clock().millisecondsSinceEpoch};
    _record = {..._record, 'automations': all};
    final runs = _sessionRuns.putIfAbsent(_userKey, () => {});
    runs[a.id] = (runs[a.id] ?? 0) + 1;
    _save();
  }

  void _report(Object error, StackTrace stack, String message) {
    final s = codelessly.services;
    if (s is Services) {
      s.analytics.logError(error, stackTrace: stack, message: message, type: 'automation_failed');
    } else {
      debugPrint('Codelessly: $message: $error');
    }
  }

  /// Stops it: no more automations run, and [events] closes.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stopIntervals();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    if (_starting != null) {
      codelessly.removeListener(_modelChanged);
      codelessly.route.removeListener(_routeChanged);
    }
    _authWatch?.removeListener(_authChanged);
    unawaited(_events.close());
  }
}
