import 'package:codelessly_sdk/src/ui/codelessly_dialog_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A full height sheet gives the canvas 90% of the screen so it scrolls its
/// own content.
void main() {
  Future<BoxConstraints> constraintsIn(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1000);
    addTearDown(tester.view.reset);
    late BoxConstraints given;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(400, 1000)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: CodelesslyBottomSheetWidget(
              builder: (context) => LayoutBuilder(
                builder: (context, constraints) {
                  given = constraints;
                  return const SizedBox(height: 100);
                },
              ),
            ),
          ),
        ),
      ),
    );
    return given;
  }

  testWidgets('a full height sheet gives its canvas 90% of the screen', (
    tester,
  ) async {
    final constraints = await constraintsIn(tester);
    expect(constraints.maxHeight, 900);
    expect(constraints.minHeight, 900);
  });
}
