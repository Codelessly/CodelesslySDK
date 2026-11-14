// Zero-prop buttons against SSUI's own Flutter widgets: the page
// design_systems/ssui/tool/ssui_golden renders (every variant at every size,
// an icon button and two disabled ones; Roboto, light and dark), rebuilt from
// core button nodes with nothing styled but the variant's colour, rendered
// by the SDK, compared pixel by pixel with the stored reference
// (design_systems/ssui/examples/renders/ssui-reference).
//
// SSUI variant → core node: primary = filledButton; secondary, destructive =
// filledButton with that fill; outline = outlinedButton; ghost = textButton.
// SSUI size → the node's height (24, 28, 32, 36, 44); compact (28) is a
// button with no size at all (it hugs).
//
// With CODELESSLY_M3_RENDERS=<dir> the renders are written there
// (design_systems/ssui/examples/renders/m3 holds the committed ones).
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
/// paragraph path and sub-pixel label positions, nothing else.
const _maxDiffering = 0.005;
const _channel = 40;

/// The button rows of the reference page: y 24 to 332, x 24 to 700.
const _rows = Rect.fromLTRB(24, 24, 700, 332);

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

const _sizes = {'xs': 24.0, 'compact': null, 'small': 32.0, 'medium': 36.0, 'large': 44.0};

Map<String, Object?> _page({required bool dark}) {
  final nodes = <String, Object?>{};
  final rows = <String>[];
  Map<String, Object?> button(String type, String label, double? height, {String? fill, bool enabled = true, Map<String, Object?>? icon}) => {
        'type': type,
        'layout': {'width': {'hug': 0}, 'height': height == null ? {'hug': 0} : height},
        'props': {
          'label': label,
          if (!enabled) 'enabled': false,
          'icon': ?icon,
          if (fill != null) 'style': {'backgroundColor': fill},
        },
      };
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

  final variants = {
    'Primary': ('filledButton', null),
    'Secondary': ('filledButton', dark ? '#FF4A4A4A' : '#FF374151'),
    'Outline': ('outlinedButton', null),
    'Ghost': ('textButton', null),
    'Destructive': ('filledButton', dark ? '#FFEF4444' : '#FFDC2626'),
  };
  for (final v in variants.entries) {
    row('row${v.key}', {
      for (final s in _sizes.entries) '${v.key}-${s.key}': button(v.value.$1, '${v.key} ${s.key}', s.value, fill: v.value.$2),
    });
  }
  row('rowMore', {
    'newFile': button('filledButton', 'New file', null,
        icon: {'source': 'icon', 'type': 'MATERIAL_ICON', 'name': 'add', 'codepoint': 0xe047, 'style': 'filled'}),
    'disabledFilled': button('filledButton', 'Disabled', null, enabled: false),
    'disabledOutline': button('outlinedButton', 'Disabled', null, enabled: false),
  });
  nodes['page'] = {
    'type': 'column',
    'layout': {'width': 1200, 'height': 760, 'padding': [24, 24, 24, 24]},
    'decoration': {
      'fills': [
        {'color': dark ? '#FF1C1C1C' : '#FFF9FAFB'},
      ],
    },
    'props': {'spacing': 12, 'crossAxisAlignment': 'start'},
    'children': rows,
  };
  return {'schema': 3, 'id': 'ssui-buttons', 'roots': ['page'], 'nodes': nodes};
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
    testWidgets('zero-prop buttons match SSUI\'s own buttons within ${(_maxDiffering * 100).round()} % of the pixels: $mode',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(_page(dark: dark))))
        ..theme = ThemeTokens.fromJson({'fontFamily': 'Roboto'})
        ..dark = dark;
      addTearDown(tree.dispose);
      final image = await _render(tester, tree);
      await _save(tester, image, 'buttons-$mode');
      final ours = await _rgba(tester, image);
      final reference = await _decode(tester, 'design_systems/ssui/examples/renders/ssui-reference/ssui-$mode.png');

      // The same geometry: every variant at every size is SSUI's height.
      for (final v in ['Primary', 'Secondary', 'Outline', 'Ghost', 'Destructive']) {
        for (final s in _sizes.entries) {
          final box = tree.boxOf('$v-${s.key}')!;
          expect(box.size.height, s.value ?? 28, reason: '$v ${s.key}');
        }
      }

      var differing = 0, total = 0;
      for (var y = _rows.top.toInt(); y < _rows.bottom; y++) {
        for (var x = _rows.left.toInt(); x < _rows.right; x++) {
          final i = (y * 1200 + x) * 4;
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
      print('SSUI buttons $mode: ${(share * 100).toStringAsFixed(2)} % of the pixels differ');
      expect(share, lessThan(_maxDiffering));
    });
  }
}
