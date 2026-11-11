// The inbox's runtime: fetches the user's cards, caches them for offline
// use, keeps read/click/dismiss state, queues changes while offline, and
// logs analytics. Built on an EngageHost only.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../host.dart';
import 'inbox_models.dart';

/// Opens a URL or deep link from a card. The app supplies it (for example
/// with url_launcher or its router); the SDK opens nothing by itself.
typedef InboxUrlOpener = FutureOr<void> Function(Uri uri);

/// Receives a card's custom action key (`InboxActionKind.custom`).
typedef InboxCustomActionHandler =
    FutureOr<void> Function(String key, InboxCard card);

/// Called on every card or button tap before the default handling. Return
/// true when the app handled it, to skip the default (open the URL, hand
/// the custom key, dismiss).
typedef InboxCardTapHandler = FutureOr<bool> Function(InboxCardTap tap);

/// Renders a Codelessly layout for the inbox or a card. The SDK's core sets
/// [CodelesslyInbox.layoutBuilder] to a builder over CodelesslyWidget; it
/// returns null to fall back to the default UI.
typedef CodelesslyInboxLayoutBuilder =
    Widget? Function(BuildContext context, InboxLayoutRequest request);

/// What a Codelessly layout for the inbox binds to, and how it acts.
@immutable
class InboxLayoutRequest {
  const InboxLayoutRequest({
    required this.layoutId,
    required this.data,
    required this.inbox,
    this.card,
  });

  /// The layout to render.
  final String layoutId;

  /// The values the layout binds to. For a card layout:
  /// `{card: InboxCard.toValue(), inbox: InboxState.toValue()}`. For the
  /// inbox layout: `{cards: [card...], pinned: [card...], others: [card...],
  /// inbox: InboxState.toValue()}`.
  final Map<String, Object?> data;
  final CodelesslyInbox inbox;

  /// The card, for a card layout.
  final InboxCard? card;

  /// Runs a layout's inbox action; see [CodelesslyInbox.perform].
  Future<void> perform(
    String operation, [
    Map<String, Object?> params = const {},
    BuildContext? context,
  ]) => inbox.perform(operation, params);
}

/// A user's inbox of content cards, managed from the Codelessly editor.
///
/// ```dart
/// final inbox = CodelesslyInbox(host, openUrl: (uri) => launchUrl(uri));
/// CodelesslyInboxBadge(inbox: inbox, child: const Icon(Icons.inbox));
/// showCodelesslyInbox(context, inbox);
/// ```
///
/// Nothing here throws into the app: failures land in [state] as `error`,
/// and an unreachable backend leaves an empty, unavailable inbox.
class CodelesslyInbox {
  CodelesslyInbox(
    this.host, {
    this.openUrl,
    this.onCustomAction,
    this.onCardTap,
    this.pageSize = 20,
    this.flushDelay = const Duration(seconds: 1),
    bool autoRefresh = true,
  }) {
    _identityKey = host.identity.id;
    _identitySub = host.identityChanges.listen(_onIdentity);
    _restoreCache();
    if (autoRefresh) unawaited(refresh());
  }

  /// The core this inbox runs on.
  final EngageHost host;

  /// Opens URLs and deep links from cards. Without it, URL taps are only
  /// logged (and handed to [onCardTap]).
  InboxUrlOpener? openUrl;

  /// Receives custom action keys.
  InboxCustomActionHandler? onCustomAction;

  /// Sees every tap first; return true to skip the default handling.
  InboxCardTapHandler? onCardTap;

  /// Cards per page fetched from the server (1 to 50).
  final int pageSize;

  /// How long read, click, dismiss and impression changes wait to be sent
  /// together. [Duration.zero] sends at once.
  final Duration flushDelay;

  /// Renders Codelessly layouts for the inbox; set by the SDK's core.
  static CodelesslyInboxLayoutBuilder? layoutBuilder;

  static const _endpointList = 'inbox/list';
  static const _endpointTrack = 'inbox/track';
  static const _endpointReadAll = 'inbox/readAll';

  final _state = ValueNotifier<InboxState>(const InboxState());
  final _unread = ValueNotifier<int>(0);
  final _cards = StreamController<List<InboxCard>>.broadcast();
  late final StreamSubscription<EngageIdentity> _identitySub;

