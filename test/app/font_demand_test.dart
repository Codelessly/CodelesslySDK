// A family a text style reaches only through a binding (no publish lists
// it) is fetched the first time it is drawn, once per family/weight/style.
import 'dart:typed_data';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/convert.dart' show FontDemand;
import 'package:flutter_test/flutter_test.dart';

class _Fetcher implements FontFetcher {
  final asked = <String>[];
  @override
  Future<Uint8List?> fetch(PublishFont font) async {
    asked.add('${font.family} ${font.weight}${font.italic ? ' italic' : ''}');
    return null;
  }
}

void main() {
  test('a style naming an unlisted family fetches it once', () async {
    FontDemand.handler = null;
    final fetcher = _Fetcher();
    CodelesslyFonts(fetcher: fetcher, register: (_, _) async {});
    textStyle(const api.TextStyle(fontFamily: 'Anton', fontWeight: 400));
    textStyle(const api.TextStyle(fontFamily: 'Anton', fontWeight: 400));
    textStyle(const api.TextStyle(fontFamily: 'Fraunces', fontWeight: 500, fontStyle: api.FontStyle.italic));
    await Future<void>.delayed(Duration.zero);
    expect(fetcher.asked, ['Anton 400', 'Fraunces 500 italic']);
    FontDemand.handler = null;
  });
}
