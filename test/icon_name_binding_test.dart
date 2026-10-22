import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/transformers/node_transformers/passive_icon_transformer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MultiSourceIconModel model(IconModel icon) =>
      MultiSourceIconModel(icon: icon, show: true, size: 18);

  test('a Material Icon shows the named Material Symbol in the same style', () {
    final MultiSourceIconModel icon = withIconName(
      model(MaterialIcon(
        codepoint: 0xe0c3,
        fontFamily: 'MaterialIcons',
        name: 'help_outline',
        style: MaterialIconStyle.rounded,
        version: 12,
      )),
      'water_drop',
    );
    expect(icon.icon, isA<MaterialSymbol>());
    expect(icon.icon!.toSvgUrl(), contains('/materialsymbolsrounded/water_drop/'));
    expect(icon.size, 18);
    expect(icon.show, isTrue);
  });

  test('a filled Material Icon becomes a filled outlined symbol', () {
    final MultiSourceIconModel icon = withIconName(
      model(MaterialIcon(
        codepoint: 0,
        fontFamily: 'MaterialIcons',
        name: 'add',
        style: MaterialIconStyle.filled,
      )),
      'thunderstorm',
    );
    expect(icon.fill, 1);
    expect(
      icon.icon!.toSvgUrl(fill: icon.fill),
      contains('/materialsymbolsoutlined/thunderstorm/fill1/'),
    );
  });

  test('a Material Symbol keeps its style and swaps its name', () {
    final MultiSourceIconModel icon = withIconName(
      model(MaterialSymbol(
        codepoint: 0,
        fontFamily: 'MaterialSymbols',
        name: 'home',
        style: MaterialSymbolStyle.sharp,
      )),
      'air',
    );
    expect(icon.icon!.toSvgUrl(), contains('/materialsymbolssharp/air/'));
  });

  test('icon nodes declare iconName and iconColor as bindable', () {
    final IconNode node = IconNode(
      id: 'i',
      name: 'Sky',
      basicBoxLocal: NodeBox(0, 0, 18, 18),
      properties: IconProperties(
        icon: model(MaterialIcon(
          codepoint: 0,
          fontFamily: 'MaterialIcons',
          name: 'help',
          style: MaterialIconStyle.outlined,
        )),
      ),
    );
    expect(
      node.propertyVariables.map((v) => v.name),
      containsAll(['iconName', 'iconColor']),
    );
  });
}
