// A site's theme family in a publish (tool/render/src/publish.dart): the
// family its theme names (`"fontFamily": "Fraunces"`), which its texts that
// name none are drawn in, is listed with each layout's fonts at the weights
// those texts ask for, so an app fetches it from Google Fonts with the page;
// a family the site declares a file for is read from that file.
import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/publish.dart';

void main() {
  Json page(Map<String, Object?> style) => {
        'schema': 3,
        'roots': ['home'],
        'nodes': {
          'home': {
            'type': 'canvas',
            'layout': {'width': 390, 'height': 200},
            'slots': {'body': 'col'},
          },
          'col': {
            'type': 'column',
            'children': ['t'],
          },
          't': {
            'type': 'text',
            'props': {'text': 'Hello', 'style': style},
          },
        },
      };

  test('the theme\'s family is a layout\'s font at the weights of its texts, fetched by family', () {
    final published = publishPages([(name: 'home', json: page({'fontWeight': 700}))], theme: {'fontFamily': 'Fraunces', 'titleFontFamily': 'Fraunces'});
    final fonts = published.bundle.model.fontsOf('home');
    expect({for (final f in fonts) '${f.family} ${f.weight}'}, {'Fraunces 400', 'Fraunces 700'});
    expect(fonts.every((f) => f.url == null), isTrue, reason: 'a Google Font: fetched by family');
  });

  test('a declared family keeps its files; Roboto, the default, is not listed', () {
    final published = publishPages(
      [(name: 'home', json: page({'fontWeight': 400}))],
      theme: {'fontFamily': 'Fraunces'},
      fonts: [FontFamily(family: 'Fraunces', fonts: [FontAsset(asset: 'fonts/Fraunces.ttf', weight: 400)])],
    );
    expect([for (final f in published.bundle.model.fontsOf('home')) f.url], ['fonts/Fraunces.ttf']);
    final plain = publishPages([(name: 'home', json: page({'fontWeight': 400}))], theme: {'fontFamily': 'Roboto'});
    expect(plain.bundle.model.fontsOf('home'), isEmpty);
  });
}
