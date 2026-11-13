import 'dart:convert';
import 'dart:typed_data';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/present_support.dart';
import 'action_chains_test.dart' show Harness;

// captureScreenshot (a screen, a node, the whole app), uploading what it
// captured with cloudFiles' source, and calling the host's functions
// (optional ones, ones registered later).

// A cloudFiles upload without a `source` asks the person for files. The app
// shell's screens give no picker of their own, so the services' FilePicker
// (the platform's file dialog by default) chooses them; before, the upload
// got no files and did nothing ("Change photo" never opened a dialog).


Node _click(List<Json> actions) => Node.fromJson({
      'type': 'box',
      'actions': [
        {
          'trigger': {'type': 'click'},
          'actions': actions,
        },
      ],
    }, id: 'photo')!;

const Json _upload = {
  'type': 'cloudFiles',
  'path': 'avatars/u1',
  'maxSizeMB': 5,
  'actions': [
    {'type': 'setVariable', 'variable': 'url', 'value': r'${result.url}'},
  ],
};

PickedFile _photo(int bytes, {String type = 'image/jpeg'}) =>
    PickedFile(name: 'photo.jpg', bytes: Uint8List(bytes), contentType: type);

// preloadImages: loads a story's images before it's read, reporting progress
// in a variable and giving {loaded, failed, total}.

Variable v(String name, Object? value, [VariableType type = VariableType.text]) =>
    Variable(name: name, type: type, value: type.coerce(value));

class Printer implements PrintService {
  final images = <Uint8List>[];
  @override
  Future<bool> printPng(Uint8List png) async {
    images.add(png);
    return true;
  }
}

