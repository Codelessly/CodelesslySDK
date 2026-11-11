// What a list reorder changes:
// moved lists, the order value between two neighbors, and the
// `${result}` of a reorder.

/// [list] with the item at [from] moved so that it ends up at [to] (an
/// index in the new order).
List<T> moveListItem<T>(List<T> list, int from, int to) {
  if (from < 0 || from >= list.length) return [...list];
  final result = [...list];
  final item = result.removeAt(from);
  result.insert(to.clamp(0, result.length), item);
  return result;
}

/// The two lists after the item at [from] of [source] is moved to index
/// [to] of [target] (an index among the target's items before the move).
({List<T> source, List<T> target}) moveBetweenLists<T>(List<T> source, List<T> target, int from, int to) {
  if (from < 0 || from >= source.length) return (source: [...source], target: [...target]);
  final newSource = [...source];
  final item = newSource.removeAt(from);
  final newTarget = [...target]..insert(to.clamp(0, target.length), item);
  return (source: newSource, target: newTarget);
}

/// An order value between [before] and [after] (the order values of the
/// moved item's new neighbors, null at an end), so only the moved
/// document is written: the midpoint, or one past the end.
double orderBetween(num? before, num? after) {
  if (before == null && after == null) return 0;
  if (before == null) return after!.toDouble() - 1;
  if (after == null) return before.toDouble() + 1;
  return (before + after) / 2;
}

/// The `${result}` of a reorder.
Map<String, Object?> reorderResult({
  required int from,
  required int to,
  required Object? item,
  required String fromList,
  required String toList,
}) =>
    {'from': from, 'to': to, 'item': item, 'fromList': fromList, 'toList': toList};
