// The theme of a layout's controls and of the runtime's chrome
// (themeDataOf): every color role from the project's tokens or a neutral
// ink, paper and grey set; fonts from the tokens; nothing of Material's
// defaults, nothing of the app's theme.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/buttons.dart' show RenderButton;
import 'package:flutter/material.dart' hide TextStyle;
import 'package:flutter_test/flutter_test.dart';

/// Every color role of [s].
List<Color> _roles(ColorScheme s) => [
      s.primary, s.onPrimary, s.primaryContainer, s.onPrimaryContainer, s.primaryFixed, s.primaryFixedDim, //
      s.onPrimaryFixed, s.onPrimaryFixedVariant, s.secondary, s.onSecondary, s.secondaryContainer,
      s.onSecondaryContainer, s.secondaryFixed, s.secondaryFixedDim, s.onSecondaryFixed, s.onSecondaryFixedVariant,
      s.tertiary, s.onTertiary, s.tertiaryContainer, s.onTertiaryContainer, s.tertiaryFixed, s.tertiaryFixedDim,
      s.onTertiaryFixed, s.onTertiaryFixedVariant, s.surface, s.onSurface, s.surfaceDim, s.surfaceBright,
      s.surfaceContainerLowest, s.surfaceContainerLow, s.surfaceContainer, s.surfaceContainerHigh,
      s.surfaceContainerHighest, s.onSurfaceVariant, s.outline, s.outlineVariant, s.shadow, s.scrim,
      s.inverseSurface, s.onInverseSurface, s.inversePrimary,
    ];

bool _grey(Color c) {
  int ch(double v) => (v * 255).round();
  return (ch(c.r) - ch(c.g)).abs() <= 1 && (ch(c.g) - ch(c.b)).abs() <= 1;
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return la > lb ? (la + .05) / (lb + .05) : (lb + .05) / (la + .05);
}

Color? _resolve(WidgetStateProperty<Color?>? p, [Set<WidgetState> states = const {}]) => p?.resolve(states);

