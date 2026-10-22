import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class IndexedItemProvider extends InheritedWidget {
  final IndexedItem item;

  const IndexedItemProvider({
    super.key,
    required super.child,
    required this.item,
  });

  static IndexedItem? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<IndexedItemProvider>()?.item;

  /// The item of the next list out, for a list nested in another list's
  /// item, or null. It does not make [context] depend on it: the inner list
  /// is rebuilt with its outer item anyway.
  static IndexedItem? parentOf(BuildContext context) {
    final InheritedElement? inner = context
        .getElementForInheritedWidgetOfExactType<IndexedItemProvider>();
    if (inner == null) return null;
    IndexedItem? parent;
    inner.visitAncestorElements((element) {
      if (element.widget case final IndexedItemProvider provider) {
        parent = provider.item;
        return false;
      }
      return true;
    });
    return parent;
  }

  @override
  bool updateShouldNotify(covariant IndexedItemProvider oldWidget) =>
      oldWidget.item != item;
}

class IndexedItem with Equatable {
  final int index;
  final Object? item;

  IndexedItem(this.index, this.item);

  @override
  List<Object?> get props => [index, item];
}
