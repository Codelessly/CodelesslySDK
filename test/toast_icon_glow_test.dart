import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A toast's icon takes [ShowToastAction.iconShadows]: a soft halo round a
/// small round icon draws a lit lamp, as an app's own toast lamp glows.
void main() {
  testWidgets('a toast icon without a disc glows with its iconShadows', (
    tester,
  ) async {
    late BuildContext page;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Builder(
            builder: (c) {
              page = c;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    AppToast.show(
      page,
      ShowToastAction(
        message: 'Saved',
        duration: 1000,
        icon: const MultiSourceIconModel.icon(
          size: 8,
          color: ColorRGBA.white,
          icon: MaterialIcon(
            codepoint: 0xef4a,
            name: 'circle',
            style: MaterialIconStyle.filled,
          ),
        ),
        iconShadows: [
          Effect(
            id: 'glow',
            type: EffectType.dropShadow,
            radius: 9.6,
            color: ColorRGBA(r: 0.49, g: 1, b: 0.42, a: 0.8),
            offset: Vec(0, 0),
          ),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final DecoratedBox glow = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('codelessly-toast-icon-glow')),
    );
    final BoxDecoration decoration = glow.decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.boxShadow, hasLength(1));
    expect(decoration.boxShadow!.single.blurRadius, 9.6);

    // Without iconShadows there is no halo.
    AppToast.show(page, ShowToastAction(message: 'Plain', duration: 1000));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('codelessly-toast-icon-glow')),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 2));
  });
}
