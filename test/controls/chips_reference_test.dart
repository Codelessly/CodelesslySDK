// Zero-prop chips and badges against SSUI's own Flutter widgets: the page
// design_systems/ssui/tool/ssui_golden/test/ssui_chips_golden_test.dart
// renders (SoftSaaSChip with and without an icon, SoftSaaSBadge; Roboto,
// light and dark), rebuilt from core `chip` and `badge` nodes with nothing
// styled, compared pixel by pixel with the stored reference
// (design_systems/ssui/examples/renders/ssui-reference/chips-*.png).
//
// With CODELESSLY_M3_RENDERS=<dir> the renders are written there.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The share of the button rows' pixels that may differ (by more than
/// [_channel] in a channel) from the reference: text rasterised by another
/// paragraph path, sub-pixel label positions and the pill's antialiasing.
const _maxDiffering = 0.005;
const _channel = 40;

/// The chip and badge rows of the reference page.
const _rows = Rect.fromLTRB(16, 16, 320, 96);

Future<void> _fonts() async {
  const dir = '/opt/flutter/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    roboto.addFont(Future.value(ByteData.sublistView(File('$dir/$f').readAsBytesSync())));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(File('$dir/MaterialIcons-Regular.otf').readAsBytesSync())));
  await icons.load();
}


Map<String, Object?> _page({required bool dark}) {
  final nodes = <String, Object?>{};
  final rows = <String>[];
  void row(String id, Map<String, Map<String, Object?>> children) {
    nodes[id] = {
      'type': 'row',
      'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
      'props': {'spacing': 12, 'crossAxisAlignment': 'center'},
      'children': children.keys.toList(),
    };
    nodes.addAll(children);
    rows.add(id);
  }

  row('chips', {
    'design': {'type': 'chip', 'props': {'label': 'Design'}},
    'engineering': {'type': 'chip', 'props': {'label': 'Engineering'}},
    'tagged': {
      'type': 'chip',
      'props': {
        'label': 'Tagged',
        'avatar': {'source': 'icon', 'type': 'MATERIAL_ICON', 'name': 'sell', 'codepoint': 0xe570, 'style': 'filled'},
      },
    },
  });
  row('badges', {
    'draft': {'type': 'badge', 'props': {'label': 'Draft'}},
    'archived': {'type': 'badge', 'props': {'label': 'Archived'}},
  });
  nodes['page'] = {
    'type': 'column',
    'layout': {'width': 600, 'height': 160, 'padding': [24, 24, 24, 24]},
    'decoration': {
      'fills': [
        {'color': dark ? '#FF1C1C1C' : '#FFF9FAFB'},
      ],
    },
    'props': {'spacing': 12, 'crossAxisAlignment': 'start'},
    'children': rows,
  };
  return {'schema': 3, 'id': 'ssui-chips', 'roots': ['page'], 'nodes': nodes};
}

Future<ui.Image> _render(WidgetTester tester, NodeTree tree) async {
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: key, child: NodeView(tree: tree, rootId: 'page')));
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  return (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
}

Future<Uint8List> _rgba(WidgetTester tester, ui.Image image) async =>
    (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!.buffer.asUint8List();

Future<Uint8List> _decode(WidgetTester tester, String path) async {
  final bytes = File(path).readAsBytesSync();
  final image = (await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(bytes);
    return (await codec.getNextFrame()).image;
  }))!;
  return _rgba(tester, image);
}

Future<void> _save(WidgetTester tester, ui.Image image, String name) async {
  final dir = Platform.environment['CODELESSLY_M3_RENDERS'];
  if (dir == null || dir.isEmpty) return;
  final png = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  Directory(dir).createSync(recursive: true);
  File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  setUpAll(_fonts);

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('zero-prop chips and badges match SSUI\'s own within ${(_maxDiffering * 100).round()} % of the pixels: $mode',
        (tester) async {
      tester.view.physicalSize = const Size(600, 160);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(_page(dark: dark))))
        ..theme = ThemeTokens.fromJson({'fontFamily': 'Roboto'})
        ..dark = dark;
      addTearDown(tree.dispose);
      final image = await _render(tester, tree);
      await _save(tester, image, 'chips-$mode');
      final ours = await _rgba(tester, image);
      final reference = await _decode(tester, 'design_systems/ssui/examples/renders/ssui-reference/chips-$mode.png');
      for (final id in ['design', 'engineering', 'tagged']) {
        expect(tree.boxOf(id)!.size.height, 24, reason: id);
      }
      for (final id in ['draft', 'archived']) {
        expect(tree.boxOf(id)!.size.height, 20, reason: id);
      }
      var differing = 0, total = 0;
      for (var y = _rows.top.toInt(); y < _rows.bottom; y++) {
        for (var x = _rows.left.toInt(); x < _rows.right; x++) {
          final i = (y * 600 + x) * 4;
          total++;
          if ((ours[i] - reference[i]).abs() > _channel ||
              (ours[i + 1] - reference[i + 1]).abs() > _channel ||
              (ours[i + 2] - reference[i + 2]).abs() > _channel) {
            differing++;
          }
        }
      }
      final share = differing / total;
      // ignore: avoid_print
      print('SSUI chips $mode: ${(share * 100).toStringAsFixed(2)} % of the pixels differ');
      expect(share, lessThan(_maxDiffering));
    });
  }
}
