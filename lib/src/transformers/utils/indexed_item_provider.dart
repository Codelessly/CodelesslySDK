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
    if (inner is _IndexedItemElement) return inner.parentItem;
    return null;
  }

  @override
  InheritedElement createElement() => _IndexedItemElement(this);

  @override
  bool updateShouldNotify(covariant IndexedItemProvider oldWidget) =>
      oldWidget.item != item;
}

/// Finds the provider of the next list out once, not on every read: every
/// binding in a list item asks for it ([ScopedValues.of]), and walking up
/// to the root each time, when there is no outer list, took a large share
/// of every rebuild of a list's rows.
class _IndexedItemElement extends InheritedElement {
  _IndexedItemElement(IndexedItemProvider super.widget);

  Element? _outer;
  bool _found = false;

  /// The item of the next [IndexedItemProvider] out, or null.
  IndexedItem? get parentItem {
    if (!_found) {
      _found = true;
      _outer = null;
      visitAncestorElements((element) {
        if (element.widget is IndexedItemProvider) {
          _outer = element;
          return false;
        }
        return true;
      });
    }
    return (_outer?.widget as IndexedItemProvider?)?.item;
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _found = false;
  }

  @override
  void activate() {
    super.activate();
    // Moved under another parent: look again.
    _found = false;
  }
}

class IndexedItem with Equatable {
  final int index;
  final Object? item;

  IndexedItem(this.index, this.item);

  @override
  List<Object?> get props => [index, item];
}
