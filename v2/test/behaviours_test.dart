import 'package:codelessly_api_v2/codelessly_api.dart' as api;
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
  testWidgets('the design canvas draws behaviours at rest', (tester) async {
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
    // its centre.
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
}
