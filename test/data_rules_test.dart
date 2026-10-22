import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DataRules rules = DataRules.fromJson({
    'collections': {
      'tasks': 'owner',
      'posts': 'publicReadOwnerWrite',
      'members': 'signedIn',
      'odd': 'notARule',
    },
  });

  test('reads rules per top-level collection', () {
    expect(rules.ruleFor('tasks'), DataRule.owner);
    expect(rules.ruleFor('tasks/abc/comments'), DataRule.owner);
    expect(rules.ruleFor('posts.p1.likes'), DataRule.publicReadOwnerWrite);
    expect(rules.ruleFor('menu'), DataRule.app);
    expect(rules.ruleFor('odd'), DataRule.app);
    expect(DataRules.fromJson(rules.toJson()).collections, rules.collections);
  });

  test('owned collections record the owner and need a signed-in user', () {
    expect(rules.prepareWrite('tasks', {'title': 'A'}, 'u1'), {
      'title': 'A',
      'ownerId': 'u1',
    });
    expect(rules.prepareWrite('menu', {'title': 'A'}, null), {'title': 'A'});
    expect(rules.prepareWrite('members', {'a': 1}, 'u1'), {'a': 1});
    expect(
      () => rules.prepareWrite('posts', {'a': 1}, null),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Sign in'),
        ),
      ),
    );
  });

  test('role-write collections name the role that writes them', () {
    final DataRules rules = DataRules.fromJson({
      'collections': {'products': 'roleWrite'},
      'roles': {'products': 'admin'},
    });
    expect(rules.ruleFor('products'), DataRule.roleWrite);
    expect(rules.roles['products'], 'admin');
    expect(rules.readFilters('products', null), isEmpty);
    expect(() => rules.prepareWrite('products', {}, null), throwsStateError);
    expect(rules.prepareWrite('products', {'a': 1}, 'u1'), {'a': 1});
    expect(DataRules.fromJson(rules.toJson()).roles, rules.roles);
  });
}
