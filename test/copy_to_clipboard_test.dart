import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('copy to clipboard copies the text with its variables', (
    tester,
  ) async {
    final List<Object?> copied = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text']);
        }
        return null;
      },
    );
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
      ..variables['homeId'] = Observable(
        VariableData(
          id: 'homeId',
          name: 'homeId',
          type: VariableType.text,
          value: 'h_meadow',
        ),
      );
    late BuildContext context;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final bool done = await FunctionsRepository.copyToClipboard(
      context,
      CopyToClipboardAction(text: r'https://nook.homes/homes/${homeId}'),
    );
    expect(done, isTrue);
    expect(copied, ['https://nook.homes/homes/h_meadow']);
  });
}
