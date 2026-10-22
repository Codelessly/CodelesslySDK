import 'package:flutter/material.dart';

/// What a list that pages with a "Show more" button shows.
typedef ShowMorePage = ({
  /// How many items are shown.
  int shown,

  /// How many items are left, when known.
  int? remaining,

  /// Whether the button shows.
  bool hasMore,
});

/// The page a "Show more" list shows: [revealed] items of the [loaded] ones,
/// and what is left of the [total] (all documents the query matches, when
/// counted) or of what [hasMoreToFetch] says Firestore still has.
ShowMorePage showMorePage({
  required int loaded,
  required int revealed,
  required bool hasMoreToFetch,
  int? total,
}) {
  final int shown = revealed < loaded ? revealed : loaded;
  final int? remaining = total != null
      ? (total - shown).clamp(0, total)
      : hasMoreToFetch
      ? null
      : loaded - shown;
  return (
    shown: shown,
    remaining: remaining,
    hasMore: shown < loaded || hasMoreToFetch || (remaining ?? 0) > 0,
  );
}

/// The label of the "Show more" button.
String showMoreLabel(int? remaining) => remaining == null || remaining <= 0
    ? 'Show more'
    : 'Show more · $remaining remaining';

/// The "Show more" button at the end of a list that pages with a button.
class ShowMoreButton extends StatelessWidget {
  /// How many items are left, when known.
  final int? remaining;

  /// Whether the next page is loading.
  final bool loading;

  /// Shows the next page.
  final VoidCallback onPressed;

  const ShowMoreButton({
    super.key,
    required this.remaining,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: TextButton(
          onPressed: loading ? null : onPressed,
          child: loading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(showMoreLabel(remaining)),
        ),
      ),
    );
  }
}

/// Keeps how many items a "Show more" list has revealed, across rebuilds of
/// its query results, and builds [builder] with it. Starts at [pageSize]
/// and grows by it each time the button is pressed.
class ShowMorePager extends StatefulWidget {
  /// Items revealed per press.
  final int pageSize;

  /// Builds the list with the number of items revealed and a callback that
  /// reveals the next page.
  final Widget Function(
    BuildContext context,
    int revealed,
    VoidCallback revealMore,
  )
  builder;

  const ShowMorePager({
    super.key,
    required this.pageSize,
    required this.builder,
  });

  @override
  State<ShowMorePager> createState() => _ShowMorePagerState();
}

class _ShowMorePagerState extends State<ShowMorePager> {
  late int revealed = widget.pageSize;

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    revealed,
    () => setState(() => revealed += widget.pageSize),
  );
}
