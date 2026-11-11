// Painting and islands of the media group: image fills, SVG paths (the
// `path` widget and a box's path), icons, and the players' islands.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/paint/icon_glyph.dart';
import 'package:codelessly_sdk/src/render/paint/material_icon_versions.dart';
import 'package:codelessly_sdk/src/render/paint/path_paint.dart';
import 'package:codelessly_sdk/src/widgets/media_players.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A 4×2 red PNG.
const _png = 'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAACCAYAAAB/qH1jAAAAEklEQVR4nGP4z8DwHxkzoAsAAA8hD/EEN8afAAAAAElFTkSuQmCC';

/// A 10×10 SVG square.
const _svg = 'data:image/svg+xml;base64,'
    'PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMCIgaGVpZ2h0PSIxMCI+PHJlY3Qgd2lkdGg9IjEwIiBoZWlnaHQ9IjEwIi8+PC9zdmc+';

Map<String, Object?> _doc(Map<String, Object?> nodes, {double w = 300, double h = 200}) => {
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': [for (final k in nodes.keys) k], 'layout': {'width': w, 'height': h}},
        ...nodes,
      },
    };

Future<NodeTree> _show(WidgetTester tester, Map<String, Object?> json, {bool interactive = false}) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(json)));
  await tester.pumpWidget(MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's', interactive: interactive))));
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });
  return tree;
}

