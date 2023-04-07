import 'package:flutter/material.dart';

class IndexedItemProvider extends InheritedWidget {
  final int index;
  final dynamic item;

  const IndexedItemProvider({
    super.key,
    required super.child,
    required this.index,
    this.item,
  });

  static IndexedItemProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<IndexedItemProvider>();
  }

  @override
  bool updateShouldNotify(covariant IndexedItemProvider oldWidget) {
    return index != oldWidget.index || item != oldWidget.item;
  }
}
