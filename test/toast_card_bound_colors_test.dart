import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const Color _navy = Color(0xFF0E1A2C);
const Color _ivory = Color(0xFFF7F1E3);
const Color _gold = Color(0xFFE5B04A);
const Color _surface = Color(0xFFFBF7EE);
const Color _ink = Color(0xFF1F2B2E);
const Color _danger = Color(0xFFB3392B);

/// An app whose `pal` variable holds a palette, as a Meridian-style theme
/// would, with [onContext] handed the context of its home.
Future<void> _pumpApp(
  WidgetTester tester,
  void Function(BuildContext context) onContext, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final CodelesslyContext ctx = CodelesslyContext.empty()
    ..variables['pal'] = Observable(
      VariableData(
        id: 'pal',
        name: 'pal',
        type: VariableType.map,
        value: <String, dynamic>{
          'toast': '#0E1A2C',
          'ivory': '#F7F1E3',
          'gold': '#E5B04A',
          'surface': '#FBF7EE',
          'ink': '#1F2B2E',
          'danger': '#B3392B',
        },
      ),
    );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: ctx,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => onContext(context),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

ShowToastAction _card() => ActionModel.fromJson({
  'type': 'showToast',
  'title': 'Gate change',
  'body': 'MR 88 now boards at A11',
  'position': 'top',
  'duration': 6000,
  'icon': MultiSourceIconModel(
    show: true,
    size: 18,
    icon: CupertinoIcon(
      codepoint: CupertinoIcons.airplane.codePoint,
      name: 'airplane',
    ),
  ).toJson(),
  'iconDiscSize': 36,
  'titleStyle': {'fontSize': 13.5, 'fontWeight': 'w800'},
  'fontSize': 12,
  'alignment': 'end',
  'alignments': {'mobile': 'stretch'},
  'sideMargin': 24,
  'sideMargins': {'mobile': 14},
  'maxWidth': 380,
  'minWidth': 380,
  'actionLabel': 'View',
  'showClose': true,
  'variables': {
    'backgroundColor': r'${pal.toast}',
    'textColor': r'${pal.ivory}',
    'iconColor': r'${pal.gold}',
    'iconDiscColor': r'${= alpha(pal.gold, 0.18)}',
    'borderColor': r'${= alpha(pal.gold, 0.5)}',
    'actionColor': r'${pal.gold}',
    // A binding that gives no color keeps the field.
    'closeColor': r'${pal.missing}',
  },
}) as ShowToastAction;

BoxDecoration _decorationOf(WidgetTester tester, Key key) =>
    tester.widget<Container>(find.byKey(key)).decoration! as BoxDecoration;

TextStyle _styleOf(WidgetTester tester, String text) => tester
    .widget<RichText>(
      find.descendant(of: find.text(text), matching: find.byType(RichText)),
    )
    .text
    .style!;

void main() {
  testWidgets('a card toast shows a title, a body, a disc and bound colors', (
    tester,
  ) async {
    await _pumpApp(tester, (context) => AppToast.show(context, _card()));
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Gate change'), findsOneWidget);
    expect(find.text('MR 88 now boards at A11'), findsOneWidget);

    final BoxDecoration card = _decorationOf(
      tester,
      const ValueKey('codelessly-toast'),
    );
    expect(card.color, _navy);
    final Border border = card.border! as Border;
    expect(border.top.color.a, closeTo(0.5, 0.01));
    expect(border.top.color.r, closeTo(_gold.r, 0.01));

    final BoxDecoration disc = _decorationOf(
      tester,
      const ValueKey('codelessly-toast-icon-disc'),
    );
    expect(disc.shape, BoxShape.circle);
    expect(disc.color!.a, closeTo(0.18, 0.01));
    expect(
      tester.getSize(find.byKey(const ValueKey('codelessly-toast-icon-disc'))),
      const Size(36, 36),
    );

    final TextStyle title = _styleOf(tester, 'Gate change');
    expect(title.color, _ivory);
    expect(title.fontSize, 13.5);
    expect(title.fontWeight, FontWeight.w800);
    final TextStyle body = _styleOf(tester, 'MR 88 now boards at A11');
    expect(body.fontSize, 12);
    // The body is a fainter line of the text color.
    expect(body.color!.a, closeTo(0.72, 0.01));
    expect(body.color!.r, closeTo(_ivory.r, 0.01));

    final ButtonStyle view = tester
        .widget<TextButton>(
          find.byKey(const ValueKey('codelessly-toast-action')),
        )
        .style!;
    expect(view.foregroundColor!.resolve({}), _gold);
    // The unresolved close binding falls back to the text color.
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('codelessly-toast-close')),
          )
          .color,
      _ivory,
    );

    // On a phone it stretches between 14px margins below the safe area.
    final Rect rect = tester.getRect(
      find.byKey(const ValueKey('codelessly-toast')),
    );
    expect(rect.left, 14);
    expect(rect.width, 390 - 28);
    AppToast.hide();
  });

  testWidgets('a fixed-width card toast sits at the right on a desktop', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      (context) => AppToast.show(context, _card()),
      size: const Size(1440, 900),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final Rect rect = tester.getRect(
      find.byKey(const ValueKey('codelessly-toast')),
    );
    expect(rect.width, 380);
    expect(rect.right, 1440 - 24);
    // The button and close sit at the card's end.
    expect(
      tester
          .getRect(find.byKey(const ValueKey('codelessly-toast-close')))
          .right,
      greaterThan(rect.right - 20),
    );
    AppToast.hide();
  });

  testWidgets('a toast without a title or bindings looks as before', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      (context) => AppToast.show(
        context,
        ShowToastAction(
          message: 'Saved',
          backgroundColor: ColorRGBA.fromHex('#1F2B2E'),
          textColor: ColorRGBA.fromHex('#F3ECDD'),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('codelessly-toast-title')), findsNothing);
    expect(
      _decorationOf(tester, const ValueKey('codelessly-toast')).color,
      _ink,
    );
    expect(_styleOf(tester, 'Saved').color, const Color(0xFFF3ECDD));
    AppToast.hide();
  });

  testWidgets('a confirm dialog takes colors bound to formulas', (
    tester,
  ) async {
    final ConfirmAction action = ActionModel.fromJson({
      'type': 'confirm',
      'title': 'Remove pass?',
      'message': 'It leaves your wallet.',
      'confirmLabel': 'Remove',
      'cancelLabel': 'Keep',
      // A static color the binding wins over.
      'backgroundColor': '#FFFFFF',
      'variables': {
        'backgroundColor': r'${pal.surface}',
        'titleColor': r'${pal.ink}',
        'messageColor': r'${= alpha(pal.ink, 0.7)}',
        'confirmColor': r'${pal.danger}',
        'confirmTextColor': r'${pal.ivory}',
        'cancelColor': r'${pal.surface}',
        'cancelTextColor': r'${pal.ink}',
        'buttonBorderColor': r'${= alpha(pal.ink, 0.22)}',
      },
    }) as ConfirmAction;
    await _pumpApp(tester, (context) => AppConfirmDialog.show(context, action));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
      _surface,
    );
    expect(_styleOf(tester, 'Remove pass?').color, _ink);
    expect(
      _styleOf(tester, 'It leaves your wallet.').color!.a,
      closeTo(0.7, 0.01),
    );
    final ButtonStyle ok = tester
        .widget<FilledButton>(
          find.byKey(const ValueKey('codelessly-confirm-ok')),
        )
        .style!;
    final ButtonStyle cancel = tester
        .widget<TextButton>(
          find.byKey(const ValueKey('codelessly-confirm-cancel')),
        )
        .style!;
    expect(ok.backgroundColor!.resolve({}), _danger);
    expect(ok.foregroundColor!.resolve({}), _ivory);
    expect(cancel.backgroundColor!.resolve({}), _surface);
    expect(cancel.foregroundColor!.resolve({}), _ink);
    expect(cancel.side!.resolve({})!.color.a, closeTo(0.22, 0.01));

    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
  });
}
