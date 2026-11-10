import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/widgets.dart';

import '../../../codelessly_sdk.dart';

/// How a list keys its items and, for a list that layers them, the order it
/// paints them in: from its `itemKey` and `itemZIndex` bindings (see
/// [ListViewNode.itemKeyVariable] and [ListViewNode.itemZIndexVariable]),
/// evaluated for each item, and [ListViewProperties.reversePaintOrder].
class ListItemArrangement {
  ListItemArrangement._(this._keys, this.paintOrder);

  final List<Object> _keys;

  /// The item indexes in the order they are painted: the first is drawn at
  /// the bottom, the last on top (and takes taps first).
  final List<int> paintOrder;

  /// The key of the item at [index], unique among the items: its bound key,
  /// or its index when it has none or shares it with another item.
  Object keyOf(int index) => _keys[index];

  /// The keys and paint order of [count] items of [list], the value of item
  /// `i` being `values(i)`. [scope] is the list's own scope; each binding is
  /// read with the item added to it, as the item's own nodes read it.
  ///
  /// [firstOnTop] is the list's natural order: true for a stacked list,
  /// false for a positional stack (later items are drawn over earlier
  /// ones). [ListViewProperties.reversePaintOrder] flips it, and a bound z
  /// index sorts before it.
  factory ListItemArrangement.of(
    ListViewNode list, {
    required int count,
    required Object? Function(int index) values,
    required ScopedValues scope,
    bool firstOnTop = false,
  }) {
    final String? keyBinding = list.variables[ListViewNode.itemKeyVariable];
    final String? zBinding = list.variables[ListViewNode.itemZIndexVariable];
    final bool keyed = keyBinding != null && keyBinding.trim().isNotEmpty;
    final bool sorted = zBinding != null && zBinding.trim().isNotEmpty;

    ScopedValues itemScope(int index) =>
        ScopedValues.forItem(scope, IndexedItem(index, values(index)));

    final List<Object?> bound = [
      for (int index = 0; index < count; index++)
        keyed
            ? PropertyValueDelegate.getPropertyValue<Object>(
                list,
                ListViewNode.itemKeyVariable,
                scopedValues: itemScope(index),
              )
            : null,
    ];
    final Map<Object?, int> uses = {};
    for (final Object? key in bound) {
      if (key != null) uses[key] = (uses[key] ?? 0) + 1;
    }
    final List<Object> keys = [
      for (int index = 0; index < count; index++)
        switch (bound[index]) {
          final Object key when uses[key] == 1 => ('item', key),
          _ => ('index', index),
        },
    ];

    final bool topFirst = firstOnTop != list.properties.reversePaintOrder;
    // Natural order, bottom to top.
    final List<int> order = [
      for (int i = 0; i < count; i++) topFirst ? count - 1 - i : i,
    ];
    if (sorted) {
      final List<num> z = [
        for (int index = 0; index < count; index++)
          _number(
                PropertyValueDelegate.getPropertyValue<Object>(
                  list,
                  ListViewNode.itemZIndexVariable,
                  scopedValues: itemScope(index),
                ),
              ) ??
              0,
      ];
      final Map<int, int> rank = {
        for (int i = 0; i < order.length; i++) order[i]: i,
      };
      order.sort((a, b) {
        final int byZ = z[a].compareTo(z[b]);
        return byZ != 0 ? byZ : rank[a]!.compareTo(rank[b]!);
      });
    }
    return ListItemArrangement._(keys, order);
  }

  static num? _number(Object? value) => switch (value) {
    num n when n.isFinite => n,
    String s => num.tryParse(s.trim()),
    bool b => b ? 1 : 0,
    _ => null,
  };

  /// Whether [list] binds its item keys or paint order, so its items are
  /// arranged by a [ListItemArrangement].
  static bool arranges(ListViewNode list) =>
      list.variables[ListViewNode.itemKeyVariable]?.trim().isNotEmpty == true ||
      list.variables[ListViewNode.itemZIndexVariable]?.trim().isNotEmpty ==
          true ||
      list.properties.reversePaintOrder;
}

/// A widget key for the item of a list keyed [key] (see
/// [ListItemArrangement.keyOf]), unique for [role] within the list.
Key listItemKey(Object key, [String role = 'item']) => ValueKey((role, key));
