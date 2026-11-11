import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final stopFirst in [false, true]) {
    testWidgets(
      'app book and page updates preserve page zero when the book shrinks (stop=$stopFirst)',
      (tester) async {
        final layout = PublishLayout(
          document: LayoutDocument.fromJson({
            'id': 'reader',
            'roots': ['canvas'],
            'nodes': {
              'canvas': {
                'type': 'canvas',
                'layout': {'width': 390, 'height': 600},
                'slots': {'body': 'pager'},
              },
              'pager': {
                'type': 'pageView',
                'layout': {'width': 390, 'height': 600},
                'children': ['text'],
                'props': {
                  'scrollDirection': 'horizontal',
                  'animationDuration': 650,
                  'animationCurve': 'easeInOut',
                  'pageMotion': {
                    'rotateY': -9,
                    'scale': .97,
                    'opacity': .75,
                    'perspective': .001,
                    'originX': -1,
                  },
                },
                'bind': {
                  'data': r'${= books[book].pages}',
                  'props.initialPage': r'${page}',
                },
                'actions': [
                  {
                    'trigger': {'type': 'changed'},
                    'actions': [
                      if (stopFirst) {'type': 'speak', 'stop': true},
                      if (stopFirst) {'type': 'delay', 'ms': 60},
                      {
                        'type': 'setVariable',
                        'variable': 'page',
                        'value': r'${result.index}',
                      },
                    ],
                  },
                ],
              },
              'text': {
                'type': 'text',
                'layout': {
                  'width': {'fill': 390},
                  'height': {'fill': 600},
                },
                'props': {'text': r'${item.title}'},
              },
            },
          }),
          pageId: 'page-one',
          projectId: 'burrow',
        );
        final books = [
          {
            'pages': List.generate(12, (i) => {'title': 'Light $i'}),
          },
          {
            'pages': List.generate(4, (i) => {'title': 'Rain $i'}),
          },
        ];
        final app = Codelessly.fromBundle(
          PublishBundle(
            model: PublishModel(
              projectId: 'burrow',
              entryLayoutId: 'reader',
              layouts: {'reader': PublishLayoutInfo.of(layout)},
              variables: {
                'books': Variable(
                  name: 'books',
                  type: VariableType.list,
                  value: books,
                ).toJson(),
                'book': const Variable(
                  name: 'book',
                  type: VariableType.integer,
                  value: 0,
                ).toJson(),
                'page': const Variable(
                  name: 'page',
                  type: VariableType.integer,
                  value: 0,
                ).toJson(),
              },
            ),
            layouts: {'reader': layout},
          ),
          fonts: const NoFontFetcher(),
        );
        final debug = CodelesslyWidgetController();
        addTearDown(debug.dispose);
        addTearDown(app.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: CodelesslyWidget(codelessly: app, controller: debug),
          ),
        );
        await tester.pumpAndSettle();
        final controller = tester
            .widget<PageView>(find.byType(PageView))
            .controller!;
        expect(controller.page, 0);
        app.appVariables.set('page', 11);
        await tester.pump();
        for (var frame = 0; frame < 30; frame++) {
          await tester.pump(const Duration(milliseconds: 40));
        }
        expect(controller.page, closeTo(11, .001));
        expect(app.appVariables.read('page'), 11);
        if (stopFirst) {
          // A real external retarget must remain distinct from delayed feedback,
          // including while earlier changed reactions are still awaiting actions.
          app.appVariables.set('page', 0);
          await tester.pump();
          for (var frame = 0; frame < 7; frame++) {
            await tester.pump(const Duration(milliseconds: 40));
          }
          app.appVariables.set('page', 8);
          await tester.pump();
          for (var frame = 0; frame < 30; frame++) {
            await tester.pump(const Duration(milliseconds: 40));
          }
          expect(controller.page, closeTo(8, .001));
          expect(app.appVariables.read('page'), 8);
          app.appVariables.set('page', 11);
          await tester.pump();
          for (var frame = 0; frame < 30; frame++) {
            await tester.pump(const Duration(milliseconds: 40));
          }
          expect(controller.page, closeTo(11, .001));
        }
        app.appVariables.set('book', 1);
        app.appVariables.set('page', 0);
        await tester.pump();
        for (var frame = 0; frame < 40; frame++) {
          await tester.pump(const Duration(milliseconds: 40));
        }
        expect(app.appVariables.read('book'), 1);
        expect(app.appVariables.read('page'), 0);
        expect(controller.page, closeTo(0, .001));
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
