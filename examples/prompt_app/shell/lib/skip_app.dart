// The running app behind the generated screens: the constants (the
// contract's data, the screens) and what varies by person (their token set,
// which generated screen they get). A screen never owns the data: the store
// here does, and puts its values into each screen as it is shown.
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart' show UiEvent, UiSession;
import 'package:flutter/foundation.dart';

/// The people the screens were generated for, each with their token set.
const people = {'beginner': 'default', 'kid': 'pink', 'athlete': 'athlete'};

/// The screens of the app, in the order of `app.json`.
const screens = ['home', 'history', 'session'];

/// The token sets over the one design system.
const tokenSets = ['default', 'pink', 'athlete'];

/// What a screen told the app: which screen and person it came from, the
/// event's name and value, when, and whether the app acted on it (a story
/// only lists what its screen says).
typedef LogLine = ({String screen, String person, String event, Object? value, DateTime time, bool handled});

class SkipApp extends ChangeNotifier {
  SkipApp(this._load);

  /// Reads an asset by key.
  final Future<String> Function(String key) _load;

  late api.DesignSystem designSystem;
  final _themes = <String, api.ThemeTokens>{};
  final _documents = <String, Map<String, Object?>>{};

  /// The sessions on screen besides [session] (stories, the steps of a
  /// flow): a store edit reaches each of them.
  final _shown = <UiSession>{};

  /// The contract's data: every screen reads it, none owns it.
  final data = <String, Object?>{};
  final log = <LogLine>[];

  String person = 'beginner';
  String screen = 'home';

  /// The token set the screens are drawn under. Choosing a person sets it to
  /// theirs; [restyle] changes it alone, with the same generated screens.
  String tokens = 'default';
  UiSession? session;
  bool ready = false;

  /// Why [start] could not finish, when it could not.
  Object? failure;

  Future<void> start() async {
    failure = null;
    try {
      designSystem = api.DesignSystem.fromJson(jsonDecode(await _load('assets/skip.json')));
      _themes['default'] = api.ThemeTokens.none;
      for (final t in const ['pink', 'athlete']) {
        _themes[t] = api.ThemeTokens.fromJson(jsonDecode(await _load('assets/themes/$t.json')));
      }
      final app = jsonDecode(await _load('assets/app.json')) as Map;
      data
        ..clear()
        ..addAll(((app['contract'] as Map)['variables'] as Map).cast<String, Object?>());
    } catch (e) {
      failure = e;
      notifyListeners();
      return;
    }
    for (final p in people.keys) {
      for (final s in screens) {
        // A screen that was not generated is a state of the app, not a
        // failure: the others still run.
        try {
          _documents['$s.$p'] = (jsonDecode(await _load('assets/screens/$s.$p.json')) as Map).cast<String, Object?>();
        } catch (_) {
          _documents.remove('$s.$p');
        }
      }
    }
    ready = true;
    open(screen);
  }

  /// Whether [name] was generated for [who].
  bool has(String name, [String? who]) => _documents.containsKey('$name.${who ?? person}');

  /// The declared variables of [doc]'s canvas that the store holds.
  Map<String, Object?> _declared(Map<String, Object?> doc, Map<String, Object?> values) {
    final canvas = (doc['roots']! as List).first as String;
    final declared = {for (final v in (((doc['variables'] as Map?)?[canvas] as List?) ?? const [])) (v as Map)['name']};
    return {
      for (final e in values.entries)
        if (declared.contains(e.key)) e.key: e.value,
    };
  }

  void _put(UiSession into, Map<String, Object?> doc, Map<String, Object?> values) {
    final set = _declared(doc, values);
    if (set.isEmpty) return;
    into.apply({
      'ops': [
        {'op': 'vars', 'scope': (doc['roots']! as List).first, 'set': set},
      ],
    });
  }

  /// A session showing [name] for [who] under [under], with the store's
  /// values put in, then [state] (the screen's own state, or a value shown
  /// in place of the store's). Null when the screen was not generated. The
  /// session follows the store until it is given back with [close].
  UiSession? show(String name, {String? who, String? under, Map<String, Object?> state = const {}}) {
    final doc = _documents['$name.${who ?? person}'];
    if (doc == null) return null;
    final catalog = designSystem.catalogOver(api.standardCatalog);
    final next = UiSession(
      document: api.LayoutDocument.fromJson(doc, catalog: catalog),
      designSystem: designSystem,
      theme: _themes[under ?? tokens],
      holdEmptyContainers: false,
    );
    // The screen declares the contract's variables with sample values (so it
    // can be shown alone); here they take the store's.
    _put(next, doc, {...data, ...state});
    _shown.add(next);
    _docOf[next] = doc;
    return next;
  }

