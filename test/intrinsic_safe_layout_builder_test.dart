import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a LayoutBuilder under IntrinsicWidth throws', (tester) async {
    await tester.pumpWidget(
      Center(
        child: IntrinsicWidth(
          child: LayoutBuilder(builder: (_, _) => const SizedBox(width: 10)),
        ),
      ),
    );
    expect(tester.takeException(), isNotNull);
  });

  testWidgets('IntrinsicSafeLayoutBuilder reports its intrinsic size', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: IntrinsicWidth(
            child: IntrinsicHeight(
              child: IntrinsicSafeLayoutBuilder(
                intrinsicSize: const Size(40, 30),
                builder: (_, constraints) => SizedBox(
                  key: const Key('child'),
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const Key('child'))), const Size(40, 30));
  });

  testWidgets('it builds with the constraints it is laid out with', (
    tester,
  ) async {
    BoxConstraints? seen;
    await tester.pumpWidget(
      Center(
        child: SizedBox(
          width: 120,
          height: 80,
          child: IntrinsicSafeLayoutBuilder(
            builder: (_, constraints) {
              seen = constraints;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    expect(seen, BoxConstraints.tight(const Size(120, 80)));
  });
}
