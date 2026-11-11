// captureScreenshot (a screen, a node, the whole app), uploading what it
// captured with cloudFiles' source, and calling the host's functions
// (optional ones, ones registered later).
import 'dart:convert';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/runtime/actions/action_error.dart' show CodedFailure;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/present_support.dart';

void main() {
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

  testWidgets('captures a node as a PNG and uploads it', (tester) async {
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

  testWidgets('captures the screen, or the whole app inside a capture scope', (tester) async {
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

  testWidgets('an upload source that is not a data: URL fails the chain', (tester) async {
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

  test('source files: data URLs, maps and lists, named and numbered', () {
    const png = 'data:image/png;base64,iVBORw0KGgo=';
    expect(sourceFiles(png, name: 'a.png').single.name, 'a.png');
    expect(sourceFiles({'data': png, 'name': 'b.png'}).single.name, 'b.png');
    final two = sourceFiles([png, 'data:text/plain,hi'], name: 'shot.png');
    expect([for (final f in two) f.name], ['shot-1.png', 'shot-2.png']);
    expect(two.last.contentType, 'text/plain');
    expect(utf8.decode(two.last.bytes), 'hi');
    expect(sourceFiles(png).single.name, matches(RegExp(r'^file-\d+\.png$')));
    expect(() => sourceFiles(42), throwsA(isA<CodedFailure>()));
  });

  testWidgets('call function: a missing optional one is skipped; a registered one is found later', (tester) async {
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
}