  final _docOf = Expando<Map<String, Object?>>();

  /// Puts [values] into a session from [show] (a value shown in place of the
  /// store's, after the store changed).
  void put(UiSession into, Map<String, Object?> values) {
    final doc = _docOf[into];
    if (doc != null) _put(into, doc, values);
  }

  void close(UiSession? shown) {
    if (shown == null || !_shown.remove(shown)) return;
    shown.dispose();
  }

  /// Shows [name] for the current person: its generated document in a new
  /// session, under the token set, with the store's values put in.
  void open(String name) {
    if (!screens.contains(name)) return;
    screen = name;
    final old = session;
    session = null;
    close(old);
    final next = show(name);
    next?.events.listen(handle);
    session = next;
    notifyListeners();
  }

  void choose(String who) {
    if (!people.containsKey(who) || who == person) return;
    person = who;
    tokens = people[who]!;
    open(screen);
  }

  /// Draws the same generated screens under another token set.
  void restyle(String under) {
    if (!tokenSets.contains(under) || under == tokens) return;
    tokens = under;
    open(screen);
  }

  /// Changes one of the store's values (from the panel): every screen on
  /// show has it at once, with its own state untouched.
  void set(String key, Object? value) {
    if (!data.containsKey(key) || _same(data[key], value)) return;
    data[key] = value;
    _stored({key: value});
    notifyListeners();
  }

  void _stored(Map<String, Object?> values) {
    for (final s in _shown) {
      put(s, values);
    }
  }

  static bool _same(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);

  /// Lists what a screen said without acting on it (a story's screen).
  void note(UiEvent e, {required String from, String? who}) => _note(e, from, who ?? person, false);

  void _note(UiEvent e, String from, String who, bool handled) {
    log.insert(0, (screen: from, person: who, event: e.event, value: e.value, time: DateTime.now(), handled: handled));
    if (log.length > 100) log.removeLast();
    if (!handled) notifyListeners();
  }

  void clearLog() {
    if (log.isEmpty) return;
    log.clear();
    notifyListeners();
  }

  /// What a screen told the app: the contract's actions.
  void handle(UiEvent e) {
    _note(e, screen, person, true);
    switch (e.event) {
      case 'open_home':
        open('home');
      case 'open_history':
        open('history');
      case 'start_session':
        if (screen != 'session') {
          open('session');
        } else {
          notifyListeners();
        }
      case 'finish_session':
        _finished(e.value);
        notifyListeners();
      default:
        notifyListeners();
    }
  }

  /// A finished session goes into the store: the next screen shown has it.
  void _finished(Object? value) {
    final jumps = switch (value) {
      final num n => n.round(),
      final String s => int.tryParse(s) ?? 0,
      _ => 0,
    };
    final today = (data['today'] as Map?) ?? const {};
    data['sessions'] = [
      {
        'date': 'Today',
        'name': today['name'] ?? 'Session',
        'minutes': today['minutes'] ?? 0,
        'jumps': jumps,
        'best': 0,
      },
      ...(data['sessions'] as List? ?? const []),
    ];
    data['streak'] = ((data['streak'] as num?) ?? 0) + 1;
    data['sessionsThisWeek'] = ((data['sessionsThisWeek'] as num?) ?? 0) + 1;
    final weeks = [...(data['weeks'] as List? ?? const [])];
    if (weeks.isNotEmpty) {
      final last = {...(weeks.last as Map)};
      last['jumps'] = ((last['jumps'] as num?) ?? 0) + jumps;
      weeks[weeks.length - 1] = last;
      data['weeks'] = weeks;
    }
    _stored({
      for (final k in const ['sessions', 'streak', 'sessionsThisWeek', 'weeks']) k: data[k],
    });
  }

  @override
  void dispose() {
    for (final s in _shown.toList()) {
      s.dispose();
    }
    _shown.clear();
    session = null;
    super.dispose();
  }
}
