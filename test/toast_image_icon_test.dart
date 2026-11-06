import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const String _url = 'https://example.com/toast_check.png';

/// Apiary's toast: an ink pill with wax text and an uploaded honey check.
ShowToastAction _toast(Map<String, dynamic> icon) => ActionModel.fromJson({
  'type': 'showToast',
  'message': 'Logged 12 kg',
  'duration': 2200,
  'backgroundColor': {'r': 0.2, 'g': 0.15, 'b': 0.1, 'a': 1},
  'textColor': {'r': 1, 'g': 0.98, 'b': 0.93, 'a': 1},
  'icon': icon,
  'iconSize': 18,
}) as ShowToastAction;

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

void main() {
  test('an image icon reads imageUrl as its iconImage', () {
    final MultiSourceIconModel icon = MultiSourceIconModel.fromJson({
      'type': 'image',
      'imageUrl': _url,
    });
    expect(icon.iconImage, _url);
  });

  testWidgets('an image icon shows as is, loaded like the app\'s images', (
    tester,
  ) async {
    await _show(
      tester,
      // The toast's iconSize (18) gives way to the icon's own size, which
      // reads as 24 when left out of the icon's JSON.
      _toast({'type': 'image', 'iconImage': _url, 'show': true, 'size': 18}),
    );
    final Finder icon = find.byKey(
      const ValueKey('codelessly-toast-icon-image'),
    );
    expect(icon, findsOneWidget);
    expect(tester.getSize(icon), const Size(18, 18));
    final UltimateImageBuilder image = tester.widget(
      find.descendant(of: icon, matching: find.byType(UltimateImageBuilder)),
    );
    expect(image.url, _url);
    // Not tinted with the toast's text color: a colored check stays so.
    expect(image.color, isNull);
    expect(find.byType(ImageIcon), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('an icon color tints the image', (tester) async {
    await _show(
      tester,
      _toast({
        'type': 'image',
        'iconImage': _url,
        'show': true,
        'color': {'r': 1, 'g': 0, 'b': 0, 'a': 1},
      }),
    );
    final UltimateImageBuilder image = tester.widget(
      find.byType(UltimateImageBuilder),
    );
    expect(image.color, const Color(0xFFFF0000));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
