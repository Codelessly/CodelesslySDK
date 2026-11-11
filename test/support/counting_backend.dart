// A document store that counts what it is asked: listeners open now and
// ever, one-shot reads and aggregates, by collection. For tests of what a
// live load costs.
import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';

class CountingBackend implements DocumentBackend {
  CountingBackend([MemoryDocumentBackend? inner]) : inner = inner ?? MemoryDocumentBackend();

  final MemoryDocumentBackend inner;

  /// Query listeners open now, by full collection path.
  final Map<String, int> listening = {};

  /// Query listeners ever opened, by full collection path.
  final Map<String, int> opened = {};

  /// One-shot queries and aggregates run, by full collection path.
  final Map<String, int> queries = {};
  final Map<String, int> aggregates = {};

  int get commits => inner.commits;

  int listeningOn(String collection) => listening[collection] ?? 0;

  void seed(String collection, Map<String, Map<String, Object?>> docs) => inner.seed(collection, docs);

  @override
  int get maxBatchWrites => inner.maxBatchWrites;

  @override
  Future<Map<String, Object?>?> get(String collection, String id) => inner.get(collection, id);

  @override
  Stream<Map<String, Object?>?> watch(String collection, String id) => inner.watch(collection, id);

  @override
  Future<List<CloudDocument>> query(String collection, CloudQuery query) {
    queries[collection] = (queries[collection] ?? 0) + 1;
    return inner.query(collection, query);
  }

  @override
  Stream<List<CloudDocument>> watchQuery(String collection, CloudQuery query) {
    late StreamController<List<CloudDocument>> controller;
    StreamSubscription<List<CloudDocument>>? sub;
    controller = StreamController(
      onListen: () {
        listening[collection] = listeningOn(collection) + 1;
        opened[collection] = (opened[collection] ?? 0) + 1;
        sub = inner.watchQuery(collection, query).listen(controller.add, onError: controller.addError);
      },
      onCancel: () {
        listening[collection] = listeningOn(collection) - 1;
        return sub?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<num?> aggregate(String collection, CloudQuery query, CloudAggregate operation, String field) {
    aggregates[collection] = (aggregates[collection] ?? 0) + 1;
    return inner.aggregate(collection, query, operation, field);
  }

  @override
  String newId(String collection) => inner.newId(collection);

  @override
  Future<void> commit(List<DocumentWrite> writes) => inner.commit(writes);
}