void main() {
  group('without a theme', () {
    test('every color role is ink, paper or a grey between them, light and dark', () {
      for (final b in Brightness.values) {
        final scheme = themeDataOf(ThemeTokens.none, brightness: b).colorScheme;
        final notGrey = [for (final c in _roles(scheme)) if (!_grey(c)) c];
        expect(notGrey, isEmpty, reason: '$b');
        expect(scheme.surfaceTint, Colors.transparent);
      }
      final light = themeDataOf(ThemeTokens.none).colorScheme;
      expect(light.surface, kPaper);
      expect(light.primary, kInk);
      final dark = themeDataOf(ThemeTokens.none, brightness: Brightness.dark).colorScheme;
      expect(dark.surface, kPaperDark);
      expect(dark.primary, kInkOnDark);
    });

    test('a filled button is ink with a paper label; text, outlined and icon buttons are ink on nothing', () {
      final theme = themeDataOf(ThemeTokens.none);
      final filled = theme.filledButtonTheme.style!;
      expect(_resolve(filled.backgroundColor), kInk);
      expect(_resolve(filled.foregroundColor), kPaper);
      for (final style in [theme.textButtonTheme.style!, theme.outlinedButtonTheme.style!, theme.iconButtonTheme.style!]) {
        expect(_resolve(style.foregroundColor), kInk);
        expect(_resolve(style.backgroundColor), Colors.transparent);
        expect(style.elevation?.resolve({}), 0);
      }
    });

    test('no control splashes, tints or casts a shadow of its own', () {
      final theme = themeDataOf(ThemeTokens.none);
      expect(theme.splashFactory, NoSplash.splashFactory);
      expect(theme.highlightColor, Colors.transparent);
      expect(theme.applyElevationOverlayColor, isFalse);
      for (final style in [theme.filledButtonTheme.style!, theme.elevatedButtonTheme.style!]) {
        expect(style.elevation?.resolve({}), 0);
        expect(style.splashFactory, NoSplash.splashFactory);
        expect(_resolve(style.surfaceTintColor), Colors.transparent);
      }
      expect(theme.floatingActionButtonTheme.elevation, 0);
      expect(theme.dialogTheme.surfaceTintColor, Colors.transparent);
      expect(theme.navigationBarTheme.elevation, 0);
    });

    test('a pressed or hovered button shows only a faint layer of its label\'s ink', () {
      final style = themeDataOf(ThemeTokens.none).textButtonTheme.style!;
      expect(_resolve(style.overlayColor, {WidgetState.hovered}), kInk.withValues(alpha: .06));
      expect(_resolve(style.overlayColor, {WidgetState.pressed}), kInk.withValues(alpha: .10));
      expect(_resolve(style.overlayColor), isNull);
    });

    test('disabled buttons stay visible on light and on dark', () {
      for (final b in Brightness.values) {
        final theme = themeDataOf(ThemeTokens.none, brightness: b);
        final style = theme.filledButtonTheme.style!;
        final fill = _resolve(style.backgroundColor, {WidgetState.disabled})!;
        final label = _resolve(style.foregroundColor, {WidgetState.disabled})!;
        expect(_contrast(fill, theme.colorScheme.surface), greaterThan(1.15), reason: '$b fill on the surface');
        expect(_contrast(label, fill), greaterThan(2), reason: '$b label on the fill');
      }
    });

    test('without a theme, controls have small radii: no stadium buttons, outlined fields, hairline dialogs', () {
      final theme = themeDataOf(ThemeTokens.none);
      const control = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(kControlRadius)));
      for (final style in [
        theme.filledButtonTheme.style!,
        theme.elevatedButtonTheme.style!,
        theme.textButtonTheme.style!,
        theme.outlinedButtonTheme.style!,
        theme.segmentedButtonTheme.style!,
      ]) {
        expect(style.shape?.resolve({}), control);
      }
      expect(theme.chipTheme.shape, control);
      final field = theme.inputDecorationTheme.border;
      expect(field, isA<OutlineInputBorder>());
      expect((field! as OutlineInputBorder).borderRadius, BorderRadius.circular(kControlRadius));
      for (final shape in [theme.dialogTheme.shape, theme.popupMenuTheme.shape, theme.datePickerTheme.shape]) {
        final r = shape! as RoundedRectangleBorder;
        expect(r.borderRadius, BorderRadius.circular(kSurfaceRadius));
        expect(r.side.width, 1, reason: 'a hairline border');
      }
      // A plain toggle: one thumb size, no outline around the track.
      expect(theme.switchTheme.thumbIcon?.resolve({}), isNotNull);
      expect(theme.switchTheme.trackOutlineColor?.resolve({})?.a, 0);
    });

    test('text has no font family: never Roboto', () {
      final text = themeDataOf(ThemeTokens.none).textTheme;
      for (final s in [text.bodyMedium, text.labelLarge, text.titleLarge, text.displaySmall]) {
        expect(s?.fontFamily, isNull);
      }
    });
  });

  group('with a theme', () {
    const brand = ThemeTokens(
      primary: api.Color(0xFF1F6F4A),
      onPrimary: api.Color(0xFFFFFFFF),
      surface: api.Color(0xFFFBF8F1),
      fontFamily: 'Barlow',
      titleFontFamily: 'Lora',
      buttonRadius: 6,
      radius: 12,
    );

    test('the brand primary fills buttons and draws the controls on the surface', () {
      final theme = themeDataOf(brand);
      expect(theme.colorScheme.primary, const Color(0xFF1F6F4A));
      expect(theme.colorScheme.surface, const Color(0xFFFBF8F1));
      expect(_resolve(theme.filledButtonTheme.style!.backgroundColor), const Color(0xFF1F6F4A));
      expect(_resolve(theme.filledButtonTheme.style!.foregroundColor), const Color(0xFFFFFFFF));
      expect(_resolve(theme.textButtonTheme.style!.foregroundColor), const Color(0xFF1F6F4A));
    });

    test('body text and labels take the theme\'s font, titles its title font', () {
      final text = themeDataOf(brand).textTheme;
      expect(text.bodyMedium?.fontFamily, 'Barlow');
      expect(text.labelLarge?.fontFamily, 'Barlow');
      expect(text.titleLarge?.fontFamily, 'Lora');
      expect(text.headlineSmall?.fontFamily, 'Lora');
    });

    test('the button radius shapes every kind of button and chip; the radius dialogs and fields', () {
      final theme = themeDataOf(brand);
      const button = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(6)));
      for (final style in [
        theme.filledButtonTheme.style!,
        theme.elevatedButtonTheme.style!,
        theme.textButtonTheme.style!,
        theme.outlinedButtonTheme.style!,
        theme.iconButtonTheme.style!,
        theme.segmentedButtonTheme.style!,
      ]) {
        expect(style.shape?.resolve({}), button);
      }
      expect(theme.chipTheme.shape, button);
      expect(theme.floatingActionButtonTheme.shape, button);
      // Dialogs: the radius, and a hairline border (not Material's shadow).
      final dialog = theme.dialogTheme.shape! as RoundedRectangleBorder;
      expect(dialog.borderRadius, const BorderRadius.all(Radius.circular(12)));
      expect(dialog.side.width, 1);
      expect(dialog.side.color, theme.colorScheme.outlineVariant);
      expect((theme.inputDecorationTheme.border as OutlineInputBorder?)?.borderRadius, BorderRadius.circular(12));
    });

    test('a white onPrimary never puts white text on a white surface', () {
      // A primary as light as the surface can't mark the controls on it:
      // they take the surface's ink, labelled in what reads on that.
      const pale = ThemeTokens(primary: api.Color(0xFFFFFFFF), onPrimary: api.Color(0xFFFFFFFF), surface: api.Color(0xFFFFFFFF));
      final theme = themeDataOf(pale);
      final text = _resolve(theme.textButtonTheme.style!.foregroundColor)!;
      expect(_contrast(text, const Color(0xFFFFFFFF)), greaterThan(4.5));
      final filled = theme.filledButtonTheme.style!;
      expect(_contrast(_resolve(filled.foregroundColor)!, _resolve(filled.backgroundColor)!), greaterThan(4.5));
      expect(_contrast(theme.colorScheme.onPrimary, theme.colorScheme.primary), greaterThan(4.5));
    });

    test('controls on a dark band of a light theme are drawn light', () {
      final theme = themeDataOf(brand, surface: const Color(0xFF101418));
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(_contrast(_resolve(theme.textButtonTheme.style!.foregroundColor)!, const Color(0xFF101418)), greaterThan(3));
      expect(_contrast(theme.colorScheme.onSurface, const Color(0xFF101418)), greaterThan(4.5));
    });
  });

  group('in a layout', () {
    /// Node [id]'s button render object.
    RenderButton button(NodeTree tree, String id) {
      RenderButton? found;
      void visit(RenderObject o) {
        if (o is RenderButton) found ??= o;
        o.visitChildren(visit);
      }

      visit(tree.boxOf(id)!);
      return found!;
    }

    Future<NodeTree> show(WidgetTester tester, Map<String, Json> nodes, {ThemeData? appTheme}) async {
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({'roots': ['band'], 'nodes': nodes})));
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(
        theme: appTheme,
        home: Scaffold(body: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'band'))),
      ));
      await tester.pump();
      return tree;
    }

    testWidgets('an unstyled text button on a dark band is labelled light, on paper dark', (tester) async {
      final tree = await show(tester, {
        'band': {
          'type': 'column',
          'layout': {'width': 300, 'height': 200},
          'children': ['dark', 'light'],
        },
        'dark': {
          'type': 'stack',
          'layout': {'width': 300, 'height': 100},
          'decoration': {
            'fills': [
              {'color': '#FF101418'},
            ],
          },
          'children': ['onDark'],
        },
        'light': {
          'type': 'stack',
          'layout': {'width': 300, 'height': 100},
          'decoration': {
            'fills': [
              {'color': '#FFFFFFFF'},
            ],
          },
          'children': ['onLight'],
        },
        'onDark': {
          'type': 'textButton',
          'layout': {'width': 120, 'height': 40},
          'props': {'label': 'Back'},
        },
        'onLight': {
          'type': 'textButton',
          'layout': {'width': 120, 'height': 40},
          'props': {'label': 'Next'},
        },
      });
      expect(_contrast(button(tree, 'onDark').labelColor, const Color(0xFF101418)), greaterThan(4.5));
      expect(_contrast(button(tree, 'onLight').labelColor, const Color(0xFFFFFFFF)), greaterThan(4.5));
    });

    testWidgets('a button with a fill but no label color is labelled in what reads on its fill', (tester) async {
      final tree = await show(tester, {
        'band': {
          'type': 'filledButton',
          'layout': {'width': 120, 'height': 40},
          'props': {
            'label': 'Go',
            'style': {'backgroundColor': '#FFFFFFFF'},
          },
        },
      });
      expect(_contrast(button(tree, 'band').labelColor, const Color(0xFFFFFFFF)), greaterThan(4.5));
    });

    testWidgets('a button\'s label color set in its text style is the label\'s color', (tester) async {
      final tree = await show(tester, {
        'band': {
          'type': 'textButton',
          'layout': {'width': 120, 'height': 40},
          'props': {
            'label': 'Back',
            'style': {
              'textStyle': {'color': '#FF244B32'},
            },
          },
        },
      });
      expect(button(tree, 'band').labelColor, const Color(0xFF244B32));
    });

    testWidgets('an icon button is a plain glyph: no raised surface', (tester) async {
      final tree = await show(tester, {
        'band': {
          'type': 'iconButton',
          'layout': {'width': 48, 'height': 48},
          'props': {'icon': 'close'},
        },
      });
      final b = button(tree, 'band');
      expect(b.shadows, isEmpty);
      expect(b.fillColor, isNull);
      expect(b.borderSide, isNull);
    });

    testWidgets('the app\'s theme doesn\'t reach a layout\'s controls', (tester) async {
      final tree = await show(
        tester,
        {
          'band': {
            'type': 'filledButton',
            'layout': {'width': 120, 'height': 40},
            'props': {'label': 'Go'},
          },
        },
        appTheme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.red), fontFamily: 'Comic'),
      );
      // The default (SSUI) button: SSUI's primary, the platform's font.
      expect(button(tree, 'band').fillColor, const Color(0xFF2563EB));
      expect(button(tree, 'band').fontFamily, isNull);
    });
  });
}
