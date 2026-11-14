// SSUI's reference page of toggles, sliders and segmented controls
// (design_systems/ssui/tool/ssui_golden/test/ssui_toggles_test.dart renders
// soft_saas_ui's own widgets into
// design_systems/ssui/examples/renders/ssui-reference/ssui-toggles-*.png),
// rebuilt from core nodes with nothing styled but their values, and how
// the SDK's render compares with it.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' as api show WidgetState;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The page's size.
const ssuiTogglesSize = Size(600, 240);

/// Where the reference renders are.
String ssuiTogglesReference(bool dark) =>
    'design_systems/ssui/examples/renders/ssui-reference/ssui-toggles-${dark ? 'dark' : 'light'}.png';

/// Roboto, as the reference is set in.
Future<void> loadRoboto() async {
  const dir = '/opt/flutter/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    roboto.addFont(Future.value(ByteData.sublistView(File('$dir/$f').readAsBytesSync())));
  }
  await roboto.load();
}

/// The page: a row of toggles, a row of sliders, a row of segmented
/// controls; every node hugs (the sliders are 240 and 160 wide) and sets
/// only its value.
Map<String, Object?> ssuiTogglesPage({required bool dark}) {
  final nodes = <String, Object?>{};
  final rows = <String>[];
  Map<String, Object?> hug(String type, Map<String, Object?> props, {Object? width, Object? height}) => {
        'type': type,
        'layout': {'width': width ?? {'hug': 0}, 'height': height ?? {'hug': 0}},
        'props': props,
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

  const days = [
    {'value': 'd', 'label': 'Day'},
    {'value': 'w', 'label': 'Week'},
    {'value': 'm', 'label': 'Month'},
  ];
  row('toggles', {
    'checked': hug('checkbox', {'value': true}),
    'unchecked': hug('checkbox', {'value': false}),
    'mixed': hug('checkbox', {'tristate': true}),
    'radioOn': hug('radio', {'value': 'a', 'groupValue': 'a'}),
    'radioOff': hug('radio', {'value': 'b', 'groupValue': 'a'}),
    'switchOn': hug('switch', {'value': true}),
    'switchOff': hug('switch', {}),
    'checkedOff': hug('checkbox', {'value': true}),
    'switchDisabled': hug('switch', {'value': true, 'enabled': false}),
  });
  row('sliders', {
    'half': hug('slider', {'value': 50, 'max': 100}, width: 240),
    'most': hug('slider', {'value': 80, 'max': 100}, width: 160),
  });
  // SSUI's Flutter segmented control inherits Material's 0.25 letter
  // spacing from ThemeData's typography (the design system's control text
  // styles have none, nor do the SDK's segments): the page sets it so the
  // labels line up with the reference's.
  const spacing = {'letterSpacing': 0.25};
  row('segments', {
    'week': hug('segmentedButton', {'segments': days, 'selected': ['w'], 'textStyle': spacing}),
    'dayXs': hug('segmentedButton', {'segments': days, 'selected': ['d'], 'textStyle': spacing}, height: 24),
    'monthSmall': hug('segmentedButton', {'segments': days, 'selected': ['m'], 'textStyle': spacing}, height: 32),
  });
  nodes['page'] = {
    'type': 'column',
    'layout': {'width': ssuiTogglesSize.width, 'height': ssuiTogglesSize.height, 'padding': [24, 24, 24, 24]},
    'decoration': {
      'fills': [
        {'color': dark ? '#FF1C1C1C' : '#FFF9FAFB'},
      ],
    },
    'props': {'spacing': 12, 'crossAxisAlignment': 'start'},
    'children': rows,
  };
  return {'schema': 3, 'id': 'ssui-toggles', 'roots': ['page'], 'nodes': nodes};
}

/// The page rendered by the SDK at 1×, in Roboto ([dark] or light), as RGBA.
Future<(NodeTree, ui.Image)> renderSsuiToggles(WidgetTester tester, {required bool dark}) async {
  tester.view.physicalSize = ssuiTogglesSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(ssuiTogglesPage(dark: dark))))
    ..theme = ThemeTokens.fromJson({'fontFamily': 'Roboto'})
    ..dark = dark;
  addTearDown(tree.dispose);
  tree.setState('checkedOff', api.WidgetState.disabled, true);
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: key, child: NodeView(tree: tree, rootId: 'page')));
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
  return (tree, image);
}

Future<Uint8List> rgbaOf(WidgetTester tester, ui.Image image) async =>
    (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!.buffer.asUint8List();

Future<Uint8List> decodePng(WidgetTester tester, String path) async {
  final bytes = File(path).readAsBytesSync();
  final image = (await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(bytes);
    return (await codec.getNextFrame()).image;
  }))!;
  return rgbaOf(tester, image);
}

/// Writes [image] to CODELESSLY_M3_RENDERS/[name].png when that is set.
Future<void> saveRender(WidgetTester tester, ui.Image image, String name) async {
  final dir = Platform.environment['CODELESSLY_M3_RENDERS'];
  if (dir == null || dir.isEmpty) return;
  final png = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  Directory(dir).createSync(recursive: true);
  File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
}

/// The share of the pixels in [area] that differ (by more than [channel]
/// in a channel) between [a] and [b], both [width] wide.
double differingShare(Uint8List a, Uint8List b, int width, Rect area, {int channel = 40}) {
  var differing = 0, total = 0;
  for (var y = area.top.toInt(); y < area.bottom; y++) {
    for (var x = area.left.toInt(); x < area.right; x++) {
      final i = (y * width + x) * 4;
      total++;
      if ((a[i] - b[i]).abs() > channel || (a[i + 1] - b[i + 1]).abs() > channel || (a[i + 2] - b[i + 2]).abs() > channel) {
        differing++;
      }
    }
  }
  return total == 0 ? 0 : differing / total;
}
