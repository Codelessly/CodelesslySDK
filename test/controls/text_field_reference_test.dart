// Zero-prop text fields against SSUI's own text inputs: the row of three
// fields on the reference page design_systems/ssui/tool/ssui_golden renders
// (an empty one with a hint, one with a value, one with a value and an
// error; Roboto, light and dark), rebuilt from core textField nodes with
// nothing styled but the texts, rendered by the SDK, compared pixel by pixel
// with the stored reference (design_systems/ssui/examples/renders/
// ssui-reference). The other rows of the page are the buttons'
// (ssui_reference_test.dart).
//
// With CODELESSLY_M3_RENDERS=<dir> the renders are written there.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/editable.dart' show CaretBlink;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The share of the field row's pixels that may differ (by more than
/// [_channel] in a channel) from the reference.
const _maxDiffering = 0.01;
const _channel = 40;

/// The field row of the reference page (below six rows of buttons).
const _row = Rect.fromLTRB(24, 344, 712, 396);

Future<void> _fonts() async {
  const dir = '/opt/flutter/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    roboto.addFont(Future.value(ByteData.sublistView(File('$dir/$f').readAsBytesSync())));
  }
  await roboto.load();
}

Map<String, Object?> _page({required bool dark}) {
  Map<String, Object?> field(Map<String, Object?> props) => {
        'type': 'textField',
        'layout': {'width': 220, 'height': {'hug': 0}},
        'props': props,
      };
  return {
    'schema': 3,
    'id': 'ssui-fields',
    'roots': ['page'],
    'nodes': {
      'page': {
        'type': 'column',
        'layout': {'width': 1200, 'height': 760, 'padding': [24, 24, 24, 24]},
        'decoration': {
          'fills': [
            {'color': dark ? '#FF1C1C1C' : '#FFF9FAFB'},
          ],
        },
        'props': {'crossAxisAlignment': 'start'},
        'children': ['above', 'row'],
      },
      // The six rows of buttons above the fields.
      'above': {'type': 'box', 'layout': {'width': 10, 'height': 320}},
      'row': {
        'type': 'row',
        'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
        'props': {'spacing': 12, 'crossAxisAlignment': 'center'},
        'children': ['empty', 'filled', 'error'],
      },
      'empty': field({'decoration': {'hintText': 'Full name'}}),
      'filled': field({'initialValue': 'ada@example.com'}),
      'error': field({'initialValue': 'ada@example.com', 'decoration': {'errorText': 'Enter an email.'}}),
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

Future<void> _save(WidgetTester tester, ui.Image image, String name) async {
  final dir = Platform.environment['CODELESSLY_M3_RENDERS'];
  if (dir == null || dir.isEmpty) return;
  final png = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  Directory(dir).createSync(recursive: true);
  File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  setUpAll(_fonts);
  setUp(() => CaretBlink.enabled = false);
  tearDown(() => CaretBlink.enabled = true);

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('zero-prop text fields match SSUI\'s own text inputs within ${(_maxDiffering * 100).round()} % of the pixels: $mode',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(_page(dark: dark))))
        ..theme = ThemeTokens.fromJson({'fontFamily': 'Roboto'})
        ..dark = dark;
      addTearDown(tree.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: NodeView(tree: tree, rootId: 'page')));
      await tester.pump();
      final image = (await tester.runAsync(() => tester.renderObject<RenderRepaintBoundary>(find.byKey(key)).toImage(pixelRatio: 1)))!;
      await _save(tester, image, 'text-fields-$mode');
      final ours = await _rgba(tester, image);
      final reference = await _decode(tester, 'design_systems/ssui/examples/renders/ssui-reference/ssui-$mode.png');
      for (final id in ['empty', 'filled']) {
        expect(tree.boxOf(id)!.size, const Size(220, 28), reason: id);
      }
      var differing = 0, total = 0;
      for (var y = _row.top.toInt(); y < _row.bottom; y++) {
        for (var x = _row.left.toInt(); x < _row.right; x++) {
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
      print('SSUI text fields $mode: ${(share * 100).toStringAsFixed(2)} % of the pixels differ');
      expect(share, lessThan(_maxDiffering));
    });
  }
}
