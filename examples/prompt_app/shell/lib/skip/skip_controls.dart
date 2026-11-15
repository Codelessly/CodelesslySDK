// The storyboard's controls: one schema for the dynamic properties panel and
// one controller, kept the same as the app in both directions. A row edited
// in the panel becomes a call on the app (choose, restyle, open, set); a
// change made by the app (a finished session, a screen that navigated)
// becomes the panel's value.
import 'dart:async';
import 'dart:convert';

import 'package:dynamic_properties_panel/dynamic_properties_panel.dart';

import '../skip_app.dart';

/// The rows that choose what is shown.
const shownKeys = ['person', 'tokens', 'screen'];

/// The rows that are the store (the contract's data).
const storeKeys = ['streak', 'weeklyGoal', 'sessionsThisWeek', 'today', 'sessions', 'weeks'];

String _title(String s) => s[0].toUpperCase() + s.substring(1);

/// The one schema. Defaults are the contract's sample values, so a row's
/// reset returns to what `app.json` declares.
List<DynamicPropertyDefinition> skipSchema(Map<String, Object?> contract) {
  final today = (contract['today'] as Map?) ?? const {};
  return DynamicPropertyDefinition.listFromJson([
    {
      'name': 'person',
      'title': 'Person',
      'type': 'String',
      'description': 'Whose generated screens are shown',
      'enumValues': people.keys.toList(),
      'enumLabels': {for (final p in people.keys) p: _title(p)},
      'defaultValue': 'beginner',
    },
    {
      'name': 'tokens',
      'title': 'Token set',
      'type': 'String',
      'description': 'A restyle of the same screens, with nothing regenerated',
      'enumValues': tokenSets,
      'enumLabels': {for (final t in tokenSets) t: _title(t)},
      'defaultValue': 'default',
    },
    {
      'name': 'screen',
      'title': 'Screen',
      'type': 'String',
      'enumValues': screens,
      'enumLabels': {for (final s in screens) s: _title(s)},
      'defaultValue': 'home',
    },
    {
      'name': 'streak',
      'title': 'Streak',
      'type': 'int',
      'bounds': {'minimum': 0, 'maximum': 999, 'suffix': 'd'},
      'defaultValue': contract['streak'],
    },
    {
      'name': 'weeklyGoal',
      'title': 'Weekly goal',
      'type': 'int',
      'bounds': {'minimum': 1, 'maximum': 14},
      'defaultValue': contract['weeklyGoal'],
    },
    {
      'name': 'sessionsThisWeek',
      'title': 'This week',
      'type': 'int',
      'bounds': {'minimum': 0, 'maximum': 14},
      'defaultValue': contract['sessionsThisWeek'],
    },
    {
      'name': 'today',
      'title': 'Today',
      'type': 'object',
      'defaultValue': contract['today'],
      'properties': {
        'name': {'defaultValue': today['name'], 'title': 'Name', 'type': 'String'},
        'rounds': {
          'defaultValue': today['rounds'],
          'title': 'Rounds',
          'type': 'int',
          'bounds': {'minimum': 1, 'maximum': 30},
        },
        'work': {
          'defaultValue': today['work'],
          'title': 'Work',
          'type': 'int',
          'bounds': {'minimum': 5, 'maximum': 600, 'suffix': 's'},
        },
        'rest': {
          'defaultValue': today['rest'],
          'title': 'Rest',
          'type': 'int',
          'bounds': {'minimum': 0, 'maximum': 600, 'suffix': 's'},
        },
        'minutes': {
          'defaultValue': today['minutes'],
          'title': 'Minutes',
          'type': 'int',
          'bounds': {'minimum': 1, 'maximum': 120, 'suffix': 'min'},
        },
      },
    },
    {
      'name': 'sessions',
      'title': 'Sessions',
      'type': 'array',
      'defaultValue': contract['sessions'],
      'item': {
        'title': 'Session',
        'type': 'object',
        'properties': {
          'date': {'title': 'Date', 'type': 'String'},
          'name': {'title': 'Name', 'type': 'String'},
          'minutes': {
            'title': 'Minutes',
            'type': 'int',
            'bounds': {'minimum': 0, 'suffix': 'min'},
          },
          'jumps': {
            'title': 'Jumps',
            'type': 'int',
            'bounds': {'minimum': 0},
          },
          'best': {
            'title': 'Best run',
            'type': 'int',
            'bounds': {'minimum': 0},
          },
        },
      },
    },
    {
      'name': 'weeks',
      'title': 'Weeks',
      'type': 'array',
      'defaultValue': contract['weeks'],
      'item': {
        'title': 'Week',
        'type': 'object',
        'properties': {
          'label': {'title': 'Label', 'type': 'String'},
          'jumps': {
            'title': 'Jumps',
            'type': 'int',
            'bounds': {'minimum': 0},
          },
        },
      },
    },
  ]);
}

