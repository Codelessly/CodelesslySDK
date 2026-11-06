import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The built-in confirm dialog's layout fields: the reference's "Take
/// Reading lamp down?" is at most 380 wide with 20 px to the screen edges,
/// 24/26/24/22 padding and 48 px buttons; the sizes can follow data.
void main() {
  // The dialog's own surface: the Material inside the Dialog's inset.
  Finder surfaceFinder() => find
      .descendant(of: find.byType(Dialog), matching: find.byType(Material))
      .first;

  Future<void> open(
    WidgetTester tester,
    ConfirmAction action,
    Size screen,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = screen;
    addTearDown(tester.view.reset);
    final CodelesslyContext ctx = CodelesslyContext.empty()
      ..variables['wide'] = Observable(
        VariableData(
          id: 'wide',
          name: 'wide',
          type: VariableType.integer,
          value: 300,
        ),
      );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: ctx,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => AppConfirmDialog.show(context, action),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  ConfirmAction reference([Map<String, dynamic> extra = const {}]) =>
      ActionModel.fromJson({
        'type': 'confirm',
        'title': 'Take Reading lamp down?',
        'message': 'It goes back to the tray.',
        'confirmLabel': 'Take down',
        'cancelLabel': 'Keep it',
        'expandButtons': true,
        'width': 380,
        'maxWidth': 380,
        'insets': {'l': 20, 't': 20, 'r': 20, 'b': 20},
        'padding': {'l': 24, 't': 26, 'r': 24, 'b': 22},
        'buttonHeight': 48,
        ...extra,
      }) as ConfirmAction;

  test('the layout fields survive JSON and are left out by default', () {
    final ConfirmAction action = reference();
    final Map json = action.toJson();
    expect(json['width'], 380);
    expect(json['maxWidth'], 380);
    expect(json['buttonHeight'], 48);
    final ConfirmAction back = ConfirmAction.fromJson(json);
    expect(back, action);
    expect(
      back.padding,
      const EdgeInsetsModel.only(left: 24, top: 26, right: 24, bottom: 22),
    );
    expect(back.insets, const EdgeInsetsModel.all(20));
    final Map plain = ConfirmAction(title: 'Sure?').toJson();
    for (final String key in [
      'width',
      'maxWidth',
      'insets',
      'padding',
      'buttonHeight',
    ]) {
      expect(plain.containsKey(key), isFalse, reason: key);
    }
    expect(
      action.copyWith(clearWidth: true, clearButtonHeight: true).width,
      isNull,
    );
  });

  testWidgets('a wide screen: 380 wide, 48 px buttons, the given padding', (
    tester,
  ) async {
    await open(tester, reference(), const Size(800, 900));

    expect(tester.getSize(surfaceFinder()).width, 380);

    final Rect keep = tester.getRect(
      find.byKey(const ValueKey('codelessly-confirm-cancel')),
    );
    final Rect take = tester.getRect(
      find.byKey(const ValueKey('codelessly-confirm-ok')),
    );
    expect(keep.height, 48);
    expect(take.height, 48);
    final Rect surface = tester.getRect(surfaceFinder());
    // 22 below the buttons, 24 to the sides.
    expect(surface.bottom - take.bottom, 22);
    expect(keep.left - surface.left, 24);
    expect(surface.right - take.right, 24);
    // 26 above the title.
    expect(
      tester.getRect(find.text('Take Reading lamp down?')).top - surface.top,
      26,
    );
  });

  testWidgets('a phone: 20 px from each edge', (tester) async {
    await open(tester, reference(), const Size(360, 800));
    final Rect surface = tester.getRect(surfaceFinder());
    expect(surface.left, 20);
    expect(surface.width, 320);
  });

  testWidgets('sizes bind to data', (tester) async {
    await open(
      tester,
      reference({
        'variables': {
          'width': r'${wide}',
          'buttonHeight': r'${= wide / 6}',
          'padding': r'${= [10, 12]}',
        },
      }),
      const Size(800, 900),
    );
    final Rect surface = tester.getRect(surfaceFinder());
    expect(surface.width, 300);
    final Rect take = tester.getRect(
      find.byKey(const ValueKey('codelessly-confirm-ok')),
    );
    expect(take.height, 50);
    expect(surface.right - take.right, 10);
    expect(surface.bottom - take.bottom, 12);
  });

  testWidgets('without them the dialog keeps its defaults', (tester) async {
    await open(tester, ConfirmAction(title: 'Sure?'), const Size(800, 900));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('codelessly-confirm-ok')))
          .height,
      greaterThanOrEqualTo(44),
    );
  });
}
