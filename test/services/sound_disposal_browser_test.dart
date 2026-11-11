@TestOn('browser')
library;

import 'dart:js_interop';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

@JS('eval')
external JSAny? _eval(JSString source);

void main() {
  test('repeated web sounds close audio contexts and remove unlock listeners', () async {
    _eval(
      '''
      globalThis.__soundOriginal = globalThis.AudioContext;
      globalThis.__soundContexts = [];
      globalThis.__soundResumes = 0;
      globalThis.AudioContext = class extends globalThis.__soundOriginal {
        constructor() { super(); globalThis.__soundContexts.push(this); }
        resume() { globalThis.__soundResumes++; return Promise.resolve(); }
      };
    '''
          .toJS,
    );
    try {
      for (var i = 0; i < 20; i++) {
        final sound = SoundService();
        expect(sound.engine, isA<DisposableSoundEngine>());
        sound.dispose();
        sound.dispose();
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      _eval("document.dispatchEvent(new Event('pointerdown')); document.dispatchEvent(new Event('keydown'));".toJS);
      expect(_eval('globalThis.__soundContexts.length'.toJS).dartify(), 20);
      expect(_eval("globalThis.__soundContexts.every(c => c.state === 'closed')".toJS).dartify(), true);
      expect(_eval('globalThis.__soundResumes'.toJS).dartify(), 0);
    } finally {
      _eval(
        'globalThis.AudioContext = globalThis.__soundOriginal; delete globalThis.__soundOriginal; delete globalThis.__soundContexts; delete globalThis.__soundResumes;'
            .toJS,
      );
    }
  });
}
