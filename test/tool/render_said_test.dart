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

  testWidgets('a painted box 0 high, hugging with nothing in it: zero_size names the cause', (tester) async {
    final report = await render(tester, {
      // A box that hugs its height with nothing in it (as `{"flex": 1, "height": {"hug": 0}}` in a Column): 0.
      'dim': {
        'type': 'box',
        'layout': {
          'width': {'fill': 0},
          'height': {'hug': 0},
        },
        'decoration': {
          'fills': [
            {'color': '#80D9D9D9'},
          ],
        },
      },
      // A hairline written as such: not 0, nothing to say.
      'hair': {
        'type': 'box',
        'layout': {
          'width': {'fill': 0},
          'height': 0.4,
        },
        'decoration': {
          'fills': [
            {'color': '#FFA9A9AF'},
          ],
        },
      },
      // A plain box 0 high that paints nothing: no word for it.
      'plain': {
        'type': 'box',
        'layout': {
          'width': {'fill': 0},
          'height': {'hug': 0},
        },
      },
    });
    final zero = said(report, 'zero_size');
    expect(zero.map((d) => d['nodeId']), containsAll(['dim']));
    expect(zero.map((d) => d['nodeId']), isNot(anyOf(contains('plain'), contains('hair'))));
    final dim = zero.firstWhere((d) => d['nodeId'] == 'dim');
    expect(dim['message'], allOf(contains('"dim" (box) is 0 high'), contains('hugs its height and has nothing in it'), contains('h=fill grow')));
  });

  testWidgets('a text cut in a box 0 wide: text_clipped says why the box is 0 wide', (tester) async {
    final report = await render(tester, {
      'full': {
        'type': 'row',
        'layout': {'width': 200, 'height': {'hug': 0}},
        'children': ['wide', 'words'],
      },
      '_wide': {
        'type': 'box',
        'layout': {'width': 200, 'height': 20},
      },
      '_words': {
        'type': 'text',
        'layout': {
          'width': {'fill': 0},
          'height': {'hug': 0},
        },
        'props': {
          'text': 'Words that need room',
          'style': {'color': '#FF000000'},
        },
      },
    });
    final cut = said(report, 'text_clipped').where((d) => d['nodeId'] == 'words').toList();
    expect(cut, isNotEmpty, reason: '${report.diagnostics}');
    expect(cut.first['message'], allOf(contains('in a box 0 wide'), contains('"full" (row) gave "words" no width')));
  });

  testWidgets('an icon whose size is larger than its box: icon_smaller_than_size says what it is drawn at', (tester) async {
    final report = await render(tester, {
      'chev': {
        'type': 'icon',
        'layout': {'width': 10, 'height': 16},
        'props': {'icon': 'chevron_right', 'size': 16},
      },
      'fits': {
        'type': 'icon',
        'layout': {'width': 16, 'height': 16},
        'props': {'icon': 'chevron_right', 'size': 16},
      },
    });
    final icons = said(report, 'icon_smaller_than_size');
    expect(icons, hasLength(1));
    expect(icons.single['message'], allOf(contains('"chev" has size=16 but its box is 10 wide'), contains('drawn at 10'), contains('w=16')));
  });

  group('control_heights_differ', () {
    const hug = {'hug': 0};
    Map<String, Object?> row(List<String> children) => {
          'type': 'row',
          'layout': {'width': {'fill': 0}, 'height': hug},
          'props': {'spacing': 8, 'crossAxisAlignment': 'center'},
          'children': children,
        };
    Map<String, Object?> input({Map<String, Object?> props = const {}, Object? height = hug}) => {
          'type': 'textField',
          'layout': {'flex': 1, 'width': {'fill': 0}, 'height': height},
          'props': {
            'decoration': {'hintText': 'Message'},
            ...props,
          },
        };
    Map<String, Object?> iconButton({Object? size = hug}) => {
          'type': 'iconButton',
          'layout': {'width': size, 'height': size},
          'props': {'icon': 'send'},
        };
    Map<String, Object?> button(String label) => {
          'type': 'filledButton',
          'layout': {'width': hug, 'height': hug},
          'props': {'label': label},
        };

    testWidgets('a field that hugs beside a button written 44 high: said once for the row, naming both', (tester) async {
      // `Row / Input grow fontSize=17 / IconButton "send" w=44 h=44`: a chat
      // composer two writers wrote.
      final report = await render(tester, {
        'composer': row(['msg', 'send']),
        '_msg': input(props: {
          'style': {'fontSize': 17},
        }),
        '_send': iconButton(size: 44),
      });
      final issues = said(report, 'control_heights_differ');
      expect(issues, hasLength(1), reason: '${report.diagnostics}');
      expect(issues.single['nodeId'], 'composer');
      expect(
          issues.single['message'],
          allOf(
            contains('Row "composer"'),
            contains('"msg" (textField) 29 high, hugging'),
            contains('"send" (iconButton) 44 high, h=44 written'),
            contains('leave the heights off'),
            contains('the same h'),
            // Why the field is 29, not 28.
            contains('"msg" hugs to 29, not the step\'s 28'),
          ));
    });

    testWidgets('rows of controls that all hug, or all have one written height: nothing to say', (tester) async {
      final report = await render(tester, {
        // Input grow / IconButton / Button: 28, 28x28, 28.
        'all': row(['a1', 'a2', 'a3']),
        '_a1': input(),
        '_a2': iconButton(),
        '_a3': button('Send'),
        'pair': row(['b1', 'b2']),
        '_b1': input(),
        '_b2': button('Send'),
        'icon': row(['c1', 'c2']),
        '_c1': input(),
        '_c2': iconButton(),
        // One height written on each, on purpose.
        'tall': row(['d1', 'd2']),
        '_d1': input(height: 44),
        '_d2': iconButton(size: 44),
      });
      expect(said(report, 'control_heights_differ'), isEmpty, reason: '${report.diagnostics}');
    });

    testWidgets('a field of lines that has grown past one line beside a button: nothing to say', (tester) async {
      final report = await render(tester, {
        'notes': row(['field', 'save']),
        '_field': input(props: {'minLines': 1, 'maxLines': 6, 'initialValue': 'one\ntwo\nthree'}),
        '_save': button('Save'),
      });
      expect(said(report, 'control_heights_differ'), isEmpty, reason: '${report.diagnostics}');
    });
  });

  testWidgets('an image whose path is worked out as the page runs and names no file: image_failed', (tester) async {
    Map<String, Object?> image(String formula) => {
          'type': 'box',
          'layout': {'width': 40, 'height': 40},
          'decoration': {
            'fills': [
              {'type': 'image', 'image': {'url': '', 'fit': 'cover'}},
            ],
          },
          'bind': {'decoration.fills[0].image.url': formula},
        };
    final report = await render(tester, {
      'missing': image(r'${= "images/" + "none" + ".png"}'),
    });
    final failed = said(report, 'image_failed');
    expect(failed.map((d) => '$d'), [allOf(contains('images/none.png'), contains('worked out as the page runs'), contains('no such file'))]);
    expect(failed.single['severity'], 'error');
  });
}
