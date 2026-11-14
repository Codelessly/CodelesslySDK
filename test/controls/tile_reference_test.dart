// Zero-prop tiles against SSUI's own renders:
//
// - `accordion` nodes (nothing styled; their header and content texts set as
//   SSUI's Accordion sets its title and content) against soft_saas_ui's own
//   `SoftSaaSAccordion`, rendered by design_systems/ssui/tool/ssui_golden
//   (test/ssui_tiles_golden_test.dart) into
//   design_systems/ssui/examples/renders/ssui-reference/ssui-accordion-*.png;
// - `listTile` nodes (nothing styled; an icon, a title and a subtitle in their
//   slots) against SSUI's ListRow component (components/ListRow.json),
//   rendered here from its definition.
//
// Roboto, light and dark, compared pixel by pixel. With
// CODELESSLY_M3_RENDERS=<dir> the renders are written there
// (design_systems/ssui/examples/renders/m3 holds the committed ones).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/tokens.dart' show ssuiTokens;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The share of pixels that may differ (by more than [_channel] in a
/// channel): text rasterised by another paragraph path, the chevron drawn as
/// a path rather than Lucide's glyph, sub-pixel positions.
const _maxDiffering = 0.005;
const _channel = 40;

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

String _hex(int argb) => '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// SSUI's color [name] for [dark], as its ARGB value.
int _token(String name, bool dark) => ssuiTokens.forBrightness(dark: dark).color(name)!.value;

Map<String, Object?> _text(String text, Map<String, Object?> style, {Object width = const {'hug': 0}}) => {
      'type': 'text',
      'layout': {'width': width, 'height': {'hug': 0}},
      'props': {
        'text': text,
        'style': {'fontFamily': 'Roboto', ...style},
      },
    };

/// SSUI's reference page (tool/ssui_golden/test/ssui_tiles_golden_test.dart)
/// rebuilt from zero-prop accordions: the first open, the others closed.
Map<String, Object?> _accordionPage({required bool dark}) {
  final nodes = <String, Object?>{};
  final items = {
    'What is included?': 'Every feature, for every seat on the team.',
    'Can I cancel at any time?': 'Yes.',
    'Do you offer refunds?': 'Within 30 days.',
  };
  var i = 0;
  for (final e in items.entries) {
    nodes['acc$i'] = {
      'type': 'accordion',
      'layout': {'width': 360, 'height': {'hug': 0}},
      'props': {'expanded': i == 0},
      'children': ['q$i', 'a$i'],
    };
    nodes['q$i'] = _text(e.key, {
      'fontSize': 12,
      'fontWeight': 600,
      'height': 1.4,
      'letterSpacing': -0.01,
      'color': _hex(_token('primaryText', dark)),
    });
    nodes['a$i'] = _text(e.value, {'fontSize': 12, 'height': 1.5, 'color': _hex(_token('secondaryText', dark))},
        width: const {'fill': 326});
    i++;
  }
  nodes['page'] = {
    'type': 'column',
    'layout': {'width': 600, 'height': 400, 'padding': [24, 24, 24, 24]},
    'decoration': {
      'fills': [
        {'color': _hex(_token('secondaryBackground', dark))},
      ],
    },
    'props': {'spacing': 12, 'crossAxisAlignment': 'start'},
    'children': [for (var j = 0; j < items.length; j++) 'acc$j'],
  };
  return {'schema': 3, 'id': 'ssui-accordion', 'roots': ['page'], 'nodes': nodes};
}

const _rows = [
  ('Invoice #1042', '', 'description'),
  ('Ada Lovelace', 'ada@example.com', 'person_outline'),
  ('Settings', '', 'settings'),
];

Map<String, Object?> _rowPage(Map<String, Object?> nodes, List<String> rows, {required bool dark}) => {
      'schema': 3,
      'id': 'rows',
      'roots': ['page'],
      'nodes': {
        ...nodes,
        'page': {
          'type': 'column',
          'layout': {'width': 400, 'height': 220, 'padding': [24, 24, 24, 24]},
          'decoration': {
            'fills': [
              {'color': _hex(_token('primaryBackground', dark))},
            ],
          },
          'props': {'spacing': 0, 'crossAxisAlignment': 'start'},
          // ListRow's texts take the theme's styles, which name no family.
          'defaultTextStyle': {'fontFamily': 'Roboto'},
          'children': rows,
        },
      },
    };

/// SSUI's ListRow calls.
Map<String, Object?> _listRowPage({required bool dark}) {
  final nodes = <String, Object?>{};
  for (var i = 0; i < _rows.length; i++) {
    final (title, sub, icon) = _rows[i];
    nodes['row$i'] = {
      'type': 'ListRow',
      'layout': {'width': 320, 'height': {'hug': 36}},
      // No hairline: a core list tile has none (a list draws its dividers).
      'props': {'title': title, 'subtitle': sub, 'icon': icon, 'divider': false},
    };
  }
  return _rowPage(nodes, [for (var i = 0; i < _rows.length; i++) 'row$i'], dark: dark);
}

