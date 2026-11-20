// A formula that calls a function the formulas do not have (`str(badge)`,
// `substr(name,0,5)`, `has(reply,'id')`) parses, and gives nothing when it
// runs: the render said so, expand did not (NOCD parts 01, 03, 11). Expand
// says it where it was written, with the functions nearest.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/notation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/notation/formula_check.dart';

const _page = '''
state badge=3
state name="Jordan"
state reply={"id":1}
state twice(v):integer={v * 2}
Column
  Text "{str(badge)}"
  Text "{substr(name,0,5)}"
  Text "{has(reply,'id') ? 'yes' : 'no'}"
  Text "{twice(badge)} {upper(name)} {length(name)}"
''';

void main() {
  test('each unknown function is said at its line, with what to call instead; a page\'s own function and the engine\'s are not', () {
    final r = api.Catalog.run(api.standardCatalog, () => parseNotation(_page));
    expect(r.issues, isEmpty);
    final notes = formulaNotes(r.document, {'pages/home.txt': _page});
    expect(notes, [
      allOf(startsWith('pages/home.txt:6:'), contains('calls str(…), a function the formulas do not have'), contains('Did you mean text')),
      allOf(startsWith('pages/home.txt:7:'), contains('calls substr(…)'), contains('Did you mean substring')),
      allOf(startsWith('pages/home.txt:8:'), contains('calls has(…)'), contains('contains')),
    ]);
  });

  test('a function the site declares is known; a line an issue already said is not said again', () {
    const page = 'Column\n  Text "{siteFn(1)}"\n  Text "{nope(1)}"\n';
    final r = api.Catalog.run(api.standardCatalog, () => parseNotation(page));
    final notes = formulaNotes(r.document, {'p.txt': page}, site: {'siteFn': const {'type': 'integer'}}, said: {'p.txt:3'});
    expect(notes, isEmpty);
    expect(nearestFunctions('substr'), contains('substring'));
    expect(nearestFunctions('lenght'), contains('length'));
  });
}