/// The app's side of the panel: what each row shows.
Map<String, dynamic> panelValues(SkipApp app) => {
  'person': app.person,
  'tokens': app.tokens,
  'screen': app.screen,
  for (final k in storeKeys) k: _copy(app.data[k]),
};

dynamic _copy(Object? v) => v == null ? null : jsonDecode(jsonEncode(v));
bool _same(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);

class SkipControls {
  SkipControls(this.app) : controller = DynamicPropertiesController() {
    _commits = controller.commits.listen(_committed);
    app.addListener(sync);
    sync();
  }

  final SkipApp app;
  final DynamicPropertiesController controller;
  late final StreamSubscription<PropertyChange> _commits;

  List<DynamicPropertyDefinition> _schema = const [];
  Map<String, Object?> _contract = const {};

  /// The schema, once the contract is read (empty before).
  List<DynamicPropertyDefinition> get schema => _schema;

  List<DynamicPropertyDefinition> rows(List<String> keys) => [
    for (final k in keys)
      for (final p in _schema)
        if (p.name == k) p,
  ];

  bool _applying = false;

  /// The app changed: the rows whose value differs take the app's, without
  /// the write coming back as a commit (as the Editor's generated sections
  /// do when a node changes outside the panel). A row that already shows the
  /// value is not written, so only what changed rebuilds.
  void sync() {
    if (!app.ready || _applying) return;
    if (_schema.isEmpty) {
      _contract = {for (final k in storeKeys) k: _copy(app.data[k])};
      _schema = skipSchema(_contract);
    }
    final next = panelValues(app);
    final changed = <String, dynamic>{
      for (final e in next.entries)
        if (!_same(controller[e.key], e.value)) e.key: e.value,
    };
    // ignore: invalid_use_of_internal_member
    if (changed.isNotEmpty) controller.applyAllSilent(changed);
  }

  /// A row changed (or several: a bulk write): each becomes a call on the
  /// app, the person first since it brings its own token set.
  void _committed(PropertyChange change) {
    if (!app.ready) return;
    final values = change.isBulk ? change.bulkValues! : {change.key!: change.value};
    // A row that was reset holds null: it returns to its default.
    Object? of(String key) => values[key] ?? _default(key);
    _applying = true;
    try {
      if (values.containsKey('person')) app.choose('${of('person')}');
      if (values.containsKey('tokens')) app.restyle('${of('tokens')}');
      if (values.containsKey('screen') && of('screen') != app.screen) app.open('${of('screen')}');
      for (final key in storeKeys) {
        if (values.containsKey(key)) app.set(key, _stored(key, of(key)));
      }
    } finally {
      _applying = false;
    }
    // Whatever the app did not take (a value out of range, a reset), and
    // what it changed besides (a person's token set), goes back to the rows.
    sync();
  }

  Object? _default(String key) => switch (key) {
    'person' => 'beginner',
    'tokens' => people[app.person],
    'screen' => 'home',
    _ => _copy(_contract[key]),
  };

  /// The panel's value as the store keeps it: whole numbers stay whole, and
  /// a field the panel left empty keeps the store's value.
  Object? _stored(String key, Object? value) => _like(app.data[key], value);

  static Object? _like(Object? old, Object? value) {
    if (value == null) return old;
    if (old is int && value is num) return value.round();
    if (old is Map && value is Map) {
      return {
        for (final k in {...old.keys, ...value.keys}) '$k': _like(old[k], value[k]),
      };
    }
    if (old is List && value is List) {
      return [for (var i = 0; i < value.length; i++) i < old.length ? _like(old[i], value[i]) : value[i]];
    }
    return value;
  }

  void dispose() {
    app.removeListener(sync);
    _commits.cancel();
    controller.dispose();
  }
}
