// A control's label falls back for the symbols its font lacks (← → ↗ ⌘) as
// every text does: in round 11's pictures `Button "Known →"` and a Nav's
// `Contact ↗` drew missing-glyph boxes beside texts that drew the arrows.
import 'package:codelessly_sdk/src/render/controls/kit.dart' show ControlLabel;
import 'package:codelessly_sdk/src/render/convert.dart' show FontDemand;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A label lays out again when the platform's fonts change, which it hears from the binding.
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => FontDemand.symbolFallback = const []);

  test('a control label takes the symbol fallback every text style has', () {
    FontDemand.symbolFallback = const ['Symbols'];
    final label = ControlLabel()..update('Known →', const TextStyle(fontFamily: 'Inter', fontSize: 13));
    label.layout(200);
    expect(label.debugStyle?.fontFamilyFallback, contains('Symbols'));
  });

  test('with no symbol font (an app: the platform falls back) the style is as given', () {
    final label = ControlLabel()..update('Known →', const TextStyle(fontFamily: 'Inter', fontSize: 13));
    expect(label.debugStyle?.fontFamilyFallback, isNull);
  });
}
