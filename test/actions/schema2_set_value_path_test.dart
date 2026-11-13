// A setValue's paths are not migrated (an action names them; they are read
// against the node it targets when it runs): a schema-2 path is refused
// where it is used, said once with the schema-3 path to write, and sets
// nothing; the schema-3 paths beside it still apply.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screen.dart' show counter, reaction, show;

void main() {
  testWidgets('a schema-2 setValue path sets nothing and is said once, with the schema-3 path', (tester) async {
    final said = <String>[];
    final before = debugPrint;
    debugPrint = (String? m, {int? wrapWidth}) => said.add(m ?? '');
    addTearDown(() => debugPrint = before);
    final s = await show(tester, counter(actions: [
      reaction('click', [
        {
          'type': 'setValue',
          'node': 'other',
          'values': [
            {'path': 'motion.originX', 'value': 1},
            {'path': 'opacity', 'value': 0.5},
          ],
        },
      ]),
    ]));
    await tester.tapAt(s.center('button'));
    await tester.pump();
    await tester.tapAt(s.center('button'));
    await tester.pump();
    expect(s.tree.resolve('other')!.opacity, 0.5);
    expect(s.tree.resolve('other')!.toJson().toString(), isNot(contains('originX')));
    final notes = said.where((m) => m.contains('schema-2 path')).toList();
    expect(notes, hasLength(1));
    expect(notes.single, contains('motion.alignment'));
  });
}
