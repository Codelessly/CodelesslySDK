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
}
