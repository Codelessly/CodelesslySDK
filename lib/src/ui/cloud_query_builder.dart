import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';
import 'package:flutter/widgets.dart';

import '../data/cloud_query.dart';
import '../logging/debug_logger.dart';

/// Builds a widget from a cloud [query] on [ref], the way
/// [FirestoreQueryBuilder] does, without needing composite indexes.
///
/// Queries Firestore can run as is page through [FirestoreQueryBuilder].
/// Queries that need a composite index (see [CloudQuery.plan]) stream their
/// index-free part and are filtered, sorted and limited in the app; so do
/// queries Firestore reports a missing index for anyway. Either way
/// [builder] gets a [FirestoreQueryBuilderSnapshot].
class CloudQueryBuilder extends StatefulWidget {
  /// The collection the query runs on.
  final Query<Map<String, dynamic>> ref;

  /// The query.
  final CloudQuery query;

  /// How many documents a page of a server-run query holds.
  final int pageSize;

  /// Builds the result.
  final FirestoreQueryBuilderSnapshotBuilder<Map<String, dynamic>> builder;

  /// Whether to count all documents the query matches, for a "Show more"
  /// button that says how many are left. [CloudQueryTotal.of] reads it.
  final bool countTotal;

  /// The keys of the composite indexes the collection has: a query needing
  /// one of them runs and pages in Firestore. See [CloudQuery.plan].
  final Set<String> readyIndexes;

  /// Creates a [CloudQueryBuilder].
  const CloudQueryBuilder({
    super.key,
    required this.ref,
    required this.query,
    required this.pageSize,
    required this.builder,
    this.countTotal = false,
    this.readyIndexes = const {},
  });

  @override
  State<CloudQueryBuilder> createState() => _CloudQueryBuilderState();
}

class _CloudQueryBuilderState extends State<CloudQueryBuilder> {
  /// Set once Firestore reported a missing index for the server-run plan.
  bool _forceClient = false;

  Query<Map<String, dynamic>>? _streamedQuery;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  _ClientSnapshot _snapshot = const _ClientSnapshot.fetching();

  CloudQueryPlan get _plan => widget.query.plan(
    forceClient: _forceClient,
    readyIndexes: widget.readyIndexes,
  );

  Query<Map<String, dynamic>>? _countedQuery;
  int? _total;

  /// Counts the documents [query] matches once, when asked to.
  void _count(Query<Map<String, dynamic>> query) {
    if (!widget.countTotal || query == _countedQuery) return;
    _countedQuery = query;
    _total = null;
    query
        .count()
        .get()
        .then((snapshot) {
          if (mounted && query == _countedQuery) {
            setState(() => _total = snapshot.count);
          }
        })
        .catchError((Object error) {
          DebugLogger.instance.printInfo(
            'Could not count the query: ${describeCloudError(error)}',
            name: 'CloudQueryBuilder',
          );
        });
  }

  @override
  void didUpdateWidget(covariant CloudQueryBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query || oldWidget.ref != widget.ref) {
      _forceClient = false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Follows [query], keeping the current subscription while it's the same.
  void _stream(Query<Map<String, dynamic>> query) {
    if (query == _streamedQuery) return;
    _subscription?.cancel();
    _streamedQuery = query;
    _snapshot = _snapshot.refetching();
    _subscription = query.snapshots().listen(
      (snapshot) {
        if (mounted) setState(() => _snapshot = _ClientSnapshot.data(snapshot));
      },
      onError: (Object error, StackTrace stackTrace) {
        DebugLogger.instance.printInfo(
          'Cloud query failed: ${describeCloudError(error)}',
          name: 'CloudQueryBuilder',
        );
        if (mounted) {
          setState(() => _snapshot = _snapshot.failed(error, stackTrace));
        }
      },
    );
  }

  void _stopStreaming() {
    _subscription?.cancel();
    _subscription = null;
    _streamedQuery = null;
    _snapshot = const _ClientSnapshot.fetching();
  }

  @override
  Widget build(BuildContext context) {
    final CloudQueryPlan plan = _plan;
    if (!plan.runsOnClient) {
      _stopStreaming();
      _count(plan.applyTo(widget.ref));
      return CloudQueryTotal(
        total: _total,
        child: FirestoreQueryBuilder<Map<String, dynamic>>(
          query: plan.applyTo(widget.ref),
          pageSize: widget.pageSize,
          builder: (context, snapshot, child) {
            if (snapshot.hasError && isMissingIndexError(snapshot.error)) {
              DebugLogger.instance.printInfo(
                'Query needs an index Firestore does not have; running it in '
                'the app. ${describeCloudError(snapshot.error)}',
                name: 'CloudQueryBuilder',
              );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _forceClient = true);
              });
              return widget.builder(
                context,
                const _ClientSnapshot.fetching(),
                child,
              );
            }
            return widget.builder(context, snapshot, child);
          },
        ),
      );
    }

    _stream(plan.applyTo(widget.ref));
    // A query the app finishes arrives whole: what it shows is the total.
    return CloudQueryTotal(
      total: null,
      child: widget.builder(context, _snapshot.finishedBy(plan), null),
    );
  }
}

/// The number of documents a [CloudQueryBuilder] counted for its query,
/// when it was asked to and the count has arrived.
class CloudQueryTotal extends InheritedWidget {
  /// The count, or null.
  final int? total;

  const CloudQueryTotal({super.key, required this.total, required super.child});

  /// The count for the query around [context], or null.
  static int? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CloudQueryTotal>()?.total;

  @override
  bool updateShouldNotify(CloudQueryTotal oldWidget) =>
      total != oldWidget.total;
}

/// A [FirestoreQueryBuilderSnapshot] of a query the app finishes: everything
/// arrives at once, so there's never more to fetch.
class _ClientSnapshot
    implements FirestoreQueryBuilderSnapshot<Map<String, dynamic>> {
  const _ClientSnapshot._({
    required this.docs,
    required this.hasData,
    required this.isFetching,
    this.error,
    this.stackTrace,
  });

  const _ClientSnapshot.fetching()
    : this._(docs: const [], hasData: false, isFetching: true);

  _ClientSnapshot.data(QuerySnapshot<Map<String, dynamic>> snapshot)
    : this._(docs: snapshot.docs, hasData: true, isFetching: false);

  _ClientSnapshot refetching() =>
      _ClientSnapshot._(docs: docs, hasData: hasData, isFetching: true);

  _ClientSnapshot failed(Object error, StackTrace stackTrace) =>
      _ClientSnapshot._(
        docs: docs,
        hasData: hasData,
        isFetching: false,
        error: error,
        stackTrace: stackTrace,
      );

  /// This snapshot with [plan]'s app-side filters, sort and limit applied.
  _ClientSnapshot finishedBy(CloudQueryPlan plan) => _ClientSnapshot._(
    docs: plan.finish(docs, data: (doc) => doc.data(), id: (doc) => doc.id),
    hasData: hasData,
    isFetching: isFetching,
    error: error,
    stackTrace: stackTrace,
  );

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  @override
  final bool hasData;

  @override
  final bool isFetching;

  @override
  final Object? error;

  @override
  final StackTrace? stackTrace;

  @override
  bool get hasError => error != null;

  @override
  bool get hasMore => false;

  @override
  bool get isFetchingMore => false;

  @override
  void fetchMore() {}
}