  late String _identityKey;
  InboxConfig _config = const InboxConfig();
  List<InboxCard> _all = const [];
  List<InboxCard> _controls = const [];
  String? _token;
  String? _nextCursor;
  int _serverUnread = 0;
  DateTime? _fetchedAt;
  DateTime? _lastAttempt;
  Future<void>? _refreshing;
  int _generation = 0;
  bool _disposed = false;

  /// Changes not yet sent: `{cardId, op, actionId?}`.
  List<Map<String, Object?>> _pending = [];
  Timer? _flushTimer;
  Future<void>? _flushing;
  final Set<String> _impressed = {};

  /// The inbox now: cards, unread count, loading and error.
  ValueListenable<InboxState> get state => _state;

  /// The unread count, for badges.
  ValueListenable<int> get unreadCount => _unread;

  /// The visible cards each time they change.
  Stream<List<InboxCard>> get cards => _cards.stream;

  /// The visible cards now.
  List<InboxCard> get currentCards => _state.value.cards;

  /// The remotely managed configuration (refresh rules and UI).
  InboxConfig get config => _config;

  String get _cacheKey => 'inbox.cache.${host.projectId}.$_identityKey';
  String get _pendingKey => 'inbox.pending.${host.projectId}.$_identityKey';

  // ---------------------------------------------------------------- loading

  /// Fetches the user's cards. Without [force], does nothing while the
  /// cards are younger than the configured refresh interval. Forced or not,
  /// it never runs more often than the configured minimum interval.
  Future<void> refresh({bool force = false}) {
    if (_disposed) return Future.value();
    final running = _refreshing;
    if (running != null) return running;
    final now = host.now();
    final fetched = _fetchedAt;
    if (!force &&
        fetched != null &&
        now.difference(fetched) < _config.refreshInterval) {
      return Future.value();
    }
    final attempt = _lastAttempt;
    if (attempt != null &&
        now.difference(attempt) < _config.minRefreshInterval) {
      return Future.value();
    }
    _lastAttempt = now;
    final future = _refresh().whenComplete(() => _refreshing = null);
    return _refreshing = future;
  }

  Future<void> _refresh() async {
    final generation = _generation;
    _emit(_state.value.copyWith(loading: true));
    try {
      await _flush();
      if (generation != _generation) return;
      final response = await host.call(_endpointList, {
        'limit': pageSize,
        if (_token != null && _all.length <= pageSize) 'since': _token,
      });
      if (generation != _generation || _disposed) return;
      _config = InboxConfig.fromJson(response['config']);
      _serverUnread = (response['unreadCount'] as num?)?.toInt() ?? 0;
      _token = response['token'] as String?;
      _fetchedAt = host.now();
      if (response['notModified'] != true) {
        final all = _parseCards(response['cards']);
        _all = [
          for (final c in all)
            if (!c.isControl) c,
        ];
        _controls = [
          for (final c in all)
            if (c.isControl) c,
        ];
        _nextCursor = response['nextCursor'] as String?;
        // Changes still queued (the send failed) win over the server.
        final read = {
          for (final p in _pending)
            if (p['op'] == 'read' || p['op'] == 'click') p['cardId'],
        };
        _all = [
          for (final c in _all)
            read.contains(c.id) && !c.read ? c.copyWith(read: true) : c,
        ];
      }
      _emit(
        _state.value.copyWith(
          loading: false,
          available: true,
          fromCache: false,
          clearError: true,
          lastUpdated: _fetchedAt,
        ),
      );
      await _saveCache();
    } on EngageUnavailable catch (e) {
      if (generation != _generation) return;
      _emit(
        _state.value.copyWith(
          loading: false,
          available: _all.isNotEmpty || _state.value.fromCache,
          error: e.message,
        ),
      );
    } catch (e) {
      if (generation != _generation) return;
      _emit(_state.value.copyWith(loading: false, error: '$e'));
    }
  }

