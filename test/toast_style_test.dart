import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const ColorRGBA _yellow = ColorRGBA(r: 1, g: 0.76, b: 0.055, a: 1);

Future<void> _show(WidgetTester tester, ShowToastAction action) async {
  late BuildContext context;
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  AppToast.show(context, action);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

final Finder _toast = find.byKey(const ValueKey('codelessly-toast'));

BoxDecoration _decoration(WidgetTester tester) =>
    tester.widget<Container>(_toast).decoration! as BoxDecoration;

void main() {
  testWidgets('an accent color draws a bar down the left edge', (tester) async {
    await _show(
      tester,
      ShowToastAction(
        message: 'DF-3104 marked repaired',
        backgroundColor: ColorRGBA.fromHex('#16191D'),
        textColor: ColorRGBA.fromHex('#E8EAEC'),
        accentColor: _yellow,
        cornerRadius: 4,
        duration: 1000,
      ),
    );
    final Border border = _decoration(tester).border! as Border;
    expect(border.left.color, _yellow.toFlutterColor());
    expect(border.left.width, 4);
    expect(border.top, BorderSide.none);
    final ClipRRect clip = tester.widget(
      find.ancestor(of: _toast, matching: find.byType(ClipRRect)).first,
    );
    expect(clip.borderRadius, BorderRadius.circular(4));
    expect(tester.takeException(), isNull);
    await _finish(tester);
  });

  testWidgets('without an accent there is no bar and the toast is a pill', (
    tester,
  ) async {
    await _show(tester, ShowToastAction(message: 'Saved', duration: 1000));
    expect(_decoration(tester).border, isNull);
    final ClipRRect clip = tester.widget(
      find.ancestor(of: _toast, matching: find.byType(ClipRRect)).first,
    );
    expect(clip.borderRadius, BorderRadius.circular(999));
    await _finish(tester);
  });

  testWidgets('the icon takes the icon color and the text the font', (
    tester,
  ) async {
    await _show(
      tester,
      ShowToastAction(
        message: 'Saved',
        textColor: ColorRGBA.white,
        iconColor: _yellow,
        icon: MultiSourceIconModel.icon(
          icon: CupertinoIcon(codepoint: 0xf3fb, name: 'check_mark_circled'),
          size: 20,
        ),
        fontFamily: 'Fleet Sans',
        duration: 1000,
      ),
    );
    final Icon icon = tester.widget(
      find.descendant(of: _toast, matching: find.byType(Icon)),
    );
    expect(icon.color, _yellow.toFlutterColor());
    expect(icon.size, 20);
    final Text text = tester.widget(find.text('Saved'));
    expect(text.style!.fontFamily, AppToast.fontOf('Fleet Sans')!.fontFamily);
    expect(text.style!.color, Colors.white);
    await _finish(tester);
  });

  test('the new fields round-trip through JSON and are omitted by default', () {
    final ShowToastAction toast = ShowToastAction.fromJson({
      'type': 'showToast',
      'message': 'Hi',
      'accentColor': {'r': 1, 'g': 0, 'b': 0, 'a': 1},
      'accentWidth': 3,
      'iconColor': {'r': 0, 'g': 1, 'b': 0, 'a': 1},
      'fontFamily': 'Barlow',
      'cornerRadius': 4,
    });
    expect(toast.accentWidth, 3);
    expect(toast.fontFamily, 'Barlow');
    expect(toast.cornerRadius, 4);
    expect(ShowToastAction.fromJson(toast.toJson()), toast);
    final Map json = ShowToastAction(message: 'Hi').toJson();
    for (final key in [
      'accentColor',
      'accentWidth',
      'iconColor',
      'fontFamily',
      'cornerRadius',
    ]) {
      expect(json.containsKey(key), isFalse, reason: key);
    }
  });
}
