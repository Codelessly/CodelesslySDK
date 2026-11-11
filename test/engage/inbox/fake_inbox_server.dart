// An in-memory stand-in for the inbox backend (inbox/list, inbox/track,
// inbox/readAll), per identity, for the SDK's tests.
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_sdk/src/engage/host.dart';

class FakeInboxServer {
  FakeInboxServer(this.host);

  final MemoryEngageHost host;

  /// Cards per user id, as the server would compute them.
  final Map<String, List<Map<String, Object?>>> cards = {};
  Map<String, Object?> config = {
    'refreshIntervalSeconds': 300,
    'minRefreshSeconds': 10,
    'ui': <String, Object?>{},
    'version': 0,
  };

  /// Events received by inbox/track, per user.
  final Map<String, List<Map<String, Object?>>> tracked = {};

  /// When set, every call fails with it.
  Object? failWith;

  /// When set, inbox/list waits for it.
  Completer<void>? gate;

  void install() {
    host.handlers['inbox/list'] = _list;
    host.handlers['inbox/track'] = _track;
    host.handlers['inbox/readAll'] = _readAll;
  }

  List<Map<String, Object?>> _mine(String id) =>
      cards.putIfAbsent(id, () => []);

  List<Map<String, Object?>> _visible(String id) =>
      _mine(id).where((c) => c['dismissed'] != true).toList();

  String _token(String id) =>
      jsonEncode([config, _visible(id)]).hashCode.toRadixString(16);

  int _unread(String id) => _visible(
    id,
  ).where((c) => c['read'] != true && c['type'] != 'control').length;

  Future<Map<String, Object?>> _list(Map<String, Object?> body) async {
    final id = host.identity.id;
    final gate = this.gate;
    if (gate != null) await gate.future;
    if (failWith != null) throw failWith!;
    final token = _token(id);
    final base = {'unreadCount': _unread(id), 'token': token, 'config': config};
    if (body['since'] == token && body['cursor'] == null) {
      return {...base, 'notModified': true};
    }
    final limit = (body['limit'] as int?) ?? 20;
    final offset = int.tryParse('${body['cursor'] ?? 0}') ?? 0;
    final all = _visible(id);
    final page = all.skip(offset).take(limit).toList();
    return {
      ...base,
      'notModified': false,
      'cards': [
        for (final c in page) {...c}..remove('dismissed'),
      ],
      'nextCursor': offset + limit < all.length ? '${offset + limit}' : null,
    };
  }

  Future<Map<String, Object?>> _track(Map<String, Object?> body) async {
    if (failWith != null) throw failWith!;
    final id = host.identity.id;
    final events = (body['events'] as List).cast<Map<String, Object?>>();
    tracked.putIfAbsent(id, () => []).addAll(events);
    for (final e in events) {
      final card = _mine(id).where((c) => c['id'] == e['cardId']).firstOrNull;
      if (card == null) continue;
      switch (e['op']) {
        case 'read' || 'click':
          card['read'] = true;
        case 'unread':
          card['read'] = false;
        case 'dismiss':
          card['dismissed'] = true;
      }
    }
    return {'unreadCount': _unread(id), 'token': _token(id)};
  }

  Future<Map<String, Object?>> _readAll(Map<String, Object?> body) async {
    if (failWith != null) throw failWith!;
    final id = host.identity.id;
    for (final c in _mine(id)) {
      c['read'] = true;
    }
    return {'marked': 1, 'unreadCount': 0, 'token': _token(id)};
  }
}

Map<String, Object?> card(
  String id, {
  String type = 'classic',
  String title = 'Title',
  String body = 'Body',
  bool pinned = false,
  bool read = false,
  bool dismissible = true,
  String imageUrl = '',
  String category = '',
  Map<String, Object?>? tap,
  List<Map<String, Object?>> actions = const [],
  String? expiresAt,
  String layoutId = '',
}) => {
  'id': id,
  'type': type,
  'title': title,
  'body': body,
  'imageUrl': imageUrl,
  'imageAspectRatio': 2,
  'tap': tap,
  'actions': actions,
  'pinned': pinned,
  'dismissible': dismissible,
  'priority': 0,
  'category': category,
  'tags': <String>[],
  'extras': {'sku': 'a1'},
  'layoutId': layoutId,
  'sentAt': '2025-12-31T12:00:00.000Z',
  'expiresAt': expiresAt,
  'read': read,
  'clicked': false,
  'version': 1,
};
