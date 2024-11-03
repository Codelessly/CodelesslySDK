import 'dart:async';
import 'package:logging/logging.dart';

import '../logging/debug_logger.dart';
import 'codelessly_event.dart';

/// Represents a logged error with context
class ErrorLog {
  final DateTime timestamp;
  final String message;
  final String type;
  final String? layoutID;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final List<ErrorLog> relatedErrors;

  const ErrorLog({
    required this.timestamp,
    required this.message,
    required this.type,
    this.layoutID,
    this.originalError,
    this.stackTrace,
    this.relatedErrors = const [],
  });
}

/// Manages error logging and tracking related errors
class ErrorLogger {
  static const String name = 'ErrorLogger';

  static ErrorLogger? _instance;

  /// Returns the singleton instance of ErrorLogger
  static ErrorLogger get instance => _instance ??= ErrorLogger._();

  final List<ErrorLog> _errorLogs = [];

  final StreamController<ErrorLog> _errorStreamController =
      StreamController<ErrorLog>.broadcast();

  Stream<ErrorLog> get errorStream => _errorStreamController.stream;
  List<ErrorLog> get errors => List.unmodifiable(_errorLogs);

  ErrorLogger._();

  /// Factory constructor that initializes the singleton instance
  factory ErrorLogger() {
    _instance ??= ErrorLogger._();
    return _instance!;
  }

  Future<void> captureException(
    dynamic error, {
    String? message,
    String type = '',
    String? layoutID,
    StackTrace? stackTrace,
  }) async {
    final errorLog = ErrorLog(
      timestamp: DateTime.now(),
      message: message ?? error.toString(),
      type: type,
      layoutID: layoutID,
      originalError: error,
      stackTrace: stackTrace,
    );

    _errorLogs.add(errorLog);
    _errorStreamController.add(errorLog);

    DebugLogger.instance.log(
      message ?? error.toString(),
      category: DebugCategory.error,
      name: name,
      level: Level.WARNING,
    );
  }

  Future<void> captureEvent(CodelesslyEvent event) async {
    DebugLogger.instance.printInfo(event.toString(), name: name);
  }

  void dispose() {
    _errorStreamController.close();
    _errorLogs.clear();
    _instance = null;
  }

  void clear() => _errorLogs.clear();
}
