// Finding the toggles, sliders and segmented buttons the tree draws as
// render objects (render/controls/{toggles,slider,segmented}.dart).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';

/// The render object of type [T] in node [id]'s box ([instance]: a list
/// item's).
T controlIn<T extends RenderObject>(RenderTree tree, String id, {Object? instance}) {
  T? found;
  void visit(RenderObject o) {
    if (found != null) return;
    if (o is T) {
      found = o;
      return;
    }
    o.visitChildren(visit);
  }

  visit(tree.boxOf(id, instance: instance)!);
  return found!;
}

/// Every render object of type [T] under [root].
List<T> controlsUnder<T extends RenderObject>(RenderObject root) {
  final out = <T>[];
  void visit(RenderObject o) {
    if (o is T) out.add(o);
    o.visitChildren(visit);
  }

  visit(root);
  return out;
}
