// The guard against Material's default look: one page of every control the
// catalog has (the inputs, material, collections and indicators groups),
// unstyled, rendered without a theme and with a brand theme, each light
// and dark. No pixel may be one of Material 3's baseline (purple seed)
// colors unless the theme itself uses it; pressing, hovering and focusing
// a button shows no ripple and no purple; every text in a control is in
// the theme's font (no family at all without a theme: never Roboto).
//
// With CODELESSLY_THEME_RENDERS=<dir> set, the four renders are written to
// <dir>/<condition>.png before anything is checked (so the same test run
// on an older SDK gives its "before" pictures).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/buttons.dart' show RenderButton;
import 'package:codelessly_sdk/src/render/controls/kit.dart' show LabelledControl, RenderControl;
import 'package:codelessly_sdk/src/widgets/collections.dart' show collectionsRecipes;
import 'package:codelessly_sdk/src/widgets/controls.dart' show controlRecipes;
import 'package:codelessly_sdk/src/widgets/indicators.dart' show indicatorsRecipes;
import 'package:codelessly_sdk/src/widgets/inputs.dart' show inputsRecipes;
import 'package:codelessly_sdk/src/widgets/material.dart' show materialRecipes;
import 'package:flutter/material.dart' hide TextStyle;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

/// Material 3's baseline scheme (seed 0xFF6750A4), light and dark.
const _material3 = <int>[
  // light
  0xFF6750A4, 0xFFFFFFFF, 0xFFEADDFF, 0xFF21005D, 0xFF4F378B, 0xFF625B71, 0xFFE8DEF8, 0xFF1D192B, 0xFF4A4458,
  0xFF7D5260, 0xFFFFD8E4, 0xFF31111D, 0xFF633B48, 0xFFFEF7FF, 0xFFF7F2FA, 0xFFF3EDF7, 0xFFECE6F0, 0xFFE6E0E9,
  0xFFDED8E1, 0xFF1D1B20, 0xFF49454F, 0xFF79747E, 0xFFCAC4D0, 0xFF322F35, 0xFFF5EFF7, 0xFFD0BCFF,
  // dark
  0xFF381E72, 0xFFCCC2DC, 0xFF332D41, 0xFFEFB8C8, 0xFF492532, 0xFF141218, 0xFF0F0D13, 0xFF1D1B20, 0xFF211F26,
  0xFF2B2930, 0xFF36343B, 0xFF3B383E, 0xFFE6E0E9, 0xFFCAC4D0, 0xFF938F99, 0xFF49454F,
];

/// How far (per channel) a pixel may be from a Material color and still be it.
const _near = 2;

const _brand = {
  'primary': '#FF1F6F4A',
  'onPrimary': '#FFFFFFFF',
  'surface': '#FFFBF8F1',
  'onSurface': '#FF23302A',
  'fontFamily': 'Barlow',
  'titleFontFamily': 'Barlow',
  'buttonRadius': 8,
  'radius': 10,
  'dark': {'primary': '#FF7FD1A6', 'onPrimary': '#FF0B2A1B', 'surface': '#FF17201B', 'onSurface': '#FFE8EFE9'},
};

/// The groups whose types are controls (islands and their kin).
final _controlTypes = {
  ...controlRecipes.keys,
  ...inputsRecipes.keys,
  ...materialRecipes.keys,
  ...collectionsRecipes.keys,
  ...indicatorsRecipes.keys,
}.where((t) => t != 'modal');

const _sizes = <String, (double, double)>{
  'textField': (200, 56),
  'checkbox': (24, 24),
  'radio': (24, 24),
  'switch': (52, 32),
  'slider': (200, 48),
  'dropdown': (160, 48),
  'segmentedButton': (220, 40),
  'signature': (200, 80),
  'iconButton': (48, 48),
  'floatingActionButton': (56, 56),
  'badge': (40, 24),
  'listTile': (220, 56),
  'appBar': (340, 56),
  'navigationBar': (340, 80),
  'bottomNavigationBar': (340, 64),
  'tabBar': (340, 48),
  'divider': (160, 16),
  'verticalDivider': (16, 48),
  'circularProgressIndicator': (40, 40),
  'activityIndicator': (40, 40),
  'progressBar': (160, 8),
  'expansionTile': (220, 64),
  'pagination': (340, 48),
  'gaugeMeter': (120, 120),
  'radialGauge': (120, 120),
  'chart': (220, 120),
  'plotChart': (220, 120),
  'barChart': (220, 120),
  'lineChart': (220, 120),
  'barcode': (160, 60),
};

