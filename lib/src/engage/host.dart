// The seam between the managed-feature core (identity, events, the backend
// connection) and the features built on it (inbox, in-app messages,
// onboarding, feedback, support). A feature depends on [EngageHost] only;
// the core implements it, and tests use [MemoryEngageHost].
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/storage.dart';

/// Who the app's user is, as the managed features know them.
@immutable
class EngageIdentity {
  const EngageIdentity({
    required this.anonymousId,
    this.userId,
    this.attributes = const {},
  });

  /// Stable for this install, from before the user is known.
  final String anonymousId;

  /// The identified user, or null while only the install is known.
  final String? userId;

  /// The user's attributes: strings, numbers, bools, ISO-8601 dates and
  /// lists of strings.
  final Map<String, Object?> attributes;

  /// The id that per-user content is stored under.
  String get id => userId ?? anonymousId;
}

/// What a managed feature needs from the core.
abstract interface class EngageHost {
  /// The Codelessly project the app loads.
  String get projectId;

  /// The current identity; [identityChanges] fires after it changes
  /// (identify, reset, sign in, sign out).
  EngageIdentity get identity;
  Stream<EngageIdentity> get identityChanges;

  /// Records an event. Never throws; queued while offline.
  void track(String name, [Map<String, Object?> properties = const {}]);

  /// Events as they are tracked, for features that react to them on the
  /// device (triggers).
  Stream<EngageEvent> get events;

  /// Calls Codelessly's backend for this project as the current identity.
  /// [endpoint] is a feature's own endpoint name, such as `inbox/list`.
  /// Fails with [EngageUnavailable] when there is no backend or network.
  Future<Map<String, Object?>> call(
    String endpoint, [
    Map<String, Object?> body = const {},
  ]);

  /// Device storage for a feature's cache; keys are the feature's own,
  /// prefixed with its name (`inbox.cards`).
  LocalStorage get storage;

  /// The current time; a fake clock in tests.
  DateTime now();
}

/// An event a feature can react to.
@immutable
class EngageEvent {
  const EngageEvent(this.name, this.properties, this.at);
  final String name;
  final Map<String, Object?> properties;
  final DateTime at;
}

/// The backend could not be reached, or the project has no managed
/// features. Features treat it as "nothing to show", never as a crash.
class EngageUnavailable implements Exception {
  const EngageUnavailable([
    this.message = 'Managed features are not available',
  ]);
  final String message;
  @override
  String toString() => 'EngageUnavailable: $message';
}

/// An [EngageHost] in memory, for tests and previews: [handlers] answer
/// [call] by endpoint, [clock] is the time, and [tracked] collects events.
class MemoryEngageHost implements EngageHost {
  MemoryEngageHost({
    this.projectId = 'project',
    EngageIdentity identity = const EngageIdentity(anonymousId: 'anon'),
    LocalStorage? storage,
    DateTime? clock,
    Map<
      String,
      FutureOr<Map<String, Object?>> Function(Map<String, Object?> body)
    >?
    handlers,
  }) : // ignore: prefer_initializing_formals
       _identity = identity,
       storage = storage ?? MemoryLocalStorage(),
       clock = clock ?? DateTime.utc(2026),
       handlers = handlers ?? {};

  @override
  final String projectId;
  @override
  final LocalStorage storage;

  /// The time [now] answers; set it to move the clock.
  DateTime clock;

  /// Answers to [call], by endpoint. A missing endpoint is [EngageUnavailable].
  final Map<
    String,
    FutureOr<Map<String, Object?>> Function(Map<String, Object?> body)
  >
  handlers;

  /// Every call made, in order: (endpoint, body).
  final List<(String, Map<String, Object?>)> calls = [];

  /// Every event tracked, in order.
  final List<EngageEvent> tracked = [];

  final _identities = StreamController<EngageIdentity>.broadcast(sync: true);
  final _events = StreamController<EngageEvent>.broadcast(sync: true);
  EngageIdentity _identity;

  @override
  EngageIdentity get identity => _identity;

  /// Changes who the user is, as identify, reset or a sign in would.
  set identity(EngageIdentity value) {
    _identity = value;
    _identities.add(value);
  }

  @override
  Stream<EngageIdentity> get identityChanges => _identities.stream;

  @override
  Stream<EngageEvent> get events => _events.stream;

  @override
  void track(String name, [Map<String, Object?> properties = const {}]) {
    final event = EngageEvent(name, properties, now());
    tracked.add(event);
    _events.add(event);
  }

  @override
  Future<Map<String, Object?>> call(
    String endpoint, [
    Map<String, Object?> body = const {},
  ]) async {
    calls.add((endpoint, body));
    final handler = handlers[endpoint];
    if (handler == null) throw const EngageUnavailable();
    return handler(body);
  }

  @override
  DateTime now() => clock;

  Future<void> dispose() async {
    await _identities.close();
    await _events.close();
  }
}
