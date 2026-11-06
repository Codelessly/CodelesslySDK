import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A toast in a Google font with a weight of its own draws in that weight's
/// face: the font resolver loads one face per weight, so taking the
/// semibold face and only setting [TextStyle.fontWeight] drew a regular
/// (w400) toast semibold.
void main() {
  test('a Google font toast with a weight takes that weight\'s face', () {
    final TextStyle regular = AppToast.fontForAction(
      ShowToastAction(
        message: 'x',
        fontFamily: 'Barlow',
        fontWeight: FontWeightNumeric.w400,
      ),
      const TextStyle(),
    );
    expect(regular.fontWeight, FontWeight.w400);
    expect(
      regular.fontFamily,
      AppToast.fontOf('Barlow', weight: FontWeightNumeric.w400)!.fontFamily,
    );

    // Without a weight the toast is semibold, in the semibold face.
    final TextStyle semibold = AppToast.fontForAction(
      ShowToastAction(message: 'x', fontFamily: 'Barlow'),
      const TextStyle(),
    );
    expect(semibold.fontWeight, FontWeight.w600);
    expect(semibold.fontFamily, AppToast.fontOf('Barlow')!.fontFamily);
  });
}
