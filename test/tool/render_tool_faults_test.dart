// The tool faults of the NOCD rebuild's friction register, each at its source:
// a capture is named after the page a reset left shown; --only picks a state by
// its exact name; a toast's button is tapped by its label; a text changed after
// the last frame is laid out before the checks read it; --outline reaches every
// --state of a batch and is read from a manifest's args; a covered node says what
// covers it and which copy is not covered; a point is no target; a text field's
// icon is tapped in the field (it keeps the focus); a drag can rest before it
// moves; a key typed after a new line adds to the field; camel-case step keys;
// --clock lets now() move; a turned node's drawn box; a notation file site.json
// lists is not written over; --scroll runs scroll reactions.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/cli/src/common.dart' show runCaptured;
import '../../tool/cli/src/outline.dart';
import '../../tool/cli/src/render_cmd.dart';
import '../../tool/cli/src/states.dart';
import '../../tool/notation/notation_site.dart';
import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

Map<String, Object?> _canvas(String body, {List<Object?> actions = const [], double height = 700}) => {
      'type': 'canvas',
      'slots': {'body': body},
      'layout': {'width': 390, 'height': height},
      'decoration': {
        'fills': [
          {'color': '#FFFFFFFF'},
        ],
      },
      if (actions.isNotEmpty) 'actions': actions,
    };

Map<String, Object?> _text(String text) => {
      'type': 'text',
      'layout': {'width': {'fill': 390}, 'height': {'hug': 20}},
      'props': {
        'text': text,
        'style': {'fontSize': 14, 'color': '#FF000000'},
      },
    };

Map<String, Object?> _box({double w = 120, double h = 40, List<Object?> actions = const [], Map<String, Object?> layout = const {}, String color = '#FF999999'}) => {
      'type': 'box',
      'layout': {'width': w, 'height': h, ...layout},
      'decoration': {
        'fills': [
          {'color': color},
        ],
      },
      if (actions.isNotEmpty) 'actions': actions,
    };

Map<String, Object?> _on(String trigger, List<Object?> actions) => {
      'trigger': {'type': trigger},
      'actions': actions,
    };

Map<String, Object?> _set(String variable, String value) => {'type': 'setVariable', 'variable': variable, 'value': value};

