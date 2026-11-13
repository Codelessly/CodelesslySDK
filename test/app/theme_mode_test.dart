// The site's theme mode (Flutter's ThemeMode): a setThemeMode action on any
// screen switches every named colour, named text style and unstyled control
// of every screen at once, `${theme.mode}` and `${theme.isDark}` follow it,
// the choice survives navigation and (persisted) a reload, and a site
// without dark colours stays as it was designed.
import 'package:codelessly_api/codelessly_api.dart' as api show Color, TextStyle, ThemeMode;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide TextStyle;
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

const _darkTheme = {
  'surface': '#FFFFFFFF',
  'onSurface': '#FF111111',
  'colors': {'ink': '#FF111111', 'paper': '#FFFAFAFA'},
  'textStyles': {
    'body': {'fontSize': 16, 'color': 'ink'},
  },
  'dark': {
    'surface': '#FF121212',
    'onSurface': '#FFEEEEEE',
    'colors': {'ink': '#FFEEEEEE', 'paper': '#FF0A0A0A'},
  },
};

/// A page with a paper background, a text in the `body` style, an
/// unstyled checkbox, a toggle and a link to [other].
Json _page(String id, {String? other, bool persist = true}) => {
      'schema': 3,
      'id': id,
      'roots': [id],
      'nodes': {
        id: {'type': 'canvas', 'name': id, 'slots': {'body': '$id-body'}, 'layout': {'width': 390, 'height': 844}},
        '$id-body': {
          'type': 'column',
          'layout': {'width': {'fill': 390}, 'height': {'fill': 844}},
          'decoration': {'fills': [{'color': 'paper'}]},
          'children': ['$id-label', '$id-check', '$id-toggle', if (other != null) '$id-go'],
        },
        '$id-label': {
          'type': 'text',
          'props': {'text': r'${theme.mode} ${theme.isDark}', 'style': 'body'},
          'layout': {'width': 300, 'height': 24},
        },
        '$id-check': {'type': 'checkbox', 'props': {'value': true}, 'layout': {'width': 40, 'height': 40}},
        '$id-toggle': {
          'type': 'box',
          'layout': {'width': 44, 'height': 44},
          'decoration': {'fills': [{'color': 'ink'}]},
          'actions': [
            {
              'trigger': {'type': 'click'},
              'actions': [
                {'type': 'setThemeMode', 'mode': r"${= theme.isDark ? 'light' : 'dark'}", if (!persist) 'persist': false},
              ],
            },
          ],
        },
        if (other != null)
          '$id-go': {
            'type': 'box',
            'layout': {'width': 44, 'height': 44},
            'decoration': {'fills': [{'color': '#FF888888'}]},
            'actions': [
              {
                'trigger': {'type': 'click'},
                'actions': [
                  {'type': 'navigate', 'to': other},
                ],
              },
            ],
          },
      },
    };

PublishBundle _bundle(Json theme, {bool persist = true}) {
  final home = PublishLayout.fromJson(_page('home', other: 'about', persist: persist));
  final about = PublishLayout.fromJson(_page('about'));
  return PublishBundle(
    model: PublishModel(
      projectId: 'mode',
      entryLayoutId: 'home',
      layouts: {'home': PublishLayoutInfo.of(home), 'about': PublishLayoutInfo.of(about)},
      theme: ThemeTokens.fromJson(theme),
    ),
    layouts: {'home': home, 'about': about},
  );
}

Future<CodelesslyWidgetController> _pump(WidgetTester tester, Codelessly app) async {
  final controller = CodelesslyWidgetController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(
    onGenerateRoute: CodelesslyWidget.onGenerateRoute(app),
    home: CodelesslyWidget(codelessly: app, controller: controller),
  ));
  await settle(tester);
  return controller;
}

/// What a screen shows in its current mode: the label's text and colour,
/// the background's colour, and the brightness and surface of the theme
/// its unstyled checkbox draws with.
({String text, api.Color? ink, api.Color? paper, Brightness control, Color surface}) _look(WidgetTester tester, String id) {
  final tree = tester.widgetList<NodeView>(find.byType(NodeView)).map((v) => v.tree).lastWhere((t) => t.boxOf('$id-label') != null);
  final label = tree.boxOf('$id-label')!.node!;
  final style = label.prop(TextProps.style) as api.TextStyle;
  final island = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_CheckboxIsland').last;
  final theme = Theme.of(tester.element(island));
  return (
    text: label.prop(TextProps.text),
    ink: style.color,
    paper: tree.boxOf('$id-body')!.node!.decoration.fills.single.color,
    control: theme.brightness,
    surface: theme.colorScheme.surface,
  );
}

Future<void> _tap(WidgetTester tester, String id) async {
  final box = tester.widgetList<NodeView>(find.byType(NodeView)).map((v) => v.tree.boxOf(id)).nonNulls.last;
  await tester.tapAt(box.localToGlobal(box.size.center(Offset.zero)));
  await settle(tester);
}