/// Lets images decode (real async), then repaints.
Future<void> _loadImages(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
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
  test('symbol, material and cupertino icon URLs', () {
    expect(IconSources.urlOf({'source': 'icon', 'type': 'MATERIAL_ICON', 'name': 'Home', 'style': 'rounded', 'version': 16}),
        'https://fonts.gstatic.com/s/i/materialiconsround/home/v16/24px.svg');
    // Without a version (an icon named in data): its latest version, since
    // gstatic doesn't keep v1 of every icon.
    expect(IconSources.urlOf({'source': 'icon', 'type': 'MATERIAL_ICON', 'name': 'home', 'style': 'filled'}),
        'https://fonts.gstatic.com/s/i/materialicons/home/v16/24px.svg');
    expect(IconSources.urlOf({'type': 'MATERIAL_ICON', 'name': 'auto_awesome', 'style': 'rounded'}),
        'https://fonts.gstatic.com/s/i/materialiconsround/auto_awesome/v14/24px.svg');
    // A name bound at runtime keeps the design icon's version: the name's own is used.
    expect(IconSources.urlOf({'source': 'icon', 'type': 'MATERIAL_ICON', 'name': 'bolt', 'style': 'rounded', 'version': 18}),
        'https://fonts.gstatic.com/s/i/materialiconsround/bolt/v10/24px.svg');
    // A name the table doesn't know keeps its stored version.
    expect(IconSources.urlOf({'source': 'icon', 'type': 'MATERIAL_ICON', 'name': 'brand_new_icon', 'version': 3}),
        'https://fonts.gstatic.com/s/i/materialicons/brand_new_icon/v3/24px.svg');
    // ios_share has no v1 SVG: without the table it drew nothing.
    expect(IconSources.urlOf({'source': 'icon', 'type': 'MATERIAL_ICON', 'name': 'ios_share', 'style': 'rounded'}),
        contains('/materialiconsround/ios_share/v'));
    expect(IconSources.urlOf({'source': 'icon', 'type': 'MATERIAL_ICON', 'name': 'ios_share', 'style': 'rounded'}),
        isNot(contains('/v1/')));
    expect(
        IconSources.urlOf({
          'source': 'icon', 'type': 'MATERIAL_SYMBOL', 'name': 'star', 'style': 'rounded', //
          'fill': 1, 'weight': 700, 'grade': -20, 'opticalSize': 44,
        }),
        'https://fonts.gstatic.com/s/i/short-term/release/materialsymbolsrounded/star/wght700gradN25fill1/40px.svg');
    expect(IconSources.urlOf({'source': 'icon', 'type': 'MATERIAL_SYMBOL', 'name': 'star', 'style': 'outlined'}),
        endsWith('/star/default/24px.svg'));
    expect(IconSources.urlOf({'source': 'icon', 'type': 'CUPERTINO_ICON', 'codepoint': 61708}),
        'https://icons.codelessly.com/cupertino/1.0.9/f10c.svg');
    expect(IconSources.urlOf({'source': 'image', 'image': 'https://x.com/a.png'}), 'https://x.com/a.png');
  });

  test("a Material icon named with Flutter's style suffix is served under its base name", () {
    String? url(String name, [String? style]) =>
        IconSources.urlOf({'type': 'MATERIAL_ICON', 'name': name, 'style': ?style});
    expect(url('download_rounded', 'rounded'), startsWith('https://fonts.gstatic.com/s/i/materialiconsround/download/'));
    expect(url('check_circle_outline_rounded', 'rounded'),
        startsWith('https://fonts.gstatic.com/s/i/materialiconsround/check_circle_outline/'));
    expect(url('theater_comedy_outlined', 'outlined'),
        startsWith('https://fonts.gstatic.com/s/i/materialiconsoutlined/theater_comedy/'));
    // With no style set, the suffix names it.
    expect(url('playlist_add_rounded'), startsWith('https://fonts.gstatic.com/s/i/materialiconsround/playlist_add/'));
    expect(url('memory_sharp'), startsWith('https://fonts.gstatic.com/s/i/materialiconssharp/memory/'));
    // Names that only contain the words are untouched.
    expect(url('outlined_flag'), startsWith('https://fonts.gstatic.com/s/i/materialicons/outlined_flag/'));
  });

  test('a Material icon saved without its version is drawn from its current SVG', () {
    const week = {'source': 'icon', 'type': 'MATERIAL_ICON', 'name': 'calendar_view_week', 'style': 'rounded'};
    // Icons added after Material's first release have no v1 SVG.
    expect(IconSources.urlOf(week),
        'https://fonts.gstatic.com/s/i/materialiconsround/calendar_view_week/v${materialIconVersions['calendar_view_week']}/24px.svg');
    // urlOf already gives the current version: no second try.
    expect(IconSources.fallbackUrlOf(week), isNull);
    expect(IconSources.fallbackUrlOf({'source': 'icon', 'type': 'MATERIAL_SYMBOL', 'name': 'star'}), isNull);
    expect(IconSources.fallbackUrlOf({'source': 'image', 'image': 'https://x.com/a.png'}), isNull);
  });

  test('SVG paths parse, trim and dash', () {
    expect(parseSvgPath(''), isNull);
    expect(parseSvgPath('M0 0 L'), isNull);
    final line = parseSvgPath('M0 0 H100')!;
    expect(line.getBounds(), const Rect.fromLTRB(0, 0, 100, 0));
    expect(trimPath(line, 0.25, 0.5).getBounds(), const Rect.fromLTRB(25, 0, 50, 0));
    final dashed = dashPath(line, 10, 30);
    expect(dashed.computeMetrics().length, 3);
  });

  testWidgets('an image fill paints its image by fit, tinted and faded', (tester) async {
    final tree = await _show(tester, _doc({
      'b': {
        'type': 'box',
        'layout': {'width': 100, 'height': 50},
        'decoration': {
          'fills': [
            {'color': '#FF00FF00'},
            {'type': 'image', 'opacity': 0.5, 'image': {'url': _png, 'fit': 'fill', 'tint': '#FF0000FF'}},
          ],
        },
      },
    }));
    await _loadImages(tester);
    final box = tree.boxOf('b')!;
    expect(
        box,
        paints
          ..rrect(color: const Color(0xFF00FF00))
          ..drawImageRect(source: const Rect.fromLTWH(0, 0, 4, 2), destination: const Rect.fromLTWH(0, 0, 100, 50)));
  });

  testWidgets('an image placed by hand draws in its rect; a flipped one mirrors', (tester) async {
    final tree = await _show(tester, _doc({
      'b': {
        'type': 'box',
        'layout': {'width': 100, 'height': 50},
        'decoration': {
          'radius': 8,
          'fills': [
            {'type': 'image', 'image': {'url': _png, 'fit': 'fill', 'rect': [10, 5, 40, 20], 'flipX': true}},
          ],
        },
      },
    }));
    await _loadImages(tester);
    expect(
        tree.boxOf('b')!,
        paints
          ..clipRRect(rrect: RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 100, 50), const Radius.circular(8)))
          ..drawImageRect(destination: const Rect.fromLTWH(10, 5, 40, 20)));
  });

  testWidgets('a path widget fills and strokes its data, scaled from its view box', (tester) async {
    final tree = await _show(tester, _doc({
      'p': {
        'type': 'path',
        'layout': {'width': 100, 'height': 100, 'x': {'start': 10}, 'y': {'start': 10}},
        'decoration': {
          'fills': [{'color': '#FFFF0000'}],
          'strokes': [{'color': '#FF0000FF'}],
          'strokeWidth': 2,
        },
        'props': {'data': 'M0 0 H10 V10 H0 Z', 'viewBox': [10, 10]},
      },
    }));
    expect(tree.boxOf('p')!.rectIn(tester.renderObject(find.byType(NodeView))), const Rect.fromLTWH(10, 10, 100, 100));
    expect(
        tree.boxOf('p')!,
        paints
          ..path(color: const Color(0xFFFF0000), includes: const [Offset(50, 50), Offset(95, 95)], excludes: const [Offset(105, 50)])
          ..path(color: const Color(0xFF0000FF), style: PaintingStyle.stroke, strokeWidth: 2));
  });

  testWidgets('a box with a path fills inside the path and strokes along it, unclipped and unshadowed', (tester) async {
    final tree = await _show(tester, _doc({
      'b': {
        'type': 'box',
        'layout': {'width': 100, 'height': 100},
        'decoration': {
          'fills': [{'color': '#FFFF0000'}],
          'strokes': [{'color': '#FF000000'}],
          'strokeWidth': 4,
          'clip': 'hardEdge',
          'effects': [{'type': 'dropShadow', 'color': '#FF000000', 'blurRadius': 4}],
        },
        'props': {'path': 'M0 0 L100 0 L0 100 Z', 'strokeJoin': 'round'},
      },
    }));
    final box = tree.boxOf('b')!;
    expect(box, isNot(paints..something((m, _) => m == #drawShadow || m == #clipRect)));
    expect(
        box,
        paints
          ..clipPath(pathMatcher: isPathThat(includes: const [Offset(10, 10)], excludes: const [Offset(90, 90)]))
          ..rrect(color: const Color(0xFFFF0000))
          ..path(color: const Color(0xFF000000), style: PaintingStyle.stroke, strokeWidth: 4));
  });

  testWidgets('icons paint their SVG contained in the box, tinted', (tester) async {
    final tree = await _show(tester, _doc({
      'i': {
        'type': 'icon',
        'layout': {'width': 40, 'height': 20},
        'props': {
          'icon': {'source': 'image', 'image': _svg},
          'color': '#FF00FF00',
        },
      },
    }));
    await _loadImages(tester);
    expect(
        tree.boxOf('i')!,
        paints
          ..clipRect(rect: const Rect.fromLTWH(10, 0, 20, 20))
          ..something((m, args) => m == #drawPicture));
  });

  testWidgets('an SVG icon whose first fetch fails loads on a retry', (tester) async {
    var calls = 0;
    final svg = UriData.parse(_svg).contentAsBytes();
    final client = MockClient((request) async {
      calls++;
      return calls == 1 ? http.Response('dropped', 502) : http.Response.bytes(svg, 200);
    });
    await http.runWithClient(() async {
      final tree = await _show(tester, _doc({
        'i': {
          'type': 'icon',
          'layout': {'width': 20, 'height': 20},
          'props': {'icon': {'source': 'image', 'image': 'https://cdn.example.com/icons/flaky.svg'}, 'color': '#FF00FF00'},
        },
      }));
      await _loadImages(tester);
      expect(calls, 1);
      expect(tree.boxOf('i')!, isNot(paints..something((m, args) => m == #drawPicture)));
      // The retry after a second loads it.
      await tester.pump(const Duration(milliseconds: 1100)); // the retry timer
      await _loadImages(tester);
      expect(calls, 2);
      expect(tree.boxOf('i')!, paints..something((m, args) => m == #drawPicture));
    }, () => client);
  });

  testWidgets('players are islands showing their design-time preview', (tester) async {
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

  testWidgets('an external node builds the app\'s widget', (tester) async {
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

  test('embedded video URLs carry the player settings', () {
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

  test('media URLs must be remote HTTPS on a public host', () {
    expect(isRemoteMediaUrl('https://cdn.example.com/a.mp4', ['.mp4']), isTrue);
    expect(isRemoteMediaUrl('http://cdn.example.com/a.mp4', ['.mp4']), isFalse);
    expect(isRemoteMediaUrl('https://192.168.1.2/a.mp4', ['.mp4']), isFalse);
    expect(isRemoteMediaUrl('https://172.20.0.1/a.mp3', ['.mp3']), isFalse);
    expect(isRemoteMediaUrl('https://cdn.example.com/a.mov', ['.mp4']), isFalse);
  });
}
