// Toasts and the confirm dialog (the action's `look`, bound colors and sizes, the button's actions,
// a designed dialog's answer).
import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  tearDown(CodelesslyToast.hide);

  group('toast', () {
    testWidgets('shows the message with variables, a new one replaces it, then it hides', (tester) async {
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

    testWidgets('the look: colors, radius, border, shadows, offsets, alignment and rotation', (tester) async {
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
      final button = tester.widget<TextButton>(find.byKey(const ValueKey('codelessly-toast-action')));
      expect(button.style!.backgroundColor!.resolve({}), Colors.white);
      expect(button.style!.side!.resolve({}), const BorderSide(color: Colors.black, width: 2));
      expect(
        (button.style!.shape!.resolve({}) as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(6),
      );
      expect(find.byKey(const ValueKey('codelessly-toast-close')), findsOneWidget);
    });

    testWidgets('stretch fills the margins; desktop takes its own offset', (tester) async {
      final h = Host([]);
      await h.pump(tester, size: const Size(1200, 800));
      await h.run([
        {
          'type': 'showToast',
          'message': 'Wide',
          'look': {
            'alignment': 'center',
            'alignments': {'desktop': 'stretch'},
            'sideMargin': 40,
            'maxWidth': 2000,
            'bottomOffset': 30,
          },
        },
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      final rect = tester.getRect(find.byKey(const ValueKey('codelessly-toast')));
      expect(rect.left, closeTo(40, 1));
      expect(rect.right, closeTo(1160, 1));
      expect(800 - rect.bottom, closeTo(30, 1));
    });

    testWidgets('a title card with an icon in a disc; bound colors, icon and duration', (tester) async {
      final h = Host([
        v('tint', '#FF2E7D32'),
        v('ms', 0, VariableType.integer),
      ]);
      await h.pump(tester);
      await h.run([
        {
          'type': 'showToast',
          'title': 'Saved',
          'message': 'Your note is safe',
          'look': {'iconDiscColor': '#FFFFFFFF', 'iconDiscSize': 40, 'accentColor': '#FFFF0000'},
          'variables': {'backgroundColor': r'${tint}', 'icon': 'check_circle', 'duration': r'${ms}'},
        },
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('codelessly-toast-title')), findsOneWidget);
      expect(find.byKey(const ValueKey('codelessly-toast-message')), findsOneWidget);
      expect(decorationOf(tester, find.byKey(const ValueKey('codelessly-toast'))).color, const Color(0xFF2E7D32));
      final disc = find.byKey(const ValueKey('codelessly-toast-icon-disc'));
      expect(tester.getSize(disc), const Size(40, 40));
      // The accent bar on the left.
      final border = decorationOf(tester, find.byKey(const ValueKey('codelessly-toast'))).border! as Border;
      expect(border.left.color, const Color(0xFFFF0000));
      expect(border.left.width, 4);
      // A duration of 0 stays.
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('the button runs its actions with the chain\'s result, and closes the toast', (tester) async {
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
      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(h['restored'], 'yes');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Deleted'), findsNothing);
      expect(h.errors, isEmpty);
    });

    testWidgets('a toast without a button lets taps through; under a dialog it takes the barrier', (tester) async {
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

  group('confirm', () {
    testWidgets('dialog look supports leading actions and explicit text gaps', (
      tester,
    ) async {
      final host = Host([]);
      await host.pump(tester, theme: ThemeData(visualDensity: VisualDensity.compact));
      final pending = host.run([
        {
          'type': 'confirm',
          'caption': 'EXPERIMENT',
          'title': 'Clear?',
          'message': 'Keep a copy first.',
          'look': {
            'width': 294,
            'padding': 26,
            'captionGap': 10,
            'messageGap': 12,
            'buttonsAlignment': 'start',
            'buttonMinWidth': 0,
            'buttonPadding': [15, 0, 15, 0],
            'buttonHeight': 43,
          },
        },
      ]);
      await tester.pumpAndSettle();
      final title = tester.getRect(find.text('Clear?')),
          caption = tester.getRect(find.text('EXPERIMENT')),
          message = tester.getRect(find.text('Keep a copy first.'));
      final cancel = tester.getRect(
        find.byKey(const ValueKey('codelessly-confirm-cancel')),
      );
      expect(title.top - caption.bottom, closeTo(10, .01));
      expect(message.top - title.bottom, closeTo(12, .01));
      expect(cancel.left, closeTo(title.left, .01));
      expect(cancel.height, 43);
      await tester.tap(find.byKey(const ValueKey('codelessly-confirm-cancel')));
      await tester.pumpAndSettle();
      await pending;
    });


    // Petri v2: the buttons share a text style (font, size, weight, a light
    // color), and the brass confirm takes dark text. Before, the shared
    // style's color won and the confirm's label was light on brass.
    testWidgets('a button\'s own text color wins over the shared button style\'s', (tester) async {
      final host = Host([]);
      await host.pump(tester);
      final pending = host.run([
        {
          'type': 'confirm',
          'title': 'Switch?',
          'confirmLabel': 'Switch',
          'look': {
            'buttonStyle': {'fontSize': 13.5, 'fontWeight': 600, 'color': '#FFF3E6BF'},
            'confirmColor': '#FFE2BE6A',
            'confirmTextColor': '#FF2A2109',
          },
        },
      ]);
      await tester.pumpAndSettle();
      Color colorOf(String text) => tester.widget<RichText>(find.descendant(of: find.text(text), matching: find.byType(RichText))).text.style!.color!;
      expect(colorOf('Switch'), const Color(0xFF2A2109));
      expect(colorOf('Cancel'), const Color(0xFFF3E6BF), reason: 'no cancelTextColor: the shared style\'s');
      await tester.tap(find.byKey(const ValueKey('codelessly-confirm-cancel')));
      await tester.pumpAndSettle();
      await pending;
    });

    testWidgets('the built-in dialog: confirm runs actions, cancel runs cancelActions', (tester) async {
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
      final ok = tester.widget<FilledButton>(find.byKey(const ValueKey('codelessly-confirm-ok')));
      expect(ok.style!.backgroundColor!.resolve({}), Theme.of(h.context!).colorScheme.error);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(h['out'], 'removed');
      unawaited(h.run(ask));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(h['out'], 'kept');
    });

    testWidgets('its look: icon disc, centered, expanded buttons, sizes, bound colors and width', (tester) async {
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
      expect(tester.widget<FilledButton>(ok).style!.backgroundColor!.resolve({}), const Color(0xFFE0B000));
      expect(tester.widget<TextButton>(cancel).style!.backgroundColor!.resolve({}), const Color(0xFF444444));
      // Centered: the title centers.
      expect(tester.widget<Text>(find.text('Reset?')).textAlign, TextAlign.center);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
    });

    testWidgets('as a bottom sheet', (tester) async {
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
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(h['out'], 'ok');
    });

    testWidgets('a designed dialog answers with `confirmed`; its other values are the result', (tester) async {
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

  test('neutral buttons do not hide a light-canvas accent; dark canvases may use white', () {
    for (final dark in [false, true]) {
      final doc = LayoutDocument.fromJson({
        'roots': ['c'],
        'nodes': {
          'c': {'type': 'canvas', 'children': ['b0', 'b1', 'b2', 'b3'],
            if (dark) 'decoration': {'fills': [{'color': '#101010'}]}},
          for (var i = 0; i < 4; i++) 'b$i': {
            'type': 'box', 'decoration': {'fills': [{'color': i < 3 ? '#FFFFFF' : '#147D68'}]},
            'actions': [{'trigger': {'type': 'click'}, 'actions': []}],
          },
        },
      });
      expect(FeedbackTheme.fromDocument(doc).primary, dark ? Colors.white : const Color(0xFF147D68));
    }
  });

  test('a layout\'s look, read from its nodes and tokens', () {
    final doc = LayoutDocument.fromJson({
      'roots': ['c'],
      'nodes': {
        'c': {
          'type': 'canvas',
          'children': ['t', 'h', 'b', 's'],
          'decoration': {
            'fills': [
              {'color': '#FFFAF6EE'},
            ],
          },
        },
        't': {
          'type': 'text',
          'props': {
            'text': 'A long body of text in Lora',
            'style': {'fontFamily': 'Lora', 'color': '#FF222222'},
          },
        },
        'h': {
          'type': 'text',
          'props': {
            'text': 'Title',
            'style': {'fontFamily': 'Lora', 'fontWeight': 700, 'fontSize': 28},
          },
        },
        'b': {
          'type': 'filledButton',
          'props': {
            'label': 'Go',
            'style': {'backgroundColor': '#FF8A2BE2', 'shape': {'borderRadius': 6}},
          },
        },
        's': {
          'type': 'box',
          'decoration': {
            'fills': [
              {'color': '#FF8A2BE2'},
            ],
            'radius': 6,
          },
          'actions': [
            {'trigger': {'type': 'click'}, 'actions': []},
          ],
        },
      },
    });
    final t = FeedbackTheme.fromDocument(doc);
    expect(t.bodyStyle!.fontFamily, 'Lora');
    expect(t.titleStyle!.fontWeight, FontWeight.w700);
    expect(t.surface, const Color(0xFFFAF6EE));
    expect(t.onSurface, const Color(0xFF222222));
    expect(t.primary, const Color(0xFF8A2BE2));
    expect(t.buttonRadius, 6);
    final themed = FeedbackTheme.fromTokens(const ThemeTokens(fontFamily: 'Inter')).merge(t);
    expect(themed.bodyStyle!.fontFamily, 'Inter');
    expect(ResolvedFeedbackTheme.resolve(themed, ThemeData()).radius, 14);
  });
}
