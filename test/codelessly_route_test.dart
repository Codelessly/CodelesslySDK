import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a route is a screen id and its parameters as a query', () {
    final CodelesslyRoute route = CodelesslyRoute.of('album', {
      'albumId': 'a 1',
      'count': 3,
      'list': [1, 2],
    });
    expect(route.params, {'albumId': 'a 1', 'count': '3'});
    expect(route.toPath(), 'album?albumId=a+1&count=3');
    expect(CodelesslyRoute.tryParse(route.toPath()), route);
    expect(
      CodelesslyRoute.tryParse('/my-slug/album?albumId=a%201'),
      const CodelesslyRoute('album', {'albumId': 'a 1'}),
    );
    expect(CodelesslyRoute.tryParse('/'), isNull);
    expect(const CodelesslyRoute('home').toPath(), 'home');
  });
}
