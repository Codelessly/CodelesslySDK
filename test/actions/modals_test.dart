import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/pickers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/support.dart';
import '../lists/support.dart' as lists;
import '../support/recording_ui.dart';
import '../support/screen.dart' as harness;

// Triggers in the render tree: nodes tapped (pressed, hovered, swiped...)
// in a NodeView(interactive: true) run their reactions; a variable they set
// re-applies only the boxes that read it.

// openModal anchored to a named node (`anchor: node`): a menu opened from a
// keyboard shortcut or a screen's load sits by a node, in a list by the copy
// built for an item (Tack: a column's menu opened by its link, by that column).


Map<String, Json> page(Json open, {String trigger = 'click'}) => {
      'col': {
        'type': 'column',
        'layout': {'width': 400, 'height': 400},
        'children': ['go', 'list'],
        if (trigger == 'load')
          'actions': [
            {
              'trigger': {'type': 'load'},
              'actions': [open],
            },
          ],
      },
      'go': {
        'type': 'box',
        'layout': {'width': 400, 'height': 40},
        if (trigger == 'click')
          'actions': [
            {
              'trigger': {'type': 'click'},
              'actions': [open],
            },
          ],
      },
      'list': {
        'type': 'listView',
        'props': {'scrollable': false, 'scrollDirection': 'horizontal'},
        'layout': {'width': 400, 'height': 300},
        'bind': {'data': r'${lanes}'},
        'children': ['lane'],
      },
      'lane': {
        'type': 'box',
        'layout': {'width': 100, 'height': 300},
      },
    };

const lanes = Variable(name: 'lanes', type: VariableType.list, value: [
  {'id': 'todo'},
  {'id': 'doing'},
  {'id': 'done'},
]);

Widget scopedApp(Widget screen, GlobalKey<NavigatorState> root, GlobalKey<NavigatorState> nested) {
  final inner = Localizations(
    locale: const Locale('en'),
    delegates: const [DefaultMaterialLocalizations.delegate, DefaultWidgetsLocalizations.delegate],
    child: Navigator(
      key: nested,
      onGenerateRoute: (_) => PageRouteBuilder<void>(pageBuilder: (_, _, _) => screen),
    ),
  );
  return WidgetsApp(
    color: Colors.white,
    navigatorKey: root,
    onGenerateRoute: (_) => PageRouteBuilder<void>(pageBuilder: (_, _, _) => inner),
  );
}

// A chip in a list nested in a list opens a picker (a modal) and, with its
// answer, updates the outer item: the chain resumes after the modal in the
// chip's item scope (item, parent).


class PickerUi extends NoActionUi {
  const PickerUi();
  @override
  Future<Object?> openModal(OpenModalAction action, {Json params = const {}}) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return {'emoji': '🔥', 'for': params['kudos']};
  }
}

// A modal that covers the screen: its one canvas fills the screen, so its
// root (a fill) and its responsive layouts follow the device, not the
// canvas's narrow design size.

Future<NodeView> _open(WidgetTester tester, {required bool cover}) async {
  setScreen(tester, const Size(1194, 834));
  final home = PublishLayout.fromJson({
    'schema': 2,
    'id': 'home',
    'roots': ['h'],
    'nodes': {
      'h': {'type': 'canvas', 'slots': {'body': 'button'}, 'layout': {'width': 1194, 'height': 834}},
      'button': {
        'type': 'box',
        'layout': {'width': 100, 'height': 40},
        'actions': [
          {
            'trigger': {'type': 'click'},
            'actions': [
              {'type': 'openModal', 'to': 'm', 'cover': cover, 'barrierColor': '#00000000'},
            ],
          },
        ],
      },
    },
  });
  final flash = PublishLayout.fromJson({
    'schema': 2,
    'id': 'flash',
    'roots': ['m'],
    'nodes': {
      'm': {'type': 'canvas', 'slots': {'body': 'screen'}, 'layout': {'width': 390, 'height': 844}},
      'screen': {
        'type': 'box',
        'layout': {
          'width': {'fill': 390},
          'height': {'fill': 844},
        },
      },
    },
  });
  final app = Codelessly.fromBundle(
    PublishBundle(
      model: PublishModel(
        projectId: 'p',
        entryLayoutId: 'home',
        layouts: {'home': PublishLayoutInfo.of(home), 'flash': PublishLayoutInfo.of(flash)},
      ),
      layouts: {'home': home, 'flash': flash},
    ),
  );
  addTearDown(app.dispose);
  final controller = CodelesslyWidgetController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, controller: controller)));
  await settle(tester);
  unawaited(controller.trigger('button', 'click'));
  await settle(tester);
  return find.byType(NodeView).evaluate().map((e) => e.widget as NodeView).last;
}

