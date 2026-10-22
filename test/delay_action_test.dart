import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a delay action waits before completing', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (ctx) {
          context = ctx;
          return const SizedBox();
        },
      ),
    );
    bool done = false;
    final future = FunctionsRepository.performAction(
      context,
      DelayAction(milliseconds: 300),
    );
    (future as Future).then((_) => done = true);
    await tester.pump(const Duration(milliseconds: 200));
    expect(done, isFalse);
    await tester.pump(const Duration(milliseconds: 150));
    expect(done, isTrue);
  });
}
