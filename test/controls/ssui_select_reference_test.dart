// Zero-prop dropdowns against SSUI's own Select (soft_saas_ui's
// `SoftSaaSDropdown`): the page design_systems/ssui/tool/ssui_golden/test/
// ssui_select_test.dart renders (a select with a value, an empty one with
// its placeholder, and one open on its menu; Roboto, light and dark),
// rebuilt from core `dropdown` nodes with nothing styled but the items,
// value and hint, rendered by the SDK and compared pixel by pixel with the
// stored reference (design_systems/ssui/examples/renders/ssui-reference).
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

/// The share of the page's pixels that may differ (by more than [_channel]
/// in a channel) from the reference.
const _maxDiffering = 0.01;
const _channel = 40;
const _view = Size(480, 300);

Future<void> _fonts() async {
  const dir = '/opt/flutter/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    roboto.addFont(Future.value(ByteData.sublistView(File('$dir/$f').readAsBytesSync())));
  }
  await roboto.load();
}

Map<String, Object?> _page({required bool dark}) {
  Map<String, Object?> select(double x, double y, Map<String, Object?> props) => {
        'type': 'dropdown',
        'layout': {'x': x, 'y': y, 'width': 200, 'height': {'hug': 0}},
        'props': {'items': ['Weekly', 'Monthly', 'Yearly'], ...props},
      };
  return {
    'schema': 3,
    'id': 'ssui-select',
    'roots': ['page'],
    'nodes': {
      'page': {
        'type': 'stack',
        'layout': {'width': _view.width, 'height': _view.height},
        'decoration': {
          'fills': [
            {'color': dark ? '#FF1C1C1C' : '#FFF9FAFB'},
          ],
        },
        'children': ['chosen', 'empty', 'open'],
      },
      'chosen': select(24, 24, {'value': 'Monthly'}),
      'empty': select(248, 24, {'hint': 'Select…'}),
      'open': select(24, 76, {'value': 'Monthly'}),
    },
  };
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

void main() {
  setUpAll(_fonts);

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('zero-prop dropdowns and their menu match SSUI\'s own Select: $mode', (tester) async {
      tester.view.physicalSize = _view;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(_page(dark: dark))),
          environment: const IslandEnvironment(interactive: true))
        ..theme = ThemeTokens.fromJson({'fontFamily': 'Roboto'})
        ..dark = dark;
      addTearDown(tree.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: NodeView(tree: tree, rootId: 'page', interactive: true)));
      final open = tree.boxOf('open')!;
      await tester.tapAt(open.localToGlobal(open.size.center(Offset.zero)));
      await tester.pump();
      // The pointer leaves (no row hovered, as in the reference).
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
      final dir = Platform.environment['CODELESSLY_M3_RENDERS'];
      if (dir != null && dir.isNotEmpty) {
        final png = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
        Directory(dir).createSync(recursive: true);
        File('$dir/dropdown-$mode.png').writeAsBytesSync(png!.buffer.asUint8List());
      }
      final ours = await _rgba(tester, image);
      final reference = await _decode(tester, 'design_systems/ssui/examples/renders/ssui-reference/ssui-select-$mode.png');

      expect(tree.boxOf('chosen')!.size, const Size(200, 28));
      var differing = 0, total = 0;
      for (var y = 0; y < _view.height; y++) {
        for (var x = 0; x < _view.width; x++) {
          final i = (y * _view.width.toInt() + x) * 4;
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
      print('SSUI select $mode: ${(share * 100).toStringAsFixed(2)} % of the pixels differ');
      expect(share, lessThan(_maxDiffering));
    });
  }
}
