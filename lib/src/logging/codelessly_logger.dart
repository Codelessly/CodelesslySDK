import 'dart:async';
import 'dart:developer' as dev;

const logger = CodelesslyLogger._();

class CodelesslyLogger {
  const CodelesslyLogger._();

  void log(
    String label,
    Object? message, {
    DateTime? time,
    int? sequenceNumber,
    int level = 0,
    Zone? zone,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      dev.log(
        message.toString(),
        name: label,
        time: time,
        sequenceNumber: sequenceNumber,
        level: level,
        zone: zone,
        error: error,
        stackTrace: stackTrace,
      );

  void error(
    String label,
    Object? message, {
    required Object? error,
    required StackTrace? stackTrace,
    DateTime? time,
    int? sequenceNumber,
    int level = 0,
    Zone? zone,
  }) =>
      dev.log(
        message.toString(),
        name: label,
        error: error,
        stackTrace: stackTrace,
        time: time,
        sequenceNumber: sequenceNumber,
        level: level,
        zone: zone,
      );
}