/// Types whose catalog declares a look of their own (a colored default:
/// a gauge's green, a pagination's blue): the model's design, not
/// Material's. They're on the page; their boxes aren't checked here.
bool _designedByCatalog(WidgetSpec spec) => spec.props.any((d) {
      final v = d.defaultValue;
      if (v == null || v.runtimeType.toString() != 'Color') return false;
      final c = (v as dynamic).value as int;
      final a = c >> 24, r = (c >> 16) & 0xFF, g = (c >> 8) & 0xFF, b = c & 0xFF;
      return a > 0 && ((r - g).abs() > 8 || (g - b).abs() > 8);
    });

bool _designed(String? type) {
  final spec = type == null ? null : Catalog.current.widget(type);
  return spec != null && _designedByCatalog(spec);
}

/// Sample values a control needs to show something (a label, items).
Json _props(String type, WidgetSpec spec) {
  final p = <String, Object?>{};
  for (final d in spec.props) {
    if (const {'label', 'title', 'hint', 'labelText', 'helpText'}.contains(d.key) && d.defaultValue is String) {
      p[d.key] = 'Label';
    }
  }
  switch (type) {
    case 'textField':
      p['decoration'] = {'labelText': 'Label', 'hintText': 'Hint'};
    case 'dropdown':
      p['items'] = ['One', 'Two'];
      p['value'] = 'One';
    case 'segmentedButton':
      p['segments'] = [
        {'value': 'a', 'label': 'One'},
        {'value': 'b', 'label': 'Two'},
      ];
      p['selected'] = ['a'];
    case 'tabBar':
      p['tabs'] = [
        {'id': 'a', 'label': 'One'},
        {'id': 'b', 'label': 'Two'},
      ];
    case 'navigationBar' || 'bottomNavigationBar':
      p['destinations'] = [
        {'label': 'Home', 'icon': 'home'},
        {'label': 'Search', 'icon': 'search'},
      ];
    case 'iconButton' || 'floatingActionButton':
      p['icon'] = 'favorite';
    case 'datePicker':
      p['value'] = '2026-11-13';
    case 'timePicker':
      p['value'] = '09:30';
    case 'slider':
      p['value'] = 0.4;
      p['divisions'] = 5;
    case 'progressBar' || 'circularProgressIndicator':
      p['value'] = 0.4;
    case 'badge':
      p['count'] = 3;
  }
  return p;
}

/// The page: each control unstyled, then on (checked, selected) and
/// disabled where it has those states.
Map<String, Object?> _page({required Object? canvasFill}) {
  final nodes = <String, Object?>{};
  final ids = <String>[];
  for (final type in _controlTypes) {
    final spec = Catalog.current.widget(type);
    if (spec == null) continue;
    final base = _props(type, spec);
    final (w, h) = _sizes[type] ?? (160.0, 48.0);
    void add(String id, Json props) {
      nodes[id] = {
        'type': type,
        'layout': {'width': w, 'height': h},
        'props': props,
      };
      ids.add(id);
    }

    add(type, base);
    final on = {...base};
    for (final d in spec.props) {
      if (const {'value', 'selected'}.contains(d.key) && d.defaultValue is bool) on[d.key] = true;
    }
    if (type == 'radio') on['groupValue'] = on['value'] = 'x';
    if (on.length != base.length || type == 'radio') add('$type-on', on);
    final off = {...base};
    for (final d in spec.props) {
      if (const {'enabled', 'isEnabled'}.contains(d.key) && d.defaultValue == true) off[d.key] = false;
    }
    if (off.length != base.length) add('$type-disabled', off);
  }
  // A chip narrower than its selected content: its check mark must not cut
  // the label.
  nodes['chip-narrow'] = {
    'type': 'filterChip',
    'layout': {'width': 72, 'height': 40},
    'props': {'label': 'Engineering', 'selected': true},
  };
  ids.add('chip-narrow');
  nodes['canvas'] = {
    'type': 'canvas',
    'slots': {'body': 'body'},
    'layout': {'width': _view.width, 'height': _view.height},
    if (canvasFill != null)
      'decoration': {
        'fills': [
          {'color': canvasFill},
        ],
      },
  };
  nodes['body'] = {
    'type': 'row',
    'layout': {
      'width': {'fill': _view.width},
      'height': {'fill': _view.height},
      'padding': {'left': 16, 'top': 16, 'right': 16, 'bottom': 16},
    },
    'props': {'wrap': true, 'spacing': 16, 'runSpacing': 16},
    'children': ids,
  };
  return {'schema': 3, 'id': 'controls', 'roots': ['canvas'], 'nodes': nodes};
}