// A screen's load actions can open a modal, decided by a link parameter that
// sets an app variable (`/?learn=1` opens the tutorial sheet).

void main() {
  testWidgets('navigate and modal actions reach the app\'s navigator', (tester) async {
    final ui = RecordingUi();
    final s = await harness.show(tester, harness.counter(actions: [
      harness.reaction('click', [
        {'type': 'navigate', 'mode': 'push', 'to': 'details', 'params': {'n': r'${count}'}},
        {'type': 'openModal', 'to': 'sheet', 'presentation': 'bottomSheet'},
      ]),
    ]), variables: [harness.v('count', 3, VariableType.integer)], ui: ui);
    await tester.tapAt(s.center('button'));
    await tester.pump();
    expect(ui.log, ['navigate push details {n: 3}', 'modal sheet bottomSheet']);
  });

  testWidgets('a popover opens above the node that opened it and gives back its result', (tester) async {
    late BuildContext appContext;
    late NavigatorActionUi ui;
    ui = NavigatorActionUi(
      context: () => appContext,
      modal: (to, params) => SizedBox(key: ValueKey(to), width: 120, height: 40),
    );
    final s = await harness.show(tester, harness.counter(actions: [
      harness.reaction('click', [
        {'type': 'openModal', 'to': 'picker', 'presentation': 'popover', 'anchor': 'trigger', 'placement': 'aboveStart', 'anchorGap': 8},
        {'type': 'setVariable', 'variable': 'count', 'value': r'${result.n}'},
      ]),
    ]), variables: [harness.v('count', 0, VariableType.integer)], ui: ui);
    appContext = tester.element(find.byType(NodeView));
    final box = s.tree.boxOf('button')!;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    await tester.tapAt(rect.center);
    await tester.pumpAndSettle();
    // By the button, left edges aligned, 8 px off: no room above it at
    // the top of the screen, so below.
    expect(tester.getTopLeft(find.byKey(const ValueKey('picker'))), Offset(rect.left, rect.bottom + 8));
    Navigator.of(tester.element(find.byKey(const ValueKey('picker')))).pop({'n': 7});
    await tester.pumpAndSettle();
    expect(s['count'], 7);
  });

  testWidgets('a modal anchored to its trigger or to the pointer opens there', (tester) async {
    late BuildContext appContext;
    final ui = NavigatorActionUi(
      context: () => appContext,
      modal: (to, params) => SizedBox(key: ValueKey(to), width: 120, height: 80),
    );
    final s = await harness.show(tester, harness.counter(actions: [
      harness.reaction('click', [
        {'type': 'openModal', 'to': 'menu', 'anchor': 'trigger', 'placement': 'rightStart', 'anchorGap': 6},
      ]),
      harness.reaction('secondaryClick', [
        {'type': 'openModal', 'to': 'pointerMenu', 'anchor': 'pointer'},
      ]),
    ]), variables: [harness.v('count', 0, VariableType.integer)], ui: ui);
    appContext = tester.element(find.byType(NodeView));
    final box = s.tree.boxOf('button')!;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    await tester.tapAt(rect.center);
    await tester.pumpAndSettle();
    // Right of the button, its top edges aligned.
    expect(tester.getTopLeft(find.byKey(const ValueKey('menu'))), Offset(rect.right + 6, rect.top));
    Navigator.of(appContext).pop();
    await tester.pumpAndSettle();

    // At the pointer: below it, starting at it.
    final at = rect.center + const Offset(10, 5);
    await tester.tapAt(at, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('pointerMenu'))), Offset(at.dx, at.dy + 4));
  });

  testWidgets('a modal shown as a bottom sheet is as wide as the sheet, and a dialog keeps its design width', (tester) async {
    late BuildContext appContext;
    final ui = NavigatorActionUi(
      context: () => appContext,
      modal: (to, params) => SizedBox(key: ValueKey('dialog $to'), width: 120, height: 80),
      sheetModal: (to, params) => SizedBox(key: ValueKey('sheet $to'), width: double.infinity, height: 80),
    );
    final s = await harness.show(tester, harness.counter(actions: [
      harness.reaction('click', [
        {'type': 'openModal', 'to': 'newCard', 'presentation': 'bottomSheet', 'insets': [24, 24, 24, 24]},
      ]),
      harness.reaction('secondaryClick', [
        {'type': 'openModal', 'to': 'newCard'},
      ]),
    ]), variables: [harness.v('count', 0, VariableType.integer)], ui: ui);
    appContext = tester.element(find.byType(NodeView));
    await tester.tapAt(s.center('button'));
    await tester.pumpAndSettle();
    // The sheet's own width (Material 3 caps it at 640; a phone is narrower).
    expect(tester.getSize(find.byKey(const ValueKey('sheet newCard'))).width, 640);
    // A dialog's insets don't push a sheet off the screen's edge.
    expect(tester.getBottomLeft(find.byKey(const ValueKey('sheet newCard'))).dy, 600);
    // No tinted Material surface behind the screen's own.
    expect(tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor, Colors.transparent);
    Navigator.of(appContext).pop();
    await tester.pumpAndSettle();
    await tester.tapAt(s.center('button'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('dialog newCard'))).width, 120);
  });

  testWidgets('a popover flips above when there is no room below and stays on screen', (tester) async {
    final layout = PopoverLayout(anchor: const Rect.fromLTWH(700, 560, 80, 30), placement: api.PopoverPlacement.belowStart);
    // 600 tall: 200 doesn't fit below 594, so above; 800 wide keeps it in.
    expect(layout.getPositionForChild(const Size(800, 600), const Size(232, 200)), const Offset(560, 356));
  });

  group('a popover anchored to a named node', () {
    NavigatorActionUi ui(WidgetTester tester) => NavigatorActionUi(
          context: () => tester.element(find.byType(NodeView)),
          modal: (to, params) => SizedBox(key: ValueKey(to), width: 120, height: 80),
        );
    // Tack's column menu by its link: the lane's right - 200, its top + 40.
    const open = {
      'type': 'openModal',
      'to': 'menu',
      'anchor': 'node',
      'anchorNode': 'lane',
      'anchorItem': r'${laneId}',
      'placement': 'rightStart',
      'anchorGap': -60,
      'anchorOffset': 40,
    };

    testWidgets('sits by the copy of that node for its list item', (tester) async {
      final s = await harness.show(tester, page(open),
          variables: [lanes, const Variable(name: 'laneId', value: 'doing')], ui: ui(tester));
      await tester.tapAt(s.center('go'));
      await tester.pumpAndSettle();
      final lane = s.tree.boxesOf('lane').elementAt(1);
      final rect = lane.localToGlobal(Offset.zero) & lane.size;
      expect(rect.left, 100, reason: 'the second copy is the doing lane');
      expect(tester.getTopLeft(find.byKey(const ValueKey('menu'))), Offset(rect.right - 60, rect.top + 40));
    });

    testWidgets('opens as a dialog when the node is not there', (tester) async {
      await harness.show(tester, page({...open, 'anchorNode': 'missing'}),
          variables: [lanes, const Variable(name: 'laneId', value: 'doing')], ui: ui(tester));
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('menu')), findsOneWidget);
    });
  });

  group('an app hosted inside another app', () {
    testWidgets('a dialog stays in the hosted app\'s navigator and keeps its localizations', (tester) async {
      final root = GlobalKey<NavigatorState>(), nested = GlobalKey<NavigatorState>();
      BuildContext? screen;
      await tester.pumpWidget(scopedApp(Builder(builder: (c) {
        screen = c;
        return const SizedBox.expand();
      }), root, nested));
      final ui = NavigatorActionUi(
        context: () => screen,
        modal: (_, _) => const Material(
          child: SizedBox(width: 300, height: 150, child: TextField(decoration: InputDecoration(labelText: 'Name'))),
        ),
      );
      unawaited(ui.openModal(const OpenModalAction(to: 'form')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
      expect(nested.currentState!.canPop(), isTrue);
      expect(root.currentState!.canPop(), isFalse);
      nested.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('date and time pickers open in the root\'s overlay layer: nothing is pushed on a navigator', (tester) async {
      final root = GlobalKey<NavigatorState>(), nested = GlobalKey<NavigatorState>();
      final doc = LayoutDocument.fromJson({'roots': ['fields'], 'nodes': {
        'fields': {'type': 'column', 'children': ['date', 'time'], 'layout': {'width': 300, 'height': 160}},
        'date': {'type': 'datePicker', 'layout': {'width': 300, 'height': 50}, 'props': {'value': '2026-11-09'}},
        'time': {'type': 'timePicker', 'layout': {'width': 300, 'height': 50}, 'props': {'value': '08:00'}},
      }});
      final tree = NodeTree(DocumentSource(doc));
      addTearDown(tree.dispose);
      final screen = Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'fields', interactive: true));
      await tester.pumpWidget(scopedApp(screen, root, nested));
      await tester.pumpAndSettle();
      for (final id in ['date', 'time']) {
        final box = tree.boxOf(id)!;
        await tester.tapAt(box.localToGlobal(box.size.center(Offset.zero)));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(_picker(tree, id).open, isTrue, reason: id);
        expect(nested.currentState!.canPop(), isFalse);
        expect(root.currentState!.canPop(), isFalse);
        _picker(tree, id).close();
        await tester.pump();
      }
    });
  });

  group('a modal opened from a list item', () {
    testWidgets('a reaction in a nested list item carries on after its modal closes, with the result and the outer item', (tester) async {
      final s = await lists.show(tester, {
        'col': {'type': 'column', 'children': ['cards'], 'layout': {'width': 400, 'height': 600}},
        'cards': {
          'type': 'listView',
          'children': ['card'],
          'layout': {'width': {'fill': 400}, 'height': {'hug': 10}},
          'props': {'scrollable': false},
          'bind': {'data': r'${kudos}'},
        },
        'card': {'type': 'column', 'children': ['chips'], 'layout': {'width': {'fill': 400}, 'height': {'hug': 10}}},
        'chips': {
          'type': 'listView',
          'children': ['chip'],
          'layout': {'width': {'fill': 400}, 'height': {'hug': 10}},
          'props': {'scrollable': false, 'scrollDirection': 'horizontal'},
          'bind': {'data': r"${= append(item.reactions, {emoji: '+', plus: true})}"},
        },
        'chip': {
          'type': 'box',
          'layout': {'width': 40, 'height': 30},
          'bind': {'opacity': r'${= pickerFor == parent.id ? 0.5 : 1}'},
          'actions': [
            lists.reaction('click', [
              {'type': 'if', 'condition': {'left': r'${item.plus}', 'op': 'equalsTo', 'right': 'true'}, 'then': [
                {'type': 'setVariable', 'variable': 'pickerFor', 'value': r'${parent.id}'},
                {'type': 'openModal', 'to': 'picker', 'presentation': 'popover', 'params': {'kudos': r'${parent.id}'}},
                {'type': 'setVariable', 'variable': 'pickerFor', 'value': ''},
                {'type': 'setVariable', 'variable': 'picked', 'value': r'${result.emoji}'},
                {'type': 'setVariable', 'variable': 'kudos',
                 'value': r"${= map(kudos, k => k.id == parent.id ? merge(k, {reactions: append(k.reactions, {emoji: result.emoji, by: ['maya']})}) : k)}"},
              ]},
            ]),
          ],
        },
      }, variables: [
        lists.v('kudos', [
          {'id': 'k1', 'reactions': [{'emoji': '🎉', 'by': ['a']}]},
          {'id': 'k2', 'reactions': []},
        ], VariableType.list),
        lists.v('pickerFor', ''),
        lists.v('picked', ''),
      ], ui: const PickerUi());
      // Each card is a 30 px row of chips: the second card's only chip is its +.
      await tester.tapAt(const Offset(20, 45));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(s['picked'], '🔥');
      expect(s['pickerFor'], '');
      expect(((s['kudos'] as List)[1] as Map)['reactions'], [
        {'emoji': '🔥', 'by': ['maya']},
      ]);
    });
  });

  group('modal sizes', () {
    testWidgets('a covering modal fills the screen', (tester) async {
      final view = await _open(tester, cover: true);
      expect(view.rootId, 'm');
      expect(tester.getSize(find.byType(NodeView).last), const Size(1194, 834));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a dialog keeps its design size', (tester) async {
      await _open(tester, cover: false);
      expect(tester.getSize(find.byType(NodeView).last), const Size(390, 834));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a modal shows the canvas for the screen\'s width', (tester) async {
      setScreen(tester, const Size(1000, 900));
      final home = PublishLayout.fromJson({
        'schema': 2,
        'id': 'home',
        'roots': ['h'],
        'nodes': {
          'h': {
            'type': 'canvas',
            'slots': {'body': 'button'},
            'layout': {'width': 1000, 'height': 900},
          },
          'button': {
            'type': 'box',
            'layout': {'width': 100, 'height': 40},
            'actions': [
              {
                'trigger': {'type': 'click'},
                'actions': [
                  {'type': 'openModal', 'to': 'm', 'barrierBlur': 1},
                ],
              },
            ],
          },
        },
      });
      final dialog = PublishLayout.fromJson({
        'schema': 2,
        'id': 'dialog',
        'roots': ['m', 'd'],
        'nodes': {
          'm': {
            'type': 'canvas',
            'layout': {'width': 360, 'height': 500},
          },
          'd': {
            'type': 'canvas',
            'layout': {'width': 900, 'height': 500},
          },
        },
        'breakpoints': [
          {'canvas': 'm', 'minWidth': 0},
          {'canvas': 'd', 'minWidth': 700},
        ],
      });
      final app = Codelessly.fromBundle(
        PublishBundle(
          model: PublishModel(
            projectId: 'p',
            entryLayoutId: 'home',
            layouts: {'home': PublishLayoutInfo.of(home), 'dialog': PublishLayoutInfo.of(dialog)},
          ),
          layouts: {'home': home, 'dialog': dialog},
        ),
      );
      addTearDown(app.dispose);
      final controller = CodelesslyWidgetController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: CodelesslyWidget(codelessly: app, controller: controller),
        ),
      );
      await settle(tester);
      unawaited(controller.trigger('button', 'click'));
      await settle(tester);
      final views = find.byType(NodeView).evaluate().map((e) => e.widget as NodeView).toList();
      expect(views.last.rootId, 'd');
      expect(tester.getSize(find.byType(NodeView).last).width, 900);
      expect(tester.takeException(), isNull);
    });

    {
      testWidgets('a sheet that asks for a drag handle shows it at its top', (tester) async {
        setScreen(tester, const Size(390, 844));
        final home = PublishLayout.fromJson({
          'schema': 2,
          'id': 'home',
          'roots': ['h'],
          'nodes': {
            'h': {
              'type': 'canvas',
              'slots': {'body': 'label'},
              'layout': {'width': 390, 'height': 844},
              'actions': [
                {
                  'trigger': {'type': 'load'},
                  'actions': [
                    {
                      'type': 'if',
                      'condition': {'left': r'${learn}', 'op': 'isTrue'},
                      'then': [
                        {'type': 'openModal', 'to': 'm', 'presentation': 'adaptive', 'showDragHandle': true},
                      ],
                    },
                  ],
                },
              ],
            },
            'label': {'type': 'text', 'props': {'text': 'Library'}},
          },
        });
        final sheet = PublishLayout.fromJson({
          'schema': 2,
          'id': 'tutorial',
          'roots': ['m'],
          'nodes': {
            'm': {'type': 'canvas', 'slots': {'body': 't'}, 'layout': {'width': 600, 'height': 400}},
            't': {'type': 'text', 'props': {'text': 'Timeline basics'}},
          },
        });
        final app = Codelessly.fromBundle(
          PublishBundle(
            model: PublishModel(
              projectId: 'p',
              entryLayoutId: 'home',
              layouts: {'home': PublishLayoutInfo.of(home), 'tutorial': PublishLayoutInfo.of(sheet)},
              variables: {
                'l': {'id': 'l', 'name': 'learn', 'type': 'boolean', 'value': false},
              },
            ),
            layouts: {'home': home, 'tutorial': sheet},
          ),
        );
        addTearDown(app.dispose);
        await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, params: const {'learn': '1'})));
        await settle(tester);
        final handle = find.byKey(const ValueKey('Codelessly sheet drag handle'));
        expect(handle, findsOneWidget);
        final shown = tester.getRect(find.byType(NodeView).last);
        final grip = tester.getRect(handle);
        expect(shown.contains(grip.center), isTrue, reason: 'on the screen, not above it: $grip in $shown');
        expect(grip.top - shown.top, lessThan(16));
        expect(tester.takeException(), isNull);
      });

      Future<String?> shownAs(WidgetTester tester, Size size) async {
        setScreen(tester, size);
        final home = PublishLayout.fromJson({
          'schema': 2,
          'id': 'home',
          'roots': ['h'],
          'nodes': {
            'h': {
              'type': 'canvas',
              'layout': {'width': size.width, 'height': size.height},
              'actions': [
                {
                  'trigger': {'type': 'load'},
                  'actions': [
                    {'type': 'openModal', 'to': 'm', 'presentation': 'adaptive', 'showDragHandle': true},
                  ],
                },
              ],
            },
          },
        });
        final sheet = PublishLayout.fromJson({
          'schema': 2,
          'id': 'tutorial',
          'roots': ['m'],
          'nodes': {
            'm': {
              'type': 'canvas',
              'layout': {'width': 600, 'height': {'hug': 400}},
              'actions': [
                {
                  'trigger': {'type': 'load'},
                  'actions': [
                    {'type': 'setVariable', 'variable': 'shownAs', 'value': r"${= screen.sheet ? 'sheet' : (screen.modal ? 'dialog' : 'screen')}"},
                  ],
                },
              ],
            },
          },
        });
        final app = Codelessly.fromBundle(
          PublishBundle(
            model: PublishModel(
              projectId: 'p',
              entryLayoutId: 'home',
              layouts: {'home': PublishLayoutInfo.of(home), 'tutorial': PublishLayoutInfo.of(sheet)},
              variables: {
                's': {'id': 's', 'name': 'shownAs', 'type': 'text', 'value': ''},
              },
            ),
            layouts: {'home': home, 'tutorial': sheet},
          ),
        );
        addTearDown(app.dispose);
        await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app)));
        await settle(tester);
        return app.appVariables.read('shownAs') as String?;
      }

      testWidgets('a modal screen can read whether it is shown as a sheet or as a dialog', (tester) async {
        expect(await shownAs(tester, const Size(390, 844)), 'sheet');
        expect(await shownAs(tester, const Size(1000, 900)), 'dialog');
      });
    }
  });
}

/// The picker field drawn for node [id] (render/controls/pickers.dart).
RenderPickerField _picker(RenderTree tree, String id) {
  RenderPickerField? found;
  void visit(RenderObject o) {
    if (o is RenderPickerField) found ??= o;
    o.visitChildren(visit);
  }

  visit(tree.boxOf(id)!);
  return found!;
}
