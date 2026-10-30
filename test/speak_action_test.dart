import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _RecordingSpeech implements SpeechBackend {
  final List<String> calls = [];

  @override
  void speak(
    String text, {
    required String language,
    required double rate,
    required double pitch,
  }) => calls.add('speak $text|$language|$rate|$pitch');

  @override
  void stop() => calls.add('stop');
}

Observable<VariableData> _variable(
  String name,
  VariableType type,
  Object value,
) => Observable(VariableData(id: name, name: name, type: type, value: value));

void main() {
  late SpeechBackend original;
  late _RecordingSpeech speech;

  setUp(() {
    original = Speech.backend;
    speech = _RecordingSpeech();
    Speech.backend = speech;
  });
  tearDown(() => Speech.backend = original);

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
    expect(speech.calls, ['speak شكرا|ar-EG|0.6|1.0']);
  });

  testWidgets('a stop action stops speech instead of speaking', (tester) async {
    final BuildContext context = await pumpContext(tester);
    FunctionsRepository.performAction(
      context,
      SpeakAction(text: r'${phrase}', stop: true),
    );
    expect(speech.calls, ['stop']);
  });

  testWidgets('a rate that is not a number falls back to normal and pitch '
      'is clamped', (tester) async {
    final BuildContext context = await pumpContext(tester);
    FunctionsRepository.performAction(
      context,
      SpeakAction(text: 'Hello', language: 'en-US', rate: 'fast', pitch: '5'),
    );
    expect(speech.calls, ['speak Hello|en-US|1.0|2.0']);
  });
}
