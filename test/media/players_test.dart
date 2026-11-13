// Painting and islands of the media group: image fills, SVG paths (the
// `path` widget and a box's path), icons, and the players' islands.

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/features/media/players.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _doc(Map<String, Object?> nodes, {double w = 300, double h = 200}) => {
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': [for (final k in nodes.keys) k], 'layout': {'width': w, 'height': h}},
        ...nodes,
      },
    };

Future<NodeTree> _show(WidgetTester tester, Map<String, Object?> json, {bool interactive = false}) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(json)), recipes: mediaFeature.recipes);
  await tester.pumpWidget(MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's', interactive: interactive))));
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });
  return tree;
}

List<T> _find<T extends RenderObject>(RenderObject root) {
  final out = <T>[];
  void visit(RenderObject o) {
    if (o is T) out.add(o);
    o.visitChildren(visit);
  }

  visit(root);
  return out;
}

/// The text painted under [root].
String _text(RenderObject root) => _find<RenderParagraph>(root).map((p) => p.text.toPlainText()).join();

void main() {
  svgCacheTests();

  testWidgets('on the design canvas a player shows its preview', (tester) async {
    final tree = await _show(tester, _doc({
      'v': {'type': 'video', 'layout': {'width': 160, 'height': 90}, 'props': {'url': 'https://cdn.example.com/a.mp4'}},
      'e': {'type': 'embeddedVideo', 'layout': {'width': 160, 'height': 90, 'y': {'start': 100}}},
      'a': {'type': 'audioPlayer', 'layout': {'width': 200, 'height': 64, 'x': {'start': 0}, 'y': {'start': 200}}},
      'w': {'type': 'webView', 'layout': {'width': 100, 'height': 100, 'x': {'start': 170}}},
      'x': {'type': 'external', 'layout': {'width': 100, 'height': 80, 'x': {'start': 170}, 'y': {'start': 110}}},
    }, h: 300));
    expect(_text(tree.boxOf('v')!), contains(String.fromCharCode(Icons.movie_outlined.codePoint)));
    expect(_text(tree.boxOf('e')!), contains(String.fromCharCode(Icons.play_circle_fill.codePoint)));
    expect(_text(tree.boxOf('a')!), contains('Audio'));
    expect(_text(tree.boxOf('w')!), contains(String.fromCharCode(Icons.language_rounded.codePoint)));
    expect(_find<RenderCustomPaint>(tree.boxOf('x')!), isNotEmpty); // Placeholder
  });

  testWidgets('an external node shows the widget the app gives for it', (tester) async {
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(_doc({
      'x': {'type': 'external', 'layout': {'width': 100, 'height': 80}, 'props': {'builderId': 'map'}},
    }))));
    await tester.pumpWidget(MaterialApp(
      home: ExternalComponents(
        builders: {'map': (_) => const Text('the map')},
        child: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's')),
      ),
    ));
    expect(_text(tree.boxOf('x')!), 'the map');
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });

  test('an embedded video\'s URL carries its player settings', () {
    final n = Node.fromJson({
      'type': 'embeddedVideo',
      'props': {'videoId': 'abc', 'mute': true, 'loop': true, 'startAt': 5, 'showControls': false},
    })!;
    final url = Uri.parse(embeddedVideoUrl(n));
    expect(url.host, 'www.youtube.com');
    expect(url.path, '/embed/abc');
    expect(url.queryParameters, containsPair('mute', '1'));
    expect(url.queryParameters, containsPair('playlist', 'abc'));
    expect(url.queryParameters, containsPair('start', '5'));
    expect(url.queryParameters, containsPair('controls', '0'));
    final vimeo = Uri.parse(embeddedVideoUrl(n.withProp(EmbeddedVideoProps.source, EmbeddedVideoSource.vimeo)));
    expect(vimeo.host, 'player.vimeo.com');
    expect(vimeo.queryParameters, containsPair('muted', '1'));
  });

  test('a media URL must be HTTPS on a public host', () {
    expect(isRemoteMediaUrl('https://cdn.example.com/a.mp4', ['.mp4']), isTrue);
    expect(isRemoteMediaUrl('http://cdn.example.com/a.mp4', ['.mp4']), isFalse);
    expect(isRemoteMediaUrl('https://192.168.1.2/a.mp4', ['.mp4']), isFalse);
    expect(isRemoteMediaUrl('https://172.20.0.1/a.mp3', ['.mp3']), isFalse);
    expect(isRemoteMediaUrl('https://cdn.example.com/a.mov', ['.mp4']), isFalse);
  });
}

void svgCacheTests() {
}