const _view = Size(1100, 1500);

PublishBundle _bundle(Map<String, Object?> page, ThemeTokens? theme) {
  final layout = PublishLayout.fromJson(page);
  return PublishBundle(
    model: PublishModel(
      projectId: 'controls',
      entryLayoutId: layout.id,
      layouts: {layout.id: PublishLayoutInfo.of(layout)},
      theme: theme ?? ThemeTokens.none,
    ),
    layouts: {layout.id: layout},
  );
}

class _Condition {
  const _Condition(this.name, {required this.dark, this.theme, required this.canvasFill});
  final String name;
  final bool dark;
  final Map<String, Object?>? theme;
  final Object? canvasFill;

  ThemeTokens? get tokens => theme == null ? null : ThemeTokens.fromJson(theme);

  /// The colors the theme itself uses (allowed even when Material's).
  Set<int> get themeColors {
    final t = tokens;
    if (t == null) return const {};
    final both = [t, t.forBrightness(dark: true)];
    return {
      for (final x in both)
        for (final c in [x.primary, x.onPrimary, x.surface, x.onSurface, x.error, x.success, x.warning])
          if (c != null) c.value,
    };
  }

  String? get family => tokens?.fontFamily;
}

const _conditions = [
  _Condition('no-theme-light', dark: false, canvasFill: '#FFFFFFFF'),
  _Condition('no-theme-dark', dark: true, canvasFill: '#FF121212'),
  _Condition('brand-theme-light', dark: false, theme: _brand, canvasFill: 'surface'),
  _Condition('brand-theme-dark', dark: true, theme: _brand, canvasFill: 'surface'),
];

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final file = File(f);
      if (file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
  }

  const material = '/opt/flutter/bin/cache/artifacts/material_fonts';
  await load('Roboto', ['$material/Roboto-Regular.ttf', '$material/Roboto-Medium.ttf']);
  await load('MaterialIcons', ['$material/MaterialIcons-Regular.otf']);
  final barlow = [
    for (final w in ['Regular', 'Medium', 'SemiBold']) '../references/backline/assets/fonts/Barlow-$w.ttf',
  ];
  await load('Barlow', barlow);
}

