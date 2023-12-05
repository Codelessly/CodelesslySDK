import 'dart:developer' as dev;

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
      dev.log(
        message.toString(),
        name: label,
      );
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
      dev.log(
        message.toString(),
        name: label,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
