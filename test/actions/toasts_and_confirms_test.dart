import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/internals.dart';
import 'package:codelessly_sdk/src/render/control_theme.dart' show rolesOf;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/shell_controls.dart';

// Toasts and the confirm dialog (the action's `look`, bound colors and sizes, the button's actions,
// a designed dialog's answer).


Variable v(String name, Object? value, [VariableType type = VariableType.text]) =>
    Variable(name: name, type: type, value: type.coerce(value));

class Host {
  Host(List<Variable> variables) : scope = VariableScope(variables);

  final VariableScope scope;
  BuildContext? context;
  late final RuntimeActionContext actions = RuntimeActionContext(
    scope: scope,
    ui: NavigatorActionUi(
      context: () => context,
      modal: (id, params) => id == 'askReason'
          ? Builder(
              builder: (c) => Material(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Q: ${params['title']}'),
                  TextButton(
                    onPressed: () => Navigator.of(c).pop({'confirmed': true, 'reason': 'late'}),
                    child: const Text('Yes'),
                  ),
                  TextButton(onPressed: () => Navigator.of(c).pop({'confirmed': false}), child: const Text('No')),
                ]),
              ),
            )
          : null,
    ),
    onError: (e, s, a) => errors.add(e),
  );
  final List<Object> errors = [];

  Future<void> pump(WidgetTester tester, {Size size = const Size(400, 800), ThemeData? theme}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Builder(builder: (c) {
        context = c;
        return const Scaffold(body: SizedBox.expand());
      }),
    ));
  }

  Future<void> run(List<Json> list) => const CodelesslyActions().run(
        Node.fromJson({
          'type': 'box',
          'actions': [
            {'trigger': {'type': 'click'}, 'actions': list},
          ],
        }, id: 'n')!,
        'click',
        actions,
      );

  Object? operator [](String name) => scope.read(name);
}

BoxDecoration decorationOf(WidgetTester tester, Finder f) => tester.widget<Container>(f).decoration! as BoxDecoration;

