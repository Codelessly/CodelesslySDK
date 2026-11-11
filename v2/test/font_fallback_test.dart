import 'package:codelessly_api_v2/codelessly_api.dart' as api;
import 'package:codelessly_sdk_v2/src/render/convert.dart';
import 'package:flutter_test/flutter_test.dart';
void main(){test('Flutter text preserves symbol fallback families',(){
 final style=textStyle(const api.TextStyle(fontFamily:'JetBrains Mono',fontFamilyFallback:['Noto Sans Symbols 2']));
 expect(style.fontFamilyFallback,['Noto Sans Symbols 2']);
});}
