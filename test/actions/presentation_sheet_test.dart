import 'dart:math' as math;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'feedback_test.dart' show Host, v;

const sheetKey = ValueKey('Codelessly bottom sheet');
List<Json> ask(Json look) => [
  {
    'type': 'confirm',
    'title': 'Delete account?',
    'message': 'Remove this sandbox profile.',
    'confirmLabel': 'Delete',
    'presentation': 'bottomSheet',
    'look': look,
    'actions': [
      {'type': 'setVariable', 'variable': 'answer', 'value': 'confirmed'},
    ],
    'cancelActions': [
      {'type': 'setVariable', 'variable': 'answer', 'value': 'cancelled'},
    ],
  },
];
void main() {
  for (final size in [const Size(390, 844), const Size(834, 1112), const Size(1440, 900)]) {
    testWidgets('native bottom-sheet confirm honors explicit 640 width cap and radius28 at ${size.width}', (tester) async {
      final host = Host([v('answer', '')]);
      await host.pump(tester, size: size);
      final pending = host.run(ask({'sheetWidth': 640, 'radius': 28, 'stackButtons': true, 'buttonHeight': 54, 'padding': 28}));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byKey(sheetKey));
      expect(rect.width, math.min(640, size.width));
      expect(rect.center.dx, size.width / 2);
      expect(rect.bottom, size.height);
      final clip = tester.widget<ClipRRect>(find.byKey(sheetKey));
      expect(clip.borderRadius, const BorderRadius.vertical(top: Radius.circular(28)));
      await tester.tap(find.byKey(const ValueKey('codelessly-confirm-ok')));
      await tester.pumpAndSettle();
      await pending;
      expect(host['answer'], 'confirmed');
      expect(host.errors, isEmpty);
    });
  }
  testWidgets('omitted sheet width and radius retain full-width native sheet and radius10', (tester) async {
    final host = Host([v('answer', '')]);
    await host.pump(tester, size: const Size(834, 1112));
    final pending = host.run(ask({}));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byKey(sheetKey));
    expect(rect.width, 834);
    expect(rect.left, 0);
    expect(rect.bottom, 1112);
    expect(tester.widget<ClipRRect>(find.byKey(sheetKey)).borderRadius, const BorderRadius.vertical(top: Radius.circular(10)));
    await tester.tap(find.byKey(const ValueKey('codelessly-confirm-cancel')));
    await tester.pumpAndSettle();
    await pending;
    expect(host['answer'], 'cancelled');
    expect(host.errors, isEmpty);
  });
  testWidgets('side sheets retain explicit or default widths when a bottom-sheet corner radius is supplied', (tester) async {
    final host = Host([]);
    await host.pump(tester, size: const Size(900, 900));
    for (final width in <double?>[null, 410]) {
      final pending = Navigator.of(host.context!).push<void>(
        PresentationRoute<void>(
          context: host.context!,
          presentation: ModalPresentation.sideSheet,
          sheetWidth: width,
          cornerRadius: 28,
          builder: (_) => const Material(child: SizedBox.expand()),
        ),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byKey(const ValueKey('Codelessly side sheet')));
      expect(rect.width, width ?? 400);
      expect(rect.right, 900);
      Navigator.of(host.context!).pop();
      await tester.pumpAndSettle();
      await pending;
    }
  });
}
