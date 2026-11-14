// A theme's font family is the default family of every text of a site, as it
// is its controls' (Flutter: the DefaultTextStyle an app's theme gives its
// text): a text node with no family takes it; one with its own keeps it.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide TextStyle;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// The family the paragraph drawing [text] uses: its first span's, else its
/// root's.
String? _family(WidgetTester tester, String text) {
  RenderParagraph? found;
  void visit(RenderObject o) {
    if (found == null && o is RenderParagraph && o.text.toPlainText() == text) found = o;
    o.visitChildren(visit);
  }

  visit(tester.binding.rootElement!.renderObject!);
  String? family = found!.text.style?.fontFamily;
  found!.text.visitChildren((s) {
    family ??= s.style?.fontFamily;
    return family == null;
  });
  return family;
}

void main() {
  testWidgets('a site whose theme names a font draws its texts without a family in it, and the others in theirs', (tester) async {
    setScreen(tester, const Size(390, 844));
    final layout = PublishLayout.fromJson({
      'schema': 3,
      'id': 'home',
      'roots': ['home'],
      'nodes': {
        'home': {'type': 'canvas', 'slots': {'body': 'col'}, 'layout': {'width': 390, 'height': 844}},
        'col': {'type': 'column', 'children': ['plain', 'own'], 'layout': {'width': {'fill': 390}, 'height': {'fill': 844}}},
        'plain': {'type': 'text', 'props': {'text': 'Plain'}, 'layout': {'width': 200, 'height': 20}},
        'own': {
          'type': 'text',
          'props': {'text': 'Own', 'style': {'fontFamily': 'Serif Face'}},
          'layout': {'width': 200, 'height': 20},
        },
      },
    });
    final bundle = PublishBundle(
      model: PublishModel(
          projectId: 'font',
          entryLayoutId: 'home',
          layouts: {'home': PublishLayoutInfo.of(layout)},
          theme: const ThemeTokens(fontFamily: 'Theme Sans')),
      layouts: {'home': layout},
    );
    final app = Codelessly(loader: MemoryPublishLoader(bundle), fonts: const NoFontFetcher());
    addTearDown(app.dispose);
    final controller = CodelesslyWidgetController();
    addTearDown(controller.dispose);
    await tester.runAsync(() => app.loadLayout('home'));
    await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, controller: controller)));
    await settle(tester);
    expect(_family(tester, 'Plain'), 'Theme Sans');
    expect(_family(tester, 'Own'), 'Serif Face');
  });
}
