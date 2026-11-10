import 'package:codelessly_sdk/src/transformers/node_transformers/passive_row_column_transformer.dart';
import 'package:codelessly_sdk/src/transformers/utils/fit_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A row that hugs its height and stretches its children is laid out by
/// [HugCross] with a tight box when its width is fixed too, which makes
/// the flex a relayout boundary. A child that grows later (a hidden strip
/// shown by a formula) must still grow the row, not be cut at its old
/// height.
void main() {
  testWidgets('a hug-stretch row grows when a child grows later', (
    tester,
  ) async {
    final ValueNotifier<double> height = ValueNotifier<double>(40);
    addTearDown(height.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: HugCross(
              child: CodelesslyFlex(
                key: const ValueKey('row'),
                direction: Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(key: ValueKey('edge'), width: 5),
                  Expanded(
                    child: ValueListenableBuilder<double>(
                      valueListenable: height,
                      builder: (context, h, _) => SizedBox(height: h),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const ValueKey('row'))).height, 40);

    height.value = 96;
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const ValueKey('row'))).height, 96);
    expect(tester.getSize(find.byKey(const ValueKey('edge'))).height, 96);

    height.value = 30;
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey('row'))).height, 30);
  });
}
