// Live joins: documents of another collection attached to each document of
// a live query (a list of cards with each user's state of the card), read
// with a few `in` queries kept live, never one read or listener per item.
import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart' show Json, WhereOperator;

import 'database.dart';
import 'query.dart';

/// The most values one `in` filter takes (Firestore's limit).
const int kCloudInQueryLimit = 30;

/// One join of [watchJoined], its collection resolved.
class CloudJoinSpec {
  const CloudJoinSpec({
    required this.collection,
    required this.as,
    required this.keyOf,
    this.foreignField = '',
    this.many = false,
  });

  /// The app's collection path the matches are read from.
  final String collection;

  /// The field of each item that gets its match.
  final String as;

  /// An item's key: the value a matching document has in [foreignField];
  /// null or empty: the item has no match.
  final Object? Function(Json item) keyOf;

  /// The matching documents' field; empty: their id.
  final String foreignField;

  /// Every match, as a list, instead of the first.
  final bool many;
}

/// [items] (a live query's documents) with each [joins]' matches attached,
/// live: a change to an item or to a match emits again.
///
/// The matches are read with `in` queries of at most [chunkSize] keys
/// (each with the collection's rules applied by [db]), so N items mean
/// about N / [chunkSize] listeners per join. A new item's key joins the last
/// chunk with room (that chunk subscribes again); a chunk none of whose keys
/// are wanted any more is closed. The first value comes once every chunk
/// has answered.
Stream<List<Json>> watchJoined(CloudDatabase db, Stream<List<Json>> items, List<CloudJoinSpec> joins,
    {int chunkSize = kCloudInQueryLimit}) {
  if (joins.isEmpty) return items;
  late StreamController<List<Json>> controller;
  StreamSubscription<List<Json>>? base;
  List<Json>? current;
  final states = [for (final j in joins) _JoinState(db, j, chunkSize)];

  void emit() {
    final docs = current;
    if (docs == null || controller.isClosed) return;
    if (states.any((s) => !s.ready)) return;
    controller.add([
      for (final item in docs)
        {
          ...item,
          for (final s in states) s.join.as: s.matchFor(item),
        },
    ]);
  }

  void fail(Object error, StackTrace stack) {
    if (!controller.isClosed) controller.addError(error, stack);
  }

  controller = StreamController<List<Json>>(
    onListen: () {
      base = items.listen(
        (docs) {
          current = docs;
          for (final s in states) {
            s.update(docs, emit, fail);
          }
          emit();
        },
        onError: fail,
        onDone: () => controller.close(),
      );
    },
    onCancel: () async {
      for (final s in states) {
        s.close();
      }
      await base?.cancel();
    },
  );
  return controller.stream;
}

class _Chunk {
  _Chunk(this.keys);

  /// The keys it subscribed with, by their text.
  final Map<String, Object> keys;
  StreamSubscription<List<Json>>? sub;
  List<Json>? docs;
}

class _JoinState {
  _JoinState(this.db, this.join, this.chunkSize);

  final CloudDatabase db;
  final CloudJoinSpec join;
  final int chunkSize;
  final List<_Chunk> chunks = [];

  /// Match key text → the documents having it.
  Map<String, List<Json>> _matches = const {};

  bool get ready => chunks.every((c) => c.docs != null);

  static String? _text(Object? key) => switch (key) {
        null => null,
        final String s when s.trim().isEmpty => null,
        final String s => s.trim(),
        _ => '$key',
      };

  Object? matchFor(Json item) {
    final key = _text(join.keyOf(item));
    final found = key == null ? const <Json>[] : (_matches[key] ?? const <Json>[]);
    if (join.many) return found;
    return found.isEmpty ? null : found.first;
  }

  void update(List<Json> items, void Function() emit, void Function(Object, StackTrace) fail) {
    final wanted = <String, Object>{};
    for (final item in items) {
      final key = join.keyOf(item);
      final text = _text(key);
      if (text != null) wanted[text] = key is String ? key.trim() : key!;
    }
    // Chunks nobody needs any more close; the others keep their keys.
    for (final c in [...chunks]) {
      if (!c.keys.keys.any(wanted.containsKey)) {
        c.sub?.cancel();
        chunks.remove(c);
      }
    }
    final had = {for (final c in chunks) ...c.keys.keys};
    final added = [
      for (final e in wanted.entries)
        if (!had.contains(e.key)) e,
    ];
    if (added.isNotEmpty) {
      final dirty = <_Chunk>{};
      for (final e in added) {
        var chunk = chunks.isNotEmpty && chunks.last.keys.length < chunkSize ? chunks.last : null;
        if (chunk == null) {
          chunk = _Chunk({});
          chunks.add(chunk);
        }
        chunk.keys[e.key] = e.value;
        dirty.add(chunk);
      }
      for (final c in dirty) {
        _subscribe(c, emit, fail);
      }
    }
    _index();
  }

  void _subscribe(_Chunk c, void Function() emit, void Function(Object, StackTrace) fail) {
    c.sub?.cancel();
    c.docs = null;
    final field = join.foreignField.trim().isEmpty ? cloudDocumentIdField : join.foreignField.trim();
    final query = CloudQuery(filters: [CloudWhereFilter(field, WhereOperator.inArray, c.keys.values.toList())]);
    c.sub = db.watchQuery(join.collection, query).listen(
      (docs) {
        c.docs = docs;
        _index();
        emit();
      },
      onError: fail,
    );
  }

  void _index() {
    final field = join.foreignField.trim();
    final out = <String, List<Json>>{};
    for (final c in chunks) {
      for (final doc in c.docs ?? const <Json>[]) {
        final key = _text(field.isEmpty ? doc['id'] : readCloudField(doc, '${doc['id']}', field).$2);
        if (key != null) (out[key] ??= []).add(doc);
      }
    }
    _matches = out;
  }

  void close() {
    for (final c in chunks) {
      c.sub?.cancel();
    }
    chunks.clear();
  }
}