/// [image]'s RGBA bytes.
Future<Uint8List> _rgba(WidgetTester tester, ui.Image image) async =>
    (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!.buffer.asUint8List();

/// The pixels of [rgba] ([width] wide) near a Material color: color → count
/// and the first place.
Map<int, (int, Offset)> _materialPixels(Uint8List rgba, int width, Set<int> allowed,
    {Rect? within, List<Rect> skip = const []}) {
  final palette = [for (final c in _material3) if (!allowed.contains(c)) c];
  final found = <int, (int, Offset)>{};
  final height = rgba.length ~/ (width * 4);
  final area = within ?? Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  for (var y = area.top.floor().clamp(0, height); y < area.bottom.ceil().clamp(0, height); y++) {
    for (var x = area.left.floor().clamp(0, width); x < area.right.ceil().clamp(0, width); x++) {
      final i = (y * width + x) * 4;
      final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
      if (skip.isNotEmpty && skip.any((s) => s.contains(Offset(x + .5, y + .5)))) continue;
      // Material's colors are tinted; a grey can't be one of them.
      if ((r - g).abs() <= 2 * _near && (g - b).abs() <= 2 * _near) continue;
      for (final c in palette) {
        if ((r - ((c >> 16) & 0xFF)).abs() <= _near &&
            (g - ((c >> 8) & 0xFF)).abs() <= _near &&
            (b - (c & 0xFF)).abs() <= _near) {
          final prev = found[c];
          found[c] = (1 + (prev?.$1 ?? 0), prev?.$2 ?? Offset(x.toDouble(), y.toDouble()));
        }
      }
    }
  }
  return found;
}

/// The node whose box holds [p], for a readable failure.
String _nodeAt(CodelesslyWidgetController controller, Offset p) {
  String? best;
  var area = double.infinity;
  for (final box in controller.tree!.boxes) {
    if (!box.attached || !box.hasSize) continue;
    final r = box.localToGlobal(Offset.zero) & box.size;
    if (r.contains(p) && r.width * r.height < area && box.id != 'canvas' && box.id != 'body') {
      area = r.width * r.height;
      best = box.id;
    }
  }
  return best ?? 'the page';
}

Future<(CodelesslyWidgetController, Codelessly)> _show(WidgetTester tester, _Condition c) async {
  tester.view.physicalSize = _view;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.platformBrightnessTestValue = c.dark ? Brightness.dark : Brightness.light;
  final app = Codelessly.fromBundle(_bundle(_page(canvasFill: c.canvasFill), c.tokens), fonts: const NoFontFetcher());
  final controller = CodelesslyWidgetController();
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(key: _boundary, child: CodelesslyWidget(codelessly: app, controller: controller)),
  ));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));
  return (controller, app);
}

final _boundary = GlobalKey();

Future<ui.Image> _capture(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_boundary));
  return (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
}

Future<void> _save(WidgetTester tester, ui.Image image, String name) async {
  final dir = Platform.environment['CODELESSLY_THEME_RENDERS'];
  if (dir == null || dir.isEmpty) return;
  final png = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  Directory(dir).createSync(recursive: true);
  File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
}

/// The texts drawn inside the controls (islands), with their font family.
List<(String, String?)> _controlTexts(WidgetTester tester) {
  final out = <(String, String?)>[];
  void visit(RenderObject o, bool inControl) {
    // A control drawn as a render object sets its own text.
    if (o is LabelledControl) {
      for (final l in o.labels) {
        if (l.text.trim().isNotEmpty) out.add((l.text, l.fontFamily));
      }
    }
    final control = inControl || o is IslandHost;
    if (control && o is RenderParagraph) {
      o.text.visitChildren((span) {
        // Icon glyphs (a private-use code point) are in their icon font.
        if (span is TextSpan && (span.text?.trim().isNotEmpty ?? false) && !_isGlyph(span.text!)) {
          out.add((span.text!, span.style?.fontFamily ?? _inherited(o.text, span)));
        }
        return true;
      });
    }
    if (control && o is RenderEditable) {
      final text = o.text?.toPlainText() ?? '';
      if (text.trim().isNotEmpty) out.add((text, o.text?.style?.fontFamily));
    }
    o.visitChildren((c) => visit(c, control));
  }

  visit(tester.binding.rootElement!.renderObject!, false);
  return out;
}

bool _isGlyph(String text) => text.runes.every((r) => r >= 0xE000 && r <= 0xF8FF || r >= 0xF0000);

String? _inherited(InlineSpan root, InlineSpan target) {
  String? found;
  bool walk(InlineSpan s, String? family) {
    final f = s.style?.fontFamily ?? family;
    if (identical(s, target)) {
      found = f;
      return true;
    }
    if (s is TextSpan) {
      for (final c in s.children ?? const <InlineSpan>[]) {
        if (walk(c, f)) return true;
      }
    }
    return false;
  }

  walk(root, null);
  return found;
}

/// The controls drawn as render objects, by family (each family adds its
/// own line): what must be on the page as a render-object control, with no
/// Material widget's paragraph inside.
const _renderControls = <String, List<String>>{
  'toggles': ['checkbox', 'switch', 'radio', 'slider', 'segmentedButton'],
};

/// The labelled controls whose label must sit centred in their box.
const _labelled = [
  'filledButton', 'elevatedButton', 'outlinedButton', 'textButton', 'segmentedButton', //
  'chip', 'actionChip', 'choiceChip', 'filterChip', 'inputChip', 'tabBar', 'dropdown', 'textField', 'datePicker',
  'timePicker', 'dateTimeInput', 'pagination',
];

