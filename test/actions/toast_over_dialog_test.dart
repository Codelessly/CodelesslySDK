// A toast shown from an open dialog (Northstar's "Password needed" when the
// delete dialog is confirmed empty) sits above that dialog's barrier and
// takes taps; a toast that was already up when a dialog opened goes under
// the dialog's barrier, as before.
import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_test.dart' show Host;

Iterable<DecoratedBox> _barriersOver(WidgetTester tester, String text) => tester
    .widgetList<DecoratedBox>(find.ancestor(of: find.text(text), matching: find.byType(DecoratedBox)))
    .where((b) => b.position == DecorationPosition.foreground);

bool _ignoring(WidgetTester tester, String text) =>
    tester.widget<IgnorePointer>(find.ancestor(of: find.text(text), matching: find.byType(IgnorePointer)).first).ignoring;

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('a toast shown while a dialog is open is above its barrier', (tester) async {
    final h = Host([]);
    await h.pump(tester);
    unawaited(h.run([
      {'type': 'confirm', 'title': 'Delete your account?', 'barrierColor': '#B3030512'},
    ]));
    await _settle(tester);
    expect(CodelesslyToast.covers.value, hasLength(1));
    await h.run([
      {'type': 'showToast', 'title': 'Password needed', 'message': 'Enter your password to confirm.', 'durationMs': 5000, 'showClose': true},
    ]);
    await _settle(tester);
    expect(_barriersOver(tester, 'Enter your password to confirm.'), isEmpty, reason: 'not dimmed by the dialog it came from');
    expect(_ignoring(tester, 'Enter your password to confirm.'), isFalse, reason: 'its close button takes taps');
    await tester.tap(find.byKey(const ValueKey('codelessly-confirm-cancel')));
    await tester.pumpAndSettle();
  });

  testWidgets('a toast already up when a dialog opens goes under its barrier', (tester) async {
    final h = Host([]);
    await h.pump(tester);
    await h.run([
      {'type': 'showToast', 'title': 'Saved', 'message': 'Synced to your account.', 'durationMs': 5000, 'showClose': true},
    ]);
    await _settle(tester);
    expect(_ignoring(tester, 'Synced to your account.'), isFalse);
    unawaited(h.run([
      {'type': 'confirm', 'title': 'Sign out?'},
    ]));
    await _settle(tester);
    expect(_barriersOver(tester, 'Synced to your account.'), isNotEmpty);
    expect(_ignoring(tester, 'Synced to your account.'), isTrue);
    await tester.tap(find.byKey(const ValueKey('codelessly-confirm-cancel')));
    await tester.pumpAndSettle();
  });
}