Map<String, Object?> _column(List<String> children, {double height = 700}) => {
      'type': 'column',
      'children': children,
      'layout': {'width': {'fill': 390}, 'height': {'fill': height}},
    };

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_tool_faults_test'));
  tearDown(() => out.deleteSync(recursive: true));

  List<Map> boxesOf(String png) => (jsonDecode(File(png.replaceFirst('.png', '.layout.json')).readAsStringSync()) as List).cast<Map>();
  String textOf(RenderReport report, String id) => '${boxesOf(report.images.single).firstWhere((b) => b['id'] == id)['text']}';
  String failure(RenderReport report) =>
      '${report.diagnostics.firstWhere((d) => d['code'] == 'interaction_failed', orElse: () => {'message': 'none: ${report.diagnostics}'})['message']}';

  Future<RenderReport> runPage(WidgetTester tester, Map<String, Object?> page, List<Step> steps, {DateTime? clock}) {
    final file = File('${out.path}/page.json')..writeAsStringSync(jsonEncode(page));
    return runRender(tester,
        RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(390, 700)], steps: steps, dumpLayout: true, clock: clock));
  }

  group('a capture is named after the page shown at its end', () {
    testWidgets('a reset (pushed, then the pages under it removed) names the page it shows, not the one before', (tester) async {
      Map<String, Object?> page(String id, String title, List<String> extra, Map<String, Object?> nodes) => {
            'schema': 3,
            'id': id,
            'roots': [id],
            'nodes': {
              id: _canvas('${id}Col', height: 600),
              '${id}Col': _column(['${id}Title', ...extra], height: 600),
              '${id}Title': _text(title),
              ...nodes,
            },
          };
      final site = Directory('${out.path}/site')..createSync();
      File('${site.path}/site.json').writeAsStringSync(jsonEncode({
        'pages': ['home.json', 'detail.json', 'start.json'],
      }));
      File('${site.path}/home.json').writeAsStringSync(jsonEncode(page('home', 'Home', ['open'], {
        'open': _box(actions: [
          _on('click', [
            {'type': 'navigate', 'to': 'detail'},
          ]),
        ]),
      })));
      File('${site.path}/detail.json').writeAsStringSync(jsonEncode(page('detail', 'Detail', ['leave'], {
        'leave': _box(actions: [
          _on('click', [
            {'type': 'navigate', 'to': 'start', 'mode': 'reset'},
          ]),
        ]),
      })));
      File('${site.path}/start.json').writeAsStringSync(jsonEncode(page('start', 'Start', const [], const {})));
      final report = await runRender(tester, RenderArgs(
          inputs: [site.path], out: '${out.path}/o', screens: const ['home'], sizes: const [Size(390, 600)],
          steps: const [Step('tap', 'open'), Step('tap', 'leave')], dumpLayout: true));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      final png = report.images.single;
      expect([for (final b in boxesOf(png)) if (b['text'] != null) b['text']], contains('Start'));
      expect(png.split('/').last, startsWith('start@390x600'));
    });
  });

  group('states', () {
    test('--only picks the state of that name alone; a name no state has picks those containing it', () {
      final all = [
        for (final n in ['profile', 'profile-loading', 'picker-a', 'picker-b']) {'name': n},
      ];
      List<String> names(List<String> only) => [for (final s in pickStates(all, only)) '${s['name']}'];
      expect(names(['profile']), ['profile']);
      expect(names(['picker-']), ['picker-a', 'picker-b']);
      expect(names(['profile', 'picker-b']), ['profile', 'picker-b']);
      expect(names(const []), hasLength(4));
    });

    test('a step key in camel case is the option it names; --outline in args is the command\'s own', () {
      expect(stepArgs([
        {'longPress': 'replyRow#0/support'},
        {'doubleTap': 'photo'},
        {'tap': 'go'},
        {'unfocus': true},
      ]), ['--long-press', 'replyRow#0/support', '--double-tap', 'photo', '--tap', 'go', '--unfocus']);
      final (args, outlined) = takeOutline(['--no-google-fonts', '--outline']);
      expect(args, ['--no-google-fonts']);
      expect(outlined, isTrue);
      expect(takeOutline(['--no-google-fonts']).$2, isFalse);
    });
  });

  test('render --outline dumps the layout of every --state of a batch, not the last one\'s only', () {
    final args = withDumpLayout(['site', '--out', 'o', '--state', 'a', '--tap', 'x', '--state', 'b', '--tap', 'y']);
    final runs = stateRuns(args);
    expect(runs, hasLength(2));
    for (final r in runs) {
      expect(r, contains('--dump-layout'));
    }
    expect(withDumpLayout(['site', '--out', 'o']), ['site', '--out', 'o', '--dump-layout']);
    expect(withDumpLayout(['site', '--dump-layout', '--out', 'o']), ['site', '--dump-layout', '--out', 'o']);
  });

  group('a toast\'s own buttons', () {
    Map<String, Object?> toastPage() => {
          'schema': 3,
          'roots': ['page'],
          'variables': {
            'page': [
              {'name': 'result', 'type': 'text', 'value': 'none'},
            ],
          },
          'nodes': {
            'page': _canvas('col'),
            'col': _column(['label', 'show']),
            'label': _text(r'result ${result}'),
            'show': _box(actions: [
              _on('click', [
                {
                  'type': 'showToast',
                  'message': 'Changes saved',
                  'durationMs': 8000,
                  'actionLabel': 'Undo',
                  'actions': [_set('result', 'undone')],
                  'showClose': true,
                },
              ]),
            ]),
          },
        };

    testWidgets('are tapped by their label (--tap Undo) or id (toastAction)', (tester) async {
      final byLabel = await runPage(tester, toastPage(), const [Step('tap', 'show'), Step('tap', 'Undo')]);
      expect(byLabel.errors, 0, reason: '${byLabel.diagnostics}');
      expect(textOf(byLabel, 'label'), 'result undone');
      expect(byLabel.diagnostics.where((d) => d['code'] == 'tap_no_reaction'), isEmpty);
      final byId = await runPage(tester, toastPage(), const [Step('tap', 'show'), Step('tap', 'toastAction')]);
      expect(byId.errors, 0, reason: '${byId.diagnostics}');
      expect(textOf(byId, 'label'), 'result undone');
    });

    testWidgets('a tap that names nothing on screen lists them', (tester) async {
      final missed = await runPage(tester, toastPage(), const [Step('tap', 'show'), Step('tap', 'Redo')]);
      expect(failure(missed), allOf(contains('toastAction ("Undo")'), contains('toastClose')));
    });
  });

  testWidgets('a text changed after the last frame is laid out before it is read', (tester) async {
    await tester.pumpWidget(const Directionality(textDirection: TextDirection.ltr, child: Text('one', maxLines: 1)));
    final p = tester.renderObject<RenderParagraph>(find.byType(RichText));
    // As a stream's next words land: the text changes with no frame after it.
    p.text = const TextSpan(text: 'one two three', style: TextStyle(fontSize: 14));
    expect(p.debugNeedsLayout, isTrue);
    await layoutSettled(tester);
    expect(p.debugNeedsLayout, isFalse);
    expect(() => p.didExceedMaxLines, returnsNormally);
  });

  group('a step that reaches no node says what to write', () {
    testWidgets('covered by a later child of the same node: which comes after which, and to reorder', (tester) async {
      final report = await runPage(tester, {
        'schema': 3,
        'roots': ['page'],
        'nodes': {
          'page': _canvas('stack'),
          'stack': {
            'type': 'stack',
            'children': ['send', 'art'],
            'layout': {'width': 41, 'height': 41},
          },
          'send': _box(w: 41, h: 41, actions: [_on('click', const [])]),
          'art': _box(w: 41, h: 41, color: '#FF3366FF'),
        },
      }, const [Step('tap', 'send')]);
      expect(failure(report), allOf(contains('covered by "art"'), contains('"art" comes after "send" in "stack"'), contains('Put "send" after "art"')));
    });

    testWidgets('a list copy covered by what is over it names the copies that are not', (tester) async {
      final report = await runPage(tester, {
        'schema': 3,
        'roots': ['page'],
        'variables': {
          'page': [
            {'name': 'cards', 'type': 'list', 'value': [1, 2, 3]},
          ],
        },
        'nodes': {
          'page': _canvas('stack'),
          'stack': {
            'type': 'stack',
            'children': ['list', 'pinned'],
            'layout': {'width': {'fill': 390}, 'height': {'fill': 700}},
          },
          'list': {
            'type': 'listView',
            'children': ['card'],
            'layout': {'width': {'fill': 390}, 'height': {'hug': 0}},
            'props': {'scrollable': false},
            'bind': {'data': r'${cards}'},
          },
          'card': _box(w: 390, h: 60, actions: [_on('click', const [])]),
          'pinned': _box(w: 390, h: 70, color: '#FF000000'),
        },
      }, const [Step('tap', 'card#0')]);
      final message = failure(report);
      expect(message, contains('covered by "pinned"'));
      expect(message, contains('Not covered: card#1, card#2'));
    });

    testWidgets('a point is no target: the step says to name the node', (tester) async {
      final report = await runPage(tester, {
        'schema': 3,
        'roots': ['page'],
        'nodes': {'page': _canvas('col'), 'col': _column(['b']), 'b': _box()},
      }, const [Step('tap', '150,345')]);
      expect(failure(report), allOf(contains('names a node, not a point'), contains('--dump-layout')));
    });
  });

  testWidgets('field@suffix taps the icon in the field: its reaction runs and the field keeps the focus', (tester) async {
    final report = await runPage(tester, {
      'schema': 3,
      'roots': ['page'],
      'variables': {
        'page': [
          {'name': 'shown', 'type': 'boolean', 'value': false},
        ],
      },
      'nodes': {
        'page': _canvas('col'),
        'col': _column(['secret', 'label']),
        'secret': {
          'type': 'textField',
          'layout': {'width': 300, 'height': {'hug': 0}},
          'props': {
            'decoration': {
              'suffixIcon': {
                'icon': 'visibility',
                'actions': [
                  _on('click', [_set('shown', r'${= !shown}')]),
                ],
              },
            },
          },
        },
        'label': _text(r'shown ${shown}'),
      },
    }, const [Step('focus', 'secret'), Step('type', 'secret', 'hunter2'), Step('tap', 'secret@suffix')]);
    expect(report.errors, 0, reason: '${report.diagnostics}');
    expect(textOf(report, 'label'), 'shown true');
    expect(report.focus.map((f) => f['id']), contains('secret'));
    expect(boxesOf(report.images.single).firstWhere((b) => b['id'] == 'secret')['parts'], contains('@suffix'));
  });

  group('--drag', () {
    Map<String, Object?> holdPage() => {
          'schema': 3,
          'roots': ['page'],
          'variables': {
            'page': [
              {'name': 'held', 'type': 'integer', 'value': 0},
            ],
          },
          'nodes': {
            'page': _canvas('col'),
            'col': _column(['label', 'wrapper']),
            'label': _text(r'held ${held}'),
            'wrapper': _box(w: 200, h: 80, actions: [
              _on('longPress', [_set('held', '1')]),
            ]),
          },
        };

    testWidgets(',press=<ms> rests the finger first: a hold reaction fires, then the same pointer moves', (tester) async {
      final pressed = await runPage(tester, holdPage(), parseArgs(['p', '--out', 'o', '--drag', 'wrapper=0,60,press=700']).steps);
      expect(pressed.errors, 0, reason: '${pressed.diagnostics}');
      expect(textOf(pressed, 'label'), 'held 1');
      final quick = await runPage(tester, holdPage(), parseArgs(['p', '--out', 'o', '--drag', 'wrapper=0,60']).steps);
      expect(textOf(quick, 'label'), 'held 0');
    });
  });

  testWidgets('a key typed after a new line adds to what was typed', (tester) async {
    final report = await runPage(tester, {
      'schema': 3,
      'roots': ['page'],
      'variables': {
        'page': [
          {'name': 'draft', 'type': 'text', 'value': ''},
          {'name': 'focused', 'type': 'boolean', 'value': false},
        ],
      },
      'nodes': {
        'page': _canvas('col'),
        'col': _column(['field', 'label']),
        // As NOCD 26's SheetField: bound, counted, sentence case, with focus reactions.
        'field': {
          'type': 'textField',
          'layout': {'width': 300, 'height': 48},
          'props': {'maxLines': 6, 'minLines': 1, 'keyboardType': 'multiline', 'maxLength': 600, 'textCapitalization': 'sentences'},
          'bind': {'props.initialValue': r'${draft}'},
          'actions': [
            _on('changed', [_set('draft', r'${result}')]),
            _on('focusGained', [_set('focused', 'true')]),
            _on('focusLost', [_set('focused', 'false')]),
          ],
        },
        'label': _text(r'[${draft}]'),
      },
    }, parseArgs(['p', '--out', 'o', '--focus', 'field', '--type', 'field=Ask for reassurance', '--key', 'shift+Enter', '--key', 's']).steps);
    expect(report.errors, 0, reason: '${report.diagnostics}');
    expect(textOf(report, 'label'), '[Ask for reassurance\ns]');
  });

  group('--clock', () {
    Map<String, Object?> clockPage() => {
          'schema': 3,
          'roots': ['clock'],
          'variables': {
            'clock': [
              {'name': 'end', 'type': 'integer', 'value': 0},
            ],
          },
          'nodes': {
            'clock': _canvas('col', actions: [
              _on('load', [_set('end', r'${= nowMs() + 12000}')]),
            ]),
            'col': _column(['shown']),
            'shown': _text(r"${= formatDate(now(), 'yyyy')} ${= round((end - nowMs()) / 1000)}"),
          },
        };

    testWidgets('starts now() at that time and moves it with the wait: a countdown ticks', (tester) async {
      final report = await runPage(tester, clockPage(), const [Step('wait', '5000')], clock: DateTime.utc(2031, 3, 9, 12));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      final parts = textOf(report, 'shown').split(' ');
      expect(parts.first, '2031');
      // Twelve seconds from load, less the wait (and the settles around it).
      expect(int.parse(parts.last), lessThanOrEqualTo(7));
    });

    test('does not go with --now', () {
      expect(() => parseArgs(['p', '--out', 'o', '--now', '2026-01-01T00:00:00Z', '--clock', '2026-01-01T00:00:00Z']), throwsFormatException);
      expect(parseArgs(['p', '--out', 'o', '--clock', '2026-01-01T00:00:00Z']).clock, DateTime.utc(2026));
    });
  });

  testWidgets('a turned node\'s layout entry has where it is drawn, and the outline says it', (tester) async {
    final report = await runPage(tester, {
      'schema': 3,
      'roots': ['page'],
      'nodes': {
        'page': _canvas('stack'),
        'stack': {
          'type': 'stack',
          'children': ['bar'],
          'layout': {'width': 100, 'height': 100, 'x': {'start': 40}, 'y': {'start': 40}},
        },
        'bar': {
          ..._box(w: 80, h: 10, layout: {'x': {'start': 10}, 'y': {'start': 45}}),
          'motion': {'rotate': 90},
        },
      },
    }, const []);
    expect(report.errors, 0, reason: '${report.diagnostics}');
    final bar = boxesOf(report.images.single).firstWhere((b) => b['id'] == 'bar');
    expect(bar['painted'], isA<Map>(), reason: '$bar');
    final painted = bar['painted'] as Map;
    expect(painted['transformed'], isTrue);
    // Turned a quarter about its center: 10 wide, 80 tall, at the stack's middle.
    expect(painted['w'], closeTo(10, 0.6));
    expect(painted['h'], closeTo(80, 0.6));
    final stack = boxesOf(report.images.single).firstWhere((b) => b['id'] == 'stack');
    final (x, y) = ((stack['x'] as num) + 45, (stack['y'] as num) + 10);
    expect(painted['x'], x);
    expect(painted['y'], y);
    final tree = DocumentTree.load(['${out.path}/page.json']);
    expect(outlineCapture(boxesOf(report.images.single), tree, const []).join('\n'), contains('(drawn at $x,$y 10x80, turned or scaled)'));
  });

  testWidgets('--scroll runs the scroll view\'s scroll reactions, as a user\'s scroll does', (tester) async {
    final report = await runPage(tester, {
      'schema': 3,
      'roots': ['page'],
      'variables': {
        'page': [
          {'name': 'at', 'type': 'integer', 'value': 0},
        ],
      },
      'nodes': {
        'page': _canvas('outer'),
        'outer': _column(['label', 'body']),
        'label': _text(r'at ${at}'),
        'body': {
          'type': 'column',
          'children': ['tall'],
          'layout': {'width': {'fill': 390}, 'height': 300},
          'props': {'scrollable': true},
          'actions': [
            _on('scroll', [_set('at', r'${= round(result.offset)}')]),
          ],
        },
        'tall': _box(w: 390, h: 1200),
      },
    }, const [Step('scroll', 'body', '400')]);
    expect(report.errors, 0, reason: '${report.diagnostics}');
    expect(textOf(report, 'label'), 'at 400');
  });

  test('a notation file site.json lists is not written over: its JSON goes beside it', () async {
    final root = Directory('${out.path}/notation')..createSync();
    File('${root.path}/site.json').writeAsStringSync(jsonEncode({
      'schema': 3,
      'pages': ['pages/home.txt'],
      'components': ['components/Tag.txt'],
    }));
    Directory('${root.path}/pages').createSync();
    File('${root.path}/pages/home.txt').writeAsStringSync('Column\n  Text "hi"\n');
    final site = await NotationSite.load('${root.path}/site.json');
    expect(site.pageOut('${root.path}/pages/home.txt'), endsWith('pages/home.json'));
    expect(site.componentOut('Tag'), endsWith('components/Tag.json'));
    expect(site.listedNotation, ['pages/home.txt', 'components/Tag.txt']);
    expect(NotationSite.jsonRef('pages/home.json'), 'pages/home.json');
  });

  test('tool/codelessly expand is the notation\'s expand (it was "Unknown command")', () async {
    // tool/codelessly is a bash script with no extension: started by bash, as from a shell.
    final (_, text) = await runCaptured('bash', [File('tool/codelessly').absolute.path.replaceAll(r'\', '/'), 'expand']);
    expect(text, contains('usage: expand.dart'));
    expect(text, isNot(contains('Unknown command')));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('an error of Flutter\'s semantics pass is told as one', () {
    expect(inSemanticsPass("'package:flutter/src/rendering/object.dart': Failed assertion: line 5730 pos 14: '!semantics.parentDataDirty': is not true.", null), isTrue);
    expect(inSemanticsPass('A RenderFlex overflowed by 4 pixels on the bottom.', null), isFalse);
  });
}
