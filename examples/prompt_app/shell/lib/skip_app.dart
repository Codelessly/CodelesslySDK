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

/// What a line of the event log says.
typedef LogLine = ({String screen, String text});

class SkipApp extends ChangeNotifier {
  SkipApp(this._load);

  /// Reads an asset by key.
  final Future<String> Function(String key) _load;

  late final api.DesignSystem designSystem;
  final _themes = <String, api.ThemeTokens>{};
  final _documents = <String, Map<String, Object?>>{};

  /// The contract's data: every screen reads it, none owns it.
  final data = <String, Object?>{};
  final log = <LogLine>[];

  String person = 'beginner';
  String screen = 'home';
  UiSession? session;
  bool ready = false;

  Future<void> start() async {
    designSystem = api.DesignSystem.fromJson(jsonDecode(await _load('assets/skip.json')));
    _themes['default'] = api.ThemeTokens.none;
    for (final t in const ['pink', 'athlete']) {
      _themes[t] = api.ThemeTokens.fromJson(jsonDecode(await _load('assets/themes/$t.json')));
    }
    final app = jsonDecode(await _load('assets/app.json')) as Map;
    data.addAll(((app['contract'] as Map)['variables'] as Map).cast<String, Object?>());
    for (final p in people.keys) {
      for (final s in const ['home', 'history', 'session']) {
        _documents['$s.$p'] = (jsonDecode(await _load('assets/screens/$s.$p.json')) as Map).cast<String, Object?>();
      }
    }
    ready = true;
    open('home');
  }

  /// Shows [name] for the current person: its generated document in a new
  /// session, under their token set, with the store's values put in.
  void open(String name) {
    final doc = _documents['$name.$person'];
    if (doc == null) return;
    screen = name;
    session?.dispose();
    final catalog = designSystem.catalogOver(api.standardCatalog);
    final next = UiSession(
      document: api.LayoutDocument.fromJson(doc, catalog: catalog),
      designSystem: designSystem,
      theme: _themes[people[person]!],
      holdEmptyContainers: false,
    );
    final canvas = (doc['roots']! as List).first as String;
    // The screen declares the contract's variables with sample values (so it
    // can be shown alone); here they take the store's.
    final declared = {for (final v in (((doc['variables'] as Map?)?[canvas] as List?) ?? const [])) (v as Map)['name']};
    next.apply({
      'ops': [
        {
          'op': 'vars',
          'scope': canvas,
          'set': {for (final e in data.entries) if (declared.contains(e.key)) e.key: e.value},
        },
      ],
    });
    next.events.listen((e) => handle(e));
    session = next;
    notifyListeners();
  }

  void choose(String who) {
    if (!people.containsKey(who) || who == person) return;
    person = who;
    open(screen);
  }

  /// What a screen told the app: the contract's actions.
  void handle(UiEvent e) {
    log.insert(0, (screen: screen, text: e.value == null ? e.event : '${e.event} ${jsonEncode(e.value)}'));
    if (log.length > 30) log.removeLast();
    switch (e.event) {
      case 'open_home':
        open('home');
      case 'open_history':
        open('history');
      case 'start_session':
        if (screen != 'session') open('session');
      case 'finish_session':
        _finished(e.value);
        notifyListeners();
      default:
        notifyListeners();
    }
  }

  /// A finished session goes into the store: the next screen shown has it.
  void _finished(Object? value) {
    final jumps = switch (value) { final num n => n.round(), final String s => int.tryParse(s) ?? 0, _ => 0 };
    final today = (data['today'] as Map?) ?? const {};
    data['sessions'] = [
      {'date': 'Today', 'name': today['name'] ?? 'Session', 'minutes': today['minutes'] ?? 0, 'jumps': jumps, 'best': 0},
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
  }

  @override
  void dispose() {
    session?.dispose();
    super.dispose();
  }
}
