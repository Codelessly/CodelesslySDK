import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

// A showToast whose icon follows data: `variables: {"icon": "${...}"}`.

ShowToastAction toast(Map<String, String> variables, {bool withIcon = true}) =>
    ActionModel.fromJson({
      'type': 'showToast',
      'message': 'Saved',
      if (withIcon)
        'icon': const MultiSourceIconModel.icon(
          size: 20,
          color: ColorRGBA.white,
          icon: MaterialIcon(
            codepoint: 0xe86c,
            name: 'check_circle',
            style: MaterialIconStyle.filled,
          ),
        ).toJson(),
      'variables': variables,
    }) as ShowToastAction;

void main() {
  final ScopedValues values = ScopedValues.preview(
    variables: {
      'toastNext': VariableData(
        id: 'n',
        name: 'toastNext',
        type: VariableType.map,
        value: <String, dynamic>{'icon': 'flight_takeoff_outlined'},
      ),
    },
  );

  test('a bound name picks the icon, keeping its size and colour', () {
    final MultiSourceIconModel icon = AppToast.iconOf(
      toast({'icon': r'${toastNext.icon}'}),
      values,
    )!;
    final MaterialIcon glyph = icon.icon! as MaterialIcon;
    expect(glyph.name, 'flight_takeoff');
    expect(glyph.style, MaterialIconStyle.outlined);
    expect(icon.size, 20);
    expect(icon.color, ColorRGBA.white);
    expect(icon.show, isTrue);
  });

  test('a formula works, and without an icon of its own one is made', () {
    final MultiSourceIconModel icon = AppToast.iconOf(
      toast({'icon': r"${= 1 > 0 ? 'error' : 'check'}"}, withIcon: false),
      values,
    )!;
    expect((icon.icon! as MaterialIcon).name, 'error');
    expect(icon.size, 18);
  });

  test('a binding that gives no name keeps the action icon', () {
    final ShowToastAction action = toast({'icon': r'${toastNext.missing}'});
    expect(AppToast.iconOf(action, values), action.icon);
    expect(AppToast.iconOf(toast(const {}), values), toast(const {}).icon);
    expect(
      AppToast.iconOf(
        toast({'icon': r'${toastNext.missing}'}, withIcon: false),
        values,
      ),
      isNull,
    );
  });

  test('the icon binding is not read as a colour', () {
    expect(ShowToastAction.bindableColors, isNot(contains('icon')));
  });
}