  /// Loads the next page of cards, when [InboxState.hasMore].
  Future<void> loadMore() async {
    final cursor = _nextCursor;
    if (_disposed || cursor == null || _state.value.loadingMore) return;
    final generation = _generation;
    _emit(_state.value.copyWith(loadingMore: true));
    try {
      final response = await host.call(_endpointList, {
        'limit': pageSize,
        'cursor': cursor,
      });
      if (generation != _generation || _disposed) return;
      final more = _parseCards(response['cards']);
      final seen = {for (final c in _all) c.id};
      _all = [
        ..._all,
        for (final c in more)
          if (!c.isControl && !seen.contains(c.id)) c,
      ];
      _controls = [..._controls, ...more.where((c) => c.isControl)];
      _nextCursor = response['nextCursor'] as String?;
      _serverUnread =
          (response['unreadCount'] as num?)?.toInt() ?? _serverUnread;
      _emit(_state.value.copyWith(loadingMore: false, clearError: true));
    } catch (e) {
      if (generation != _generation) return;
      _emit(
        _state.value.copyWith(
          loadingMore: false,
          error: e is EngageUnavailable ? e.message : '$e',
        ),
      );
    }
  }

  List<InboxCard> _parseCards(Object? json) => [
    if (json is List)
      for (final c in json) ?InboxCard.fromJson(c),
  ];

  // ------------------------------------------------------------ user state

  /// Marks [card] read.
  Future<void> markRead(InboxCard card) => _guard(() {
    final current = _find(card.id);
    if (current == null || current.read) return;
    _replace(current.copyWith(read: true));
    _track('inbox_card_read', card);
    _queue(card.id, 'read');
  });

  /// Marks [card] unread again.
  Future<void> markUnread(InboxCard card) => _guard(() {
    final current = _find(card.id);
    if (current == null || !current.read) return;
    _replace(current.copyWith(read: false));
    _queue(card.id, 'unread');
  });

  /// Marks every card read.
  Future<void> markAllRead() => _guard(() async {
    final unread = _all.where((c) => !c.read).length;
    if (unread == 0 && _unread.value == 0) return;
    _all = [for (final c in _all) c.read ? c : c.copyWith(read: true)];
    _pending.removeWhere((p) => p['op'] == 'unread');
    _serverUnread = 0;
    _emit(_state.value);
    _safeTrack('inbox_all_read', {'count': unread});
    try {
      final response = await host.call(_endpointReadAll);
      _serverUnread = (response['unreadCount'] as num?)?.toInt() ?? 0;
      _emit(_state.value);
    } catch (_) {
      // Offline: send each card's read later.
      for (final c in _all) {
        _pending.add({'cardId': c.id, 'op': 'read'});
      }
      _schedule();
    }
    await _saveCache();
  });

  /// Removes [card] from the inbox, when it is dismissible.
  Future<void> dismiss(InboxCard card) => _guard(() {
    final current = _find(card.id);
    if (current == null || !current.dismissible) return;
    _all = [
      for (final c in _all)
        if (c.id != card.id) c,
    ];
    if (!current.read) _serverUnread = (_serverUnread - 1).clamp(0, 1 << 30);
    _emit(_state.value);
    _track('inbox_card_dismissed', current);
    _queue(card.id, 'dismiss');
  });

  /// Logs that [card] was seen; once per card per session. The default UI
  /// calls it as cards scroll into view.
  void logImpression(InboxCard card) {
    if (_disposed || !_impressed.add(card.id)) return;
    _track(
      card.isControl ? 'inbox_control_impression' : 'inbox_card_impression',
      card,
    );
    _queue(card.id, 'impression');
  }

  /// Logs a tap on [card] (or its [action]) and marks it read. The default
  /// UI calls it through [handleTap].
  void logClick(InboxCard card, [InboxAction? action]) {
    if (_disposed) return;
    final current = _find(card.id) ?? card;
    if (!current.read) {
      _replace(current.copyWith(read: true, clicked: true));
    } else if (!current.clicked) {
      _replace(current.copyWith(clicked: true));
    }
    _track('inbox_card_clicked', card, {
      'action_id': ?action?.id,
      'action_kind': ?action?.kind.name,
    });
    _queue(card.id, 'click', action?.id);
  }

  /// Logs that the inbox was shown, and the impressions of control cards
  /// (holdouts the user would have seen). The default UI calls it.
  void opened() {
    if (_disposed) return;
    _safeTrack('inbox_opened', {
      'unread_count': _unread.value,
      'card_count': _state.value.cards.length,
    });
    for (final c in _controls) {
      logImpression(c);
    }
  }