void main() {
  group('screenshots and app functions', () {
    late List<Json> calls;
    late MemoryFileStorage files;

    Codelessly app(List<PublishLayout> layouts) {
      calls = [];
      files = MemoryFileStorage();
      final c = Codelessly.fromBundle(
        bundleOf(layouts),
        config: CodelesslyConfig(
          services: Services(files: files, analytics: const NoAnalytics()),
          functions: {
            'seen': (context, params) {
              calls.add(params);
              return null;
            },
          },
        ),
        fonts: const NoFontFetcher(),
      );
      addTearDown(c.dispose);
      return c;
    }

    Json seen(Json params) => {'type': 'callFunction', 'name': 'seen', 'params': params};

    PublishLayout shotScreen(List<Json> onClick) => screen(
          'shot',
          width: 400,
          height: 800,
          variables: [const Variable(name: 'image', value: '')],
          children: ['badge'],
          extraNodes: {
            'badge': {
              'type': 'box',
              'layout': {'width': 50, 'height': 30, 'x': {'start': 10}, 'y': {'start': 20}},
              'decoration': {
                'fills': [
                  {'color': '#FFFF0000'},
                ],
              },
            },
          },
          onClick: onClick,
        );

    Future<void> run(WidgetTester tester, CodelesslyWidgetController controller, String nodeId) =>
        tester.runAsync(() => controller.trigger(nodeId, 'click'));

    testWidgets('a capture action takes a picture of a node and uploads it', (tester) async {
      setSize(tester);
      final c = app([
        shotScreen([
          {'type': 'captureScreenshot', 'target': 'node', 'node': 'badge', 'pixelRatio': 2},
          {'type': 'setVariable', 'variable': 'image', 'value': r'${result.image}'},
          seen({'w': r'${result.width}', 'h': r'${result.height}'}),
          {
            'type': 'cloudFiles',
            'path': 'reports',
            'source': r'${image}',
            'fileName': 'bug.png',
            'actions': [
              seen({'url': r'${result.url}', 'name': r'${result.name}'}),
            ],
          },
        ]),
      ]);
      final controller = CodelesslyWidgetController(layoutId: 'shot');
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: c, controller: controller)));
      await settle(tester);
      await run(tester, controller, 'shot-body');
      expect(calls, [
        {'w': 100, 'h': 60},
        {'url': 'memory://reports/bug.png', 'name': 'bug.png'},
      ]);
      final image = controller.read('image')! as String;
      expect(image, startsWith('data:image/png;base64,'));
      final (bytes, type) = files.files['reports/bug.png']!;
      expect(type, 'image/png');
      expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(base64Encode(bytes), image.substring('data:image/png;base64,'.length));
    });

    testWidgets('a capture action can take the screen, or the whole app', (tester) async {
      setSize(tester);
      final c = app([
        shotScreen([
          {'type': 'captureScreenshot', 'pixelRatio': 1},
          seen({'what': 'layout', 'w': r'${result.width}', 'h': r'${result.height}'}),
          {'type': 'captureScreenshot', 'target': 'app', 'pixelRatio': 0.5},
          seen({'what': 'app', 'w': r'${result.width}', 'h': r'${result.height}'}),
        ]),
      ]);
      final controller = CodelesslyWidgetController(layoutId: 'shot');
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Column(children: [
          const SizedBox(height: 100),
          Expanded(child: CodelesslyWidget(codelessly: c, controller: controller)),
        ]),
      ));
      await settle(tester);
      await run(tester, controller, 'shot-body');
      // No capture scope: the app capture is the screen's.
      expect(calls, [
        {'what': 'layout', 'w': 400, 'h': 700},
        {'what': 'app', 'w': 200, 'h': 350},
      ]);
      calls.clear();
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => CodelesslyCaptureScope(child: child!),
        home: Column(children: [
          const SizedBox(height: 100),
          Expanded(child: CodelesslyWidget(codelessly: c, controller: controller)),
        ]),
      ));
      await settle(tester);
      await run(tester, controller, 'shot-body');
      expect(calls.last, {'what': 'app', 'w': 200, 'h': 400});
    });

    testWidgets('an upload of something that is not image data fails the chain', (tester) async {
      setSize(tester);
      final errors = <String?>[];
      final c = app([
        shotScreen([
          {'type': 'cloudFiles', 'path': 'x', 'source': 'https://example.com/a.png'},
          seen({'never': true}),
        ]),
      ]);
      final controller = CodelesslyWidgetController(layoutId: 'shot');
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        home: CodelesslyWidget(codelessly: c, controller: controller, onActionError: (e, s, a) => errors.add(a)),
      ));
      await settle(tester);
      await controller.trigger('shot-body', 'click');
      expect(calls, isEmpty);
      expect(errors, ['cloudFiles']);
      expect(files.files, isEmpty);
    });

    testWidgets('a call to an optional app function that is missing is skipped, and one registered later is found', (tester) async {
      setSize(tester);
      final c = app([
        shotScreen([
          {'type': 'callFunction', 'name': 'askPermission', 'optional': true, 'params': {'kind': 'camera'}},
          {
            'type': 'if',
            'condition': {'left': r'${result.granted}', 'op': 'equalsTo', 'right': 'true'},
            'then': [seen({'branch': 'granted', 'raw': r'${result}'})],
            'else': [seen({'branch': 'not granted', 'raw': r'${result}'})],
          },
        ]),
      ]);
      final controller = CodelesslyWidgetController(layoutId: 'shot');
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: c, controller: controller)));
      await settle(tester);
      await controller.trigger('shot-body', 'click');
      expect(calls, [
        {'branch': 'not granted', 'raw': null},
      ]);
      // The host registers it once it can (a widget with a BuildContext).
      c.registerFunction('askPermission', (context, params) => {'granted': params['kind'] == 'camera'});
      calls.clear();
      await controller.trigger('shot-body', 'click');
      expect(calls, [
        {'branch': 'granted', 'raw': {'granted': true}},
      ]);
      c.unregisterFunction('askPermission');
      expect(c.functions.containsKey('askPermission'), isFalse);
      expect(c.functions.containsKey('seen'), isTrue);
    });
  });

  group('saving a file', () {
    test('a download action works out its file name and contents and reports when done', () async {
      final exports = RecordingFileExporter();
      final h = Harness(services: Services(exports: exports), variables: [
        v('week', '2026-11-09'), v('csv', 'Name,Hours\r\nAlma,32\r\nMaja,24'),
        v('saved', false, VariableType.boolean),
      ]);
      await h.click([
        {'type': 'downloadFile', 'fileName': r'rota-${week}.csv', 'text': r'${csv}', 'mimeType': 'text/csv'},
        {'type': 'setVariable', 'variable': 'saved', 'value': r'${result.saved}'},
      ]);
      expect(h.errors, isEmpty);
      expect(h['saved'], true);
      expect(exports.files.single.fileName, 'rota-2026-11-09.csv');
      expect(exports.files.single.text, 'Name,Hours\r\nAlma,32\r\nMaja,24');
      expect(exports.files.single.mimeType, 'text/csv');
    });
    test('cancelling the save is not an error and writes no file', () async {
      final exports = RecordingFileExporter()..cancelled = true;
      final h = Harness(services: Services(exports: exports), variables: [v('saved', true, VariableType.boolean)]);
      await h.click([
        {'type': 'downloadFile', 'fileName': 'draft.csv', 'text': 'hello'},
        {'type': 'setVariable', 'variable': 'saved', 'value': r'${result.saved}'},
      ]);
      expect(exports.files, isEmpty);
      expect(h['saved'], false);
      expect(h.errors, isEmpty);
    });
    test('a file name cannot name a folder or hold control characters', () {
      expect(exportFileName('../rota\\week\u0000.csv'), '.._rota_week_.csv');
      expect(exportFileName('  '), 'export.txt');
      expect(exportFileName('..'), 'export.txt');
      expect(exportFileName('Røta.csv'), 'Røta.csv');
    });
  });

  group('picking a file', () {
    Future<(VariableScope, List<Json>)> upload(FilePicker picker, {ActionUi? ui}) async {
      final scope = VariableScope(const [Variable(name: 'url', value: '')]);
      final events = <Json>[];
      final context = RuntimeActionContext(
        scope: scope,
        ui: ui ?? NavigatorActionUi(context: () => null),
        services: Services(filePicker: picker, analytics: const NoAnalytics()),
        onActionErrorEvent: events.add,
      );
      await const CodelesslyActions().trigger(_click([_upload]), 'click', context);
      return (scope, events);
    }

    test('a picked file is uploaded', () async {
      final (scope, events) = await upload(FixedFilePicker([_photo(1024)]));
      expect(events, isEmpty);
      expect(scope.read('url'), isNotEmpty);
      scope.dispose();
    });

    test('a photo over the size limit fails as too large', () async {
      final (scope, events) = await upload(FixedFilePicker([_photo(7 * 1024 * 1024)]));
      expect((events.single['error'] as Map)['code'], 'file-too-large');
      expect(scope.read('url'), '');
      scope.dispose();
    });

    test('cancelling the picker does nothing', () async {
      final (scope, events) = await upload(const FixedFilePicker([]));
      expect(events, isEmpty);
      expect(scope.read('url'), '');
      scope.dispose();
    });
  });

  group('preloading images', () {
    testWidgets('a preload action waits for every image and reports its progress and result', (tester) async {
      final scope = VariableScope([
        v('pages', [
          {'sky': 'https://example.com/a.webp'},
          {'sky': 'https://example.com/b.webp'},
          {'sky': 'data:image/png;base64,iVBORw0KGgo='},
          {'sky': 'https://example.com/a.webp'},
        ], VariableType.list),
        v('loaded', 0.0, VariableType.decimal),
        v('outcome', <String, Object?>{}, VariableType.map),
      ]);
      final seen = <double>[];
      scope.addListener(() => seen.add((scope.read('loaded') as num).toDouble()));
      final ctx = RuntimeActionContext(scope: scope, ui: NavigatorActionUi(context: () => null));
      await tester.runAsync(() => const CodelesslyActions().run(
            Node.fromJson({
              'type': 'box',
              'actions': [
                {
                  'trigger': {'type': 'click'},
                  'actions': [
                    {'type': 'preloadImages', 'urls': r'${= map(pages, p => p.sky)}', 'progressVariable': 'loaded'},
                    {'type': 'setVariable', 'variable': 'outcome', 'value': r'${result}'},
                  ],
                },
              ],
            }, id: 'n')!,
            'click',
            ctx,
          ));
      // Three distinct images: the two over HTTP fail in tests, the data URL counts as loaded.
      expect(scope.read('outcome'), {'loaded': 1, 'failed': 2, 'total': 3});
      expect(scope.read('loaded'), 1.0);
      expect(seen, [...seen]..sort());
      expect(seen.last, 1.0);
    });
  });

  group('printing', () {
    testWidgets(
      'a print action scrolls its node into view and sends only that node\'s picture to the print dialog',
      (tester) async {
        final document = LayoutDocument.fromJson({
          'roots': ['root'],
          'nodes': {
            'root': {
              'type': 'column',
              'props': {'scrollable': true},
              'layout': {'width': 200, 'height': 200},
              'children': ['space', 'badge'],
            },
            'space': {
              'type': 'box',
              'layout': {'height': 250},
            },
            'badge': {
              'type': 'box',
              'layout': {'width': 120, 'height': 80},
              'decoration': {
                'fills': [
                  {'color': '#E5FA52'},
                ],
              },
            },
          },
        });
        final tree = NodeTree(DocumentSource(document));
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: NodeView(tree: tree, rootId: 'root', interactive: true),
            ),
          ),
        );
        final printer = Printer();
        final scope = VariableScope([
          const Variable(
            name: 'requested',
            type: VariableType.boolean,
            value: false,
          ),
        ]);
        final errors = <Object>[];
        final context = RuntimeActionContext(
          scope: scope,
          tree: tree,
          services: Services(printing: printer),
          onError: (e, _, _) => errors.add(e),
        );
        final trigger = Node.fromJson({
          'type': 'box',
          'actions': [
            {
              'trigger': {'type': 'click'},
              'actions': [
                {'type': 'print', 'node': 'badge'},
                {
                  'type': 'setVariable',
                  'variable': 'requested',
                  'value': r'${result.requested}',
                },
              ],
            },
          ],
        }, id: 'button')!;
        await tester.runAsync(() async {
          final action = const CodelesslyActions().run(trigger, 'click', context);
          await tester.pump();
          await action;
        });
        expect(errors, isEmpty);
        expect(scope.read('requested'), true);
        expect(printer.images, hasLength(1));
        final png = printer.images.single;
        expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        final header = ByteData.sublistView(png);
        expect(header.getUint32(16), 240);
        expect(header.getUint32(20), 160);
        await tester.pumpWidget(const SizedBox());
        tree.dispose();
        scope.dispose();
      },
    );

    test('on a platform that cannot print, the action reports that no dialog opened', () async {
      expect(await const PlatformPrintService().printPng(Uint8List(0)), false);
    });
  });
}
