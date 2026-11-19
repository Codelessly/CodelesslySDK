import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_sdk/src/features/media/players.dart';
import 'package:codelessly_sdk/src/render/control_theme.dart';
import 'package:codelessly_sdk/src/render/node_view.dart';
import 'package:codelessly_sdk/src/render/paint/shell_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

// The buttons and the seek bar of the runtime's own chrome (the toast, the
// confirm dialog, the players, a list's Undo bar and jump-to-latest button)
// are the SDK's controls. They are held here to the pixels of the Material
// widgets they took the place of, at rest, under the SDK's theme.

final _tokens = api.ThemeTokens.fromJson({
  'primary': '#FF4B6CE5',
  'surface': '#FFFFFFFF',
  'onSurface': '#FF14181F',
  'buttonRadius': 9,
});

Future<Uint8List> _pixels(WidgetTester tester, Widget child,
    {TextDirection direction = TextDirection.ltr, bool dark = false}) async {
  final key = GlobalKey();
  // Shadows are drawn for real, as an app draws them (the seek bar's thumb
  // lies on its track with a shadow of no height).
  debugDisableShadows = false;
  addTearDown(() => debugDisableShadows = true);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(Directionality(
    textDirection: direction,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Theme(
        data: themeDataOf(_tokens, brightness: dark ? Brightness.dark : Brightness.light),
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: const Color(0xFFF2F2F2),
              child: SizedBox(
                width: 320.5,
                height: 120.5,
                // (Material's slider asks for an overlay.)
                child: Overlay(
                  initialEntries: [
                    OverlayEntry(
                      builder: (_) => Material(
                        type: MaterialType.transparency,
                        child: ControlHost(child: Center(child: child)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 400));
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late Uint8List bytes;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    image.dispose();
  });
  if (const String.fromEnvironment('PARITY_DUMP') != '') {
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      File('${const String.fromEnvironment('PARITY_DUMP')}/${_dump++}.png').writeAsBytesSync(png);
    });
  }
  await tester.pumpWidget(const SizedBox());
  debugDisableShadows = true;
  return bytes;
}

int _dump = 0;

/// The two pictures (641 px wide) are the same, pixel for pixel; a failure
/// says how many pixels differ, by how much at most, and where.
void _expectSame(Uint8List own, Uint8List material) {
  const width = 641;
  var count = 0, most = 0, left = width, top = 1 << 30, right = -1, bottom = -1;
  for (var i = 0; i < own.length && i < material.length; i += 4) {
    var d = 0;
    for (var c = 0; c < 4; c++) {
      final e = (own[i + c] - material[i + c]).abs();
      if (e > d) d = e;
    }
    if (d == 0) continue;
    count++;
    if (d > most) most = d;
    final x = (i ~/ 4) % width, y = (i ~/ 4) ~/ width;
    if (x < left) left = x;
    if (x > right) right = x;
    if (y < top) top = y;
    if (y > bottom) bottom = y;
  }
  expect(own.length, material.length);
  expect(count, 0, reason: '$count pixels differ, by at most $most of 255, in x $left..$right, y $top..$bottom');
}

/// The text style of a button's label as the chrome makes it: the theme's
/// body text (so its leading is even, as Material 3's is) with what the
/// chrome sets.
TextStyle _label(BuildContext context, {required double size, required FontWeight weight, double? height}) =>
    Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: size, fontWeight: weight, height: height);

void main() {
  // The icons are the MaterialIcons font's glyphs.
  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT']!;
    final font = File('$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
    final loader = FontLoader('MaterialIcons')..addFont(font.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  });

  group('a labeled button draws what a TextButton or a FilledButton of the same style drew', () {
    const ink = Color(0xFF14181F);
    for (final (name, label, background, side, style, min, max, padding) in <(
      String,
      String,
      Color?,
      BorderSide?,
      TextStyle Function(BuildContext),
      Size,
      Size,
      EdgeInsets
    )>[
      // The toast's action.
      ('a toast action', 'View', null, null, (c) => _label(c, size: 14, weight: FontWeight.w700),
          const Size(48, 36), Size.infinite, const EdgeInsets.symmetric(horizontal: 12)),
      ('a bordered action on a fill', 'Undo', const Color(0xFFFFFFFF), const BorderSide(width: 2),
          (c) => _label(c, size: 13, weight: FontWeight.w600), const Size(48, 36), Size.infinite,
          const EdgeInsets.symmetric(horizontal: 12)),
      // The confirm dialog's answers.
      ('a dialog answer', 'Cancel', null, null, (c) => _label(c, size: 15, weight: FontWeight.w600, height: 1.2),
          const Size(0, 44), const Size(240, double.infinity), const EdgeInsets.symmetric(horizontal: 18)),
      ('a filled dialog answer', 'Remove', const Color(0xFFD32F2F), null,
          (c) => _label(c, size: 15, weight: FontWeight.w600, height: 1.2), const Size(96, 52),
          const Size(240, 52), const EdgeInsets.symmetric(horizontal: 18)),
      ('a dialog answer too long for one line', 'Remove every one of them and never ask me again', null, null,
          (c) => _label(c, size: 15, weight: FontWeight.w600, height: 1.2), const Size(0, 44),
          const Size(240, double.infinity), const EdgeInsets.symmetric(horizontal: 18)),
    ]) {
      testWidgets(name, (tester) async {
        final foreground = background != null && background.computeLuminance() < .3 ? const Color(0xFFFFFFFF) : ink;
        final material = await _pixels(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: foreground,
                backgroundColor: background,
                textStyle: style(context),
                side: side,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                minimumSize: min,
                maximumSize: max,
                padding: padding,
              ),
              child: Text(label),
            ),
          ),
        );
        final own = await _pixels(
          tester,
          Builder(builder: (context) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                  minWidth: min.width, minHeight: min.height, maxWidth: max.width, maxHeight: max.height),
              child: ControlButton(
                onPressed: () {},
                spec: chromeButton(
                  tokens: chromeTokensOf(context),
                  label: label,
                  foreground: foreground,
                  background: background,
                  style: style(context),
                  side: side,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  padding: padding,
                  wrapLabel: true,
                ),
              ),
            );
          }),
        );
        _expectSame(own, material);
      });
    }

    testWidgets('the Undo bar\'s button is the theme\'s text button', (tester) async {
      final material = await _pixels(tester, TextButton(onPressed: () {}, child: const Text('Undo')));
      final own = await _pixels(
        tester,
        Builder(builder: (context) {
          final theme = Theme.of(context);
          final style = theme.textButtonTheme.style!;
          return ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 64, minHeight: 40),
            child: ControlButton(
              onPressed: () {},
              spec: chromeButton(
                tokens: chromeTokensOf(context),
                label: 'Undo',
                foreground: style.foregroundColor!.resolve(const {})!,
                style: theme.textTheme.labelLarge!,
                shape: style.shape!.resolve(const {}),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          );
        }),
      );
      _expectSame(own, material);
    });
  });

  group('an icon button draws what an IconButton drew', () {
    for (final dark in [false, true]) {
      testWidgets('a player\'s button, ${dark ? 'dark' : 'light'}', (tester) async {
        const icon = IconData(ShellGlyphs.pauseCircle, fontFamily: ShellGlyphs.font);
        final material =
            await _pixels(tester, IconButton(onPressed: () {}, icon: const Icon(icon)), dark: dark);
        final own = await _pixels(
            tester, MediaPlayerButton(label: 'Pause', icon: pauseCircleGlyph, onPressed: () {}), dark: dark);
        _expectSame(own, material);
      });

      testWidgets('a player\'s button with nothing to play, ${dark ? 'dark' : 'light'}', (tester) async {
        const icon = IconData(ShellGlyphs.playArrow, fontFamily: ShellGlyphs.font);
        final material = await _pixels(
            tester, const IconButton.filledTonal(onPressed: null, icon: Icon(icon)), dark: dark);
        final own = await _pixels(tester, MediaPlayerButton(label: 'Play', icon: playArrowGlyph), dark: dark);
        _expectSame(own, material);
      });
    }

    testWidgets('a list\'s jump-to-latest button', (tester) async {
      const icon = IconData(ShellGlyphs.arrowDownward, fontFamily: ShellGlyphs.font);
      final material = await _pixels(
        tester,
        Builder(
          builder: (context) => IconButton.filledTonal(
            onPressed: () {},
            icon: const Icon(icon),
            style: IconButton.styleFrom(
                minimumSize: const Size(48, 48), backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh),
          ),
        ),
      );
      final own = await _pixels(
        tester,
        Builder(builder: (context) {
          final theme = Theme.of(context);
          final buttons = theme.iconButtonTheme.style!;
          return SizedBox.square(
            dimension: 48,
            child: ControlButton(
              onPressed: () {},
              focusable: false,
              spec: chromeButton(
                tokens: chromeTokensOf(context),
                icon: chromeGlyph('arrow_downward', ShellGlyphs.arrowDownward),
                iconSize: 24,
                foreground: buttons.foregroundColor!.resolve(const {})!,
                background: theme.colorScheme.surfaceContainerHigh,
                shape: buttons.shape!.resolve(const {}),
              ),
            ),
          );
        }),
      );
      _expectSame(own, material);
    });
  });

  group('the audio seek bar draws what the Material slider drew', () {
    Widget material(double value, double max, bool enabled) => Builder(builder: (context) {
          final colors = Theme.of(context).colorScheme;
          return SizedBox(
            width: 260,
            height: 24,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6, disabledThumbRadius: 5, elevation: 0, pressedElevation: 0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: colors.primary,
                thumbColor: colors.primary,
                inactiveTrackColor: colors.surfaceContainerHighest,
                disabledActiveTrackColor: colors.onSurface.withValues(alpha: 0.24),
                disabledInactiveTrackColor: colors.onSurface.withValues(alpha: 0.12),
                disabledThumbColor: colors.onSurfaceVariant,
              ),
              child: Slider(value: value, max: max, onChanged: enabled ? (_) {} : null),
            ),
          );
        });
    Widget own(double value, double max, bool enabled) => SizedBox(
        width: 260, height: 24, child: MediaSeekBar(value: value, max: max, onChanged: enabled ? (_) {} : null));

    for (final direction in TextDirection.values) {
      for (final dark in [false, true]) {
        for (final enabled in [true, false]) {
          for (final (value, max) in [(0.0, 1.0), (0.0, 93000.0), (310.0, 93000.0), (31000.0, 93000.0), (92900.0, 93000.0), (93000.0, 93000.0)]) {
            testWidgets('${direction.name}, ${dark ? 'dark' : 'light'}, ${enabled ? 'seekable' : 'not seekable'}: $value of $max',
                (tester) async {
              final before = await _pixels(tester, material(value, max, enabled), direction: direction, dark: dark);
              final after = await _pixels(tester, own(value, max, enabled), direction: direction, dark: dark);
              _expectSame(after, before);
            });
          }
        }
      }
    }
  });
}
