import 'dart:async';
import 'dart:typed_data';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart' show settle;

class _Cloud extends BackendCloudDatabase {
  _Cloud() : super(backend: MemoryDocumentBackend());
  bool fail = true;
  Object? watchFailure;
  bool empty = false;
  int writes = 0;
  final documents = <StreamController<Json?>>[];
  final queries = <StreamController<List<Json>>>[];
  @override
  Future<String> addDocument(String path, Json value, {String? id, bool skipIfExists = true}) async {
    writes++;
    if (fail) throw StateError('sandbox document unavailable');
    return id ?? 'sandbox-document';
  }

  @override
  Stream<Json?> watchDocument(String path, String id) {
    if (watchFailure != null) throw watchFailure!;
    if (empty) return const Stream.empty();
    final stream = StreamController<Json?>.broadcast();
    documents.add(stream);
    return stream.stream;
  }

  @override
  Stream<List<Json>> watchQuery(String path, CloudQuery query, {List<String> loadRelated = const []}) {
    final stream = StreamController<List<Json>>.broadcast();
    queries.add(stream);
    return stream.stream;
  }

  Future<void> close() async {
    for (final stream in documents) {
      await stream.close();
    }
    for (final stream in queries) {
      await stream.close();
    }
    dispose();
  }
}

class _Files extends MemoryFileStorage {
  bool fail = true;
  @override
  Future<void> delete(String pathOrUrl) async {
    if (fail) throw StateError('sandbox file unavailable');
  }

  @override
  Future<CloudFile> upload(String path, Uint8List bytes, {String? contentType, void Function(double sent)? onProgress}) async {
    if (fail) throw StateError('sandbox upload unavailable');
    return super.upload(path, bytes, contentType: contentType);
  }
}

const Json _write = {'type': 'cloudDocuments', 'operation': 'add', 'path': 'favourites', 'id': 'sandbox', 'document': '{"owner":"sandbox"}'};
const Json _file = {'type': 'cloudFiles', 'operation': 'delete', 'path': 'sandbox/avatar.png'};
const Json _load = {
  'type': 'loadCloudData',
  'variable': 'dataState',
  'id': 'sandbox',
  'query': {'collection': 'events'},
};
Json _set(String name, String value) => {'type': 'setVariable', 'variable': name, 'value': value};
Node _click(List<Json> actions) => Node.fromJson({
  'type': 'box',
  'actions': [
    {
      'trigger': {'type': 'click'},
      'actions': actions,
    },
  ],
}, id: 'button')!;
PublishBundle _bundle(List<Json> actions, {bool brokenHandler = false}) {
  final layout = PublishLayout.fromJson({
    'schema': 2,
    'id': 'home',
    'roots': ['canvas'],
    'variables': {
      'canvas': [
        const Variable(name: 'saved', value: 'no').toJson(),
        const Variable(name: 'errorCount', type: VariableType.integer, value: 0).toJson(),
        const Variable(name: 'lastError', value: '').toJson(),
        const Variable(name: 'lastNode', value: '').toJson(),
        const Variable(name: 'dataState', type: VariableType.map, value: <String, Object?>{}).toJson(),
      ],
    },
    'nodes': {
      'canvas': {
        'type': 'canvas',
        'slots': {'body': 'body'},
        'layout': {'width': 390, 'height': 844},
        'actions': [
          {
            'trigger': {'type': 'actionError'},
            'actions': [
              {'type': 'setVariable', 'variable': 'errorCount', 'op': 'add', 'value': '1'},
              _set('lastError', r'${result.error.action}'),
              _set('lastNode', r'${result.error.nodeId}'),
              if (brokenHandler) {'type': 'callFunction', 'name': 'missing-error-handler'},
              if (!brokenHandler)
                {
                  'type': 'showToast',
                  'message': 'Could not save. Try again.',
                  'actionLabel': 'Retry',
                  'actions': [_write, _set('saved', 'yes')],
                },
            ],
          },
        ],
      },
      'body': {
        'type': 'stack',
        'layout': {
          'width': {'fill': 390},
          'height': {'fill': 844},
        },
        'children': ['button'],
      },
      'button': {
        'type': 'box',
        'layout': {'width': 100, 'height': 50},
        'decoration': {
          'fills': [
            {'color': '#FF334455'},
          ],
        },
        'actions': [
          {
            'trigger': {'type': 'click'},
            'actions': actions,
          },
        ],
      },
    },
  });
  return PublishBundle(
    model: PublishModel(projectId: 'sandbox', entryLayoutId: 'home', layouts: {'home': PublishLayoutInfo.of(layout)}),
    layouts: {'home': layout},
  );
}

class _PickUi extends NoActionUi {
  @override
  Future<List<PickedFile>> pickFiles({bool images = true, bool multiple = true}) async => [
    PickedFile(name: 'sandbox.png', bytes: Uint8List.fromList([1, 2, 3])),
  ];
}

