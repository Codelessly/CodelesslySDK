import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A browser that denies clipboard access makes Clipboard.setData throw. The
/// copy is a side effect: the chain goes on to its "Link copied" toast.
void main() {
  testWidgets('a copy the platform refuses still lets the chain go on', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(
            code: 'denied',
            message: 'clipboard-write denied',
          );
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );
    final bool ok = await FunctionsRepository.copyToClipboard(
      ctx,
      CopyToClipboardAction(text: 'https://site.codelessly.com/mixtape'),
    );
    expect(ok, isTrue);
    expect(tester.takeException(), isNull);
  });
}
