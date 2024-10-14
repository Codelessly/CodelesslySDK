import 'package:flutter/foundation.dart';

const logger = CodelesslyLogger._();

class CodelesslyLogger {
  const CodelesslyLogger._();

  void log(
    String label,
    Object? message, {
    bool largePrint = false,
  }) {
    if (largePrint && kIsWeb) {
      debugPrint('[$label] ${message.toString()}');
    } else {
      debugPrint(message.toString());
    }
  }

  void error(
    String label,
    Object? message, {
    required Object? error,
    required StackTrace? stackTrace,
  }) {
    if (kIsWeb) {
      debugPrintStack(
        label: '[$label] ${message.toString()}\n${error.toString()}',
        stackTrace: stackTrace,
        maxFrames: 100,
      );
    } else {
      debugPrint(message.toString());
    }
  }
}
