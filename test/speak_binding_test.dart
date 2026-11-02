import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The device's voice, recording what it is asked: a Speak action's text,
/// language, rate and pitch resolve from bindings before [Speech] says them.
class _RecordingEngine implements SpeechEngine {
  final List<String> calls = [];

  @override
  bool get available => true;

  @override
  Future<void> speak(
    String text, {
    required String language,
    required double rate,
    required double pitch,
  }) async => calls.add('speak $text|$language|$rate|$pitch');

  @override
  void cancel() => calls.add('cancel');
}

Observable<VariableData> _variable(
  String name,
  VariableType type,
  Object value,
) => Observable(VariableData(id: name, name: name, type: type, value: value));

void main() {
  late SpeechEngine original;
  late _RecordingEngine speech;

  setUp(() {
    original = Speech.engine;
    speech = _RecordingEngine();
    Speech.engine = speech;
  });
  tearDown(() => Speech.engine = original);

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
      ..variables['phrase'] = _variable('phrase', VariableType.text, 'شكرا')
      ..variables['lang'] = _variable('lang', VariableType.text, 'ar-EG')
      ..variables['slow'] = _variable('slow', VariableType.boolean, true);
    late BuildContext context;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    return context;
  }

  testWidgets('speak resolves text, language and a formula rate', (
    tester,
  ) async {
    final BuildContext context = await pumpContext(tester);
    final Object? done = FunctionsRepository.performAction(
      context,
      SpeakAction(
        text: r'${phrase}',
        language: r'${lang}',
        rate: r'${= slow ? 0.6 : 1}',
      ),
    );
    expect(done, isTrue);
    expect(speech.calls, ['cancel', 'speak شكرا|ar-EG|0.6|1.0']);
  });

  testWidgets('a stop action stops speech instead of speaking', (tester) async {
    final BuildContext context = await pumpContext(tester);
    FunctionsRepository.performAction(
      context,
      SpeakAction(text: r'${phrase}', stop: true),
    );
    expect(speech.calls, ['cancel']);
  });

  testWidgets('a rate that is not a number falls back to normal and pitch '
      'is clamped', (tester) async {
    final BuildContext context = await pumpContext(tester);
    FunctionsRepository.performAction(
      context,
      SpeakAction(text: 'Hello', language: 'en-US', rate: 'fast', pitch: '5'),
    );
    expect(speech.calls, ['cancel', 'speak Hello|en-US|1.0|2.0']);
  });
}
