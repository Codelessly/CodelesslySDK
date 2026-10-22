// Firestore marks its snapshots @sealed; these test fakes stand in for them.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Doc extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Doc(this.id, this._data);

  @override
  final String id;
  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic> data() => _data;
}

class _Snapshot extends Fake
    implements FirestoreQueryBuilderSnapshot<Map<String, dynamic>> {
  _Snapshot({this.count = 0, this.isFetching = false, this.hasMore = false});

  final int count;
  int fetchMoreCalls = 0;

  @override
  final bool isFetching;

  @override
  final bool hasMore;

  @override
  bool get isFetchingMore => false;

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [
    for (int i = 0; i < count; i++) _Doc('d$i', {'title': 'Task $i'}),
  ];

  @override
  void fetchMore() => fetchMoreCalls++;
}

void main() {
  group('showMorePage', () {
    test('a query finished in the app reveals a page at a time', () {
      expect(showMorePage(loaded: 45, revealed: 20, hasMoreToFetch: false), (
        shown: 20,
        remaining: 25,
        hasMore: true,
      ));
      expect(showMorePage(loaded: 45, revealed: 60, hasMoreToFetch: false), (
        shown: 45,
        remaining: 0,
        hasMore: false,
      ));
    });

    test('a server-paged query counts what is left from the total', () {
      expect(
        showMorePage(loaded: 20, revealed: 20, hasMoreToFetch: true, total: 52),
        (shown: 20, remaining: 32, hasMore: true),
      );
      // Not counted yet: the button shows without a number.
      expect(showMorePage(loaded: 20, revealed: 20, hasMoreToFetch: true), (
        shown: 20,
        remaining: null,
        hasMore: true,
      ));
    });

    test('labels', () {
      expect(showMoreLabel(32), 'Show more · 32 remaining');
      expect(showMoreLabel(null), 'Show more');
    });
  });

  group('CloudListItems', () {
    test('scroll paging shows every document and loads more at the end', () {
      final snapshot = _Snapshot(count: 3, hasMore: true);
      final items = CloudListItems(
        snapshot: snapshot,
        paging: QueryPaging.scroll,
      );
      expect(items.itemCount, 3);
      expect(items.hasButton, isFalse);
      expect(items.dataAt(1), {'id': 'd1', 'title': 'Task 1'});
      items.onItemBuilt(1);
      expect(snapshot.fetchMoreCalls, 0);
      items.onItemBuilt(2);
      expect(snapshot.fetchMoreCalls, 1);
    });

    test('button paging shows a page and a button after it', () {
      final snapshot = _Snapshot(count: 5, hasMore: true);
      int reveals = 0;
      final items = CloudListItems(
        snapshot: snapshot,
        paging: QueryPaging.button,
        revealed: 5,
        total: 12,
        revealMore: () => reveals++,
      );
      expect(items.dataCount, 5);
      expect(items.itemCount, 6);
      expect(items.isButton(5), isTrue);
      // Scrolling to the end does not load more.
      items.onItemBuilt(4);
      expect(snapshot.fetchMoreCalls, 0);
    });

    test('a skeleton shows sample items with no data', () {
      final items = CloudListItems(
        snapshot: _Snapshot(isFetching: true),
        paging: QueryPaging.button,
        skeleton: true,
      );
      expect(items.itemCount, kSkeletonItemCount);
      expect(items.dataAt(0), isEmpty);
      expect(items.hasButton, isFalse);
    });
  });

  testWidgets('the button fetches the next page when all loaded show', (
    tester,
  ) async {
    final snapshot = _Snapshot(count: 2, hasMore: true);
    late CloudListItems items;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: ShowMorePager(
            pageSize: 2,
            builder: (context, revealed, revealMore) {
              items = CloudListItems(
                snapshot: snapshot,
                paging: QueryPaging.button,
                revealed: revealed,
                total: 7,
                revealMore: revealMore,
              );
              return items.buildButton();
            },
          ),
        ),
      ),
    );
    expect(find.text('Show more · 5 remaining'), findsOneWidget);
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(snapshot.fetchMoreCalls, 1);
    expect(items.revealed, 4);
  });
}
