import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/behaviors.dart' show RenderStrokePath;
import 'package:codelessly_sdk/src/render/typewriter.dart' show RenderTypewriter;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

LayoutDocument page(Map<String, Map<String, Object?>> nodes) => LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': nodes.keys.toList(), 'layout': {'width': 400, 'height': 300}},
        ...nodes,
      },
    });

Future<(NodeTree, RenderObject)> show(WidgetTester tester, LayoutDocument doc, {bool interactive = false}) async {
  final tree = NodeTree(DocumentSource(doc));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's', interactive: interactive)),
  ));
  return (tree, tester.renderObject(find.byType(NodeView)));
}

void main() {
  testWidgets('the design canvas draws behaviors at rest', (tester) async {
    final (tree, view) = await show(
        tester,
        page({
          'm': {
            'type': 'box',
            'layout': {'width': 40, 'height': 20, 'x': {'start': 10}, 'y': {'start': 10}},
            'motion': {'translateX': 30, 'scale': 2, 'duration': 500, 'enter': true},
          },
          'l': {
            'type': 'box',
            'layout': {'width': 40, 'height': 40, 'x': {'start': 100}, 'y': {'start': 100}},
            'loops': [
              {'type': 'scale', 'scaleFrom': 0.5, 'duration': 300}
            ],
          },
          'k': {
            'type': 'box',
            'layout': {'width': 20, 'height': 20, 'x': {'start': 200}, 'y': {'start': 200}},
            'drag': {
              'track': {'variable': 'v', 'x2': 100, 'y2': 0, 'max': 10, 'defaultValue': 5}
            },
          },
        }));
    // At its values (an entrance doesn't wait at its start), scaled about
    // its center.
    expect(tree.boxOf('m')!.rectIn(view), const Rect.fromLTWH(20, 0, 80, 40));
    // A loop's first frame.
    expect(tree.boxOf('l')!.rectIn(view), const Rect.fromLTWH(110, 110, 20, 20));
    // A track's control at its variable's value.
    expect(tree.boxOf('k')!.rectIn(view), const Rect.fromLTWH(250, 200, 20, 20));
    // Nothing ticks.
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a running app plays entrances and loops', (tester) async {
    final (tree, view) = await show(
        tester,
        page({
          'm': {
            'type': 'box',
            'layout': {'width': 40, 'height': 20},
            'motion': {'translateX': 100, 'duration': 1000, 'curve': 'linear', 'enter': true},
          },
          'l': {
            'type': 'box',
            'layout': {'width': 40, 'height': 40, 'x': {'start': 100}, 'y': {'start': 100}},
            'loops': [
              {'type': 'scale', 'scaleFrom': 0.5, 'duration': 1000, 'reverse': true}
            ],
          },
        }),
        interactive: true);
    await tester.pump();
    expect(tree.boxOf('m')!.rectIn(view)!.left, 0);
    expect(tree.boxOf('l')!.rectIn(view)!.width, 20);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tree.boxOf('m')!.rectIn(view)!.left, closeTo(50, 1));
    expect(tree.boxOf('l')!.rectIn(view)!.width, closeTo(30, 1));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tree.boxOf('m')!.rectIn(view)!.left, 100);
    // Back down, the second run.
    expect(tree.boxOf('l')!.rectIn(view)!.width, closeTo(39, 1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('hover applies interaction state patches', (tester) async {
    final (tree, view) = await show(
        tester,
        page({
          'b': {
            'type': 'box',
            'layout': {'width': 100, 'height': 50},
            'decoration': {
              'fills': [
                {'color': '#FFFFFFFF'}
              ]
            },
            'inkWell': {'hoverColor': '#33000000'},
            'states': {
              'hovered': {
                'b': {
                  'layout': {'width': 120}
                },
              },
            },
          },
        }),
        interactive: true);
    expect(tree.boxOf('b')!.rectIn(view)!.width, 100);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(500, 500));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(const Offset(20, 20));
    await tester.pump();
    expect(tree.statesOf('b'), {api.WidgetState.hovered});
    expect(tree.boxOf('b')!.rectIn(view)!.width, 120);
    await mouse.moveTo(const Offset(300, 200));
    await tester.pump();
    expect(tree.statesOf('b'), isEmpty);
    expect(tree.boxOf('b')!.rectIn(view)!.width, 100);
  });

  testWidgets('blurs and stroke paths paint around the content', (tester) async {
    final (tree, view) = await show(
        tester,
        page({
          't': {
            'type': 'text',
            'props': {'text': 'Blur'},
            'decoration': {
              'effects': [
                {'type': 'layerBlur', 'blurRadius': 2}
              ]
            },
            'layout': {'width': {'hug': 10}, 'height': {'hug': 10}},
          },
          'p': {
            'type': 'box',
            'layout': {'width': 100, 'height': 50, 'x': {'start': 50}},
            'decoration': {
              'radius': 8,
              'effects': [
                {'type': 'backgroundBlur', 'blurRadius': 10}
              ]
            },
            'strokePath': {
              'points': [
                [0, 0],
                [1, 40]
              ],
            },
          },
        }));
    expect(tree.boxOf('t')!.rectIn(view), isNotNull);
    expect(find.byType(NodeView), paints..path());
    expect(tree.boxOf('p')!.rectIn(view), const Rect.fromLTWH(50, 0, 100, 50));
  });

  testWidgets('a stroke path draws itself in a running app, and rests drawn on the design canvas', (tester) async {
    Map<String, Map<String, Object?>> nodes(String key, double progress) => {
          'p': {
            'type': 'box',
            'layout': {'width': 100, 'height': 50},
            'strokePath': {
              'points': [
                [0, 0],
                [1, 40]
              ],
              'progress': progress,
              'drawMs': 400,
              'drawDelayMs': 100,
              'drawCurve': 'linear',
              'drawKey': key,
            },
          },
        };
    RenderStrokePath stroke() {
      final found = <RenderStrokePath>[];
      void visit(RenderObject o) {
        if (o is RenderStrokePath) found.add(o);
        o.visitChildren(visit);
      }

      visit(tester.renderObject(find.byType(NodeView)));
      return found.single;
    }

    // At rest: drawn at its progress at once.
    await show(tester, page(nodes('a', 1)));
    expect(stroke().shown, 1);

    // Running: from nothing, after its delay, over drawMs.
    final (tree, _) = await show(tester, page(nodes('a', 1)), interactive: true);
    expect(stroke().shown, 0);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));
    expect(stroke().shown, 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(stroke().shown, closeTo(0.5, 0.05));
    await tester.pump(const Duration(milliseconds: 300));
    expect(stroke().shown, 1);

    // A lower progress glides there from where it is.
    (tree.source as DocumentSource).document = page(nodes('a', 0.5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(stroke().shown, closeTo(0.75, 0.05));
    await tester.pump(const Duration(milliseconds: 400));
    expect(stroke().shown, 0.5);

    // A new key draws it again from nothing.
    (tree.source as DocumentSource).document = page(nodes('b', 0.5));
    await tester.pump();
    expect(stroke().shown, 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 600));
    expect(stroke().shown, 0.5);
    expect(api.StrokePath.fromJson(nodes('b', 0.5)['p']!['strokePath'])!.toJson()['drawKey'], 'b');
  });

  testWidgets('a typewriter types the text out in a running app; the layout never moves', (tester) async {
    Map<String, Map<String, Object?>> nodes(String text, {String key = '', bool skip = false, bool enabled = true}) => {
          't': {
            'type': 'text',
            'layout': {'width': 200},
            'props': {'text': text, 'style': {'fontSize': 14}},
            'typewriter': {'charsPerSecond': 100, 'delayMs': 50, 'playKey': key, 'skip': skip, 'enabled': enabled},
          },
        };
    RenderTypewriter tw() {
      final found = <RenderTypewriter>[];
      void visit(RenderObject o) {
        if (o is RenderTypewriter) found.add(o);
        o.visitChildren(visit);
      }

      visit(tester.renderObject(find.byType(NodeView)));
      return found.single;
    }

    // The design canvas shows it all.
    final (rest, view) = await show(tester, page(nodes('The wind owns the hilltop.')));
    expect(tw().shownCharacters, 26);
    expect(tw().typing, isFalse);
    final designRect = rest.boxOf('t')!.rectIn(view);

    final (tree, runningView) = await show(tester, page(nodes('The wind owns the hilltop.')), interactive: true);
    expect(tw().shownCharacters, 0);
    expect(tree.boxOf('t')!.rectIn(runningView), designRect);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 150)); // 50 ms delay, then 10 characters
    expect(tw().shownCharacters, inInclusiveRange(9, 11));
    expect(tw().typing, isTrue);
    expect(find.byType(NodeView), paints..rect());
    await tester.pump(const Duration(milliseconds: 300));
    expect(tw().shownCharacters, 26);
    expect(tw().typing, isFalse);

    // Appending types only the new characters.
    (tree.source as DocumentSource).document = page(nodes('The wind owns the hilltop. A cairn.'));
    await tester.pump();
    expect(tw().shownCharacters, 26);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tw().shownCharacters, 35);

    // A new key types it again; skip shows it all; disabled shows it all.
    (tree.source as DocumentSource).document = page(nodes('The wind owns the hilltop. A cairn.', key: 'b'));
    await tester.pump();
    expect(tw().shownCharacters, 0);
    (tree.source as DocumentSource).document = page(nodes('The wind owns the hilltop. A cairn.', key: 'b', skip: true));
    await tester.pump();
    expect(tw().shownCharacters, 35);
    (tree.source as DocumentSource).document = page(nodes('Other text', key: 'b', enabled: false));
    await tester.pump();
    expect(tw().shownCharacters, 10);
    expect(tw().typing, isFalse);
    expect(api.Typewriter.fromJson(nodes('x', key: 'k')['t']!['typewriter'])!.playKey, 'k');
  });

  testWidgets('a fitted stack scales its board of design size into its box', (tester) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': ['board'], 'layout': {'width': 400, 'height': 300}},
        'board': {
          'type': 'stack',
          'children': ['room'],
          'props': {'fit': 'contain'},
          'layout': {'width': {'fill': 480}, 'height': {'fill': 640}, 'x': {'start': 0, 'end': 0}, 'y': {'start': 0, 'end': 0}},
        },
        'room': {'type': 'box', 'layout': {'width': 96, 'height': 64, 'x': {'start': 240}, 'y': {'start': 320}}},
      },
    });
    final (tree, view) = await show(tester, doc);
    // 400 × 300 box, 480 × 640 board: scale 300 / 640, centered across.
    const k = 300 / 640;
    final left = (400 - 480 * k) / 2;
    final rect = tree.boxOf('room')!.rectIn(view)!;
    expect(rect.left, closeTo(left + 240 * k, 0.01));
    expect(rect.top, closeTo(320 * k, 0.01));
    expect(rect.width, closeTo(96 * k, 0.01));
    expect(api.StackProps.spec.props, contains(api.StackProps.fit));
  });

  testWidgets('a fading loop inside a fitted board is scaled and clipped with it', (tester) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': ['board'], 'layout': {'width': 240, 'height': 320}},
        'board': {
          'type': 'stack',
          'children': ['glow'],
          'props': {'fit': 'contain'},
          'decoration': {'clip': 'hardEdge'},
          'layout': {'width': {'fill': 480}, 'height': {'fill': 640}, 'x': {'start': 0, 'end': 0}, 'y': {'start': 0, 'end': 0}},
        },
        'glow': {
          'type': 'box',
          'layout': {'width': 64, 'height': 64, 'x': {'start': 300}, 'y': {'start': 100}},
          'decoration': {'fills': [{'color': '#FFFF0000'}]},
          'loops': [{'type': 'flicker', 'duration': 600, 'opacityFrom': 0.5, 'opacityTo': 0.9}],
        },
      },
    });
    await show(tester, doc, interactive: true);
    await tester.pump(const Duration(milliseconds: 100));
    // The glow's opacity layer sits under the board's transform (half size).
    final faded = tester.layers.whereType<OpacityLayer>().where((l) => (l.alpha ?? 255) < 255).toList();
    expect(faded, isNotEmpty);
    for (final layer in faded) {
      final transform = Matrix4.identity();
      for (ContainerLayer? l = layer.parent; l != null; l = l.parent) {
        if (l is TransformLayer) transform.multiply(l.transform!);
      }
      expect(transform.getMaxScaleOnAxis() / tester.view.devicePixelRatio, closeTo(0.5, 0.01));
    }
  });
}
