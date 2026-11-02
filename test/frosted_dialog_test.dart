import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dialogs with a frosted scrim: the page behind blurs and the dialog grows
/// in (Stillpoint's session detail, blurred 8 and scaling from 0.94).
void main() {
  group('ShowDialogAction / ConfirmAction JSON', () {
    test('barrierBlur and enterScale round-trip and default away', () {
      final action = ShowDialogAction(
        destinationId: 'c',
        barrierBlur: 8,
        enterScale: 0.94,
      );
      final json = action.toJson();
      expect(json['barrierBlur'], 8);
      expect(json['enterScale'], 0.94);
      final back = ShowDialogAction.fromJson(json);
      expect(back.barrierBlur, 8);
      expect(back.enterScale, 0.94);

      final plain = ShowDialogAction(destinationId: 'c').toJson();
      expect(plain.containsKey('barrierBlur'), isFalse);
      expect(plain.containsKey('enterScale'), isFalse);
      expect(ShowDialogAction.fromJson(plain).enterScale, 1);
    });

    test('confirm dialogs carry them too', () {
      final json = ConfirmAction(
        title: 't',
        dialogId: 'd',
        barrierBlur: 8,
        enterScale: 0.94,
      ).toJson();
      final back = ConfirmAction.fromJson(json);
      expect(back.barrierBlur, 8);
      expect(back.enterScale, 0.94);
      expect(
        ConfirmAction(title: 't').toJson().containsKey('barrierBlur'),
        isFalse,
      );
    });
  });

  group('frostedDialogTransition', () {
    Widget host(Animation<double> animation, {double blur = 8}) =>
        Directionality(
          textDirection: TextDirection.ltr,
          child: FunctionsRepository.frostedDialogTransition(
            animation: animation,
            barrierBlur: blur,
            enterScale: 0.94,
            child: const SizedBox(width: 100, height: 100),
          ),
        );

    testWidgets('blurs the page fully and shows the dialog at rest when open', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AlwaysStoppedAnimation(1)));
      final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      expect(filter.filter, ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8));
      final scale = tester.widget<ScaleTransition>(
        find.byType(ScaleTransition),
      );
      expect(scale.scale.value, 1);
      final fade = tester.widget<FadeTransition>(find.byType(FadeTransition));
      expect(fade.opacity.value, 1);
    });

    testWidgets('starts sharp, small and transparent', (tester) async {
      await tester.pumpWidget(host(const AlwaysStoppedAnimation(0)));
      final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      expect(filter.filter, ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0));
      final scale = tester.widget<ScaleTransition>(
        find.byType(ScaleTransition),
      );
      expect(scale.scale.value, closeTo(0.94, 1e-9));
      final fade = tester.widget<FadeTransition>(find.byType(FadeTransition));
      expect(fade.opacity.value, 0);
    });

    testWidgets('no blur means no backdrop filter', (tester) async {
      await tester.pumpWidget(host(const AlwaysStoppedAnimation(1), blur: 0));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ScaleTransition), findsOneWidget);
    });
  });
}