void main() {
  setUp(() => ignoreOverflows());

  testWidgets('a toggle switches every named colour, the named text style and an unstyled control to dark and back',
      (tester) async {
    setScreen(tester, const Size(390, 844));
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    final app = Codelessly.fromBundle(_bundle(_darkTheme), fonts: const NoFontFetcher());
    addTearDown(app.dispose);
    await _pump(tester, app);

    var look = _look(tester, 'home');
    expect(look.text, 'system false');
    expect(look.ink, const api.Color(0xFF111111));
    expect(look.paper, const api.Color(0xFFFAFAFA));
    expect(look.control, Brightness.light);
    expect(look.surface.computeLuminance(), greaterThan(.8), reason: 'the checkbox draws on a light surface');

    await _tap(tester, 'home-toggle');
    look = _look(tester, 'home');
    expect(look.text, 'dark true');
    expect(look.ink, const api.Color(0xFFEEEEEE), reason: 'the named text style resolves its colour in dark mode');
    expect(look.paper, const api.Color(0xFF0A0A0A));
    expect(look.control, Brightness.dark, reason: 'the control theme follows the mode');
    expect(look.surface.computeLuminance(), lessThan(.1), reason: 'and on a dark one');
    expect(app.themeMode, api.ThemeMode.dark);

    await _tap(tester, 'home-toggle');
    look = _look(tester, 'home');
    expect(look.text, 'light false');
    expect(look.ink, const api.Color(0xFF111111));
    expect(look.control, Brightness.light);
  });

  testWidgets('a chosen light mode wins over a dark device, and system follows the device again', (tester) async {
    setScreen(tester, const Size(390, 844));
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    final app = Codelessly.fromBundle(_bundle(_darkTheme), fonts: const NoFontFetcher());
    addTearDown(app.dispose);
    final controller = await _pump(tester, app);
    expect(_look(tester, 'home').text, 'system true');
    expect(controller.scope!.read('screen.isDark'), isTrue);

    app.setThemeMode(api.ThemeMode.light);
    await settle(tester);
    expect(_look(tester, 'home').text, 'light false');
    expect(_look(tester, 'home').paper, const api.Color(0xFFFAFAFA));
    expect(controller.scope!.read('screen.isDark'), isFalse, reason: 'screen.isDark is the mode the site shows');

    app.setThemeMode(null);
    await settle(tester);
    expect(_look(tester, 'home').text, 'system true');
  });

  testWidgets('the site starts in the mode its theme names', (tester) async {
    setScreen(tester, const Size(390, 844));
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    final app = Codelessly.fromBundle(_bundle({..._darkTheme, 'mode': 'dark'}), fonts: const NoFontFetcher());
    addTearDown(app.dispose);
    await _pump(tester, app);
    expect(_look(tester, 'home').text, 'dark true');
    expect(_look(tester, 'home').paper, const api.Color(0xFF0A0A0A));
  });

  testWidgets('the chosen mode carries to the next page and, persisted, to the next visit', (tester) async {
    setScreen(tester, const Size(390, 844));
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    final storage = MemoryLocalStorage();
    Codelessly open() => Codelessly.fromBundle(_bundle(_darkTheme),
        fonts: const NoFontFetcher(), config: CodelesslyConfig(services: Services(storage: storage, analytics: const NoAnalytics())));
    final app = open();
    addTearDown(app.dispose);
    await _pump(tester, app);
    await _tap(tester, 'home-toggle');
    expect(_look(tester, 'home').text, 'dark true');

    await _tap(tester, 'home-go');
    expect(app.route.value?.layoutId, 'about');
    final about = _look(tester, 'about');
    expect(about.text, 'dark true');
    expect(about.paper, const api.Color(0xFF0A0A0A));
    expect(about.control, Brightness.dark);
    expect(storage.get(Codelessly.themeModeStorageKey), 'dark');

    // A reload: a new instance over the same storage starts dark.
    await tester.pumpWidget(const SizedBox());
    final again = open();
    addTearDown(again.dispose);
    await _pump(tester, again);
    expect(_look(tester, 'home').text, 'dark true');
  });

  testWidgets('a setThemeMode that does not persist leaves the next visit as it was', (tester) async {
    setScreen(tester, const Size(390, 844));
    final storage = MemoryLocalStorage();
    final app = Codelessly.fromBundle(_bundle(_darkTheme, persist: false),
        fonts: const NoFontFetcher(), config: CodelesslyConfig(services: Services(storage: storage, analytics: const NoAnalytics())));
    addTearDown(app.dispose);
    await _pump(tester, app);
    await _tap(tester, 'home-toggle');
    expect(_look(tester, 'home').text, 'dark true');
    expect(storage.containsKey(Codelessly.themeModeStorageKey), isFalse);
  });

  testWidgets('a site without dark colours keeps its colours and controls in dark mode, and can still read the mode',
      (tester) async {
    setScreen(tester, const Size(390, 844));
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    final light = {..._darkTheme}..remove('dark');
    final app = Codelessly.fromBundle(_bundle(light), fonts: const NoFontFetcher());
    addTearDown(app.dispose);
    final controller = await _pump(tester, app);
    await _tap(tester, 'home-toggle');
    final look = _look(tester, 'home');
    expect(look.text, 'dark true', reason: 'a document can still choose its own colours by theme.isDark');
    expect(look.ink, const api.Color(0xFF111111));
    expect(look.paper, const api.Color(0xFFFAFAFA));
    expect(look.control, Brightness.light, reason: 'controls stay as the light design that has no dark variant');
    expect(controller.scope!.read('theme.hasDark'), isFalse);
  });
}