  /// Handles a tap on [card] or one of its buttons: logs the click, asks
  /// [onCardTap] (the view's callback first, then the inbox's), then by
  /// default opens URLs through [openUrl], hands custom keys to
  /// [onCustomAction], and dismisses for dismiss actions.
  Future<void> handleTap(
    InboxCard card, {
    InboxAction? action,
    InboxCardTapHandler? onTap,
  }) => _guard(() async {
    final act = action ?? card.tap;
    if (act?.kind != InboxActionKind.dismiss) logClick(card, act);
    final tap = InboxCardTap(card, act);
    for (final handler in [onTap, onCardTap]) {
      if (handler != null && await handler(tap) == true) return;
    }
    if (act == null) return;
    switch (act.kind) {
      case InboxActionKind.url:
      case InboxActionKind.deeplink:
        final uri = act.uri;
        if (uri != null) await openUrl?.call(uri);
      case InboxActionKind.custom:
        await onCustomAction?.call(act.value, card);
      case InboxActionKind.dismiss:
        await dismiss(card);
    }
  });

  /// Runs an inbox operation by name, for Codelessly layouts' actions:
  /// `click` {cardId, actionId?}, `dismiss` {cardId}, `read` {cardId},
  /// `unread` {cardId}, `impression` {cardId}, `readAll`, `refresh`,
  /// `loadMore`.
  Future<void> perform(
    String operation, [
    Map<String, Object?> params = const {},
  ]) => _guard(() async {
    final card = _find(params['cardId']?.toString() ?? '');
    switch (operation) {
      case 'refresh':
        return refresh(force: true);
      case 'loadMore':
        return loadMore();
      case 'readAll':
        return markAllRead();
    }
    if (card == null) return;
    switch (operation) {
      case 'click':
        final id = params['actionId']?.toString();
        final action = id == null
            ? null
            : [...card.actions, ?card.tap].where((a) => a.id == id).firstOrNull;
        return handleTap(card, action: action);
      case 'dismiss':
        return dismiss(card);
      case 'read':
        return markRead(card);
      case 'unread':
        return markUnread(card);
      case 'impression':
        return logImpression(card);
    }
  });

  InboxCard? _find(String id) =>
      _all.where((c) => c.id == id).firstOrNull ??
      _controls.where((c) => c.id == id).firstOrNull;

  void _replace(InboxCard card) {
    final before = _find(card.id);
    if (before != null && before.read != card.read) {
      _serverUnread = (_serverUnread + (card.read ? -1 : 1)).clamp(0, 1 << 30);
    }
    _all = [for (final c in _all) c.id == card.id ? card : c];
    _emit(_state.value);
  }

  // ------------------------------------------------------- sending changes

  void _queue(String cardId, String op, [String? actionId]) {
    _pending.add({'cardId': cardId, 'op': op, 'actionId': ?actionId});
    _schedule();
    unawaited(_saveCache());
  }

  void _schedule() {
    if (_disposed) return;
    if (flushDelay == Duration.zero) {
      unawaited(_flush());
      return;
    }
    _flushTimer ??= Timer(flushDelay, () {
      _flushTimer = null;
      unawaited(_flush());
    });
  }

  /// Sends queued changes now. Safe to call any time; failures keep them
  /// queued for the next refresh.
  Future<void> flush() => _flush();

  Future<void> _flush() {
    final running = _flushing;
    if (running != null) return running.then((_) => _flush());
    if (_pending.isEmpty || _disposed) return Future.value();
    final future = _send().whenComplete(() => _flushing = null);
    return _flushing = future;
  }

  Future<void> _send() async {
    final generation = _generation;
    final batch = _pending.take(50).toList();
    try {
      final response = await host.call(_endpointTrack, {'events': batch});
      if (generation != _generation) return;
      _pending = _pending.skip(batch.length).toList();
      final unread = (response['unreadCount'] as num?)?.toInt();
      if (unread != null) _serverUnread = unread;
      _token = response['token'] as String? ?? _token;
      _emit(_state.value);
      await _saveCache();
      if (_pending.isNotEmpty) await _send();
    } catch (_) {
      // Offline or refused: keep the queue for later.
    }
  }

  // ---------------------------------------------------------------- state

