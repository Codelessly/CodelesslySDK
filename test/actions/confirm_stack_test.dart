import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'feedback_test.dart' show Host, v;

const okKey = ValueKey('codelessly-confirm-ok');
const cancelKey = ValueKey('codelessly-confirm-cancel');
List<Json> ask({Json look = const {}}) => [
  {
    'type': 'confirm',
    'title': 'Delete account?',
    'message': 'Remove this sandbox profile.',
    'confirmLabel': 'Delete account',
    'cancelLabel': 'Keep account',
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
  testWidgets('opt-in stacked confirm uses full-width confirm-first actions with authored gaps and taps', (tester) async {
    final host = Host([v('answer', '')]);
    await host.pump(tester, size: const Size(500, 900));
    final actions = ask(
      look: {'stackButtons': true, 'width': 360, 'padding': 28, 'buttonHeight': 54, 'titleMessageGap': 16, 'actionsGap': 28, 'buttonGap': 10},
    );
    final pending = host.run(actions);
    await tester.pumpAndSettle();
    final title = tester.getRect(find.text('Delete account?'));
    final message = tester.getRect(find.text('Remove this sandbox profile.'));
    final ok = tester.getRect(find.byKey(okKey));
    final cancel = tester.getRect(find.byKey(cancelKey));
    expect(message.top - title.bottom, closeTo(16, .01));
    expect(ok.top - message.bottom, closeTo(28, .01));
    expect(cancel.top - ok.bottom, closeTo(10, .01));
    expect(ok.size, const Size(304, 54));
    expect(cancel.size, ok.size);
    expect(ok.left, cancel.left);
    expect(ok.right, cancel.right);
    expect(ok.top, lessThan(cancel.top));
    await tester.tap(find.byKey(okKey));
    await tester.pumpAndSettle();
    await pending;
    expect(host['answer'], 'confirmed');
    final next = host.run(actions);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(cancelKey));
    await tester.pumpAndSettle();
    await next;
    expect(host['answer'], 'cancelled');
    expect(host.errors, isEmpty);
  });
  testWidgets('default confirm retains cancel-first horizontal layout and native 8/20/8 spacing', (tester) async {
    final host = Host([v('answer', '')]);
    await host.pump(tester, size: const Size(600, 900));
    final pending = host.run([{...ask().single, 'confirmLabel': 'OK', 'cancelLabel': 'Cancel'}]);
    await tester.pumpAndSettle();
    final title = tester.getRect(find.text('Delete account?'));
    final message = tester.getRect(find.text('Remove this sandbox profile.'));
    final ok = tester.getRect(find.byKey(okKey));
    final cancel = tester.getRect(find.byKey(cancelKey));
    expect(message.top - title.bottom, closeTo(8, .01));
    expect(ok.top - message.bottom, closeTo(20, .01));
    expect(ok.top, cancel.top);
    expect(cancel.left, lessThan(ok.left));
    expect(ok.left - cancel.right, closeTo(8, .01));
    await tester.tap(find.byKey(cancelKey));
    await tester.pumpAndSettle();
    await pending;
    expect(host['answer'], 'cancelled');
    expect(host.errors, isEmpty);
  });
  testWidgets('expanded row keeps its legacy 12px gap unless explicitly overridden', (tester) async {
    final host = Host([v('answer', '')]);
    await host.pump(tester, size: const Size(600, 900));
    for (final explicit in [false, true]) {
      final pending = host.run(ask(look: {'expandButtons': true, 'width': 400, if (explicit) 'buttonGap': 18}));
      await tester.pumpAndSettle();
      final ok = tester.getRect(find.byKey(okKey));
      final cancel = tester.getRect(find.byKey(cancelKey));
      expect(ok.top, cancel.top);
      expect(ok.width, closeTo(cancel.width, .01));
      expect(ok.left - cancel.right, closeTo(explicit ? 18 : 12, .01));
      await tester.tap(find.byKey(cancelKey));
      await tester.pumpAndSettle();
      await pending;
    }
    expect(host.errors, isEmpty);
  });
}
