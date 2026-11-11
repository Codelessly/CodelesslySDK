import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('page scopes persist across layouts and shadow app values', () {
    final app = Codelessly();
    addTearDown(app.dispose);
    app.declareAppVariables([
      const Variable(name: 'count', type: VariableType.integer, value: 3),
      const Variable(name: 'appLabel', value: 'shared app'),
    ]);
    final first = app.pageVariables('page-one', [
      const Variable(name: 'count', type: VariableType.integer, value: 5),
      const Variable(name: 'label', value: 'original'),
    ]);
    expect(first.read('count'), 5);
    expect(first.read('appLabel'), 'shared app');
    first.set('label', 'edited');
    final nextLayout = app.pageVariables('page-one', [
      const Variable(name: 'label', value: 'original'),
    ]);
    expect(identical(first, nextLayout), isTrue);
    expect(nextLayout.read('label'), 'edited');
    expect(app.appVariables.read('count'), 3);
    final otherPage = app.pageVariables('page-two', [
      const Variable(name: 'label', value: 'second page'),
    ]);
    expect(otherPage.read('label'), 'second page');
    expect(
      otherPage.read('count'),
      3,
      reason: 'another page inherits only app state',
    );
  });

  test('two app instances never share page state', () {
    final first = Codelessly(), second = Codelessly();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final a = first.pageVariables('same-page', [
      const Variable(name: 'label', value: 'first'),
    ]);
    final b = second.pageVariables('same-page', [
      const Variable(name: 'label', value: 'second'),
    ]);
    a.set('label', 'changed');
    expect(b.read('label'), 'second');
  });
}
