// App, page and canvas computed variables (formulas over other variables)
// read by actions: a conditional action's expression, a set variable
// formula and a list item's tap must see a computed variable's value exactly
// as a text binding on the same screen does (blocker #42).
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' hide Expression;
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

PaintModel _paint(ColorRGBA color) =>
    PaintModel.solid(id: 'paint', color: color.toRGB(), opacity: color.a);

CanvasNode _canvas(String id, String bodyId) => CanvasNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, 390, 844),
  children: [bodyId],
  scaleMode: ScaleMode.responsive,
  fills: [_paint(ColorRGBA.white)],
  properties: CanvasProperties(
    bodyId: bodyId,
    safeArea: const SafeAreaModel.all(false),
  ),
)..parentID = kRootNode;

AutoPlaceholderNode _body(String id, String canvasId, List<String> children) =>
    AutoPlaceholderNode(
      id: id,
      name: id,
      basicBoxLocal: NodeBox(0, 0, 390, 844),
      children: children,
      mainAxisAlignment: MainAxisAlignmentC.start,
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.expanded,
    )..parentID = canvasId;

TextNode _text(String id, String parent, String characters) => TextNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, 300, 24),
  data: characters,
  textMixedProps: [
    StartEndProp(
      start: 0,
      end: characters.length,
      fontSize: 16,
      fills: [_paint(ColorRGBA.black)],
    ),
  ],
)..parentID = parent;

ButtonNode _button(
  String id,
  String parent,
  String label,
  List<ActionModel> actions,
) => FilledButtonNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, 160, 44),
  properties: ButtonProperties(
    label: label,
    buttonType: ButtonTypeEnum.filled,
    buttonColor: ColorRGBA.black,
  ),
  reactions: [
    for (final action in actions)
      Reaction(
        action: action,
        trigger: TriggerModel(type: TriggerType.click),
      ),
  ],
)..parentID = parent;

/// `${= formula}` true: what the editor writes for a conditional.
ConditionalAction _when(
  String formula,
  List<ActionModel> actions, [
  List<ActionModel> elseActions = const [],
]) => ConditionalAction(
  expression: Expression(
    leftPart: VariablePart(valueString: formula),
    operator: ConditionOperation.isTrue,
    rightPart: RawValuePart(''),
  ),
  actions: actions,
  elseActions: elseActions,
);

final VariableData lamps = VariableData(
  id: 'lampsVar',
  name: 'lamps',
  type: VariableType.list,
  value: jsonEncode([
    {'id': 'l1', 'room': 'living', 'on': true, 'watts': 10},
    {'id': 'l2', 'room': 'kitchen', 'on': false, 'watts': 8},
    {'id': 'l3', 'room': '', 'on': true, 'watts': 6},
  ]),
);

/// App computed variables, as `variables.set` stores them: a separate
/// formula (with `${= }`) on a typed variable.
final VariableData placed = VariableData(
  id: 'placedVar',
  name: 'placed',
  type: VariableType.list,
  formula: r"${= filter(lamps, l => l.room != '')}",
);
final VariableData lampsOn = VariableData(
  id: 'lampsOnVar',
  name: 'lampsOn',
  type: VariableType.integer,
  formula: r'${= count(placed, l => l.on)}',
);

/// A page computed variable and a canvas one over the app ones.
final VariableData pageWatts = VariableData(
  id: 'pageWattsVar',
  name: 'drawWatts',
  type: VariableType.decimal,
  formula: r'${= sum(map(placed, l => l.on ? l.watts : 0))}',
);
final VariableData canvasLabel = VariableData(
  id: 'canvasLabelVar',
  name: 'label',
  type: VariableType.text,
  formula: r"${= lampsOn + ' of ' + length(placed) + ' on'}",
);

final VariableData scenes = VariableData(
  id: 'scenesVar',
  name: 'scenes',
  type: VariableType.list,
  value: jsonEncode([
    {'id': 's1', 'name': 'Supper', 'lamps': 2},
    {'id': 's2', 'name': 'Reading', 'lamps': 1},
  ]),
);

final VariableData log = VariableData(id: 'logVar', name: 'log', value: '-');