/// The same rows as zero-prop list tiles: the icon, title and subtitle as
/// SSUI's ListRow draws them, in the tile's slots.
Map<String, Object?> _listTilePage({required bool dark}) {
  final nodes = <String, Object?>{};
  for (var i = 0; i < _rows.length; i++) {
    final (title, sub, icon) = _rows[i];
    nodes['row$i'] = {
      'type': 'listTile',
      'layout': {'width': 320, 'height': {'hug': 0}},
      'slots': {'leading': 'icon$i', 'title': 'title$i', if (sub.isNotEmpty) 'subtitle': 'sub$i'},
    };
    nodes['icon$i'] = {
      'type': 'icon',
      'layout': {'width': 16, 'height': 16},
      'props': {'icon': icon, 'size': 16, 'color': _hex(_token('secondaryText', dark))},
    };
    nodes['title$i'] = _text(title, {'fontSize': 13, 'height': 1.5, 'leadingDistribution': 'even', 'color': _hex(_token('primaryText', dark))},
        width: const {'fill': 220});
    if (sub.isNotEmpty) {
      nodes['sub$i'] = _text(sub, {'fontSize': 12, 'height': 1.5, 'leadingDistribution': 'even', 'color': _hex(_token('secondaryText', dark))},
          width: const {'fill': 220});
    }
  }
  return _rowPage(nodes, [for (var i = 0; i < _rows.length; i++) 'row$i'], dark: dark);
}

Future<ui.Image> _render(WidgetTester tester, NodeTree tree, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
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

/// The share of the pixels of [area] (in a [width]-wide image) that differ.
double _differing(Uint8List a, Uint8List b, int width, Rect area) {
  var differing = 0, total = 0;
  for (var y = area.top.toInt(); y < area.bottom; y++) {
    for (var x = area.left.toInt(); x < area.right; x++) {
      final i = (y * width + x) * 4;
      total++;
      if ((a[i] - b[i]).abs() > _channel || (a[i + 1] - b[i + 1]).abs() > _channel || (a[i + 2] - b[i + 2]).abs() > _channel) {
        differing++;
      }
    }
  }
  return differing / total;
}

void main() {
  setUpAll(_fonts);

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('zero-prop accordions match SSUI\'s own Accordion: $mode', (tester) async {
      addTearDown(tester.view.reset);
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(_accordionPage(dark: dark))))
        ..theme = ThemeTokens.fromJson({'fontFamily': 'Roboto'})
        ..dark = dark;
      addTearDown(tree.dispose);
      final image = await _render(tester, tree, const Size(600, 400));
      await _save(tester, image, 'tile-accordion-$mode');
      final reference = await _decode(tester, 'design_systems/ssui/examples/renders/ssui-reference/ssui-accordion-$mode.png');
      // SSUI's geometry: a 46 px header, the open one's 52 px panel, 12 apart.
      expect(tree.boxOf('acc0')!.size, const Size(360, 46 + 52));
      expect(tree.boxOf('acc1')!.size, const Size(360, 46));
      final share = _differing(await _rgba(tester, image), reference, 600, const Rect.fromLTRB(24, 24, 384, 238));
      // ignore: avoid_print
      print('SSUI accordion $mode: ${(share * 100).toStringAsFixed(2)} % of the pixels differ');
      expect(share, lessThan(_maxDiffering));
    });

    testWidgets('zero-prop list tiles match SSUI\'s ListRow: $mode', (tester) async {
      addTearDown(tester.view.reset);
      final definition = (jsonDecode(File('design_systems/ssui/components/ListRow.json').readAsStringSync()) as Map).cast<String, Object?>();
      final registry = ComponentRegistry([LayoutDocument.fromJson(definition)])
        ..theme = ssuiTokens.forBrightness(dark: dark).mergedWith(ThemeTokens.fromJson({'fontFamily': 'Roboto'}));
      final doc = LayoutDocument.fromJson(_listRowPage(dark: dark), catalog: standardCatalog + registry.catalog);
      final scope = VariableScope(const []);
      final binder = NodeBinder(scope: scope, projectScope: scope);
      final rows = NodeTree(DocumentSource(doc), binder: binder, components: registry)..dark = dark;
      addTearDown(() {
        rows.dispose();
        binder.dispose();
      });
      final listRows = await _render(tester, rows, const Size(400, 220));
      await _save(tester, listRows, 'tile-listrow-ssui-$mode');
      final reference = await _rgba(tester, listRows);

      final tiles = NodeTree(DocumentSource(LayoutDocument.fromJson(_listTilePage(dark: dark))))
        ..theme = ThemeTokens.fromJson({'fontFamily': 'Roboto'})
        ..dark = dark;
      addTearDown(tiles.dispose);
      final image = await _render(tester, tiles, const Size(400, 220));
      await _save(tester, image, 'tile-listtile-$mode');
      for (var i = 0; i < _rows.length; i++) {
        expect(tiles.boxOf('row$i')!.size.height, closeTo(rows.boxOf('row$i')!.size.height, .5), reason: 'row $i height');
      }
      final share = _differing(await _rgba(tester, image), reference, 400, const Rect.fromLTRB(24, 24, 344, 196));
      // ignore: avoid_print
      print('SSUI ListRow $mode: ${(share * 100).toStringAsFixed(2)} % of the pixels differ');
      expect(share, lessThan(_maxDiffering));
    });
  }
}