/// Each labelled control twice: at its default height and 32 px high, with a
/// value (text field: typed text) and once more with only a hint.
Map<String, Object?> _labelPage() {
  final nodes = <String, Object?>{};
  final ids = <String>[];
  for (final type in _labelled) {
    final spec = Catalog.current.widget(type)!;
    // Pagination as one line of page buttons (its summary is a second line).
    // A field's own text and hint (its label is drawn above it: see
    // field_label_test.dart); pagination as one line of page buttons.
    final base = {
      ..._props(type, spec),
      if (type == 'pagination') 'showSummary': false,
      if (type == 'textField') 'decoration': {'hintText': 'Hint'},
    };
    final (w, h) = _sizes[type] ?? (160.0, 48.0);
    for (final (id, height, props) in [
      ('$type@default', h, base),
      ('$type@32', 32.0, base),
      if (type == 'textField') ...[
        ('$type@default-text', h, {'initialValue': 'Typed'}),
        ('$type@32-text', 32.0, {'initialValue': 'Typed'}),
      ],
    ]) {
      nodes[id] = {
        'type': type,
        'layout': {'width': w, 'height': height},
        'props': props,
      };
      ids.add(id);
    }
  }
  nodes['canvas'] = {
    'type': 'canvas',
    'slots': {'body': 'body'},
    'layout': {'width': _view.width, 'height': _view.height},
    'decoration': {
      'fills': [
        {'color': '#FFFFFFFF'},
      ],
    },
  };
  nodes['body'] = {
    'type': 'row',
    'layout': {
      'width': {'fill': _view.width},
      'height': {'fill': _view.height},
      'padding': {'left': 16, 'top': 16, 'right': 16, 'bottom': 16},
    },
    'props': {'wrap': true, 'spacing': 24, 'runSpacing': 24},
    'children': ids,
  };
  return {'schema': 3, 'id': 'labels', 'roots': ['canvas'], 'nodes': nodes};
}

/// The vertical centre of the glyph box of every non-blank text drawn in
/// [box] (its paragraphs' and editable texts' lines, `BoxHeightStyle.tight`:
/// the font's ascent to descent, as Flutter's Text lays a line out without
/// its leading), in global coordinates.
List<(String, double)> _labelCentres(RenderBox box) {
  final out = <(String, double)>[];
  final area = box.localToGlobal(Offset.zero) & box.size;
  void visit(RenderObject o) {
    List<TextBox>? lines;
    String? text;
    if (o is RenderParagraph) {
      text = o.text.toPlainText();
      if (text.trim().isNotEmpty && !_isGlyph(text.trim())) {
        lines = o.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: text.length),
            boxHeightStyle: ui.BoxHeightStyle.tight);
      }
    } else if (o is RenderEditable) {
      text = o.text?.toPlainText() ?? '';
      if (text.trim().isNotEmpty) {
        lines = [
          for (final p in o.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: text.length)))
            p,
        ];
      }
    }
    if (o is LabelledControl && o.attached) {
      for (final l in o.labels) {
        if (l.glyphs.isEmpty || l.text.trim().isEmpty) continue;
        final top = l.glyphs.map((b) => b.top).reduce((a, b) => a < b ? a : b);
        final bottom = l.glyphs.map((b) => b.bottom).reduce((a, b) => a > b ? a : b);
        final g = o.localToGlobal(Offset(0, (top + bottom) / 2));
        if (area.inflate(1).contains(Offset(area.center.dx, g.dy))) out.add((l.text.trim(), g.dy));
      }
    }
    if (lines != null && lines.isNotEmpty && o is RenderBox && o.attached) {
      final top = lines.map((b) => b.top).reduce((a, b) => a < b ? a : b);
      final bottom = lines.map((b) => b.bottom).reduce((a, b) => a > b ? a : b);
      final g = o.localToGlobal(Offset(0, (top + bottom) / 2));
      if (area.inflate(1).contains(Offset(area.center.dx, g.dy))) out.add((text!.trim(), g.dy));
    }
    o.visitChildren(visit);
  }

  visit(box);
  return out;
}

