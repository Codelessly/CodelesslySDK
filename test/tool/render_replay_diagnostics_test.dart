// What a replay says and reaches: font files site.json declares that are not
// there are one report for the site; a state that writes no picture fails;
// --stage sets a value once where --set holds it; a newline in typed text and
// an argument such as `items=[]` reach the render as written; a node written
// inside a defined word is reached by the id written there.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/cli/src/common.dart';
import '../../tool/cli/src/states.dart';
import '../../tool/render/src/args.dart';
import '../../tool/render/src/compare.dart';
import '../../tool/render/src/render.dart';

Map<String, Object?> _canvas(String body, {List<Object?> actions = const []}) => {
      'type': 'canvas',
      'slots': {'body': body},
      'layout': {'width': 390, 'height': 700},
      'decoration': {
        'fills': [
          {'color': '#FFFFFFFF'},
        ],
      },
      if (actions.isNotEmpty) 'actions': actions,
    };

Map<String, Object?> _text(String text, {Map<String, Object?> style = const {}}) => {
      'type': 'text',
      'layout': {'width': {'fill': 390}, 'height': {'hug': 20}},
      'props': {
        'text': text,
        'style': {'fontSize': 14, 'color': '#FF000000', ...style},
      },
    };

Map<String, Object?> _button(String action) => {
      'type': 'box',
      'layout': {'width': 120, 'height': 40},
      'decoration': {
        'fills': [
          {'color': '#FF999999'},
        ],
      },
      'actions': [
        {
          'trigger': {'type': 'click'},
          'actions': [jsonDecode(action)],
        },
      ],
    };

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_replay_diagnostics_test'));
  tearDown(() => out.deleteSync(recursive: true));

  String textOf(RenderReport report, String id) {
    final boxes = jsonDecode(File(report.images.single.replaceFirst('.png', '.layout.json')).readAsStringSync()) as List;
    return '${boxes.cast<Map>().firstWhere((b) => b['id'] == id)['text']}';
  }

  Future<RenderReport> runPage(WidgetTester tester, Map<String, Object?> page, List<Step> steps) {
    final file = File('${out.path}/page.json')..writeAsStringSync(jsonEncode(page));
    return runRender(tester, RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(390, 700)], steps: steps, dumpLayout: true));
  }

  group('font files site.json declares that are not there', () {
    testWidgets('are one font_missing for the site, naming each face, its file, the folder and the fallback', (tester) async {
      final site = Directory('${out.path}/site')..createSync();
      File('${site.path}/site.json').writeAsStringSync(jsonEncode({
        'schema': 3,
        'pages': ['a.json', 'b.json'],
        'fonts': [
          {
            'family': 'Product Sans',
            'fonts': [
              {'asset': 'assets/product_sans_regular.ttf'},
              {'asset': 'assets/product_sans_bold.ttf', 'weight': 700},
            ],
          },
        ],
      }));
      for (final p in ['a', 'b']) {
        File('${site.path}/$p.json').writeAsStringSync(jsonEncode({
          'schema': 3,
          'roots': [p],
          'nodes': {
            p: _canvas('col'),
            'col': {
              'type': 'column',
              'children': ['t1', 't2'],
              'layout': {'width': {'fill': 390}, 'height': {'fill': 700}},
            },
            't1': _text('Regular', style: {'fontFamily': 'Product Sans'}),
            't2': _text('Bold', style: {'fontFamily': 'Product Sans', 'fontWeight': 700}),
          },
        }));
      }
      final report = await runRender(tester,
          RenderArgs(inputs: [site.path], out: '${out.path}/o', sizes: const [Size(390, 700), Size(430, 932)], googleFonts: false));
      // Two screens at two sizes: still one report, not one per file, screen or size.
      final missing = [for (final d in report.diagnostics) if (d['code'] == 'font_missing') d];
      expect(missing, hasLength(1), reason: '${report.diagnostics}');
      final m = missing.single;
      expect(m['severity'], 'error');
      expect(m['file'], 'site.json');
      expect(m['screen'], isNull);
      final message = m['message'] as String;
      expect(message, contains('2 font files'));
      expect(message, contains('"Product Sans" 400: "assets/product_sans_regular.ttf" is not there'));
      expect(message, contains('"Product Sans" 700: "assets/product_sans_bold.ttf" is not there'));
      expect(message, contains('relative to the site folder, ${Directory(site.path).absolute.path}'), reason: 'the folder it looked in');
      expect(message, contains('drawn with Roboto 400'));
      expect(message, contains('drawn with Roboto 700'));
      // Said before any screen's problems, and not again as a fallback per face.
      expect(report.diagnostics.first['code'], 'font_missing');
      expect(report.diagnostics.where((d) => d['code'] == 'font_fallback' && '${d['message']}'.contains('Product Sans')), isEmpty);
      // The run goes on: every screen is captured.
      expect(report.images, hasLength(4));
    });
  });

  group('states', () {
    test('a state with no picture fails, whatever the exit status', () {
      expect(noCapture(const [], 0, ''), isNotNull);
      expect(noCapture(const [], 0, '')!['code'], 'no_capture');
      expect(noCapture(const [], 0, '')!['severity'], 'error');
      expect(noCapture(const [], 0, '')!['message'], contains('did not run'));
      expect(noCapture(const ['home@390x844-empty.png'], 0, 'ok'), isNull);
    });

    test('a problem of site.json met before any screen is the site\'s, said once', () {
      expect(isSiteProblem({'code': 'font_missing', 'file': 'site.json'}), isTrue);
      expect(isSiteProblem({'code': 'image_failed', 'file': 'site.json', 'nodeId': 'card'}), isFalse);
      expect(isSiteProblem({'code': 'text_clipped', 'file': 'site.json', 'screen': 'home'}), isFalse);
    });
  });

  group('arguments reach the render as written', () {
    test('the harness reads each argument whole: a newline in one is kept', () {
      final argv = argsFromFile('site\u0000--out\u0000o\u0000--type\u0000note=one\ntwo\u0000--set\u0000items=[]\u0000');
      expect(argv, ['site', '--out', 'o', '--type', 'note=one\ntwo', '--set', 'items=[]']);
      final args = parseArgs(argv);
      expect(args.steps.first.value, 'one\ntwo');
      expect(args.steps.last.value, '[]');
      // A file of one argument per line (written before) still reads.
      expect(argsFromFile('site\n--out\no\n'), ['site', '--out', 'o']);
    });

    test('a shell script is given items=[], a newline and a * as they are (Git Bash crashed on [] and globbed *)', () async {
      final dir = Directory('${out.path}/sh')..createSync();
      // render.sh's start: the arguments from CODELESSLY_ARGS_FILE when the caller put them there.
      final launcher = File('tool/render/render.sh').readAsStringSync();
      final start = launcher.substring(launcher.indexOf('if [ -n "\${CODELESSLY_ARGS_FILE'), launcher.indexOf('here="\$(cd'));
      final script = File('${dir.path}/print.sh')
        ..writeAsStringSync('#!/usr/bin/env bash\n${start}for a in "\$@"; do printf "<%s>" "\$a"; done\n');
      if (!Platform.isWindows) Process.runSync('chmod', ['+x', script.path]);
      File('${dir.path}/x.md').writeAsStringSync('');
      final (code, text) = await runCaptured(script.path, ['items=[]', 'note=one\ntwo', '*.md'], cwd: dir.path);
      expect(code, 0, reason: text);
      expect(text, '<items=[]><note=one\ntwo><*.md>');
    });

    testWidgets('--type with a newline puts both lines in a multiline field', (tester) async {
      final report = await runPage(tester, {
        'schema': 3,
        'roots': ['page'],
        'variables': {
          'page': [
            {'name': 'note', 'type': 'text', 'value': ''},
          ],
        },
        'nodes': {
          'page': _canvas('col'),
          'col': {
            'type': 'column',
            'children': ['field', 'label'],
            'layout': {'width': {'fill': 390}, 'height': {'fill': 700}},
          },
          'field': {
            'type': 'textField',
            'layout': {'width': 300, 'height': {'hug': 0}},
            'props': {'maxLines': 5, 'keyboardType': 'multiline'},
            'bind': {'props.initialValue': r'${note}'},
            'actions': [
              {
                'trigger': {'type': 'changed'},
                'actions': [
                  {'type': 'setVariable', 'variable': 'note', 'value': r'${result}'},
                ],
              },
            ],
          },
          'label': _text(r'${note}'),
        },
      }, parseArgs(['p', '--out', 'o', '--type', 'field=one\ntwo']).steps);
      expect(report.errors, 0, reason: '${report.diagnostics}');
      expect(textOf(report, 'label'), 'one\ntwo');
    });
  });

  group('--stage and --set', () {
    const capture = 'test/tool/fixtures/capture';
    Future<int> clockColor(WidgetTester tester, RenderReport report) async {
      final p = (await tester.runAsync(() => decodePng(File(report.images.single).readAsBytesSync())))!;
      final i = (220 * p.width + 195) * 4;
      return (p.rgba[i] << 16) | (p.rgba[i + 1] << 8) | p.rgba[i + 2];
    }

    testWidgets('--stage sets a value once: the timer after it moves it, nothing is held or said', (tester) async {
      final args = parseArgs([capture, '--out', out.path, '--sizes', '390x844', '--screen', 'tools', '--stage', 'clock="2026-01-01T10:00:00Z"', '--wait', '2500']);
      final report = await runRender(tester, args);
      expect(report.diagnostics.where((d) => d['code'] == 'set_overwritten'), isEmpty);
      // The timer wrote now() over it (not 1 January): the flag is not green.
      expect(await clockColor(tester, report), isNot(0x00FF00));
    });

    testWidgets('--set followed by --wait still holds, and the warning names --stage', (tester) async {
      final args = parseArgs([capture, '--out', out.path, '--sizes', '390x844', '--screen', 'tools', '--set', 'clock="2026-01-01T10:00:00Z"', '--wait', '2500']);
      final report = await runRender(tester, args);
      expect(await clockColor(tester, report), 0x00FF00);
      final warning = report.diagnostics.firstWhere((d) => d['code'] == 'set_overwritten');
      expect(warning['message'], contains('--stage clock='));
    });
  });

  group('a node written inside a defined word', () {
    // As the notation expands `IconButton#back` inside the word Bar called as
    // bar1 (and bar2): `back_bar1` under the call's root `bar1`.
    Map<String, Object?> barsPage(List<String> calls) => {
          'schema': 3,
          'roots': ['page'],
          'variables': {
            'page': [
              {'name': 'hits', 'type': 'integer', 'value': 0},
              {
                'name': 'days',
                'type': 'list',
                'value': [for (var i = 0; i < 4; i++) {'n': i}],
              },
              {'name': 'picked', 'type': 'integer', 'value': -1},
            ],
          },
          'nodes': {
            'page': _canvas('col'),
            'col': {
              'type': 'column',
              'children': ['label', 'picked', ...calls, 'list'],
              'layout': {'width': {'fill': 390}, 'height': {'fill': 700}},
            },
            'label': _text(r'hits ${hits}'),
            'picked': _text(r'picked ${picked}'),
            for (final c in calls) ...{
              c: {
                'type': 'row',
                'children': ['back_$c'],
                'layout': {'width': {'fill': 390}, 'height': 50},
              },
              'back_$c': _button('{"type": "setVariable", "variable": "hits", "op": "add", "value": "1"}'),
            },
            'list': {
              'type': 'listView',
              'children': ['cal1'],
              'layout': {'width': {'fill': 390}, 'height': {'hug': 0}},
              'props': {'scrollable': false},
              'bind': {'data': r'${days}'},
            },
            'cal1': {
              'type': 'row',
              'children': ['day_cal1'],
              'layout': {'width': {'fill': 390}, 'height': 44},
            },
            'day_cal1': _button(r'{"type": "setVariable", "variable": "picked", "value": "${= item.n}"}'),
          },
        };

    testWidgets('by the id written there, when one such node is on screen', (tester) async {
      final report = await runPage(tester, barsPage(['bar1']), const [Step('tap', 'back')]);
      expect(report.errors, 0, reason: '${report.diagnostics}');
      expect(textOf(report, 'label'), 'hits 1');
    });

    testWidgets('a list copy by the id written there and #n', (tester) async {
      final report = await runPage(tester, barsPage(['bar1']), const [Step('tap', 'day#2')]);
      expect(report.errors, 0, reason: '${report.diagnostics}');
      expect(textOf(report, 'picked'), 'picked 2');
    });

    testWidgets('several calls: the error names each by its call, and call/id reaches one', (tester) async {
      final ambiguous = await runPage(tester, barsPage(['bar1', 'bar2']), const [Step('tap', 'back')]);
      final failed = ambiguous.diagnostics.firstWhere((d) => d['code'] == 'interaction_failed')['message'] as String;
      expect(failed, contains('bar1/back'));
      expect(failed, contains('bar2/back'));
      final one = await runPage(tester, barsPage(['bar1', 'bar2']), const [Step('tap', 'bar2/back')]);
      expect(one.errors, 0, reason: '${one.diagnostics}');
      expect(textOf(one, 'label'), 'hits 1');
    });
  });
}
