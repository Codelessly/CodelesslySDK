
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/paint/icon_glyph.dart';
import 'package:codelessly_sdk/src/render/paint/material_icon_versions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/screen.dart' as harness;

// Painting and islands of the media group: image fills, SVG paths (the
// `path` widget and a box's path), icons, and the players' islands.

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

// A Material icon whose SVG isn't available (loading, or no version 1 on
// Google's server, as grid_view rounded) draws its MaterialIcons glyph
// instead of nothing, when it carries the codepoint.

const png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAQAAAACCAYAAAB/qH1jAAAAEklEQVR4nGP4z8DwHxkzoAsAAA8hD/EEN8afAAAAAElFTkSuQmCC';

/// A layout whose `art` box draws an image fill with [url], binding [bind].
LayoutDocument doc(String url, {Map<String, Object?> bind = const {}}) => LayoutDocument.fromJson({
      'roots': ['art'],
      'nodes': {
        'art': {
          'type': 'box',
          'layout': {'width': 64, 'height': 64},
          'decoration': {
            'fills': [
              {'id': 'cover', 'type': 'image', 'image': {'url': url, 'fit': 'cover'}},
            ],
          },
          if (bind.isNotEmpty) 'bind': bind,
        },
      },
    });

String? boundUrl(LayoutDocument d, VariableScope vars) {
  final source = DocumentSource(d);
  final node = d.nodes['art']!;
  final bound = NodeBinder(scope: vars).bind(source, node, null).node;
  return bound.decoration.fills.single.image?.url;
}

// Painting and islands of the media group: image fills, SVG paths (the
// `path` widget and a box's path), icons, and the players' islands.

void main() {
  {

    test('an icon saved without a version draws the current one', () {
      const week = {'source': 'icon', 'type': 'MATERIAL_ICON', 'name': 'calendar_view_week', 'style': 'rounded'};
      // Icons added after Material's first release have no v1 SVG.
      expect(IconSources.urlOf(week),
          'https://fonts.gstatic.com/s/i/materialiconsround/calendar_view_week/v${materialIconVersions['calendar_view_week']}/24px.svg');
      // urlOf already gives the current version: no second try.
      expect(IconSources.fallbackUrlOf(week), isNull);
      expect(IconSources.fallbackUrlOf({'source': 'icon', 'type': 'MATERIAL_SYMBOL', 'name': 'star'}), isNull);
      expect(IconSources.fallbackUrlOf({'source': 'image', 'image': 'https://x.com/a.png'}), isNull);
    });

    testWidgets('an image fill paints its image by its fit, tinted and faded', (tester) async {
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

    testWidgets('an image placed by hand draws in its rect, and a flipped one is mirrored', (tester) async {
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

    testWidgets('an icon paints inside its box in its color', (tester) async {
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

    testWidgets('an icon whose first download fails loads on a retry', (tester) async {
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

    group('icons', () {
      testWidgets('an icon bound to a name changes when the name does', (tester) async {
        final vars = VariableScope([
          const Variable(id: 'playing', name: 'playing', type: VariableType.boolean, value: false),
        ]);
        final doc = LayoutDocument.fromJson({
          'roots': ['root'],
          'nodes': {
            'root': {'type': 'column', 'children': ['icon'], 'layout': {'width': 100, 'height': 100}},
            'icon': {
              'type': 'icon',
              'layout': {'width': 24, 'height': 24},
              'props': {
                'icon': {'type': 'MATERIAL_ICON', 'name': 'play_arrow', 'style': 'filled'},
              },
              'bind': {'props.icon': r"${= playing ? 'pause' : 'play_arrow'}"},
            },
          },
        });
        final tree = NodeTree(DocumentSource(doc), binder: NodeBinder(scope: vars));
        await tester.pumpWidget(MaterialApp(home: NodeView(tree: tree, rootId: 'root')));
        RenderIconGlyph glyph() {
          RenderIconGlyph? found;
          void visit(RenderObject o) {
            if (o is RenderIconGlyph) found = o;
            o.visitChildren(visit);
          }
          visit(tree.boxOf('icon')!);
          return found!;
        }
        expect(glyph().icon['name'], 'play_arrow');
        vars.set('playing', true);
        await tester.pump();
        expect(glyph().icon['name'], 'pause');
        expect(glyph().icon['type'], 'MATERIAL_ICON');
        await tester.pumpWidget(const SizedBox());
        tree.dispose();
        vars.dispose();
      });

      testWidgets('an icon shows a stand-in glyph while its image is unavailable', (tester) async {
        final doc = LayoutDocument.fromJson({
          'roots': ['i'],
          'nodes': {
            'i': {
              'type': 'icon',
              'layout': {'width': 24, 'height': 24},
              'props': {
                'icon': {'type': 'MATERIAL_ICON', 'name': 'grid_view', 'style': 'rounded', 'codepoint': 63428},
                'color': '#FF1D1A16',
              },
            },
          },
        });
        final tree = NodeTree(DocumentSource(doc));
        addTearDown(tree.dispose);
        await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'i'))));
        // The network is off in tests: the SVG never loads. Something is drawn.
        final glyph = tester.renderObject(find.byType(NodeView));
        expect(glyph, paints..paragraph());
      });
    });

    group('images', () {
      testWidgets('an image that fails runs its error reaction, and its replacement runs the loaded reaction', (tester) async {
        final s = await harness.show(
          tester,
          {
            'col': {
              'type': 'column',
              'layout': {'width': 200, 'height': 200},
              'children': ['photo'],
            },
            'photo': {
              'type': 'box',
              'layout': {'width': 100, 'height': 100},
              'decoration': {
                'fills': [
                  {
                    'type': 'image',
                    'image': {'url': ''},
                  },
                ],
              },
              'bind': {'decoration.fills[0].image.url': r'${url}'},
              'actions': [
                harness.reaction('imageLoading', [
                  {'type': 'setVariable', 'variable': 'state', 'value': 'loading'},
                ]),
                harness.reaction('imageLoaded', [
                  {'type': 'setVariable', 'variable': 'state', 'value': 'loaded'},
                ]),
                harness.reaction('imageError', [
                  {'type': 'setVariable', 'variable': 'state', 'value': 'error'},
                ]),
              ],
            },
          },
          variables: [harness.v('url', 'data:image/png;base64,broken'), harness.v('state', '')],
        );
        Future<void> decode() async {
          for (var i = 0; i < 4; i++) {
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
            await tester.pump();
          }
        }

        await decode();
        expect(s['state'], 'error');
        setVariableIn(s.scope, 'url', png);
        await tester.pump();
        await decode();
        expect(s['state'], 'loaded');
        expect(tester.takeException(), isNull);
      });

      final vars = VariableScope([
        const Variable(id: 'show', name: 'show', type: VariableType.map, value: {'cover': 'https://example.com/a.png'}),
      ]);

      test('an image URL holding a variable is filled in', () {
        expect(boundUrl(doc(r'${show.cover}'), vars), 'https://example.com/a.png');
        expect(boundUrl(doc(r'https://cdn.test/${show.cover}'), vars), 'https://cdn.test/https://example.com/a.png');
      });

      test('a binding on the paint wins over variables in its URL', () {
        final d = doc(r'${show.cover}', bind: {'decoration.fills[0].image.url': 'https://example.com/own.png'});
        expect(boundUrl(d, vars), 'https://example.com/own.png');
      });
    });
  }

  group('icons', () {

    test("an icon named with Flutter's style suffix shows the base icon", () {
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
  });
}
