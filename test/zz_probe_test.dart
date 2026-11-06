import 'dart:io';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('probe', () {
    final raw = File('/tmp/feed_value.txt').readAsStringSync();
    final v = VariableData(id: 'f', name: 'feed', value: raw, type: VariableType.list);
    final Object? typed = v.getValue();
    print('typed ${typed.runtimeType} ${typed is List ? typed.length : '-'}');
    print('typedValue ${raw.typedValue<List>()?.length}');
  });
}
