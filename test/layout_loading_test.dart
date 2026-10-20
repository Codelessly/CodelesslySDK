import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codelessly_sdk/src/ui/layout_builder.dart';
import 'package:provider/provider.dart';

// A survey option: a variance whose "selected" variant is picked by a
// condition on `role`, which its "unselected" child sets on click.
const String canvasId = '0RA4iOShqVSy59V7Bb2w';
const String selectedChild = '0RA4p4dcPLrhyyT2RYhQ';

final Map<String, dynamic> fixture = jsonDecode(
  File('test/fixtures/option_variance.json').readAsStringSync(),
) as Map<String, dynamic>;

SDKPublishLayout layout() => SDKPublishLayout.fromJson(fixture['layout']);

SDKLayoutVariables variables() =>
    SDKLayoutVariables.fromJson(fixture['variables']);

SDKLayoutConditions conditions() =>
    SDKLayoutConditions.fromJson(fixture['conditions']);

SDKPublishModel publishModel() => SDKPublishModel(
  projectId: 'project',
  owner: 'owner',
  teams: const {},
  users: const {},
  roles: const {},
  public: false,
);

class _FakeCache extends Fake implements CacheManager {}

class _FakeAuthManager extends Fake implements AuthManager {
  @override
  AuthData? get authData => AuthData(
    authToken: 'token',
    projectId: 'project',
    timestamp: DateTime(2026),
    owner: 'owner',
    teams: const {},
    users: const {},
    roles: const {},
  );
}

class _FakeLocalRepository extends Fake implements LocalDataRepository {}

class _FakeFirestore extends Fake implements FirebaseFirestore {}

/// Serves the layout right away and its variables and conditions when
/// [release] completes.
class _SlowRepository extends Fake implements NetworkDataRepository {
  final Completer<void> release = Completer<void>();

  @override
  Future<SDKPublishLayout?> downloadLayoutModel({
    required String layoutID,
    required String projectID,
    required PublishSource source,
  }) async => layout();

  @override
  Future<SDKLayoutVariables?> downloadLayoutVariables({
    required String projectID,
    required String layoutID,
    required PublishSource source,
  }) async {
    await release.future;
    return variables();
  }

  @override
  Future<SDKLayoutConditions?> downloadLayoutConditions({
    required String projectID,
    required String layoutID,
    required PublishSource source,
  }) async {
    await release.future;
    return conditions();
  }
}

class _FakeLocalDatabase extends Fake implements LocalDatabase {}

/// A data manager whose local storage is a fake, so layouts can render
/// without Hive.
class _TestDataManager extends DataManager {
  _TestDataManager(
    super.debugLabel, {
    required super.config,
    required super.cacheManager,
    required super.authManager,
    required super.networkDataRepository,
    required super.localDataRepository,
    required super.firebaseFirestore,
    required super.errorLogger,
    super.publishModel,
  });

  @override
  LocalDatabase get localDatabase => _FakeLocalDatabase();
}

DataManager dataManager({
  SDKPublishModel? model,
  NetworkDataRepository? network,
}) => _TestDataManager(
  'test',
  config: CodelesslyConfig(authToken: 'token'),
  cacheManager: _FakeCache(),
  authManager: _FakeAuthManager(),
  networkDataRepository: network ?? _SlowRepository(),
  localDataRepository: _FakeLocalRepository(),
  firebaseFirestore: _FakeFirestore(),
  errorLogger: ErrorLogger.instance,
  publishModel: model,
);

void main() {
  test(
    'a downloaded layout is added with its variables and conditions',
    () async {
      final model = publishModel().copyWith(
        updates: SDKPublishUpdates(
          layouts: {'layout': DateTime(2026)},
          variables: {'layout': DateTime(2026)},
          conditions: {'layout': DateTime(2026)},
        ),
      );
      final network = _SlowRepository();
      final manager = dataManager(model: model, network: network);

      // Emitting the model needs local storage, which these fakes don't have,
      // so the call fails after it has updated the model.
      final Future<bool> fetch = manager
          .getOrFetchPopulatedLayout(layoutID: 'layout')
          .catchError((_) => false);
      await pumpEventQueue();
      // While its variables and conditions download, a widget that rebuilds
      // must not find the layout and render it without them.
      expect(model.layouts.containsKey('layout'), isFalse);

      network.release.complete();
      await fetch;
      expect(model.variables['layout'], isNotNull);
      expect(model.conditions['layout'], isNotNull);
      expect(model.layouts.containsKey('layout'), isTrue);
    },
  );

  testWidgets(
    'variables and conditions that arrive after the layout are loaded',
    (tester) async {
      final model = publishModel();
      model.layouts['layout'] = layout();
      final codelessly = Codelessly(
        config: CodelesslyConfig(authToken: 'token'),
        publishDataManager: dataManager(model: model),
      );
      final controller = CodelesslyWidgetController(
        layoutID: 'layout',
        codelessly: codelessly,
      );
      final codelesslyContext = CodelesslyContext.empty(layoutID: 'layout');

      Widget app() => MultiProvider(
        providers: [
          ChangeNotifierProvider<CodelesslyContext>.value(
            value: codelesslyContext,
          ),
          Provider<Codelessly>.value(value: codelessly),
        ],
        child: MaterialApp(
          home: CodelesslyLayoutBuilder(
            controller: controller,
            layout: model.layouts['layout']!,
            canvasId: canvasId,
          ),
        ),
      );

      // The layout is cached without its variables and conditions.
      await tester.pumpWidget(app());
      expect(codelesslyContext.findVariableByName('role'), isNull);

      // They arrive and the publish model is emitted again.
      model.variables['layout'] = variables();
      model.conditions['layout'] = conditions();
      await tester.pumpWidget(app());
      expect(codelesslyContext.findVariableByName('role'), isNotNull);
      expect(codelesslyContext.conditions, isNotEmpty);

      await tester.tap(find.text('Designer').first, warnIfMissed: false);
      await tester.pump();
      expect(
        codelesslyContext.findVariableByName('role')!.value.value,
        'Designer',
      );
      expect(find.byKey(const ValueKey(selectedChild)), findsWidgets);
    },
  );
}
