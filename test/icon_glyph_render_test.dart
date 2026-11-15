// An icon with `render: glyph` draws its MaterialIcons font glyph exactly as
// Flutter's Icon draws Icons.* (and loads no SVG): a design that matches a
// Flutter app's icons pixel for pixel.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/paint/icon_glyph.dart';
import 'package:flutter/material.dart' hide Icon;
import 'package:flutter/material.dart' as m show Icon;
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadIconFont() async {
  final dir = '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}/bin/cache/artifacts/material_fonts';
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(File('$dir/MaterialIcons-Regular.otf').readAsBytesSync()))))
      .load();
}

Future<List<int>> _pixels(WidgetTester tester, Widget child) async {
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
      home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(key: key, child: ColoredBox(color: const Color(0xFF0E0E10), child: child)))));
  late List<int> out;
  await tester.runAsync(() async {
    final img = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
    out = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List().toList();
  });
  return out;
}

void main() {
  setUpAll(_loadIconFont);

  test('Flutter names by style', () {
    expect(IconSources.flutterCodepointOf('lock', 'rounded'), Icons.lock_rounded.codePoint);
    expect(IconSources.flutterCodepointOf('lock', null), Icons.lock.codePoint);
    expect(IconSources.flutterCodepointOf('backspace', 'outlined'), Icons.backspace_outlined.codePoint);
    expect(IconSources.flutterCodepointOf('lock_rounded', 'rounded'), Icons.lock_rounded.codePoint);
    expect(IconSources.flutterCodepointOf('not_an_icon_name', 'rounded'), isNull);
    expect(IconSources.drawsGlyph({'type': 'MATERIAL_ICON', 'name': 'lock', 'style': 'rounded'}), isFalse);
    expect(IconSources.drawsGlyph({'type': 'MATERIAL_ICON', 'name': 'lock', 'style': 'rounded', 'render': 'glyph'}), isTrue);
  });

  for (final (name, style, flutter, size) in [
    ('lock', 'rounded', Icons.lock_rounded, 34.0),
    ('backspace', 'outlined', Icons.backspace_outlined, 26.0),
    ('event', 'rounded', Icons.event_rounded, 24.0),
  ]) {
    testWidgets('$name $style at $size draws as Flutter\'s Icon', (tester) async {
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
        'roots': ['n'],
        'nodes': {
          'n': {
            'type': 'icon',
            'layout': {'width': size, 'height': size},
            'props': {
              'icon': {'type': 'MATERIAL_ICON', 'name': name, 'style': style, 'render': 'glyph'},
              'color': '#FFF7F5F0',
              'size': size,
            },
          },
        },
      })));
      final node = await _pixels(tester, NodeView(tree: tree, rootId: 'n'));
      tree.dispose();
      final reference = await _pixels(tester, m.Icon(flutter, size: size, color: const Color(0xFFF7F5F0)));
      expect(node, reference);
    });
  }
}
