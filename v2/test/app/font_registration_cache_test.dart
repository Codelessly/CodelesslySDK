import 'dart:async';
import 'dart:typed_data';

import 'package:codelessly_sdk_v2/src/app/fonts.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List file(int value) => Uint8List.fromList([value, 2, 3]);

void main() {
  test('repeated and overlapping font sets register only new files', () async {
    final registered = <(String, List<int>)>[];
    final cache = FontRegistrationCache(
      register: (family, files) async {
        registered.add((family, [for (final bytes in files) bytes.first]));
      },
    );
    await cache.load('Barlow', [file(1), file(4)]);
    await cache.load('Barlow', [file(4), file(1)]);
    await cache.load('Barlow', [file(4), file(7)]);
    await cache.load('Other', [file(1)]);
    expect(registered.map((entry) => [entry.$1, entry.$2]), [
      [
        'Barlow',
        [1, 4],
      ],
      [
        'Barlow',
        [7],
      ],
      [
        'Other',
        [1],
      ],
    ]);
  });

  test(
    'concurrent preview loads share the pending engine registration',
    () async {
      final gate = Completer<void>();
      var calls = 0;
      final cache = FontRegistrationCache(
        register: (_, _) {
          calls++;
          return gate.future;
        },
      );
      final first = cache.load('Barlow', [file(1)]);
      final second = cache.load('Barlow', [file(1)]);
      expect(calls, 1);
      gate.complete();
      await Future.wait([first, second]);
    },
  );

  test('failed engine registration can be retried', () async {
    var calls = 0;
    final cache = FontRegistrationCache(
      register: (_, _) async {
        if (calls++ == 0) throw StateError('failed');
      },
    );
    await expectLater(cache.load('Barlow', [file(1)]), throwsStateError);
    await cache.load('Barlow', [file(1)]);
    expect(calls, 2);
  });
}
