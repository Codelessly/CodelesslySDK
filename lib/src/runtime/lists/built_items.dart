// The lists on screen that build only the items near their view (a chat,
// a log, a long feed): what a scrollTo of an item reads when the item's
// copy is not built yet. The list widget registers itself here.
import '../../render/node_tree.dart' show RenderTree;

/// A list on screen whose copies of its item template are built only near
/// its view.
abstract interface class LazyItems {
  /// The tree the list is drawn in.
  RenderTree get tree;

  /// The list's item template.
  String get itemId;

  /// Whether the list repeats node [id] (its item template, or a node
  /// inside it).
  bool repeats(String id);

  /// The index of the item [item] names (its key, else [item] as an
  /// index); -1: none.
  int indexOfItem(String item);

  /// The key of item [index] as text (its `id`, or the list's key path);
  /// null when it has none.
  String? keyAt(int index);

  /// Builds item [index] (scrolls toward it until it is laid out); whether
  /// it is.
  Future<bool> buildItem(int index);
}

/// The [LazyItems] lists mounted now.
abstract final class LazyItemLists {
  static final Set<LazyItems> _live = {};

  static void add(LazyItems list) => _live.add(list);
  static void remove(LazyItems list) => _live.remove(list);

  /// The lists of [tree] that repeat node [id].
  static List<LazyItems> repeating(RenderTree tree, String id) => [
        for (final list in _live)
          if (identical(list.tree, tree) && list.repeats(id)) list,
      ];

  /// The item template of a list of [tree] with an item whose key is [key]
  /// (not an index): what a `scrollTo` of that key as a node meant.
  static String? templateOfKey(RenderTree tree, String key) {
    if (int.tryParse(key) != null) return null;
    for (final list in _live) {
      if (identical(list.tree, tree) && list.indexOfItem(key) >= 0) return list.itemId;
    }
    return null;
  }
}
