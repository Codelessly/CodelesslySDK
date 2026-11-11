// A text style's background colour (a highlighted search match) reaches
// Flutter's TextStyle, and round-trips through the API's JSON.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/src/render/convert.dart' show textStyle;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backgroundColor paints behind the glyphs', () {
    final s = api.TextStyle.fromJson({'fontWeight': 700, 'backgroundColor': '#FFFFE7A3'});
    expect(s.toJson()['backgroundColor'], '#FFFFE7A3');
    expect(textStyle(s).backgroundColor, const Color(0xFFFFE7A3));
    expect(api.TextStyle.fromJson({}).merge(s).backgroundColor, s.backgroundColor);
  });
}
