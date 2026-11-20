// `tool/codelessly states` takes one manifest: a second argument (`states <site> states.json`, from the NOCD
// rebuild) was taken silently, the first read as the manifest. It is a usage error now, said before anything runs.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/cli/src/common.dart';
import '../../tool/cli/src/states.dart';

void main() {
  test('states with two arguments is a usage error naming the one it takes', () async {
    await expectLater(
      statesMain(['site', 'states.json']),
      throwsA(isA<UsageError>().having((e) => e.message, 'message', allOf(contains('one argument'), contains('states <states.json>'), contains('site states.json')))),
    );
  });
}
