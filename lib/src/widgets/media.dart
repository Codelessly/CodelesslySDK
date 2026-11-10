// Widget recipes: media (vector paths, video, audio, web views) and slots the
// app fills (placeholders, external components). See
// lib/src/render/recipe.dart.
import 'package:codelessly_api/codelessly_api.dart' show ExternalProps, Node;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../render/node_tree.dart' show Slot, SlotKind;
import '../render/paint/path_paint.dart';
import '../render/recipe.dart';
import 'media_players.dart';

/// The widgets an app builds for its `external` nodes, by builder id. Put it
/// above the [NodeView]s that show them.
class ExternalComponents extends InheritedTheme {
  const ExternalComponents({super.key, required this.builders, required super.child});

  final Map<String, WidgetBuilder> builders;

  static ExternalComponents? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ExternalComponents>();

  @override
  Widget wrap(BuildContext context, Widget child) => ExternalComponents(builders: builders, child: child);

  @override
  bool updateShouldNotify(ExternalComponents oldWidget) => !identical(oldWidget.builders, builders);
}

/// Recipes for the media group, by node type.
final Map<String, WidgetRecipe> mediaRecipes = {
  'path': buildPath,
  'video': (b, n, chain) => _player(b, n, chain, (preview) => MediaVideo(node: n, preview: preview)),
  'embeddedVideo': (b, n, chain) =>
      _player(b, n, chain, (preview) => MediaEmbeddedVideo(key: ValueKey(n.props), node: n, preview: preview)),
  'audioPlayer': (b, n, chain) => _player(b, n, chain, (preview) => MediaAudioPlayer(node: n, preview: preview)),
  'webView': (b, n, chain) => _player(b, n, chain, (preview) => MediaWebViewNode(node: n, preview: preview)),
  'external': (b, n, chain) => _player(b, n, chain, (_) => _External(n)),
  'placeholder': _placeholder,
  'singlePlaceholder': _singlePlaceholder,
};

Size _designSize(Node n) => Size(n.layout.width.value, n.layout.height.value);

/// A widget at the node's size and fits (AdaptiveNodeBox), hosted as an
/// island. [build] gets whether this is a design canvas (no playback).
void _player(NodeBuilder b, Node n, List<RenderBox> chain, Widget Function(bool preview) build) {
  chain.add(b.fitBox('fit', n.layout.width.fit, n.layout.height.fit, _designSize(n)));
  final preview = !b.tree.islands.environment.interactive;
  chain.add(b.island(n.type, (context) => build(preview)));
}

class _External extends StatelessWidget {
  const _External(this.node);
  final Node node;

  @override
  Widget build(BuildContext context) =>
      ExternalComponents.maybeOf(context)?.builders[node.prop(ExternalProps.builderId)]?.call(context) ??
      const Placeholder();
}

/// An empty `SizedBox()`: the size its parent gives it, or none.
void _placeholder(NodeBuilder b, Node n, List<RenderBox> chain) {
  chain.add(b.obtain<RenderConstrainedBox>(
      'empty', () => RenderConstrainedBox(additionalConstraints: const BoxConstraints())));
}

/// Its one child as the child lays itself out, or a box of its design size
/// when empty.
void _singlePlaceholder(NodeBuilder b, Node n, List<RenderBox> chain) {
  final child = n.children.where((id) => b.nodeOf(id) != null).firstOrNull;
  if (child == null) {
    final c = BoxConstraints.tight(_designSize(n));
    chain.add(b.obtain<RenderConstrainedBox>('empty', () => RenderConstrainedBox(additionalConstraints: c))
      ..additionalConstraints = c);
    return;
  }
  final stack = b.obtain<RenderStack>(
      'slot', () => RenderStack(fit: StackFit.passthrough, textDirection: TextDirection.ltr, clipBehavior: Clip.none));
  b.syncChildren(stack, [child], Slot(SlotKind.root, n));
  chain.add(stack);
}
