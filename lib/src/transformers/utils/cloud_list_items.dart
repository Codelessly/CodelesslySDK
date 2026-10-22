import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';
import 'package:flutter/widgets.dart';

import '../../ui/show_more.dart';
import '../../ui/skeleton.dart';

/// The items a cloud list or grid shows for a query [snapshot], one rule for
/// both:
///
/// * In a loading skeleton ([SkeletonScope]) it shows
///   [kSkeletonItemCount] sample items with no data while the first page
///   loads, so the skeleton has something to shimmer.
/// * With [QueryPaging.scroll] it shows every loaded document and loads the
///   next page when the last one is built.
/// * With [QueryPaging.button] it shows the first [revealed] documents and a
///   "Show more" button after them.
class CloudListItems {
  /// The query result.
  final FirestoreQueryBuilderSnapshot<Map<String, dynamic>> snapshot;

  /// How the list pages.
  final QueryPaging paging;

  /// How many documents a "Show more" list has revealed.
  final int revealed;

  /// All documents the query matches, when counted.
  final int? total;

  /// Whether the items are sample items for a skeleton.
  final bool skeleton;

  /// Reveals the next page of a "Show more" list.
  final VoidCallback? revealMore;

  late final ShowMorePage _page = showMorePage(
    loaded: snapshot.docs.length,
    revealed: paging == QueryPaging.button ? revealed : snapshot.docs.length,
    hasMoreToFetch: snapshot.hasMore,
    total: total,
  );

  CloudListItems({
    required this.snapshot,
    required this.paging,
    this.revealed = 0,
    this.total,
    this.skeleton = false,
    this.revealMore,
  });

  /// Whether a skeleton shows sample items for [snapshot].
  static bool showsSkeleton(
    BuildContext context,
    FirestoreQueryBuilderSnapshot snapshot,
  ) => snapshot.isFetching && SkeletonScope.of(context);

  /// How many items show data (documents, or skeleton samples).
  int get dataCount => skeleton ? kSkeletonItemCount : _page.shown;

  /// Whether a "Show more" button follows the items.
  bool get hasButton =>
      !skeleton && paging == QueryPaging.button && _page.hasMore;

  /// How many items the list builds, the button included.
  int get itemCount => dataCount + (hasButton ? 1 : 0);

  /// Whether [index] is the "Show more" button.
  bool isButton(int index) => hasButton && index == dataCount;

  /// The data of the item at [index]: its document's fields and `id`, or an
  /// empty map for a skeleton sample.
  Map<String, dynamic> dataAt(int index) {
    if (skeleton) return const {};
    final QueryDocumentSnapshot<Map<String, dynamic>>? doc = snapshot.docs
        .elementAtOrNull(index);
    return {'id': ?doc?.id, ...?doc?.data()};
  }

  /// Called when the item at [index] is built: a list that pages on scroll
  /// loads the next page when its last item shows.
  void onItemBuilt(int index) {
    if (skeleton || paging != QueryPaging.scroll) return;
    if (index == dataCount - 1 &&
        snapshot.hasMore &&
        !snapshot.isFetchingMore) {
      snapshot.fetchMore();
    }
  }

  /// The "Show more" button.
  Widget buildButton() => ShowMoreButton(
    remaining: _page.remaining,
    loading: snapshot.isFetchingMore,
    onPressed: () {
      // Everything loaded is shown: fetch the next page first.
      if (revealed >= snapshot.docs.length &&
          snapshot.hasMore &&
          !snapshot.isFetchingMore) {
        snapshot.fetchMore();
      }
      revealMore?.call();
    },
  );
}
