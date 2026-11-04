import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/foundation.dart';

/// Where a node tree's nodes come from: a published layout, or an editor's
/// store. Each node is watched on its own, so an edit re-applies only the
/// boxes of the nodes that changed.
abstract class NodeSource {
  Node? node(String id);
  String? parentOf(String id);
  ValueListenable<Node?> watch(String id);
}

/// A [NodeSource] over a [LayoutDocument]. [document] can be replaced; only
/// nodes that differ (by `==`) notify.
class DocumentSource implements NodeSource {
  DocumentSource(this._document);

  LayoutDocument _document;
  LayoutDocument get document => _document;
  final Map<String, ValueNotifier<Node?>> _watched = {};

  set document(LayoutDocument next) {
    if (identical(next, _document)) return;
    _document = next;
    for (final e in _watched.entries) {
      final n = next[e.key];
      if (n != e.value.value) e.value.value = n;
    }
  }

  @override
  Node? node(String id) => _document[id];

  @override
  String? parentOf(String id) => _document.parentOf(id);

  @override
  ValueListenable<Node?> watch(String id) => _watched[id] ??= ValueNotifier(_document[id]);
}