void main() {
  {
    tearDown(CodelesslyToast.hide);

    group('a toast', () {
      testWidgets('shows its message with variables filled in, is replaced by a newer one, then hides', (tester) async {
        final h = Host([v('drink', 'Cortado')]);
        await h.pump(tester);
        await h.run([
          {'type': 'showToast', 'message': r'Added ${drink} to your order', 'durationMs': 1000},
        ]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Added Cortado to your order'), findsOneWidget);
        // Neutral: the app's text color as the background, a pill.
        final toast = find.byKey(const ValueKey('codelessly-toast'));
        expect(decorationOf(tester, toast).color, isNot(Colors.transparent));
        await h.run([
          {'type': 'showToast', 'message': 'Second', 'durationMs': 500},
        ]);
        await tester.pump();
        expect(find.text('Added Cortado to your order'), findsNothing);
        expect(find.text('Second'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Second'), findsNothing);
      });

      testWidgets('takes its colors, radius, border, shadows, offsets, alignment and rotation', (tester) async {
        final h = Host([]);
        await h.pump(tester);
        await h.run([
          {
            'type': 'showToast',
            'message': 'Ochre sea star added',
            'durationMs': 4000,
            'actionLabel': 'View',
            'showClose': true,
            'look': {
              'backgroundColor': '#FF1F2B2E',
              'textColor': '#FFF3ECDD',
              'actionColor': '#FF9CC5B5',
              'radius': 4,
              'border': {'color': '#FF1F2B2E', 'width': 1.5},
              'shadows': [
                {'type': 'dropShadow', 'color': '#FF1F2B2E', 'offset': [4, 4]},
              ],
              'maxWidth': 480,
              'bottomOffset': 24,
              'bottomOffsets': {'mobile': 84},
              'alignment': 'start',
              'rotation': -2,
              'actionBackgroundColor': '#FFFFFFFF',
              'actionCornerRadius': 6,
              'actionBorder': {'color': '#FF000000', 'width': 2},
              'actionShadows': [
                {'type': 'dropShadow', 'color': '#FF000000', 'offset': [2, 2]},
              ],
            },
          },
        ]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        final toast = find.byKey(const ValueKey('codelessly-toast'));
        final d = decorationOf(tester, toast);
        expect(d.color, const Color(0xFF1F2B2E));
        expect(d.border, const Border.fromBorderSide(BorderSide(color: Color(0xFF1F2B2E), width: 1.5)));
        expect(d.borderRadius, BorderRadius.circular(4));
        final shadow = tester
            .widgetList<DecoratedBox>(find.ancestor(of: toast, matching: find.byType(DecoratedBox)))
            .map((b) => b.decoration)
            .whereType<BoxDecoration>()
            .firstWhere((b) => b.boxShadow != null);
        expect(shadow.boxShadow!.single.offset, const Offset(4, 4));
        expect(tester.widget<Text>(find.text('Ochre sea star added')).style!.color, const Color(0xFFF3ECDD));
        // 84 from the bottom on a phone, against the left margin, tilted.
        final positioned = tester.widget<Positioned>(find.ancestor(of: toast, matching: find.byType(Positioned)).first);
        expect(positioned.bottom, 84);
        expect(positioned.left, 16);
        expect(tester.getRect(toast).left, lessThan(30));
        expect(find.byType(Transform), findsWidgets);
        final button = shellButtonBox(tester, find.byKey(const ValueKey('codelessly-toast-action')));
        expect(button.fillColor, Colors.white);
        expect(button.borderSide, const BorderSide(color: Colors.black, width: 2));
        expect((button.shape as RoundedRectangleBorder).borderRadius, BorderRadius.circular(6));
        expect(find.byKey(const ValueKey('codelessly-toast-close')), findsOneWidget);
      });

      testWidgets('runs its button\'s actions and closes', (tester) async {
        final h = Host([v('restored', '')]);
        await h.pump(tester);
        await h.run([
          {'type': 'setVariable', 'variable': 'restored', 'value': ''},
          {
            'type': 'showToast',
            'message': 'Deleted',
            'actionLabel': r'Undo',
            'durationMs': 5000,
            'actions': [
              {'type': 'setVariable', 'variable': 'restored', 'value': 'yes'},
            ],
          },
        ]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(shellButton('Undo'));
        await tester.pump();
        expect(h['restored'], 'yes');
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Deleted'), findsNothing);
        expect(h.errors, isEmpty);
      });

      testWidgets('without a button lets taps through, and under a dialog is behind its barrier', (tester) async {
        final h = Host([]);
        await h.pump(tester);
        await h.run([
          {'type': 'showToast', 'message': 'Passive', 'durationMs': 5000},
        ]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        final ignore = tester.widget<IgnorePointer>(
            find.ancestor(of: find.text('Passive'), matching: find.byType(IgnorePointer)).first);
        expect(ignore.ignoring, isTrue);
        unawaited(h.run([
          {'type': 'confirm', 'title': 'Sure?'},
        ]));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(CodelesslyToast.covers.value, hasLength(1));
        await tester.tap(find.byKey(const ValueKey('codelessly-confirm-cancel')));
        await tester.pumpAndSettle();
        expect(CodelesslyToast.covers.value, isEmpty);
      });
    });

    group('a confirm', () {


      testWidgets('runs its actions on confirm and its cancel actions on cancel', (tester) async {
        final h = Host([v('who', 'Ada'), v('out', '')]);
        await h.pump(tester);
        final ask = [
          {
            'type': 'confirm',
            'title': r'Remove ${who}?',
            'caption': 'TEAM',
            'message': 'They lose access.',
            'confirmLabel': 'Remove',
            'destructive': true,
            'actions': [
              {'type': 'setVariable', 'variable': 'out', 'value': 'removed'},
            ],
            'cancelActions': [
              {'type': 'setVariable', 'variable': 'out', 'value': 'kept'},
            ],
          },
        ];
        unawaited(h.run(ask));
        await tester.pumpAndSettle();
        expect(find.text('Remove Ada?'), findsOneWidget);
        expect(find.text('TEAM'), findsOneWidget);
        expect(find.text('They lose access.'), findsOneWidget);
        // Destructive: the confirm button takes the error color.
        final ok = shellButtonBox(tester, find.byKey(const ValueKey('codelessly-confirm-ok')));
        expect(ok.fillColor, rolesOf(h.context!).error);
        await tester.tap(shellButton('Remove'));
        await tester.pumpAndSettle();
        expect(h['out'], 'removed');
        unawaited(h.run(ask));
        await tester.pumpAndSettle();
        await tester.tap(shellButton('Cancel'));
        await tester.pumpAndSettle();
        expect(h['out'], 'kept');
      });

      testWidgets('takes its look: icon, alignment, button layout, sizes, bound colors and width', (tester) async {
        final h = Host([v('w', 300, VariableType.integer)]);
        await h.pump(tester);
        unawaited(h.run([
          {
            'type': 'confirm',
            'title': 'Reset?',
            'look': {
              'backgroundColor': '#FF101418',
              'confirmColor': '#FFE0B000',
              'radius': 20,
              'buttonRadius': 2,
              'buttonHeight': 52,
              'centered': true,
              'expandButtons': true,
              'icon': {'source': 'icon', 'type': 'MATERIAL_ICON', 'name': 'restart_alt'},
              'iconDiscColor': '#FF333333',
              'iconDiscSize': 60,
              'padding': [10, 12, 10, 12],
              'shadows': [
                {'type': 'dropShadow', 'color': '#FF000000', 'offset': [0, 8], 'blurRadius': 20},
              ],
            },
            'variables': {'width': r'${w}', 'cancelColor': '#FF444444'},
          },
        ]));
        await tester.pumpAndSettle();
        final disc = find.byKey(const ValueKey('codelessly-confirm-icon-disc'));
        expect(tester.getSize(disc), const Size(60, 60));
        final surface = tester.widget<DecoratedBox>(find.byKey(const ValueKey('codelessly-confirm-surface')));
        final deco = surface.decoration as BoxDecoration;
        expect(deco.color, const Color(0xFF101418));
        expect(deco.borderRadius, BorderRadius.circular(20));
        expect(tester.getSize(find.byKey(const ValueKey('codelessly-confirm-surface'))).width, 300);
        final ok = find.byKey(const ValueKey('codelessly-confirm-ok'));
        final cancel = find.byKey(const ValueKey('codelessly-confirm-cancel'));
        expect(tester.getSize(ok).height, 52);
        // Expanded: the two buttons share the row.
        expect(tester.getSize(ok).width, closeTo(tester.getSize(cancel).width, 0.5));
        expect(shellButtonBox(tester, ok).fillColor, const Color(0xFFE0B000));
        expect(shellButtonBox(tester, cancel).fillColor, const Color(0xFF444444));
        // Centered: the title centers.
        expect(tester.widget<Text>(find.text('Reset?')).textAlign, TextAlign.center);
        await tester.tap(cancel);
        await tester.pumpAndSettle();
      });

      testWidgets('on a phone its buttons share the width; with room they sit at the end, each at most 240 wide', (tester) async {
        for (final (size, label, shared) in [
          (const Size(390, 844), 'Archive', true),
          (const Size(1440, 900), 'Archive', false),
          (const Size(1440, 900), 'Archive these three conversations and every reply to them now', false),
        ]) {
          final h = Host([v('out', '')]);
          await h.pump(tester, size: size);
          unawaited(h.run([
            {'type': 'confirm', 'title': 'Archive the whole thread?', 'confirmLabel': label},
          ]));
          await tester.pumpAndSettle();
          final ok = tester.getRect(find.byKey(const ValueKey('codelessly-confirm-ok')));
          final cancel = tester.getRect(find.byKey(const ValueKey('codelessly-confirm-cancel')));
          final title = tester.getRect(find.text('Archive the whole thread?'));
          if (shared) {
            expect(ok.width, closeTo(cancel.width, 0.5), reason: '$size');
            expect(cancel.left, closeTo(title.left, 0.5), reason: 'from edge to edge');
          } else if (label.length < 20) {
            // Side by side at the end, as wide as their words.
            expect(ok.top, closeTo(cancel.top, 0.5));
            expect(cancel.right, lessThanOrEqualTo(ok.left));
            expect(ok.right, greaterThanOrEqualTo(title.right - 0.5));
            expect(cancel.left, greaterThan(title.left + 40));
            expect(ok.width, lessThan(240));
          } else {
            // A long word wraps in a button no wider than 240.
            expect(ok.width, 240);
          }
          await tester.tap(find.byKey(const ValueKey('codelessly-confirm-cancel')));
          await tester.pumpAndSettle();
        }
      });

      testWidgets('the focus starts on the yes (on Cancel when it is destructive); Enter presses it, Tab moves, Escape cancels', (tester) async {
        final h = Host([v('out', '')]);
        await h.pump(tester, size: const Size(1440, 900));
        List<Json> ask({bool danger = false}) => [
              {
                'type': 'confirm',
                'title': 'Save?',
                if (danger) 'destructive': true,
                'actions': [
                  {'type': 'setVariable', 'variable': 'out', 'value': 'yes'},
                ],
                'cancelActions': [
                  {'type': 'setVariable', 'variable': 'out', 'value': 'no'},
                ],
              },
            ];
        bool focused(String key) => shellButtonBox(tester, find.byKey(ValueKey(key))).focusNode.hasFocus;

        Future<void> press(LogicalKeyboardKey key) async {
          await tester.sendKeyEvent(key);
          await tester.pumpAndSettle();
        }

        unawaited(h.run(ask()));
        await tester.pumpAndSettle();
        expect(focused('codelessly-confirm-ok'), isTrue);
        await press(LogicalKeyboardKey.enter);
        expect(h['out'], 'yes');
        expect(find.text('Save?'), findsNothing);

        unawaited(h.run(ask(danger: true)));
        await tester.pumpAndSettle();
        expect(focused('codelessly-confirm-cancel'), isTrue);
        await press(LogicalKeyboardKey.enter);
        expect(h['out'], 'no');

        unawaited(h.run(ask(danger: true)));
        await tester.pumpAndSettle();
        await press(LogicalKeyboardKey.tab);
        expect(focused('codelessly-confirm-ok'), isTrue);
        await press(LogicalKeyboardKey.enter);
        expect(h['out'], 'yes');

        unawaited(h.run(ask()));
        await tester.pumpAndSettle();
        await press(LogicalKeyboardKey.escape);
        expect(h['out'], 'no');
        expect(find.text('Save?'), findsNothing);
      });

      testWidgets('can show as a bottom sheet', (tester) async {
        final h = Host([v('out', '')]);
        await h.pump(tester);
        unawaited(h.run([
          {
            'type': 'confirm',
            'title': 'Sheet?',
            'presentation': 'bottomSheet',
            'look': {'showDragHandle': true},
            'actions': [
              {'type': 'setVariable', 'variable': 'out', 'value': 'ok'},
            ],
          },
        ]));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('Codelessly bottom sheet')), findsOneWidget);
        expect(find.byKey(const ValueKey('Codelessly sheet drag handle')), findsOneWidget);
        expect(tester.getRect(find.byKey(const ValueKey('Codelessly bottom sheet'))).bottom, 800);
        await tester.tap(shellButton('OK'));
        await tester.pumpAndSettle();
        expect(h['out'], 'ok');
      });

      testWidgets('shown as a designed screen answers with confirmed, and its other values are the result', (tester) async {
        final h = Host([v('why', ''), v('out', '')]);
        await h.pump(tester);
        final ask = [
          {
            'type': 'confirm',
            'title': 'Late?',
            'dialog': 'askReason',
            'actions': [
              {'type': 'setVariable', 'variable': 'why', 'value': r'${result.reason}'},
            ],
            'cancelActions': [
              {'type': 'setVariable', 'variable': 'out', 'value': 'no'},
            ],
          },
        ];
        unawaited(h.run(ask));
        await tester.pumpAndSettle();
        // The dialog receives the action's own text.
        expect(find.text('Q: Late?'), findsOneWidget);
        await tester.tap(find.text('Yes'));
        await tester.pumpAndSettle();
        expect(h['why'], 'late');
        unawaited(h.run(ask));
        await tester.pumpAndSettle();
        await tester.tap(find.text('No'));
        await tester.pumpAndSettle();
        expect(h['out'], 'no');
        expect(isConfirmResult({'confirmed': 'yes'}), isTrue);
        expect(isConfirmResult(1), isTrue);
        expect(isConfirmResult({'confirmed': 0}), isFalse);
      });
    });
  }
}
