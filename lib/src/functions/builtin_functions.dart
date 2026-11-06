import 'package:flutter/widgets.dart';

import '../speech/speech.dart';
import '../ui/codelessly_context.dart';
import 'functions.dart';

/// App functions every Codelessly app has, reached with a Call function
/// action when the host registered no function of that name:
///
/// - `listen` {language, expected, timeoutMs}: listens for one phrase with
///   the platform's speech recognition and scores it against `expected`;
///   the result is in the `speech` variable (`speech.heard`,
///   `speech.score`, `speech.listening`, `speech.error`). Blocking actions
///   wait for it.
/// - `stopListening`: stops listening.
final Map<String, CodelesslyFunction> builtinFunctions = <String, CodelesslyFunction>{
  'listen': (BuildContext context, CodelesslyContext reference, Map<String, dynamic> params) => Speech.instance.listen(
    language: '${params['language'] ?? 'en-US'}',
    expected: '${params['expected'] ?? ''}',
    timeout: Duration(milliseconds: int.tryParse('${params['timeoutMs'] ?? ''}') ?? 8000),
  ),
  'stopListening': (BuildContext context, CodelesslyContext reference, Map<String, dynamic> params) =>
      Speech.instance.stopListening(),
};
