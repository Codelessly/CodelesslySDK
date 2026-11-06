import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// `animating` became a built-in (the variables an Animate variable action
/// is playing) after projects already had boolean variables called that. A
/// project's own `animating` wins, in plain reads, in formulas and in the
/// computed variables built on it: a game frozen mid-flight
/// (`frozenFly = phase == 'flying' && !animating`) jumped to its end when
/// `!animating` read the built-in map.
void main() {
  ScopedValues scopeWith(Map<String, VariableData> extra) =>
      ScopedValues.preview(variables: extra);

  Object? read(ScopedValues scope, String path) =>
      PropertyValueDelegate.getVariableValueFromPath<Object>(
        path,
        scopedValues: scope,
      );

  test('a project variable named animating wins over the built-in', () {
    final ScopedValues scope = scopeWith({
      'animating': VariableData(
        id: 'animating',
        name: 'animating',
        type: VariableType.boolean,
        value: 'false',
      ),
      'frozen': VariableData(
        id: 'frozen',
        name: 'frozen',
        type: VariableType.boolean,
        formula: '!animating',
      ),
    });
    expect(read(scope, r'${animating}'), false);
    expect(read(scope, r'${= !animating}'), true);
    expect(read(scope, 'frozen'), true);
  });

  test('without a project variable, animating is the built-in map', () {
    final ScopedValues scope = scopeWith({});
    expect(read(scope, r'${animating}'), isA<Map>());
  });
}