SDKPublishLayout _layout() => SDKPublishLayout.fromJson(
  jsonDecode(
    jsonEncode(
      SDKPublishLayout(
        id: 'homeLayout',
        pageId: 'page',
        projectId: 'project',
        canvases: {
          'home': {
            for (final BaseNode node in [
              _canvas('home', 'homeBody'),
              _body('homeBody', 'home', [
                'label',
                'logText',
                'allOff',
                'dinner',
                'copy',
                'watts',
                'scenesList',
              ]),
              ListViewNode(
                id: 'scenesList',
                name: 'Scenes',
                basicBoxLocal: NodeBox(0, 0, 390, 44),
                scrollDirection: AxisC.horizontal,
                properties: ListViewProperties(),
                children: ['chip'],
                variables: {'data': r'${scenes}'},
              )..parentID = 'homeBody',
              _button('chip', 'scenesList', r'${item.name}', [
                _when(
                  r'${= length(placed) > 0 && item.lamps <= lampsOn + 1}',
                  [
                    SetVariableAction(
                      variable: log,
                      newValue: r"${= item.name + ' on · ' + lampsOn}",
                    ),
                  ],
                ),
              ]),
              _text('label', 'homeBody', r'${label}'),
              _text('logText', 'homeBody', r'log: ${log}'),
              _button('allOff', 'homeBody', 'All off', [
                _when(
                  r'${= lampsOn > 0}',
                  [
                    SetVariableAction(
                      variable: lamps,
                      newValue: r'${= map(lamps, l => merge(l, {on: false}))}',
                    ),
                    SetVariableAction(variable: log, newValue: 'all off'),
                  ],
                  [SetVariableAction(variable: log, newValue: 'nothing on')],
                ),
              ]),
              _button('dinner', 'homeBody', 'Dinner', [
                _when(r'${= length(placed) > 0}', [
                  SetVariableAction(variable: log, newValue: 'dinner'),
                ]),
              ]),
              _button('copy', 'homeBody', 'Copy', [
                SetVariableAction(
                  variable: log,
                  newValue: r'${= lampsOn + "/" + drawWatts + "/" + label}',
                ),
              ]),
              _button('watts', 'homeBody', 'Watts', [
                _when(r'${= drawWatts > 0}', [
                  SetVariableAction(variable: log, newValue: 'watts'),
                ]),
              ]),
            ])
              node.id: node,
          },
        },
        lastUpdated: DateTime(2026),
        owner: 'owner',
        teams: const {},
        users: const {},
        roles: const {},
        public: false,
      ).toJson(),
    ),
  ) as Map<String, dynamic>,
);

/// What the editor publishes: app variables, page variables and the
/// canvas's own, round-tripped through JSON.
SDKLayoutVariables _variables() => SDKLayoutVariables.fromJson(
  jsonDecode(
    jsonEncode(
      SDKLayoutVariables(
        id: 'homeLayout',
        variables: {
          kAppVariablesScope: {
            for (final v in [lamps, placed, lampsOn, log, scenes]) v.id: v,
          },
          kPageVariablesScope: {pageWatts.id: pageWatts},
          'home': {canvasLabel.id: canvasLabel.withCanvas('home')},
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

class _FakeNetworkRepository extends Fake implements NetworkDataRepository {}

class _FakeFirestore extends Fake implements FirebaseFirestore {}

class _FakeLocalDatabase extends Fake implements LocalDatabase {}

class _TestDataManager extends DataManager {
  _TestDataManager(SDKPublishModel model)
    : super(
        'test',
        config: CodelesslyConfig(authToken: 'token'),
        cacheManager: _FakeCache(),
        authManager: _FakeAuthManager(),
        networkDataRepository: _FakeNetworkRepository(),
        localDataRepository: _FakeLocalRepository(),
        firebaseFirestore: _FakeFirestore(),
        errorLogger: ErrorLogger.instance,
        publishModel: model,
      );

  @override
  LocalDatabase get localDatabase => _FakeLocalDatabase();
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final model = SDKPublishModel(
    projectId: 'project',
    owner: 'owner',
    teams: const {},
    users: const {},
    roles: const {},
    public: false,
    pages: const ['page'],
  );
  final layout = _layout();
  model.layouts[layout.id] = layout;
  model.variables[layout.id] = _variables();
  final codelessly = Codelessly(
    config: CodelesslyConfig(authToken: 'token'),
    publishDataManager: _TestDataManager(model)..status = CStatus.loaded(),
  )..status = CStatus.loaded();
  await tester.pumpWidget(
    MaterialApp(
      home: CodelesslyWidget(codelessly: codelessly, layoutID: 'homeLayout'),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('bindings show the app, page and canvas computed variables', (
    tester,
  ) async {
    await _pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('1 of 2 on'), findsOneWidget);
    expect(find.text('log: -'), findsOneWidget);
  });

  testWidgets('a conditional on an app computed variable runs its actions', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Dinner'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('log: dinner'), findsOneWidget);
  });

  testWidgets('a conditional on a computed variable over another computed '
      'one runs, and sees the change its own actions make', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('All off'));
    await tester.pumpAndSettle();
    expect(find.text('log: all off'), findsOneWidget);
    expect(find.text('0 of 2 on'), findsOneWidget);

    // Nothing on now: the else branch.
    await tester.tap(find.text('All off'));
    await tester.pumpAndSettle();
    expect(find.text('log: nothing on'), findsOneWidget);
  });

  testWidgets('a list item\'s conditional reads app computed variables and '
      'its item', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Reading'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('log: Reading on · 1'), findsOneWidget);
  });

  testWidgets('a conditional on a page computed variable runs', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Watts'));
    await tester.pumpAndSettle();
    expect(find.text('log: watts'), findsOneWidget);
  });

  testWidgets('a set variable formula reads app, page and canvas computed '
      'variables', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(find.text('log: 1/10/1 of 2 on'), findsOneWidget);
  });

  testWidgets('CodelesslyContext.getVariableValue reads a computed '
      'variable', (tester) async {
    await _pump(tester);
    final CodelesslyContext context = tester
        .element(find.text('1 of 2 on'))
        .read<CodelesslyContext>();
    expect(context.getVariableValue<int>('lampsOn'), 1);
    expect(context.getVariableValue<List>('placed'), hasLength(2));
  });
}