void main() {
  for (final action in [_write, _file]) {
    testWidgets('published ${action['type']} failure emits one canvas event and toast Retry recovers', (tester) async {
      final cloud = _Cloud();
      final files = _Files();
      final errors = <String?>[];
      final app = Codelessly.fromBundle(
        _bundle([action, _set('saved', 'yes')]),
        config: CodelesslyConfig(
          services: Services(cloud: cloud, files: files, analytics: const NoAnalytics()),
        ),
        fonts: const NoFontFetcher(),
      );
      final controller = CodelesslyWidgetController();
      await tester.pumpWidget(
        MaterialApp(
          home: CodelesslyWidget(codelessly: app, controller: controller, onActionError: (e, s, a) => errors.add(a)),
        ),
      );
      await settle(tester);
      await controller.trigger('button', 'click');
      await settle(tester);
      expect(controller.read('saved'), 'no');
      expect(controller.read('errorCount'), 1);
      expect(controller.read('lastError'), action['type']);
      expect(controller.read('lastNode'), 'button');
      expect(errors, [action['type']]);
      expect(find.text('Could not save. Try again.'), findsOneWidget);
      cloud.fail = false;
      files.fail = false;
      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(controller.read('saved'), 'yes');
      expect(controller.read('errorCount'), 1);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      app.dispose();
      await cloud.close();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('failed authored error reaction reports to host without recursion', (tester) async {
    final cloud = _Cloud();
    final errors = <String?>[];
    final app = Codelessly.fromBundle(
      _bundle([_write], brokenHandler: true),
      config: CodelesslyConfig(
        services: Services(cloud: cloud, analytics: const NoAnalytics()),
      ),
      fonts: const NoFontFetcher(),
    );
    final controller = CodelesslyWidgetController();
    await tester.pumpWidget(
      MaterialApp(
        home: CodelesslyWidget(codelessly: app, controller: controller, onActionError: (e, s, a) => errors.add(a)),
      ),
    );
    await settle(tester);
    await controller.trigger('button', 'click');
    await settle(tester);
    expect(controller.read('errorCount'), 1);
    expect(errors, ['cloudDocuments', 'callFunction']);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    app.dispose();
    await cloud.close();
    expect(tester.takeException(), isNull);
  });
  testWidgets('published async load failure cancels remaining actions and retry remains usable', (tester) async {
    final cloud = _Cloud();
    final errors = <String?>[];
    final app = Codelessly.fromBundle(
      _bundle([
        _load,
        {'type': 'delay', 'ms': 5000},
        _set('saved', 'yes'),
      ]),
      config: CodelesslyConfig(
        services: Services(cloud: cloud, analytics: const NoAnalytics()),
      ),
      fonts: const NoFontFetcher(),
    );
    final controller = CodelesslyWidgetController();
    await tester.pumpWidget(
      MaterialApp(
        home: CodelesslyWidget(codelessly: app, controller: controller, onActionError: (e, s, a) => errors.add(a)),
      ),
    );
    await settle(tester);
    final first = controller.trigger('button', 'click');
    await tester.pump();
    cloud.documents.single.add({'title': 'fixture'});
    await tester.pump();
    cloud.documents.single.addError(StateError('sandbox stream unavailable'));
    await settle(tester);
    await first;
    expect(controller.read('saved'), 'no');
    expect(controller.read('dataState.status'), 'error');
    expect(controller.read('errorCount'), 1);
    expect(errors, ['loadCloudData']);
    final retry = controller.trigger('button', 'click');
    await tester.pump();
    cloud.documents.last.add({'title': 'recovered'});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 5100));
    await retry;
    expect(controller.read('saved'), 'yes');
    expect(controller.read('dataState.status'), 'loaded');
    expect(controller.read('errorCount'), 1);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    app.dispose();
    await cloud.close();
    expect(tester.takeException(), isNull);
  });
  for (final query in [false, true]) {
    test('initial ${query ? 'query' : 'document'} load failure stops success chain and reports once', () async {
      final cloud = _Cloud();
      final events = <Json>[];
      final errors = <Object>[];
      final scope = VariableScope([
        const Variable(name: 'dataState', type: VariableType.map, value: <String, Object?>{}),
        const Variable(name: 'saved', value: 'no'),
      ]);
      final context = RuntimeActionContext(
        scope: scope,
        services: Services(cloud: cloud, analytics: const NoAnalytics()),
        onError: (e, s, a) => errors.add(e),
        onActionErrorEvent: events.add,
      );
      final run = const CodelesslyActions().trigger(
        _click([
          {..._load, 'single': !query},
          _set('saved', 'yes'),
        ]),
        'click',
        context.withScope(ValuesScope({}, scope)),
      );
      await pumpEventQueue();
      if (query) {
        cloud.queries.single.addError(StateError('sandbox query unavailable'));
      } else {
        cloud.documents.single.addError(StateError('sandbox document unavailable'));
      }
      await run;
      expect(scope.read('saved'), 'no');
      expect(scope.read('dataState.status'), 'error');
      expect(events, hasLength(1));
      expect(errors, hasLength(1));
      expect((events.single['error'] as Map)['action'], 'loadCloudData');
      expect((events.single['error'] as Map)['nodeId'], 'button');
      expect((events.single['error'] as Map).keys.toSet(), {'type', 'code', 'message', 'action', 'nodeId'});
      context.dispose();
      scope.dispose();
      await cloud.close();
    });
  }
  for (final empty in [false, true]) {
    test(empty ? 'empty load stream exits loading and reports once' : 'synchronous watch failure exits loading and reports once', () async {
      final cloud = _Cloud();
      if (empty) {
        cloud.empty = true;
      } else {
        cloud.watchFailure = StateError('sandbox watch unavailable');
      }
      final events = <Json>[];
      final scope = VariableScope([
        const Variable(name: 'dataState', type: VariableType.map, value: <String, Object?>{}),
        const Variable(name: 'saved', value: 'no'),
      ]);
      final context = RuntimeActionContext(
        scope: scope,
        services: Services(cloud: cloud, analytics: const NoAnalytics()),
        onActionErrorEvent: events.add,
      );
      await const CodelesslyActions().trigger(_click([_load, _set('saved', 'yes')]), 'click', context);
      expect(scope.read('dataState.status'), 'error');
      expect(scope.read('saved'), 'no');
      expect(events, hasLength(1));
      context.dispose();
      scope.dispose();
      await cloud.close();
    });
  }
  test('an async load failure stops only its invocation and leaves the node token reusable', () async {
    final cloud = _Cloud();
    final events = <Json>[];
    final lifecycle = ActionCancellation();
    final scope = VariableScope([
      const Variable(name: 'dataState', type: VariableType.map, value: <String, Object?>{}),
      const Variable(name: 'saved', value: 'no'),
    ]);
    final context = RuntimeActionContext(
      scope: scope,
      services: Services(cloud: cloud, analytics: const NoAnalytics()),
      onActionErrorEvent: events.add,
    );
    final first = const CodelesslyActions().run(
      _click([
        _load,
        {'type': 'delay', 'ms': 5000},
        _set('saved', 'yes'),
      ]),
      'click',
      context,
      cancellation: lifecycle,
    );
    await pumpEventQueue();
    cloud.documents.single.add({'title': 'fixture'});
    await pumpEventQueue();
    cloud.documents.single.addError(StateError('sandbox stream unavailable'));
    await first;
    expect(lifecycle.isCanceled, false);
    expect(scope.read('saved'), 'no');
    expect(events, hasLength(1));
    final retry = const CodelesslyActions().run(_click([_load, _set('saved', 'yes')]), 'click', context, cancellation: lifecycle);
    await pumpEventQueue();
    cloud.documents.last.add({'title': 'recovered'});
    await retry;
    expect(scope.read('saved'), 'yes');
    expect(events, hasLength(1));
    context.dispose();
    scope.dispose();
    await cloud.close();
  });
  test('screen disposal cancels a load waiting for its first value without reporting an error', () async {
    final cloud = _Cloud();
    final events = <Json>[];
    final scope = VariableScope([
      const Variable(name: 'dataState', type: VariableType.map, value: <String, Object?>{}),
      const Variable(name: 'saved', value: 'no'),
    ]);
    final context = RuntimeActionContext(
      scope: scope,
      services: Services(cloud: cloud, analytics: const NoAnalytics()),
      onActionErrorEvent: events.add,
    );
    final pending = const CodelesslyActions().trigger(_click([_load, _set('saved', 'yes')]), 'click', context);
    await pumpEventQueue();
    context.dispose();
    await pending;
    expect(events, isEmpty);
    expect(scope.read('saved'), 'no');
    scope.dispose();
    await cloud.close();
  });
  test('upload failure stops nested success actions and emits a JSON-only event', () async {
    final events = <Json>[];
    final files = _Files();
    final scope = VariableScope([const Variable(name: 'saved', value: 'no')]);
    final context = RuntimeActionContext(
      scope: scope,
      ui: _PickUi(),
      services: Services(files: files, analytics: const NoAnalytics()),
      onActionErrorEvent: events.add,
    );
    await const CodelesslyActions().trigger(
      _click([
        {
          'type': 'cloudFiles',
          'path': 'sandbox',
          'actions': [_set('saved', 'yes')],
        },
        _set('saved', 'yes'),
      ]),
      'click',
      context,
    );
    expect(scope.read('saved'), 'no');
    expect(events, hasLength(1));
    expect((events.single['error'] as Map)['action'], 'cloudFiles');
    context.dispose();
    scope.dispose();
  });
}
