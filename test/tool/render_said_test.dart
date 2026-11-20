// What a render says of a picture that is wrong with no error: a color or a
// theme value the theme does not have, a control's icon that names no
// glyph, a child drawn past its Stack over what follows it.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

Map<String, Object?> _box(Object? color, {Map<String, Object?>? bind}) => {
      'type': 'column',
      'layout': {'width': 40, 'height': 40},
      'decoration': {
        'fills': [
          {'color': color},
        ],
      },
      if (bind != null) 'bind': bind,
    };

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_said_test'));
  tearDown(() => out.deleteSync(recursive: true));

  Future<RenderReport> render(WidgetTester tester, Map<String, Object?> nodes, {Map<String, Object?> theme = const {}}) async {
    final site = Directory('${out.path}/site')..createSync();
    File('${site.path}/site.json').writeAsStringSync(jsonEncode({
      'schema': 3,
      'pages': ['page.json'],
      if (theme.isNotEmpty) 'theme': theme,
    }));
    File('${site.path}/page.json').writeAsStringSync(jsonEncode({
      'schema': 3,
      'id': 'page',
      'roots': ['page'],
      'nodes': {
        'page': {
          'type': 'canvas',
          'slots': {'body': 'col'},
          'layout': {'width': 400, 'height': 600},
          'decoration': {
            'fills': [
              {'color': '#FFFFFFFF'},
            ],
          },
        },
        'col': {
          'type': 'column',
          'children': [...nodes.keys.where((k) => !k.startsWith('_'))],
          'layout': {
            'width': {'fill': 0},
            'height': {'hug': 0},
          },
        },
        for (final e in nodes.entries) e.key.startsWith('_') ? e.key.substring(1) : e.key: e.value,
      },
    }));
    return runRender(tester, RenderArgs(inputs: [site.path], out: '${out.path}/o', sizes: const [Size(400, 600)]));
  }

  List<Map> said(RenderReport r, String code) => [
        for (final d in r.diagnostics)
          if (d['code'] == code) d,
      ];

  testWidgets('a color the theme does not have, theme.<name> as a text and as a read with no value: theme_name_unknown', (tester) async {
    final report = await render(tester, {
      'known': _box('ember'),
      'role': _box('surface'),
      'unknown': _box('amberTint'),
      'asText': _box('theme.amberTint'),
      'read': _box('#00000000', bind: {'decoration.fills[0].color': r'${theme.red}'}),
      'readKnown': _box('#00000000', bind: {'decoration.fills[0].color': r'${theme.colors.ember}'}),
    }, theme: {
      'colors': {'ember': '#FFB45309'},
    });
    final names = said(report, 'theme_name_unknown');
    expect(names.map((d) => '$d'), [contains('"unknown" names the color "amberTint"'), contains('"asText" is written "theme.amberTint"'), contains('"read" reads theme.red')]);
    expect(names.first['severity'], 'warning');
    expect(names.first['message'], contains('ember'));
  });

  testWidgets('a control\'s icon that names no glyph: icon_not_drawn names the control and the name', (tester) async {
    final report = await render(tester, {
      'play': {
        'type': 'iconButton',
        'layout': {'width': 36, 'height': 36},
        'props': {'icon': 'tray'},
      },
      'ok': {
        'type': 'iconButton',
        'layout': {'width': 36, 'height': 36},
        'props': {'icon': 'search'},
      },
    });
    final icons = said(report, 'icon_not_drawn');
    expect(icons, hasLength(1));
    expect('${icons.single}', allOf(contains('play'), contains('"tray"')));
  });

  testWidgets('a child drawn past its Stack over what follows it: paints_outside says by how much', (tester) async {
    Map<String, Object?> text(String t) => {
          'type': 'text',
          'layout': {
            'width': {'fill': 0},
            'height': {'hug': 0},
          },
          'props': {
            'text': t,
            'style': {'color': '#FF000000'},
          },
        };
    final report = await render(tester, {
      'stage': {
        'type': 'stack',
        'layout': {'width': 300, 'height': 60},
        'children': ['tall', 'inside'],
      },
      '_tall': {
        'type': 'column',
        'layout': {'width': 300, 'height': 200, 'x': 0, 'y': 0},
        'decoration': {
          'fills': [
            {'color': '#FFFFCC00'},
          ],
        },
      },
      '_inside': {
        'type': 'column',
        'layout': {'width': 30, 'height': 30, 'x': 0, 'y': 0},
      },
      'after': text('What follows the stage'),
      // The same child in a Stack that clips: cut at its edge, nothing to say.
      'clipped': {
        'type': 'stack',
        'layout': {'width': 300, 'height': 60},
        'decoration': {'clip': 'hardEdge'},
        'children': ['tall2'],
      },
      '_tall2': {
        'type': 'column',
        'layout': {'width': 300, 'height': 200, 'x': 0, 'y': 0},
      },
      'last': text('After the clipped one'),
    });
    final past = said(report, 'paints_outside');
    expect(past, hasLength(1));
    expect('${past.single}', allOf(contains('"tall"'), contains('140 px past the bottom of "stage"'), contains('over "after"')));
    expect(past.single['severity'], 'warning');
  });
}
