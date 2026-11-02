import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// An icon's `icon` or `iconName` bound to a plain icon name (not a
/// variable or formula) shows that icon, as `${= 'name'}` does.
void main() {
  IconNode iconNode(Map<String, String> variables) => IconNode(
    id: 'i',
    name: 'Status',
    basicBoxLocal: NodeBox(0, 0, 24, 24),
    properties: IconProperties(
      icon: MultiSourceIconModel(
        icon: const MaterialIcon(
          codepoint: 0,
          fontFamily: 'MaterialIcons',
          name: 'help',
          style: MaterialIconStyle.filled,
        ),
        show: true,
        size: 24,
      ),
    ),
  )..variables.addAll(variables);

  ScopedValues scope([Map<String, VariableData> variables = const {}]) =>
      ScopedValues.preview(variables: variables);

  test('a plain icon name for `icon` shows that Material Icon', () {
    final IconNode node = iconNode({'icon': 'block_rounded'});
    expect(
      PropertyValueDelegate.getPropertyValue<String>(
        node,
        'icon',
        scopedValues: scope(),
      ),
      'block_rounded',
    );
    final IconModel? icon = PassiveIconWidget.resolvedIcon(node, scope()).icon;
    expect(icon, isA<MaterialIcon>());
    expect(icon!.name, 'block');
    expect((icon as MaterialIcon).style, MaterialIconStyle.rounded);
  });

  test('it shows the same icon as the formula giving that name', () {
    final IconModel? plain = PassiveIconWidget.resolvedIcon(
      iconNode({'icon': 'block_rounded'}),
      scope(),
    ).icon;
    final IconModel? formula = PassiveIconWidget.resolvedIcon(
      iconNode({'icon': r"${= 'block_rounded'}"}),
      scope(),
    ).icon;
    expect(plain?.toJson(), formula?.toJson());
  });

  test('a plain name for `iconName` shows that Material Symbol', () {
    final IconModel? icon = PassiveIconWidget.resolvedIcon(
      iconNode({'iconName': 'block'}),
      scope(),
    ).icon;
    expect(icon, isA<MaterialSymbol>());
    expect(icon!.name, 'block');
  });

  test('a variable of that name still gives its value', () {
    final IconNode node = iconNode({'icon': 'statusIcon'});
    expect(
      PropertyValueDelegate.getPropertyValue<String>(
        node,
        'icon',
        scopedValues: scope({
          'statusIcon': VariableData(
            id: 'v',
            name: 'statusIcon',
            value: 'check_circle',
          ),
        }),
      ),
      'check_circle',
    );
    // A missing data path is not an icon name.
    expect(
      PropertyValueDelegate.getPropertyValue<String>(
        iconNode({'icon': 'item.icon'}),
        'icon',
        scopedValues: scope(),
      ),
      isNull,
    );
  });

  test('other properties and nodes keep reading plain names as variables', () {
    expect(
      PropertyValueDelegate.getPropertyValue<String>(
        iconNode({'iconColor': 'red'}),
        'iconColor',
        scopedValues: scope(),
      ),
      isNull,
    );
    final TextNode text = TextNode(
      id: 't',
      name: 'Text',
      basicBoxLocal: NodeBox(0, 0, 10, 10),
      data: 'x',
      textMixedProps: [StartEndProp(start: 0, end: 1)],
    )..variables['icon'] = 'block';
    expect(
      PropertyValueDelegate.getPropertyValue<String>(
        text,
        'icon',
        scopedValues: scope(),
      ),
      isNull,
    );
  });
}
