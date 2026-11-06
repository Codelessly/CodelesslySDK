import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class FakeRecognizer implements SpeechRecognizer {
  final RecognitionResult result;
  String? language;
  FakeRecognizer(this.result);
  @override
  bool get available => true;
  @override
  Future<RecognitionResult> listen({
    required String language,
    required Duration timeout,
  }) async {
    this.language = language;
    return result;
  }

  @override
  void stop() {}
}

void main() {
  scoreNullTests();
  group('pronunciationScore', () {
    test('exact, case and punctuation free', () {
      expect(
        pronunciationScore(
          'Although it rained, we went out.',
          'although it rained we went out',
        ),
        100,
      );
    });
    test('a missing word costs its share', () {
      expect(pronunciationScore('since you asked', 'since asked'), 67);
    });
    test('near misses get partial credit', () {
      final int s = pronunciationScore('whereas', 'where as');
      expect(s, inInclusiveRange(1, 99));
      expect(pronunciationScore('thought', 'taught'), greaterThan(0));
    });
    test('nothing heard scores 0', () {
      expect(pronunciationScore('despite', ''), 0);
    });
    test('extra words cost a little', () {
      expect(
        pronunciationScore('because', 'because because because'),
        lessThan(100),
      );
    });
  });

  testWidgets('a listen Call function fills the speech variable', (
    tester,
  ) async {
    final FakeRecognizer fake = FakeRecognizer(
      const RecognitionResult('however it was late', confidence: 0.9),
    );
    Speech.recognizer = fake;
    final CodelesslyContext context = CodelesslyContext.empty();
    late BuildContext inner;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: context,
        child: MaterialApp(
          home: Builder(
            builder: (c) {
              inner = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    final Object? result = FunctionsRepository.callFunction(
      inner,
      CallFunctionAction(
        name: 'listen',
        params: {'language': 'en-GB', 'expected': 'However, it was late.'},
      ),
    );
    await tester.runAsync(() async => await (result as Future));
    expect(fake.language, 'en-GB');
    expect(Speech.instance.value['heard'], 'however it was late');
    expect(Speech.instance.value['score'], 100);
    expect(Speech.instance.value['listening'], false);
    expect(Speech.instance.value['confidence'], 0.9);
  });

  testWidgets('a host function of the same name wins', (tester) async {
    bool called = false;
    final CodelesslyContext context = CodelesslyContext.empty()
      ..functions['listen'] = (c, r, p) => called = true;
    late BuildContext inner;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: context,
        child: MaterialApp(
          home: Builder(
            builder: (c) {
              inner = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    FunctionsRepository.callFunction(inner, CallFunctionAction(name: 'listen'));
    expect(called, isTrue);
  });
}

void scoreNullTests() {
  testWidgets('score is null until something is heard', (tester) async {
    Speech.recognizer = FakeRecognizer(
      const RecognitionResult('', error: 'no-speech'),
    );
    await tester.runAsync(() => Speech.instance.listen(expected: 'despite'));
    expect(Speech.instance.value['score'], isNull);
    expect(Speech.instance.value['error'], 'no-speech');
  });
}
