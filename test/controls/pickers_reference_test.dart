// Zero-prop pickers against SSUI's own: the page
// design_systems/ssui/tool/ssui_golden/test/ssui_pickers_test.dart renders
// (a date picker, a 24-hour time picker and an empty date picker, closed,
// then SSUI's calendar on March 2026; Roboto, light and dark), rebuilt from
// core nodes with nothing styled, the calendar opened from the first field,
// compared pixel by pixel with the stored reference
// (design_systems/ssui/examples/renders/ssui-reference/ssui-pickers-*.png).
//
// With CODELESSLY_M3_RENDERS=<dir> the renders are written there.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/kit_pickers.dart';
import 'package:codelessly_sdk/src/render/controls/root.dart';
import 'package:codelessly_sdk/src/runtime/expressions/formula_clock.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The share of the compared pixels that may differ by more than [_channel]
/// in a channel (measured: fields 4.2 % light / 4.8 % dark, calendar 6.1 % /
/// 7.0 %). Nearly all of it is text: SSUI's own `Text` inherits Material's
/// 0.25 letter spacing (its `inputText` token has none, which the SDK
/// follows), so every label sits a fraction of a pixel per glyph apart;
/// the rest is lucide's icon glyphs, which the SDK draws as paths.
const _maxDiffering = 0.09;
const _channel = 40;
const _size = Size(640, 400);

Future<void> _fonts() async {
  const dir = '/opt/flutter/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    roboto.addFont(Future.value(ByteData.sublistView(File('$dir/$f').readAsBytesSync())));
  }
  await roboto.load();
}

Map<String, Object?> _page({required bool dark}) {
  Map<String, Object?> field(String type, Map<String, Object?> props) =>
      {'type': type, 'layout': {'width': 180, 'height': {'hug': 0}}, 'props': props};
  return {
    'schema': 3,
    'id': 'ssui-pickers',
    'roots': ['page'],
    'nodes': {
      'page': {
        'type': 'column',
        'layout': {'width': _size.width, 'height': _size.height, 'padding': [24, 24, 24, 24]},
        'decoration': {
          'fills': [
            {'color': dark ? '#FF1C1C1C' : '#FFF9FAFB'},
          ],
        },
        'props': {'crossAxisAlignment': 'start'},
        'children': ['row'],
      },
      'row': {
        'type': 'row',
        'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
        'props': {'spacing': 12},
        'children': ['date', 'time', 'empty'],
      },
      'date': field('datePicker', {'value': '2026-03-04'}),
      'time': field('timePicker', {'value': '09:30', 'alwaysUse24HourFormat': true}),
      'empty': field('datePicker', {}),
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

/// The share of [ours] in [a] (offset by [shift] in the reference) whose
/// pixels differ from [ref].
(int, int) _differing(Uint8List ours, Uint8List ref, Rect a, Offset shift) {
  var differing = 0, total = 0;
  final w = _size.width.toInt();
  for (var y = a.top.toInt(); y < a.bottom; y++) {
    for (var x = a.left.toInt(); x < a.right; x++) {
      final i = (y * w + x) * 4;
      final j = ((y + shift.dy.toInt()) * w + x + shift.dx.toInt()) * 4;
      total++;
      if ((ours[i] - ref[j]).abs() > _channel || (ours[i + 1] - ref[j + 1]).abs() > _channel || (ours[i + 2] - ref[j + 2]).abs() > _channel) {
        differing++;
      }
    }
  }
  return (differing, total);
}

void main() {
  setUpAll(_fonts);
  setUp(() => FormulaClock.pinned = DateTime(2026, 11, 14));
  tearDown(() => FormulaClock.pinned = null);

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('zero-prop pickers match SSUI\'s own within ${(_maxDiffering * 100).round()} % of the pixels: $mode',
        (tester) async {
      tester.view.physicalSize = _size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(_page(dark: dark))),
          environment: const IslandEnvironment(interactive: true))
        ..theme = ThemeTokens.fromJson({'fontFamily': 'Roboto'})
        ..dark = dark;
      addTearDown(tree.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: NodeView(tree: tree, rootId: 'page', interactive: true)));
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final closed = await _rgba(tester, (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!);
      // Open the first field's calendar.
      final date = tree.boxOf('date')!;
      await tester.tapAt(date.localToGlobal(date.size.center(Offset.zero)));
      await tester.pump();
      final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
      final open = await _rgba(tester, image);
      final dir = Platform.environment['CODELESSLY_M3_RENDERS'];
      if (dir != null && dir.isNotEmpty) {
        final png = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
        Directory(dir).createSync(recursive: true);
        File('$dir/pickers-$mode.png').writeAsBytesSync(png!.buffer.asUint8List());
      }
      final reference = await _decode(tester, 'design_systems/ssui/examples/renders/ssui-reference/ssui-pickers-$mode.png');

      for (final id in ['date', 'time', 'empty']) {
        expect(tree.boxOf(id)!.size, const Size(180, 28), reason: id);
      }
      // The fields, closed.
      final (fd, ft) = _differing(closed, reference, const Rect.fromLTRB(24, 24, 588, 52), Offset.zero);
      // The calendar: SSUI's sits 12 under the row, the popover 4 under the
      // field; header, weekdays and the five rows of March.
      final popup = tester.renderObject<RenderControlRoot>(find.byType(NodeView)).overlayEntries.single as RenderPickerPopup;
      final panel = popup.child!.localToGlobal(Offset.zero);
      expect(panel, const Offset(24, 56));
      final (cd, ct) = _differing(open, reference, Rect.fromLTWH(panel.dx, panel.dy, 236, 212), Offset(24 - panel.dx, 64 - panel.dy));
      // ignore: avoid_print
      print('SSUI pickers $mode: fields ${(fd / ft * 100).toStringAsFixed(2)} %, calendar ${(cd / ct * 100).toStringAsFixed(2)} % of the pixels differ');
      expect(fd / ft, lessThan(_maxDiffering), reason: 'the fields');
      expect(cd / ct, lessThan(_maxDiffering), reason: 'the calendar');
    });
  }
}
