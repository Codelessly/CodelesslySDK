// A published app lays out text without a line height at its font's own
// height, as Flutter does.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart' show settle;

PublishBundle _bundle() {
  final layout = PublishLayout.fromJson({
    'schema': 3,
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
        'layout': {'width': {'fill': 390}, 'height': {'fill': 844}},
        'children': ['label'],
      },
      'label': {
        'type': 'text',
        'props': {'text': 'Backlog', 'style': {'fontSize': 15}},
        'layout': {'width': {'hug': 60}, 'height': {'hug': 20}},
      },
    },
  });
  return PublishBundle(
    model: PublishModel(
      projectId: 'p',
      entryLayoutId: 'home',
      layouts: {'home': PublishLayoutInfo.of(layout)},
    ),
    layouts: {'home': layout},
  );
}

void main() {
  {
    testWidgets("a published app lays out text without a line height at the font's own height", (tester) async {
      final app = Codelessly.fromBundle(_bundle(),
          config: CodelesslyConfig(services: Services(analytics: const NoAnalytics())), fonts: const NoFontFetcher());
      final controller = CodelesslyWidgetController();
      await tester.pumpWidget(MaterialApp(
        home: Column(children: [
          Expanded(child: CodelesslyWidget(codelessly: app, controller: controller)),
          const Text('Flutter', key: Key('flutter'), style: TextStyle(fontSize: 15)),
        ]),
      ));
      await settle(tester);
      final flutter = tester.getSize(find.byKey(const Key('flutter'))).height;
      // The tree's render objects aren't widgets': walk them from the view.
      final paragraphs = <RenderParagraph>[];
      void walk(RenderObject o) {
        if (o is RenderParagraph) paragraphs.add(o);
        o.visitChildren(walk);
      }
      walk(tester.renderObject(find.byType(NodeView)));
      final label = paragraphs.firstWhere((p) => p.text.toPlainText() == 'Backlog').size.height;
      expect(label, flutter);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      app.dispose();
    });
  }
}
