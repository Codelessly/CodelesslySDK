// A Material icon without a version loads its name's current version (not
// every icon exists at v1: `star` doesn't).
import 'package:codelessly_sdk/src/render/paint/icon_glyph.dart' show IconSources;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an unversioned Material icon uses the name\'s current version', () {
    expect(IconSources.urlOf({'type': 'MATERIAL_ICON', 'name': 'star', 'style': 'rounded'}),
        'https://fonts.gstatic.com/s/i/materialiconsround/star/v22/24px.svg');
  });
}
