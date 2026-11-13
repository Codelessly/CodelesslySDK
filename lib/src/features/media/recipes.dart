// The media feature's node types: video, embedded video, audio players and
// web views, each a player widget hosted as an island at the node's size.
// Installed with the feature (CodelesslyFeature.recipes), so a core-only app
// compiles none of the platform players.
import 'package:codelessly_api/core.dart' show Node;
import 'package:flutter/widgets.dart';

import '../../render/node_tree.dart' show fireTrigger;
import '../../render/recipe.dart';
import 'players.dart';

/// The media feature's recipes, by node type.
const Map<String, WidgetRecipe> mediaPlayerRecipes = {
  'video': _video,
  'embeddedVideo': _embeddedVideo,
  'audioPlayer': _audioPlayer,
  'webView': _webView,
};

void _video(NodeBuilder b, Node n, List<RenderBox> chain) => _player(b, n, chain,
    (preview) => MediaVideo(node: n, preview: preview, onStatus: (status) => fireTrigger(b, 'changed', event: {'value': status})));

void _embeddedVideo(NodeBuilder b, Node n, List<RenderBox> chain) =>
    _player(b, n, chain, (preview) => MediaEmbeddedVideo(node: n, preview: preview));

void _audioPlayer(NodeBuilder b, Node n, List<RenderBox> chain) => _player(b, n, chain,
    (preview) => MediaAudioPlayer(node: n, preview: preview, onStatus: (status) => fireTrigger(b, 'changed', event: {'value': status})));

void _webView(NodeBuilder b, Node n, List<RenderBox> chain) =>
    _player(b, n, chain, (preview) => MediaWebViewNode(node: n, preview: preview));

/// A widget at the node's size and fits, hosted as an island; [build] gets
/// whether this is a design canvas (no playback).
void _player(NodeBuilder b, Node n, List<RenderBox> chain, Widget Function(bool preview) build) {
  chain.add(b.fitBox('fit', n.layout.width.fit, n.layout.height.fit, Size(n.layout.width.value, n.layout.height.value)));
  final preview = !b.tree.islands.environment.interactive;
  chain.add(b.island(n.type, (context) => build(preview)));
}
