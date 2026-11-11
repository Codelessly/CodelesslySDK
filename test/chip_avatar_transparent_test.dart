import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// A chip on a red page, captured: the colour at [at] in the chip's box.
Future<Color> _pixel(WidgetTester tester, Map<String, Object?> chipProps, Offset at) async {
  final source = DocumentSource(LayoutDocument.fromJson({
    'roots': ['root'],
    'nodes': {
      'root': {
        'type': 'column',
        'children': ['chip'],
        'layout': {'width': 300, 'height': 80},
        'props': {'crossAxisAlignment': 'start'},
        'decoration': {
          'fills': [
            {'color': '#FFFF0000'}
          ]
        },
      },
      'chip': {
        'type': 'choiceChip',
        'layout': {'width': {'hug': 0}, 'height': 32},
        'props': {'label': 'North', ...chipProps},
      },
    },
  }));
  final scope = VariableScope(const []);
  final tree = NodeTree(source, binder: NodeBinder(scope: scope));
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
      home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(key: key, child: NodeView(tree: tree, rootId: 'root', interactive: true)))));
  await tester.pumpAndSettle();
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late Color color;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final i = ((at.dy.round() * image.width) + at.dx.round()) * 4;
    color = Color.fromARGB(bytes.getUint8(i + 3), bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2));
  });
  addTearDown(() {
    tree.dispose();
    scope.dispose();
  });
  return color;
}

void main() {
  testWidgets('a transparent chip background shows what is behind it', (tester) async {
    final c = await _pixel(tester, {'backgroundColor': '#00000000', 'showCheckmark': false}, const Offset(14, 24));
    expect(c, const Color(0xFFFF0000));
  });

  testWidgets('a chip avatar named without a codepoint is drawn', (tester) async {
    final source = DocumentSource(LayoutDocument.fromJson({
      'roots': ['chip'],
      'nodes': {
        'chip': {
          'type': 'choiceChip',
          'layout': {'width': {'hug': 0}, 'height': 32},
          'props': {
            'label': 'Civic',
            'avatar': {'type': 'MATERIAL_ICON', 'name': 'circle', 'style': 'filled'},
            'avatarSize': 9,
            'avatarColor': '#FF1F4E8C',
          },
        },
      },
    }));
    final scope = VariableScope(const []);
    final tree = NodeTree(source, binder: NodeBinder(scope: scope));
    await tester.pumpWidget(MaterialApp(home: Center(child: NodeView(tree: tree, rootId: 'chip', interactive: true))));
    expect(tester.widget<ChoiceChip>(find.byType(ChoiceChip)).avatar, isNotNull);
    tree.dispose();
    scope.dispose();
  });
}
