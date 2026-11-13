// Named colors and text styles: a page names the project's theme
// ("color": "ink", "style": "title"); the runtime resolves the names against
// the theme as the screen shows it (its media rules at the screen's width,
// its dark colors in dark mode), and a change of theme re-applies only the
// nodes that use what changed.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide TextStyle;
import 'package:codelessly_api/codelessly_api.dart' as api show Color, TextStyle;
import 'package:flutter_test/flutter_test.dart';

final _theme = ThemeTokens.fromJson({
  'colors': {'ink': '#FF111111', 'paper': '#FFFAFAFA'},
  'textStyles': {
    'body': {'fontSize': 16, 'color': 'ink'},
    'title': {'from': 'body', 'fontSize': 28, 'fontWeight': 700},
  },
  'media': [
    {'minWidth': 1024, 'patch': {'textStyles': {'title': {'fontSize': 48}}}},
  ],
  'dark': {'colors': {'ink': '#FFEEEEEE'}},
});

PublishBundle _bundle() {
  final layout = PublishLayout.fromJson({
    'schema': 2,
    'id': 'home',
    'roots': ['canvas'],
    'nodes': {
      'canvas': {'type': 'canvas', 'slots': {'body': 'body'}, 'layout': {'width': 390, 'height': 844}},
      'body': {
        'type': 'column',
        'layout': {'width': {'fill': 390}, 'height': {'fill': 844}},
        'decoration': {'fills': [{'color': 'paper'}]},
        'children': ['title', 'note', 'plain'],
      },
      'title': {'type': 'text', 'props': {'text': 'Title', 'style': 'title'}, 'layout': {'width': 300, 'height': 60}},
      'note': {
        'type': 'text',
        'props': {'text': 'Note', 'style': {'from': 'body', 'fontSize': 12}},
        'layout': {'width': 300, 'height': 20},
      },
      'plain': {'type': 'text', 'props': {'text': 'Plain', 'style': {'fontSize': 10, 'color': '#FF000000'}}, 'layout': {'width': 300, 'height': 20}},
    },
  });
  return PublishBundle(
    model: PublishModel(projectId: 'theme', entryLayoutId: 'home', layouts: {'home': PublishLayoutInfo.of(layout)}, theme: _theme),
    layouts: {'home': layout},
  );
}

void main() {
  testWidgets('names resolve against the theme at the screen\'s width and mode; only nodes using a change re-apply',
      (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final app = Codelessly.fromBundle(_bundle(), fonts: const NoFontFetcher());
    addTearDown(app.dispose);
    final controller = CodelesslyWidgetController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, controller: controller)));
    await tester.pumpAndSettle();

    api.TextStyle style(String id) => controller.tree!.boxOf(id)!.node!.prop(TextProps.style);
    expect([style('title').fontSize, style('title').fontWeight, style('title').color], [28, 700, const api.Color(0xFF111111)]);
    expect([style('note').fontSize, style('note').color], [12, const api.Color(0xFF111111)]);
    expect(controller.tree!.boxOf('body')!.node!.decoration.fills.single.color, const api.Color(0xFFFAFAFA));
    expect(controller.scope!.read('theme.text.title.fontSize'), 28);

    // Which nodes re-apply when the mode changes: those naming "ink".
    final changed = <String>{};
    for (final id in ['body', 'title', 'note', 'plain']) {
      final w = controller.tree!.source.watch(id);
      void listener() => changed.add(id);
      w.addListener(listener);
      addTearDown(() => w.removeListener(listener));
    }
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(style('title').color, const api.Color(0xFFEEEEEE));
    expect(changed, {'title', 'note'});

    // The theme's media rule: the title at desktop width.
    changed.clear();
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    expect(style('title').fontSize, 48);
    expect(style('note').fontSize, 12);
    expect(changed, {'title'});
  });
}
