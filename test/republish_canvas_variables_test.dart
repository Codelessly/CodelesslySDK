// The Lamplight Schedule form fills draft canvas variables from the selected
// schedule in its canvas load actions. Opened right after a republish, the
// site showed the screen from its cached publish model, ran the load
// actions, then the fresh publish bundle arrived: the layout reloaded, its
// canvas variables went back to their published defaults (an empty name,
// 7:00 AM) and the load actions, which run once per screen, didn't fill
// them again.
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PaintModel paint(ColorRGBA color) =>
    PaintModel.solid(id: 'paint', color: color.toRGB(), opacity: color.a);

final VariableData schedule = VariableData(
  id: 'scheduleVar',
  name: 'scheduleName',
  value: 'Dinner time',
);

final VariableData draft = VariableData(
  id: 'draftVar',
  name: 'draftName',
  value: '',
);

TextNode text(String id, String parent, String characters) => TextNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, 300, 24),
  data: characters,
  textMixedProps: [
    StartEndProp(
      start: 0,
      end: characters.length,
      fontSize: 16,
      fills: [paint(ColorRGBA.black)],
    ),
  ],
)..parentID = parent;

ButtonNode button(String id, String parent, String label, ActionModel action) =>
    FilledButtonNode(
      id: id,
      name: id,
      basicBoxLocal: NodeBox(0, 0, 160, 44),
      properties: ButtonProperties(
        label: label,
        buttonType: ButtonTypeEnum.filled,
        buttonColor: ColorRGBA.black,
      ),
      reactions: [
        Reaction(
          action: action,
          trigger: TriggerModel(type: TriggerType.click),
        ),
      ],
    )..parentID = parent;

SDKPublishLayout formLayout(DateTime lastUpdated, {String label = 'Draft'}) =>
    SDKPublishLayout.fromJson(
      jsonDecode(
        jsonEncode(
          SDKPublishLayout(
            id: 'formLayout',
            pageId: 'page',
            projectId: 'project',
            canvases: {
              'form': {
                for (final BaseNode node in [
                  CanvasNode(
                    id: 'form',
                    name: 'form',
                    basicBoxLocal: NodeBox(0, 0, 390, 844),
                    children: ['body'],
                    scaleMode: ScaleMode.responsive,
                    fills: [paint(ColorRGBA.white)],
                    properties: CanvasProperties(
                      bodyId: 'body',
                      safeArea: const SafeAreaModel.all(false),
                    ),
                    reactions: [
                      Reaction(
                        name: 'Init',
                        trigger: TriggerModel(type: TriggerType.load),
                        action: SetVariableAction(
                          variable: draft,
                          newValue: r'${scheduleName}',
                        ),
                      ),
                    ],
                  )..parentID = kRootNode,
                  AutoPlaceholderNode(
                    id: 'body',
                    name: 'body',
                    basicBoxLocal: NodeBox(0, 0, 390, 844),
                    children: ['draftText', 'edit'],
                    mainAxisAlignment: MainAxisAlignmentC.start,
                    horizontalFit: SizeFit.expanded,
                    verticalFit: SizeFit.expanded,
                  )..parentID = 'form',
                  text('draftText', 'body', '$label: \${draftName}'),
                  button(
                    'edit',
                    'body',
                    'Edit',
                    SetVariableAction(variable: draft, newValue: 'Edited'),
                  ),
                ])
                  node.id: node,
              },
            },
            lastUpdated: lastUpdated,
            owner: 'owner',
            teams: const {},
            users: const {},
            roles: const {},
            public: false,
          ).toJson(),
        ),
      ) as Map<String, dynamic>,
    );

SDKLayoutVariables formVariables({List<VariableData>? canvasVariables}) =>
    SDKLayoutVariables.fromJson(
      jsonDecode(
        jsonEncode(
          SDKLayoutVariables(
            id: 'formLayout',
            variables: {
              kAppVariablesScope: {schedule.id: schedule},
              'form': {
                for (final v in canvasVariables ?? [draft]) v.id: v,
              },
            },
            owner: 'owner',
            teams: const {},
            users: const {},
            roles: const {},
            public: false,
          ).toJson(),
        ),
      ) as Map<String, dynamic>,
    );

SDKPublishModel modelOf(SDKPublishLayout layout, SDKLayoutVariables? vars) {
  final model = SDKPublishModel(
    // The server lists the layout's variables, downloaded or not.
    updates: SDKPublishUpdates(variables: {layout.id: DateTime(2026)}),
    projectId: 'project',
    owner: 'owner',
    teams: const {},
    users: const {},
    roles: const {},
    public: false,
    pages: const ['page'],
  );
  model.layouts[layout.id] = layout;
  if (vars != null) model.variables[layout.id] = vars;
  return model;
}

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

