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

  @override
  bool updateShouldNotify(covariant IndexedItemProvider oldWidget) =>
      oldWidget.item != item;
}

class IndexedItem with EquatableMixin {
  final int index;
  final Object? item;

  IndexedItem(this.index, this.item);

  @override
  List<Object?> get props => [index, item];
}
