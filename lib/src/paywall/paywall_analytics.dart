import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Only these fields are persisted; payment receipts and user attributes are
/// never accepted by this analytics envelope.
class PaywallAnalyticsEvent {
  final String id;
  final String name;
  final String placement;
  final String releaseId;
  final String variant;
  final String? slot;
  final int at;
  const PaywallAnalyticsEvent({
    required this.id,
    required this.name,
    required this.placement,
    required this.releaseId,
    required this.variant,
    this.slot,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'placement': placement,
    'releaseId': releaseId,
    'variant': variant,
    'slot': slot,
    'at': at,
  };
  factory PaywallAnalyticsEvent.fromJson(Map<String, dynamic> data) =>
      PaywallAnalyticsEvent(
        id: data['id'] as String,
        name: data['name'] as String,
        placement: data['placement'] as String,
        releaseId: data['releaseId'] as String,
        variant: data['variant'] as String,
        slot: data['slot'] as String?,
        at: data['at'] as int,
      );
}

/// A journal is keyed by project and authenticated UID. Consent is opt-in;
/// revoking it clears queued events immediately and blocks further writes.
class PaywallAnalyticsQueue {
  static const maxEvents = 100;
  static const maxAge = Duration(days: 7);
  final String projectId;
  final String uid;
  final Future<void> Function(PaywallAnalyticsEvent) send;
  final Future<SharedPreferences> Function() preferences;
  bool consent = false;
  Future<void> _serial = Future.value();
  Timer? _retry;
  int _attempt = 0;

  PaywallAnalyticsQueue({
    required this.projectId,
    required this.uid,
    required this.send,
    Future<SharedPreferences> Function()? preferences,
  }) : preferences = preferences ?? SharedPreferences.getInstance;
  String get _key => 'codelessly.paywall.events.$projectId.$uid';

  Future<void> setConsent(bool enabled) async {
    consent = enabled;
    if (!enabled) {
      _retry?.cancel();
      await _enqueue(() async {
        (await preferences()).remove(_key);
      });
    } else {
      await flush();
    }
  }

  Future<void> _enqueue(Future<void> Function() work) {
    final next = _serial.then((_) => work());
    _serial = next.catchError((Object _) {});
    return next;
  }

  List<PaywallAnalyticsEvent> _read(SharedPreferences prefs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final seen = <String>{};
    final events = <PaywallAnalyticsEvent>[];
    for (final raw in prefs.getStringList(_key) ?? const <String>[]) {
      try {
        final event = PaywallAnalyticsEvent.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (now - event.at <= maxAge.inMilliseconds && seen.add(event.id)) {
          events.add(event);
        }
      } catch (_) {
        /* Discard malformed device state. */
      }
    }
    return events.length > maxEvents
        ? events.sublist(events.length - maxEvents)
        : events;
  }

  Future<void> _write(
    SharedPreferences prefs,
    List<PaywallAnalyticsEvent> events,
  ) async {
    if (!await prefs.setStringList(_key, [
      for (final event in events) jsonEncode(event.toJson()),
    ])) {
      throw StateError('Could not persist paywall analytics event');
    }
  }

  Future<void> record(PaywallAnalyticsEvent event) async {
    if (!consent) return;
    await _enqueue(() async {
      if (!consent) return;
      final prefs = await preferences();
      final events = _read(prefs);
      if (events.any((item) => item.id == event.id)) return;
      await _write(prefs, [...events, event].takeLast(maxEvents).toList());
    });
    await flush();
  }

  Future<void> flush() async {
    if (!consent) return;
    await _enqueue(() async {
      final prefs = await preferences();
      final events = _read(prefs);
      for (var i = 0; i < events.length; i++) {
        if (!consent) return;
        try {
          await send(events[i]);
          if (!consent) return;
          await _write(prefs, events.sublist(i + 1));
          _attempt = 0;
        } catch (_) {
          final delay = Duration(seconds: 1 << _attempt.clamp(0, 6));
          _attempt++;
          _retry?.cancel();
          _retry = Timer(delay, () {
            unawaited(flush());
          });
          return;
        }
      }
    });
  }

  Future<int> get pending async {
    await _serial;
    return _read(await preferences()).length;
  }

  void dispose() {
    _retry?.cancel();
  }
}

extension _Tail<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    final values = toList();
    return values.skip(values.length > count ? values.length - count : 0);
  }
}
