import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// A share button builds its link from the page's own address: `route.url`
/// and `route.origin` (the Mixtape share card's COPY LINK).
void main() {
  tearDown(() => ScopedValues.pageUri = () => Uri.base);

  test('route has the page url and origin in a browser', () {
    ScopedValues.pageUri = () =>
        Uri.parse('https://site.codelessly.com/mixtape/share?id=for-dana');
    final ScopedValues values = ScopedValues.preview(
      variables: const {},
      routeParams: {'id': 'for-dana'},
    );
    expect(values.routeParams['origin'], 'https://site.codelessly.com');
    expect(
      values.routeParams['url'],
      'https://site.codelessly.com/mixtape/share?id=for-dana',
    );
    expect(values.routeParams['id'], 'for-dana');
  });

  test('a given param of the same name wins, and files have none', () {
    ScopedValues.pageUri = () => Uri.parse('https://a.example/x');
    expect(ScopedValues.preview(variables: const {}, routeParams: {'url': 'mine'}).routeParams['url'], 'mine');
    ScopedValues.pageUri = () => Uri.parse('file:///app/main.dart');
    expect(ScopedValues.preview(variables: const {}).routeParams.containsKey('origin'), isFalse);
  });
}
