// preloadImages: loads a story's images before it's read, reporting progress
// in a variable and giving {loaded, failed, total}.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

Variable v(String name, Object? value, [VariableType type = VariableType.text]) =>
    Variable(name: name, type: type, value: type.coerce(value));

void main() {
  testWidgets('waits for every image, reports progress and the result', (tester) async {
    final scope = VariableScope([
      v('pages', [
        {'sky': 'https://example.com/a.webp'},
        {'sky': 'https://example.com/b.webp'},
        {'sky': 'data:image/png;base64,iVBORw0KGgo='},
        {'sky': 'https://example.com/a.webp'},
      ], VariableType.list),
      v('loaded', 0.0, VariableType.decimal),
      v('outcome', <String, Object?>{}, VariableType.map),
    ]);
    final seen = <double>[];
    scope.addListener(() => seen.add((scope.read('loaded') as num).toDouble()));
    final ctx = RuntimeActionContext(scope: scope, ui: NavigatorActionUi(context: () => null));
    await tester.runAsync(() => const CodelesslyActions().run(
          Node.fromJson({
            'type': 'box',
            'actions': [
              {
                'trigger': {'type': 'click'},
                'actions': [
                  {'type': 'preloadImages', 'urls': r'${= map(pages, p => p.sky)}', 'progressVariable': 'loaded'},
                  {'type': 'setVariable', 'variable': 'outcome', 'value': r'${result}'},
                ],
              },
            ],
          }, id: 'n')!,
          'click',
          ctx,
        ));
    // Three distinct images: the two over HTTP fail in tests, the data URL counts as loaded.
    expect(scope.read('outcome'), {'loaded': 1, 'failed': 2, 'total': 3});
    expect(scope.read('loaded'), 1.0);
    expect(seen, [...seen]..sort());
    expect(seen.last, 1.0);
  });
}
