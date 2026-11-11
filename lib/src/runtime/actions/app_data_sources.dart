// Live data the whole app shares: `loadCloudData` with `scope: app` keeps
// one subscription per variable for the app's Codelessly instance instead of
// one per screen, so a count loaded on one screen is live on every other
// (a badge on a tab bar, a header on another host screen).
import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart' show Variable, VariableType;
import 'package:flutter/foundation.dart';

import '../expressions/scopes.dart';
import 'runner.dart' show ActionsCanceled;

/// The app's shared live data sources ([CloudDataScope.app] loads): one
/// subscription per app variable, opened by the first load and shared by
/// every later load of the same source from any screen, writing
/// `{status, isLoading, data, error}` into the app variable (declared as a
/// map when no app variable has the name).
///
/// A source lives until [dispose] (the app is done), until a load for the
/// same variable asks for another source (the old one is closed), or until
/// it fails (the next load opens it again). When the signed-in user changes
/// (`auth.uid`), every source is opened again, so queries the data rules
/// filter by owner follow the new user.
class AppDataSources {
  AppDataSources(this.variables, {this.onError});

  /// The app's variables, which the sources write.
  final VariableScope variables;

  /// Gets a source's error after its first value (no action awaits it).
  final void Function(Object error, StackTrace stack)? onError;

  final Map<String, _Source> _sources = {};
  Listenable? _identity;
  Object? _uid;
  bool _disposed = false;

  /// The variables with a live source.
  @visibleForTesting
  Set<String> get active => {for (final e in _sources.entries) if (!e.value.failed) e.key};

  /// How many subscriptions were opened since the app started.
  @visibleForTesting
  int opened = 0;

  /// Loads [variable] from the source [key] names (the same key is the same
  /// data: its path, document or query), opened with [open]. Completes with
  /// the first value; a load of a source already open completes when it
  /// has its first value, without opening another.
  Future<void> load(String variable, String key, Stream<Object?> Function() open) {
    if (_disposed) return Future.error(StateError('The app is disposed'));
    final current = _sources[variable];
    if (current != null && current.key == key && !current.failed) return current.first.future;
    current?.close();
    if (!variables.declares(variable)) {
      variables.define(Variable(name: variable, type: VariableType.map, value: const <String, Object?>{}));
    }
    final source = _sources[variable] = _Source(key, open);
    _watchIdentity();
    _start(variable, source);
    return source.first.future;
  }

  void _start(String variable, _Source source) {
    void put(String status, {Object? data, Object? error}) {
      if (!identical(_sources[variable], source) || _disposed) return;
      variables.set(variable, {
        'status': status,
        'isLoading': status == 'loading',
        'data': data,
        'error': ?error,
      });
    }

    void fail(Object error, StackTrace stack) {
      source.failed = true;
      put('error', error: '$error');
      if (!source.first.isCompleted) {
        source.first.completeError(error, stack);
      } else {
        onError?.call(error, stack);
      }
    }

    put('loading');
    opened++;
    try {
      source.subscription = source.open().listen(
        (data) {
          if (source.closed) return;
          put('loaded', data: data);
          if (!source.first.isCompleted) source.first.complete();
        },
        onError: (Object error, StackTrace stack) {
          if (!source.closed) fail(error, stack);
        },
        onDone: () {
          if (!source.closed && !source.first.isCompleted) {
            fail(StateError('Cloud data stream closed before a value'), StackTrace.current);
          }
        },
        cancelOnError: true,
      );
    } catch (error, stack) {
      fail(error, stack);
    }
    // A load that nothing awaits any more must not report an unhandled error.
    source.first.future.ignore();
  }

  /// Opens every source again when the signed-in user changes.
  void _watchIdentity() {
    if (_identity != null) return;
    _uid = variables.read('auth.uid');
    _identity = watchName(variables, 'auth');
    _identity?.addListener(_identityChanged);
  }

  void _identityChanged() {
    final uid = variables.read('auth.uid');
    if (uid == _uid || _disposed) return;
    _uid = uid;
    for (final e in [..._sources.entries]) {
      if (e.value.failed) continue;
      e.value.close();
      final again = _sources[e.key] = _Source(e.value.key, e.value.open);
      _start(e.key, again);
    }
  }

  /// Closes [variable]'s source (it keeps its last value).
  void close(String variable) => _sources.remove(variable)?.close();

  /// Closes every source.
  void dispose() {
    _disposed = true;
    _identity?.removeListener(_identityChanged);
    for (final s in _sources.values) {
      s.close();
    }
    _sources.clear();
  }
}

class _Source {
  _Source(this.key, this.open);

  final String key;
  final Stream<Object?> Function() open;
  final Completer<void> first = Completer<void>();
  StreamSubscription<Object?>? subscription;
  bool failed = false;
  bool closed = false;

  void close() {
    if (closed) return;
    closed = true;
    unawaited(subscription?.cancel());
    if (!first.isCompleted) first.completeError(const ActionsCanceled());
  }
}
