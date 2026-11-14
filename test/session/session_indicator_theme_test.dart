// A generative-UI session without a design system draws its gauges and
// charts in the session's theme, as a site and a session with a design
// system do: the colours a gauge or chart leaves unset come from the
// theme's roles (indicator_theme.dart). With no theme they are the neutral
// set (ink and greys), never a palette of their own.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/control_theme.dart' show themeDataOf;
import 'package:flutter/material.dart' hide TextStyle;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';

import '../../tool/stream/src/replay.dart' show loadDesignSystem;

/// A magenta no neutral or default palette has.
const _magenta = 0xFFD81B60;
const _darkMagenta = 0xFFF48FB1;

final _document = LayoutDocument.fromJson({
  'schema': 3,
  'roots': ['c'],
  'nodes': {
    'c': {'type': 'canvas', 'slots': {'body': 'col'}, 'layout': {'width': 300, 'height': 300}},
    'col': {'type': 'column', 'children': ['meter', 'bars'], 'props': {'spacing': 16}, 'layout': {'width': {'fill': 300}, 'height': {'fill': 300}}},
    'meter': {'type': 'gaugeMeter', 'layout': {'width': 120, 'height': 120}, 'props': {'value': 70}},
    'bars': {'type': 'barChart', 'layout': {'width': 220, 'height': 120}, 'props': {'values': [3, 5, 4], 'labels': ['a', 'b', 'c']}},
  },
});

/// Pixels of the view by ARGB colour.
Future<Map<int, int>> _pixels(WidgetTester tester, GlobalKey key) async => (await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = (await image.toByteData())!;
      image.dispose();
      final out = <int, int>{};
      for (var i = 0; i + 3 < bytes.lengthInBytes; i += 4) {
        final argb = bytes.getUint8(i + 3) << 24 | bytes.getUint8(i) << 16 | bytes.getUint8(i + 1) << 8 | bytes.getUint8(i + 2);
        out[argb] = (out[argb] ?? 0) + 1;
      }
      return out;
    }))!;

Future<Map<int, int>> _render(WidgetTester tester, UiSession session, {Brightness platform = Brightness.light}) async {
  final key = GlobalKey();
  tester.view.physicalSize = const Size(300, 300);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.platformBrightnessTestValue = platform;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: MaterialApp(debugShowCheckedModeBanner: false, home: Material(color: const Color(0xFFFFFFFF), child: CodelesslyView(session: session))),
  ));
  await tester.pumpAndSettle();
  return _pixels(tester, key);
}

int _count(Map<int, int> pixels, int argb) => pixels[argb] ?? 0;

/// Whether [argb] is a grey or ink: no channel more than [spread] from the others.
bool _neutral(int argb, {int spread = 24}) {
  final r = argb >> 16 & 0xFF, g = argb >> 8 & 0xFF, b = argb & 0xFF;
  final hi = [r, g, b].reduce((a, c) => a > c ? a : c), lo = [r, g, b].reduce((a, c) => a < c ? a : c);
  return hi - lo <= spread;
}

void main() {
  testWidgets('a plain session with a theme draws an unstyled gauge and bar chart in its primary', (tester) async {
    final session = UiSession(
        document: _document, theme: ThemeTokens.fromJson({'primary': '#FFD81B60', 'surface': '#FFFFFFFF', 'onSurface': '#FF1A1A1A'}));
    addTearDown(session.dispose);
    final pixels = await _render(tester, session);
    expect(_count(pixels, _magenta), greaterThan(800), reason: 'the meter\'s value and the bars, in the theme\'s primary');
  });

  testWidgets('in the theme\'s dark mode they take its dark primary', (tester) async {
    final session = UiSession(
        document: _document,
        theme: ThemeTokens.fromJson({
          'primary': '#FFD81B60',
          'mode': 'dark',
          'dark': {'primary': '#FFF48FB1', 'surface': '#FF121212', 'onSurface': '#FFEEEEEE'},
        }));
    addTearDown(session.dispose);
    final pixels = await _render(tester, session);
    expect(_count(pixels, _darkMagenta), greaterThan(800));
    expect(_count(pixels, _magenta), 0);
  });

  testWidgets('a plain session with no theme draws them in the neutral set, no palette of their own', (tester) async {
    final session = UiSession(document: _document);
    addTearDown(session.dispose);
    final pixels = await _render(tester, session);
    final primary = themeDataOf(ThemeTokens.none).colorScheme.primary.toARGB32();
    expect(_count(pixels, primary), greaterThan(800), reason: 'the neutral primary (ink)');
    final coloured = {for (final e in pixels.entries) if (e.value > 20 && !_neutral(e.key)) e.key.toRadixString(16): e.value};
    expect(coloured, isEmpty, reason: 'every colour drawn is a grey or ink');
  });

  testWidgets('a session with a design system and one with that design system\'s tokens as its theme draw them alike',
      (tester) async {
    final ds = (await tester.runAsync(() => loadDesignSystem('ssui')))!;
    final withDs = UiSession(document: _document, designSystem: ds);
    addTearDown(withDs.dispose);
    final a = await _render(tester, withDs);
    final plain = UiSession(document: _document, theme: ds.tokens);
    addTearDown(plain.dispose);
    final b = await _render(tester, plain);
    final primary = ds.tokens.primary!.value;
    expect(_count(a, primary), greaterThan(800));
    expect(_count(b, primary), _count(a, primary));
  });
}