void main() {
  setUpAll(_loadFonts);

  // Real fonts (Barlow, Roboto), so text is measured by a real ascent and
  // descent, not drawn as test boxes.
  for (final (name, family) in [('Barlow', 'Barlow'), ('Roboto', 'Roboto')]) {
    for (final dark in [false, true]) {
      testWidgets('every labelled control centres its label in its box, default and 32 px high: $name ${dark ? 'dark' : 'light'}',
          (tester) async {
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        tester.view.physicalSize = _view;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
        final theme = ThemeTokens.fromJson({
          'fontFamily': family,
          'surface': '#FFFFFFFF',
          'dark': {'surface': '#FF121212'},
        });
        final app = Codelessly.fromBundle(_bundle(_labelPage(), theme), fonts: const NoFontFetcher());
        final controller = CodelesslyWidgetController();
        addTearDown(() {
          controller.dispose();
          app.dispose();
        });
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(key: _boundary, child: CodelesslyWidget(codelessly: app, controller: controller)),
        ));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 1));
        final dir = Platform.environment['CODELESSLY_THEME_RENDERS'];
        if (dir != null && dir.isNotEmpty) {
          await _save(tester, await _capture(tester), 'labels-$name-${dark ? 'dark' : 'light'}');
        }
        final off = <String>[];
        for (final type in _labelled) {
          for (final id in ['$type@default', '$type@32', if (type == 'textField') ...['$type@default-text', '$type@32-text']]) {
            final box = controller.tree!.boxOf(id)!;
            final centre = (box.localToGlobal(Offset.zero) & box.size).center.dy;
            final labels = _labelCentres(box);
            if (labels.isEmpty) {
              off.add('$id: no label found');
              continue;
            }
            for (final (text, y) in labels) {
              if ((y - centre).abs() > 1) off.add('$id "$text": ${(y - centre).toStringAsFixed(1)} px from the box centre');
            }
          }
        }
        expect(off, isEmpty, reason: 'labels off centre');
      });
    }
  }

  for (final c in _conditions) {
    testWidgets('unstyled controls show no Material default color or font: ${c.name}', (tester) async {
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final (controller, app) = await _show(tester, c);
      addTearDown(() {
        controller.dispose();
        app.dispose();
      });
      expect(controller.isLoaded, isTrue);
      final image = await _capture(tester);
      await _save(tester, image, c.name);
      final rgba = await _rgba(tester, image);
      final designed = [
        for (final box in controller.tree!.boxes)
          if (box.attached && box.hasSize && _designed(box.node?.type)) (box.localToGlobal(Offset.zero) & box.size).inflate(2),
      ];
      final found = _materialPixels(rgba, image.width, c.themeColors, skip: designed);
      final report = [
        for (final e in found.entries)
          '0x${e.key.toRadixString(16).toUpperCase()}: ${e.value.$1} px, first at ${e.value.$2} in ${_nodeAt(controller, e.value.$2)}',
      ];
      expect(report, isEmpty, reason: 'Material 3 baseline colors on screen');

      final texts = _controlTexts(tester);
      expect(texts, isNotEmpty);
      final wrong = [for (final (text, family) in texts) if (family != c.family) '"$text" in $family'];
      expect(wrong, isEmpty, reason: 'every control text in the theme\'s font (${c.family ?? 'no family'})');
    });

    testWidgets('unstyled controls are not Material-shaped: ${c.name}', (tester) async {
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final (controller, app) = await _show(tester, c);
      addTearDown(() {
        controller.dispose();
        app.dispose();
      });

      // Buttons: a rounded rectangle of a small radius, never a stadium.
      for (final type in ['filledButton', 'elevatedButton', 'outlinedButton', 'textButton', 'iconButton']) {
        final buttons = <RenderButton>[];
        void visit(RenderObject o) {
          if (o is RenderButton) buttons.add(o);
          o.visitChildren(visit);
        }

        visit(controller.tree!.boxOf(type)!);
        expect(buttons, hasLength(1), reason: '$type is a render object on the page, not a Material widget');
        final shape = buttons.single.shape;
        expect(shape, isNot(isA<StadiumBorder>()), reason: '$type is a stadium');
        expect(shape, isA<RoundedRectangleBorder>(), reason: '$type shape');
        final radius = (shape as RoundedRectangleBorder).borderRadius.resolve(TextDirection.ltr).topLeft.x;
        expect(radius, inInclusiveRange(1, 12), reason: '$type radius');
      }

      // Render-object controls: drawn by a control's render object, with no
      // island (and so no Material widget) inside their box.
      for (final type in _renderControls.values.expand((t) => t)) {
        final found = <RenderObject>[];
        void visit(RenderObject o) {
          if (o is RenderControl || o is RenderParagraph) found.add(o);
          o.visitChildren(visit);
        }

        visit(controller.tree!.boxOf(type)!);
        expect(found.whereType<RenderControl>(), hasLength(1), reason: '$type is a render-object control');
        expect(found.whereType<RenderParagraph>(), isEmpty, reason: '$type draws its own text');
      }

      // Fields: no underline-only border. A field's border is what its
      // decorator draws (its decoration over the theme's) or the box a
      // fixed-height field paints.
      final borders = <String>[];
      for (final e in find.byType(InputDecorator).evaluate()) {
        final d = (e.widget as InputDecorator).decoration.applyDefaults(Theme.of(e).inputDecorationTheme);
        final b = d.enabledBorder ?? d.border;
        if (b != null && b.isOutline == false && b != InputBorder.none) borders.add('decorator: ${b.runtimeType}');
        if (b == null) borders.add('decorator: no border (Material underline)');
      }
      for (final e in find.byType(DecoratedBox).evaluate()) {
        final d = (e.widget as DecoratedBox).decoration;
        if (d is ShapeDecoration && d.shape is UnderlineInputBorder) borders.add('field box: underline');
      }
      expect(borders.where((b) => !b.contains('none')), isEmpty, reason: 'fields drawn with an underline only');

      // Chips: the label is laid out whole (no check mark eating into it).
      for (final id in ['filterChip-on', 'chip-narrow']) {
        final box = controller.tree!.boxOf(id)!;
        final labels = <RenderParagraph>[];
        void visit(RenderObject o) {
          if (o is RenderParagraph && o.text.toPlainText().trim().length > 1) labels.add(o);
          o.visitChildren(visit);
        }

        visit(box);
        expect(labels, isNotEmpty, reason: '$id has a label');
        for (final label in labels) {
          final whole = label.getMaxIntrinsicWidth(double.infinity);
          expect(label.size.width, greaterThanOrEqualTo(whole - .5), reason: '$id label "${label.text.toPlainText()}" cut');
          expect(label.didExceedMaxLines, isFalse, reason: '$id label wraps or is cut');
        }
      }
    });

    testWidgets('pressing, hovering and focusing a button shows no ripple or purple: ${c.name}', (tester) async {
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final (controller, app) = await _show(tester, c);
      addTearDown(() {
        controller.dispose();
        app.dispose();
      });
      for (final id in ['filledButton', 'textButton', 'outlinedButton', 'iconButton', 'filterChip']) {
        final box = controller.tree!.boxOf(id)!;
        final rect = box.localToGlobal(Offset.zero) & box.size;
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(rect.center);
        await tester.pump(const Duration(milliseconds: 300));
        final press = await tester.startGesture(rect.center);
        await tester.pump(const Duration(milliseconds: 120));
        final features = <Object>[];
        for (final o in _renderObjects(tester)) {
          if (o.runtimeType.toString() == '_RenderInkFeatures') {
            features.addAll(((o as dynamic).debugInkFeatures as List<Object?>? ?? const []).nonNulls);
          }
        }
        expect(features.where((f) => f is InkSplash || f is InkRipple || f is InkSparkle), isEmpty,
            reason: '$id shows a ripple when pressed');
        final image = await _capture(tester);
        final found = _materialPixels(await _rgba(tester, image), image.width, c.themeColors, within: rect.inflate(4));
        expect(found.keys.map((k) => '0x${k.toRadixString(16)}'), isEmpty, reason: '$id pressed and hovered');
        await press.up();
        await mouse.removePointer();
        await tester.pump(const Duration(milliseconds: 300));
      }
    });
  }
}

Iterable<RenderObject> _renderObjects(WidgetTester tester) sync* {
  final stack = [tester.binding.rootElement!.renderObject!];
  while (stack.isNotEmpty) {
    final o = stack.removeLast();
    yield o;
    o.visitChildren(stack.add);
  }
}