class _FakeLocalRepository extends Fake implements LocalDataRepository {
  @override
  Future<void> savePublishModel({
    required SDKPublishModel model,
    required PublishSource source,
  }) async {}
}

class FakeNetworkRepository extends Fake implements NetworkDataRepository {
  /// What the publish bundle download answers, when it does.
  final Completer<SDKPublishModel?> bundle = Completer<SDKPublishModel?>();

  @override
  Future<SDKPublishModel?> downloadCompletePublishBundle({
    required String slug,
    required PublishSource source,
  }) => bundle.future;
}

class _FakeFirestore extends Fake implements FirebaseFirestore {}

class _FakeLocalDatabase extends Fake implements LocalDatabase {}

class TestDataManager extends DataManager {
  TestDataManager(SDKPublishModel model, [FakeNetworkRepository? network])
    : super(
        'test',
        config: CodelesslyConfig(authToken: 'token'),
        cacheManager: _FakeCache(),
        authManager: _FakeAuthManager(),
        networkDataRepository: network ?? FakeNetworkRepository(),
        localDataRepository: _FakeLocalRepository(),
        firebaseFirestore: _FakeFirestore(),
        errorLogger: ErrorLogger.instance,
        publishModel: model,
      );

  @override
  LocalDatabase get localDatabase => _FakeLocalDatabase();

  @override
  Future<bool> onPublishModelLoaded(String projectId) async => false;
}

Future<TestDataManager> pumpForm(
  WidgetTester tester,
  SDKPublishModel model, {
  TestDataManager? manager,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  manager ??= TestDataManager(model);
  manager.status = CStatus.loaded();
  final codelessly = Codelessly(
    config: CodelesslyConfig(authToken: 'token'),
    publishDataManager: manager,
  )..status = CStatus.loaded();
  await tester.pumpWidget(
    MaterialApp(
      home: CodelesslyWidget(codelessly: codelessly, layoutID: 'formLayout'),
    ),
  );
  await tester.pumpAndSettle();
  return manager;
}

void main() {
  testWidgets('a republished layout keeps the canvas variables its load '
      'actions filled', (tester) async {
    final manager = await pumpForm(
      tester,
      modelOf(formLayout(DateTime(2026)), formVariables()),
    );
    expect(find.text('Draft: Dinner time'), findsOneWidget);

    // The fresh bundle: the same screen published again (new instances,
    // a later lastUpdated), with a change to the design.
    await manager.setPublishModel(
      modelOf(formLayout(DateTime(2027), label: 'Name'), formVariables()),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Name: Dinner time'), findsOneWidget);
  });

  testWidgets('a value the user changed survives a republish', (tester) async {
    final manager = await pumpForm(
      tester,
      modelOf(formLayout(DateTime(2026)), formVariables()),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Draft: Edited'), findsOneWidget);
    await manager.setPublishModel(
      modelOf(formLayout(DateTime(2027)), formVariables()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Draft: Edited'), findsOneWidget);
  });

  testWidgets('a canvas variable published with a new type or default '
      'takes the published value', (tester) async {
    final manager = await pumpForm(
      tester,
      modelOf(formLayout(DateTime(2026)), formVariables()),
    );
    expect(find.text('Draft: Dinner time'), findsOneWidget);
    await manager.setPublishModel(
      modelOf(
        formLayout(DateTime(2027)),
        formVariables(
          canvasVariables: [draft.copyWith(value: 'fresh default')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Draft: fresh default'), findsOneWidget);
  });

  testWidgets('load actions wait for variables that arrive after the '
      'layout', (tester) async {
    // A cached model with the layout but not its variables, while the
    // publish bundle (or a diff) downloads them.
    final SDKPublishModel cached = modelOf(formLayout(DateTime(2026)), null);
    final network = FakeNetworkRepository();
    final TestDataManager manager = TestDataManager(cached, network);
    final Future<bool> fetch = manager.fetchCompletePublishBundle(
      slug: 'app',
      source: PublishSource.publish,
    );
    expect(manager.variablesPending('formLayout'), isNotNull);
    await pumpForm(tester, cached, manager: manager);
    expect(find.text('Draft: '), findsOneWidget);

    network.bundle.complete(
      modelOf(formLayout(DateTime(2026)), formVariables()),
    );
    expect(await fetch, isTrue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Draft: Dinner time'), findsOneWidget);
  });

  testWidgets('without a download under way, load actions run at once', (
    tester,
  ) async {
    final SDKPublishModel cached = modelOf(formLayout(DateTime(2026)), null);
    final TestDataManager manager = TestDataManager(cached);
    expect(manager.variablesPending('formLayout'), isNull);
  });
}
