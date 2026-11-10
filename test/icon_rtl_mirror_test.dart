import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// A directional icon points the other way in a right-to-left layout
/// whether it is drawn from Flutter's font (which mirrors arrow_back and
/// chevron_right itself) or from a Material Symbol SVG, so a back button
/// bound to an icon name agrees with one placed from the catalog.
void main() {
  MaterialSymbol symbol(String name) => MaterialSymbol(
    codepoint: 0,
    fontFamily: 'MaterialSymbols',
    name: name,
    style: MaterialSymbolStyle.rounded,
  );

  test('arrows and chevrons are directional; stars are not', () {
    expect(mirrorsInRtl(symbol('arrow_back')), isTrue);
    expect(mirrorsInRtl(symbol('chevron_right')), isTrue);
    expect(mirrorsInRtl(symbol('star')), isFalse);
    expect(
      mirrorsInRtl(
        const MaterialIcon(
          codepoint: 1,
          name: 'arrow_forward',
          style: MaterialIconStyle.rounded,
        ),
      ),
      isTrue,
    );
  });
}
