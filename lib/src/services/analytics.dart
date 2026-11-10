// Analytics and error reporting: what the runtime tells the app about, to
// send wherever the app sends its own (Firebase Analytics, Sentry, logs).
import 'package:flutter/foundation.dart';

/// Receives analytics events (screen views, paywall events, custom events
/// from actions) and errors.
abstract interface class AnalyticsService {
  /// An event [name] with [parameters].
  void logEvent(String name, [Map<String, Object?> parameters = const {}]);

  /// A screen (layout, page) was shown.
  void logScreen(String name, {String? layoutId});

  /// An error that didn't reach the app otherwise. [type] groups them
  /// (`api_not_found`, `auth_failed`...).
  void logError(Object error, {StackTrace? stackTrace, String? message, String? type, Map<String, Object?> context = const {}});
}

/// Drops everything. The default in release builds.
class NoAnalytics implements AnalyticsService {
  const NoAnalytics();

  @override
  void logEvent(String name, [Map<String, Object?> parameters = const {}]) {}

  @override
  void logScreen(String name, {String? layoutId}) {}

  @override
  void logError(Object error, {StackTrace? stackTrace, String? message, String? type, Map<String, Object?> context = const {}}) {}
}

/// Prints to the debug console (with [debugPrint]). The default in debug
/// builds.
class DebugAnalytics implements AnalyticsService {
  const DebugAnalytics({this.prefix = 'Codelessly'});

  final String prefix;

  @override
  void logEvent(String name, [Map<String, Object?> parameters = const {}]) =>
      debugPrint('[$prefix] event $name${parameters.isEmpty ? '' : ' $parameters'}');

  @override
  void logScreen(String name, {String? layoutId}) =>
      debugPrint('[$prefix] screen $name${layoutId == null ? '' : ' ($layoutId)'}');

  @override
  void logError(Object error, {StackTrace? stackTrace, String? message, String? type, Map<String, Object?> context = const {}}) {
    debugPrint('[$prefix] error${type == null ? '' : ' [$type]'}: ${message ?? error}${context.isEmpty ? '' : ' $context'}');
    if (message != null) debugPrint('  $error');
    if (stackTrace != null) debugPrint('$stackTrace');
  }
}

/// One recorded call of a [RecordingAnalytics].
typedef AnalyticsRecord = ({String kind, String name, Map<String, Object?> data});

/// Records everything (tests, an in-app debug panel).
class RecordingAnalytics implements AnalyticsService {
  final List<AnalyticsRecord> records = [];

  /// The names of the recorded events.
  List<String> get events => [for (final r in records) if (r.kind == 'event') r.name];

  /// The recorded errors' types (or messages).
  List<String> get errors => [for (final r in records) if (r.kind == 'error') r.name];

  @override
  void logEvent(String name, [Map<String, Object?> parameters = const {}]) =>
      records.add((kind: 'event', name: name, data: parameters));

  @override
  void logScreen(String name, {String? layoutId}) =>
      records.add((kind: 'screen', name: name, data: {'layoutId': layoutId}));

  @override
  void logError(Object error, {StackTrace? stackTrace, String? message, String? type, Map<String, Object?> context = const {}}) =>
      records.add((kind: 'error', name: type ?? message ?? '$error', data: {'error': error, 'message': message, ...context}));
}

/// Sends to each of [services].
class MultiAnalytics implements AnalyticsService {
  const MultiAnalytics(this.services);

  final List<AnalyticsService> services;

  @override
  void logEvent(String name, [Map<String, Object?> parameters = const {}]) {
    for (final s in services) {
      s.logEvent(name, parameters);
    }
  }

  @override
  void logScreen(String name, {String? layoutId}) {
    for (final s in services) {
      s.logScreen(name, layoutId: layoutId);
    }
  }

  @override
  void logError(Object error, {StackTrace? stackTrace, String? message, String? type, Map<String, Object?> context = const {}}) {
    for (final s in services) {
      s.logError(error, stackTrace: stackTrace, message: message, type: type, context: context);
    }
  }
}
