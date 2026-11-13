
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide TextStyle;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Canvas viewport and location, layout id resolution and the initial
// screen; plus loading, caching and fonts.

// `theme` in expressions: the project's theme tokens for the current mode,
// with dark colors picked in dark mode, kept live as the device's mode (or
// the app's theme) changes.

final _theme = ThemeTokens.fromJson({
  'primary': '#FF2F6BFF',
  'surface': '#FFFFFFFF',
  'fontFamily': 'Inter',
  'colors': {'brandBlue': '#FF2F6BFF', 'mutedText': '#FF666666'},
  'textStyles': {
    'title': {'fontFamily': 'Inter', 'fontSize': 28},
  },
  'dark': {
    'surface': '#FF121212',
    'colors': {'mutedText': '#FFAAAAAA'},
  },
});

PublishBundle _bundle(ThemeTokens theme) {
  final layout = PublishLayout.fromJson({
    'schema': 2,
    'id': 'home',
    'roots': ['canvas'],
    'nodes': {
      'canvas': {
        'type': 'canvas',
        'slots': {'body': 'body'},
        'layout': {'width': 390, 'height': 844},
      },
      'body': {
        'type': 'stack',
        'layout': {
          'width': {'fill': 390},
          'height': {'fill': 844},
        },
        'children': ['card', 'label'],
      },
      'card': {
        'type': 'box',
        'layout': {'width': 100, 'height': 50},
        'decoration': {
          'fills': [
            {'color': '#FFFFFFFF'},
          ],
        },
        'bind': {'decoration.fills[0].color': r'${theme.surface}'},
      },
      'label': {
        'type': 'text',
        'props': {'text': r'${theme.brightness} ${theme.colors.mutedText} ${theme.text.title.fontSize}'},
        'layout': {'width': 300, 'height': 20},
      },
    },
  });
  return PublishBundle(
    model: PublishModel(
      projectId: 'theme',
      entryLayoutId: 'home',
      layouts: {'home': PublishLayoutInfo.of(layout)},
      theme: theme,
    ),
    layouts: {'home': layout},
  );
}

void main() {
  test('a project\'s theme tokens make the app\'s theme', () {
    final theme = themeDataOf(const api.ThemeTokens(primary: api.Color(0xFF3366FF), fontFamily: 'Barlow'));
    expect(theme.colorScheme.primary, const Color(0xFF3366FF));
  });

  group('light and dark', () {
    test('theme values are the tokens for a light or a dark screen', () {
      final light = themeValues(_theme, dark: false);
      expect(light['surface'], '#FFFFFFFF');
      expect(light['primary'], '#FF2F6BFF');
      expect(light['fontFamily'], 'Inter');
      expect(light['colors'], {'brandBlue': '#FF2F6BFF', 'mutedText': '#FF666666'});
      expect((light['text'] as Map)['title'], containsPair('fontSize', 28));
      expect(light['isDark'], isFalse);
      expect(light['brightness'], 'light');
      expect(light.containsKey('dark'), isFalse);
      final dark = themeValues(_theme, dark: true);
      expect(dark['surface'], '#FF121212');
      expect(dark['primary'], '#FF2F6BFF', reason: 'no dark primary: the light one');
      expect(dark['colors'], {'brandBlue': '#FF2F6BFF', 'mutedText': '#FFAAAAAA'});
      expect(dark['isDark'], isTrue);
      // A project without a theme still reads its mode.
      expect(light['hasDark'], isTrue);
      expect(themeValues(ThemeTokens.none, dark: true),
          {'colors': {}, 'text': {}, 'isDark': true, 'brightness': 'dark', 'mode': 'system', 'hasDark': false});
    });

    testWidgets('the theme follows the device\'s light or dark mode: bound colors, text and the Material theme', (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      final app = Codelessly.fromBundle(_bundle(_theme), fonts: const NoFontFetcher());
      addTearDown(app.dispose);
      final controller = CodelesslyWidgetController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, controller: controller)));
      await tester.pumpAndSettle();

      String text() => controller.tree!.boxOf('label')!.node!.prop(TextProps.text);
      Object? fill() => controller.tree!.boxOf('card')!.node!.toJson()['decoration'];
      Brightness material() => Theme.of(tester.element(find.byType(NodeView))).brightness;

      expect(controller.scope!.read('theme.isDark'), isFalse);
      expect(text(), 'light #FF666666 28');
      expect('${fill()}', contains('#FFFFFFFF'));
      expect(material(), Brightness.light);
      expect(controller.scope!.read('screen.isDark'), isFalse);
      expect(controller.scope!.read('screen.dark'), isFalse);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(controller.scope!.read('theme.isDark'), isTrue);
      expect(controller.scope!.read('theme.surface'), '#FF121212');
      expect(text(), 'dark #FFAAAAAA 28');
      expect('${fill()}', contains('#FF121212'));
      expect(material(), Brightness.dark, reason: 'a theme with dark colors is a dark theme in dark mode');
      expect(controller.scope!.read('screen.isDark'), isTrue);
      expect(controller.scope!.read('screen.dark'), isTrue, reason: 'the alias some guides used');
    });

    testWidgets('a project without dark colors stays light in dark mode', (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      final app = Codelessly.fromBundle(_bundle(ThemeTokens.fromJson({'primary': '#FF2F6BFF'})), fonts: const NoFontFetcher());
      addTearDown(app.dispose);
      final controller = CodelesslyWidgetController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, controller: controller)));
      await tester.pumpAndSettle();
      expect(controller.scope!.read('theme.isDark'), isTrue);
      expect(controller.scope!.read('theme.primary'), '#FF2F6BFF');
      expect(Theme.of(tester.element(find.byType(NodeView))).brightness, Brightness.light);
    });

    testWidgets('the app\'s theme decides nothing: the device\'s mode and the project\'s tokens do', (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      final app = Codelessly.fromBundle(_bundle(_theme), fonts: const NoFontFetcher());
      addTearDown(app.dispose);
      final controller = CodelesslyWidgetController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: CodelesslyWidget(codelessly: app, controller: controller),
      ));
      await tester.pumpAndSettle();
      expect(controller.scope!.read('theme.isDark'), isFalse, reason: 'the device is light');
      final theme = Theme.of(tester.element(find.byType(NodeView)));
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, const Color(0xFF2F6BFF));
      expect(theme.colorScheme.surface, const Color(0xFFFFFFFF));
    });

    testWidgets('a project\'s own variable named theme wins over the built-in one', (tester) async {
      final app = Codelessly.fromBundle(_bundle(_theme), fonts: const NoFontFetcher());
      addTearDown(app.dispose);
      app.declareAppVariables([const Variable(name: 'theme', value: 'Midnight')]);
      final controller = CodelesslyWidgetController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, controller: controller)));
      await tester.pumpAndSettle();
      expect(controller.scope!.read('theme'), 'Midnight');
      controller.setVariable('theme', 'Dusk');
      await tester.pump();
      expect(app.appVariables.read('theme'), 'Dusk');
      expect(controller.scope!.read('theme'), 'Dusk');
    });
  });
}