  void _emit(InboxState base) {
    if (_disposed) return;
    final now = host.now();
    final hidden = {
      for (final p in _pending)
        if (p['op'] == 'dismiss') p['cardId'],
    };
    final visible = [
      for (final c in _all)
        if (!c.expiredAt(now) && !hidden.contains(c.id)) c,
    ];
    // All cards known: count them; otherwise trust the server's count.
    final unread = _nextCursor == null && (_fetchedAt != null || base.fromCache)
        ? visible.where((c) => !c.read).length
        : _serverUnread;
    final next = base.copyWith(
      cards: visible,
      unreadCount: unread,
      hasMore: _nextCursor != null,
    );
    final changed = !listEquals(next.cards, _state.value.cards);
    _state.value = next;
    _unread.value = unread;
    if (changed && !_cards.isClosed) _cards.add(visible);
  }

  void _track(
    String name,
    InboxCard card, [
    Map<String, Object?> extra = const {},
  ]) => _safeTrack(name, {
    'card_id': card.id,
    'card_type': card.type.name,
    if (card.category.isNotEmpty) 'category': card.category,
    'pinned': card.pinned,
    ...extra,
  });

  void _safeTrack(String name, Map<String, Object?> properties) {
    try {
      host.track(name, properties);
    } catch (_) {}
  }

  Future<void> _guard(FutureOr<void> Function() body) async {
    if (_disposed) return;
    try {
      await body();
    } catch (e) {
      if (!_disposed) _emit(_state.value.copyWith(error: '$e'));
    }
  }

  // ---------------------------------------------------------------- cache

  void _restoreCache() {
    try {
      final cached = host.storage.get(_cacheKey);
      final pending = host.storage.get(_pendingKey);
      if (pending is List) {
        _pending = [
          for (final p in pending)
            if (p is Map) Map<String, Object?>.from(p),
        ];
      }
      if (cached is! Map) return;
      _config = InboxConfig.fromJson(cached['config']);
      final all = _parseCards(cached['cards']);
      _all = [
        for (final c in all)
          if (!c.isControl) c,
      ];
      _controls = [
        for (final c in all)
          if (c.isControl) c,
      ];
      _token = cached['token'] as String?;
      _serverUnread = (cached['unreadCount'] as num?)?.toInt() ?? 0;
      _nextCursor = cached['nextCursor'] as String?;
      final fetched = DateTime.tryParse('${cached['fetchedAt']}');
      _fetchedAt = fetched;
      _emit(_state.value.copyWith(fromCache: true, lastUpdated: fetched));
      if (_pending.isNotEmpty) _schedule();
    } catch (_) {
      // A broken cache is no cache.
    }
  }

  Future<void> _saveCache() async {
    if (_disposed) return;
    try {
      await host.storage.put(_cacheKey, {
        'cards': [
          for (final c in [..._all, ..._controls]) c.toJson(),
        ],
        'config': _config.raw,
        'token': _token,
        'unreadCount': _serverUnread,
        'nextCursor': _nextCursor,
        'fetchedAt': _fetchedAt?.toUtc().toIso8601String(),
      });
      if (_pending.isEmpty) {
        await host.storage.remove(_pendingKey);
      } else {
        await host.storage.put(_pendingKey, _pending);
      }
    } catch (_) {}
  }

  /// A new user: forget everything about the previous one, on screen and
  /// on the device, then load the new user's inbox.
  void _onIdentity(EngageIdentity identity) {
    if (_disposed || identity.id == _identityKey) return;
    final oldCache = _cacheKey;
    final oldPending = _pendingKey;
    _generation++;
    _identityKey = identity.id;
    _flushTimer?.cancel();
    _flushTimer = null;
    _flushing = null;
    _refreshing = null;
    _all = const [];
    _controls = const [];
    _pending = [];
    _token = null;
    _nextCursor = null;
    _serverUnread = 0;
    _fetchedAt = null;
    _lastAttempt = null;
    _impressed.clear();
    _state.value = const InboxState();
    _unread.value = 0;
    if (!_cards.isClosed) _cards.add(const []);
    unawaited(() async {
      try {
        await host.storage.remove(oldCache);
        await host.storage.remove(oldPending);
      } catch (_) {}
    }());
    _restoreCache();
    unawaited(refresh());
  }

  /// Stops listening and cancels pending work. Unsent changes stay in the
  /// device cache and are sent by the next inbox for the same user.
  void dispose() {
    if (_disposed) return;
    _flushTimer?.cancel();
    unawaited(_saveCache());
    _disposed = true;
    unawaited(_identitySub.cancel());
    unawaited(_cards.close());
    _state.dispose();
    _unread.dispose();
  }
}
