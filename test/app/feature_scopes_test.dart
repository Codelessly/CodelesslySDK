// The feature scopes of an app come from the features its runner installs.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a default Codelessly has every first-party feature and its values', () {
    final app = Codelessly(config: CodelesslyConfig(slug: 'p', services: Services(storage: MemoryLocalStorage())));
    addTearDown(app.dispose);
    expect(app.features, kFirstPartyFeatures);
    expect([for (final f in kFirstPartyFeatures) f.name], ['media', 'auth', 'data', 'commerce', 'engage']);
    final values = app.appVariables;
    expect(values.read('auth.isSignedIn') ?? values.read('auth'), isNotNull);
    expect(values.read('storage'), isA<Map>());
    expect(values.read('entitlements'), isA<Map>());
    expect(values.read('speech'), isA<Map>());
    expect(values.read('usage.launches'), 0);
  });

  test('a runner of another kind keeps the first-party values', () {
    final app = Codelessly(config: const CodelesslyConfig(slug: 'p', actions: NoopActionRunner()));
    addTearDown(app.dispose);
    expect(app.features, kFirstPartyFeatures);
    expect(app.appVariables.read('storage'), isA<Map>());
  });

  test('a core-only Codelessly has no feature value, and still its data and variables', () {
    final app = Codelessly(config: const CodelesslyConfig(slug: 'p', actions: CoreActions()));
    addTearDown(app.dispose);
    app.setData('name', 'Ada');
    app.declareAppVariables([const Variable(name: 'n', type: VariableType.integer, value: 3)]);
    expect(app.features, isEmpty);
    final values = app.appVariables;
    for (final name in ['auth', 'storage', 'entitlements', 'speech', 'usage']) {
      expect(values.read(name), isNull, reason: name);
    }
    expect(values.read('data.name'), 'Ada');
    expect(values.read('n'), 3);
    // Nothing to refresh; not an error.
    app.refreshAuthValues(AuthOperation.signIn);
    expect(app.automations.usage['launches'], 0);
  });

  test('only the features installed give their values', () {
    final app = Codelessly(
      config: const CodelesslyConfig(slug: 'p', actions: CodelesslyActions(features: [authFeature, dataFeature])),
    );
    addTearDown(app.dispose);
    expect(app.appVariables.read('storage'), isA<Map>());
    expect(app.appVariables.read('auth'), isA<Map>());
    expect(app.appVariables.read('entitlements'), isNull);
  });

  test('instrument voices are registered with the sound service, not known to it', () {
    final engine = SilentSoundEngine();
    final sound = SoundService(engine: engine);
    expect(kSoundWaveforms, ['sine', 'triangle', 'square', 'sawtooth']);
    expect(sound.instruments.keys, ['felt', 'reed', 'pluck']);
    sound.startNoteWithWaveform('a', waveform: 'felt');
    sound.startNoteWithWaveform('b', waveform: 'theremin');
    expect(engine.waveforms, {'a': 'felt', 'b': 'sine'});
    // An app's own instrument is registered the same way.
    sound.addInstrument(const SoundInstrument(
      'theremin',
      oscillators: [SoundOscillator('sine', 1, 1)],
      cutoffRatio: 8,
      cutoffMax: 4000,
      harmonics: [SoundOscillator('sine', 1, 1)],
    ));
    sound.startNoteWithWaveform('b', waveform: 'theremin');
    expect(engine.waveforms['b'], 'theremin');
    // Without the media feature's voices, their names are plain sines.
    final bare = SilentSoundEngine();
    SoundService(engine: bare, instruments: const []).startNoteWithWaveform('a', waveform: 'felt');
    expect(bare.waveforms['a'], 'sine');
  });
}
