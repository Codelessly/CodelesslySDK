// A Material icon without a version loads its name's current version (not
// every icon exists at v1: `star` doesn't).
import 'package:codelessly_sdk/src/render/paint/icon_glyph.dart' show IconSources;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an unversioned Material icon uses the name\'s current version', () {
    expect(IconSources.urlOf({'type': 'MATERIAL_ICON', 'name': 'star', 'style': 'rounded'}),
        'https://fonts.gstatic.com/s/i/materialiconsround/star/v22/24px.svg');
  });

  // Petri v2: a toast's icon written as `{"source": "icon", "name": ...}`
  // (the shape a toast's own default takes) resolved to nothing, so the
  // toast showed no icon.
  test('a feedback icon given by source and name is a Material icon', () {
    expect(IconSources.urlOf({'source': 'icon', 'name': 'check_rounded', 'size': 18}),
        IconSources.urlOf({'type': 'MATERIAL_ICON', 'name': 'check', 'style': 'rounded'}));
    expect(IconSources.urlOf({'source': 'icon', 'name': 'check_rounded'}), isNotNull);
    expect(IconSources.urlOf({'source': 'icon'}), isNull, reason: 'no name, no icon');
  });
}
