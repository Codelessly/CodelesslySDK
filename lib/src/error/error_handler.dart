import 'dart:async';

import 'codelessly_event.dart';
import 'reporter.dart';

/// A typedef that defines the callback for [CodelesslyErrorHandler].
/// It allows supplementary handling of any captured exceptions that the SDK
/// throws.
typedef ExceptionCallback = void Function(CodelesslyException e);

/// An enum to specify the type of error.
enum ErrorType {
  /// The token was rejected for some reason.
  invalidAuthToken('Invalid auth token'),

  /// The app has not been authenticated yet.
  notAuthenticated('Not authenticated'),

  /// The project was not found in the database.
  projectNotFound('Project not found'),

  /// The layout was not found in the database.
  layoutNotFound('Layout not found'),

  /// Failed to store an object in cache.
  cacheStoreException('Failed to store value in cache'),

  /// Failed to retrieve an object from cache.
  cacheLookupException('Failed to lookup value in cache'),

  /// Failed to clear cache.
  cacheClearException('Failed to clear cache'),

  /// Failed to download a font.
  fontDownloadException('Failed to download font'),

  /// Failed to load a font.
  fontLoadException('Failed to load font'),

  /// Failed to manipulate file system.
  fileIoException('Failed to read/write to storage'),

  /// Network error.
  networkException('Network error'),

  /// An assert failed.
  assertionError('Assertion error'),

  /// Not initialized.
  notInitializedError('Not initialized'),

  /// Any other error that is not defined in this enum.
  other('Unknown error');

  final String label;

  const ErrorType(this.label);
}

/// Abstraction for handling any error that the SDK throws.
abstract class BaseErrorHandler {
  /// Allows to catch exceptions in the SDK.
  /// Also allows to specify optional [stacktrace] to stack back the exception.
  Future<void> captureException(Exception throwable, {StackTrace? stacktrace});

  /// Allows to catch an event in the SDK. This could hold so much more data
  /// than [captureException]. This also can be use for logging non-throwing
  /// paths.
  Future<void> captureEvent(CodelesslyEvent event);

  /// Allows to catch and log a message in the SDK. Optionally allows to pass
  /// [stacktrace]. Can be an alternative of [captureException].
  Future<void> captureMessage(String message, {StackTrace? stacktrace});
}

/// Can be used to capture all the exceptions, errors and events
/// inside the SDK.
///
/// This follows singleton pattern for easy accessibility. Must call
/// [CodelesslyErrorHandler.init] before using it.
///
// TODO: Use logging implementation to log these exceptions, errors and events
// before sending to Codelessly.
class CodelesslyErrorHandler extends BaseErrorHandler {
  static CodelesslyErrorHandler? _instance;

  static CodelesslyErrorHandler get instance {
    if (_instance == null) {
      throw Exception(
        'CodelesslyErrorHandler not initialized. '
        'Please call CodelesslyErrorHandler.init() before using it.',
      );
    }
    return _instance!;
  }

  final ErrorReporter? _reporter;
  final ExceptionCallback? onException;

  final StreamController<CodelesslyException> _exceptionStreamController =
      StreamController<CodelesslyException>.broadcast();

  Stream<CodelesslyException> get exceptionStream => _exceptionStreamController.stream;

  CodelesslyErrorHandler({
    required ErrorReporter? reporter,
    this.onException,
  }) : _reporter = reporter;

  /// Initializes a global instance of this with given [reporter].
  static void init({
    required ErrorReporter? reporter,
    ExceptionCallback? onException,
  }) {
    _instance = CodelesslyErrorHandler(
      reporter: reporter,
      onException: onException,
    );
  }

  CodelesslyException? _lastException;

  CodelesslyException? get lastException => _lastException;

  @override
  Future<void> captureEvent(CodelesslyEvent event) async {
    print(event);
    _reporter?.captureEvent(event);
  }

  @override
  Future<void> captureException(
    dynamic throwable, {
    StackTrace? stacktrace,
    String? message,
    String? layoutID,
    bool markForUI = true,
  }) async {
    final bool isAssertionError = throwable is AssertionError;
    final CodelesslyException exception = throwable is CodelesslyException
        ? throwable
        : isAssertionError
            ? CodelesslyException.assertionError(
                message: throwable.message.toString(),
                layoutID: layoutID,
                originalException: throwable,
                stacktrace: stacktrace ?? StackTrace.current,
              )
            : CodelesslyException(
                message ?? throwable.toString(),
                layoutID: layoutID,
                originalException: throwable,
                stacktrace: stacktrace ?? StackTrace.current,
              );

    if (markForUI) {
      _lastException = exception;
      onException?.call(exception);
    }
    print(exception);
    print(exception.stacktrace ?? StackTrace.current);
    _reporter?.captureException(
      exception,
      stacktrace: exception.stacktrace ?? StackTrace.current,
    );
    _exceptionStreamController.add(exception);
  }

  @override
  Future<void> captureMessage(
    String message, {
    StackTrace? stacktrace,
  }) async {
    print(message);
    print(stacktrace);
    _reporter?.captureMessage(message, stacktrace: stacktrace);
  }
}

/// A generic exception intended to be used inside the SDK to throw exceptions
/// to user facing interfaces.
class CodelesslyException implements Exception {
  final String? message;
  final String? layoutID;
  final StackTrace? stacktrace;
  final dynamic originalException;

  /// This could be a link to our documentation for a possible cause and fix.
  final String? url;
  final ErrorType type;

  const CodelesslyException(
    this.message, {
    this.url,
    this.layoutID,
    this.originalException,
    this.stacktrace,
    this.type = ErrorType.other,
  });

  CodelesslyException.invalidAuthToken({
    String? message,
    String? layoutID,
    String? url,
    dynamic originalException,
    StackTrace? stacktrace,
  }) : this(
          message,
          type: ErrorType.invalidAuthToken,
          layoutID: layoutID,
          url: url,
          originalException: originalException,
          stacktrace: stacktrace,
        );

  CodelesslyException.notAuthenticated({
    String? message,
    String? layoutID,
    String? url,
    dynamic originalException,
    StackTrace? stacktrace,
  }) : this(
          message,
          type: ErrorType.notAuthenticated,
          layoutID: layoutID,
          url: url,
          originalException: originalException,
          stacktrace: stacktrace,
        );

  CodelesslyException.projectNotFound({
    String? message,
    String? layoutID,
    String? url,
    dynamic originalException,
    StackTrace? stacktrace,
  }) : this(
          message,
          type: ErrorType.projectNotFound,
          layoutID: layoutID,
          url: url,
          originalException: originalException,
          stacktrace: stacktrace,
        );

  CodelesslyException.layoutNotFound({
    String? message,
    String? layoutID,
    String? url,
    dynamic originalException,
    StackTrace? stacktrace,
  }) : this(
          message,
          type: ErrorType.layoutNotFound,
          layoutID: layoutID,
          url: url,
          originalException: originalException,
          stacktrace: stacktrace,
        );

  CodelesslyException.cacheStoreException({
    String? message,
    String? layoutID,
    String? url,
    dynamic originalException,
    StackTrace? stacktrace,
  }) : this(
          message,
          type: ErrorType.cacheStoreException,
          layoutID: layoutID,
          url: url,
          originalException: originalException,
          stacktrace: stacktrace,
        );

  CodelesslyException.cacheLookupException({
    String? message,
    String? layoutID,
    String? url,
    dynamic originalException,
    StackTrace? stacktrace,
  }) : this(
          message,
          type: ErrorType.cacheLookupException,
          layoutID: layoutID,
          url: url,
          originalException: originalException,
          stacktrace: stacktrace,
        );

  CodelesslyException.cacheClearException({
    String? message,
    String? layoutID,
    String? url,
    dynamic originalException,
    StackTrace? stacktrace,
  }) : this(
          message,
          type: ErrorType.cacheClearException,
          layoutID: layoutID,
          url: url,
          originalException: originalException,
          stacktrace: stacktrace,
        );

  CodelesslyException.fontDownloadException({
    String? message,
    String? layoutID,
    String? url,
    dynamic originalException,
    StackTrace? stacktrace,
  }) : this(
          message,
          type: ErrorType.fontDownloadException,
          layoutID: layoutID,
          url: url,
          originalException: originalException,
          stacktrace: stacktrace,
        );

  CodelesslyException.fontLoadException({
    String? message,
    String? layoutID,
    String? url,
    dynamic originalException,
    StackTrace? stacktrace,
  }) : this(
          message,
          type: ErrorType.fontLoadException,
          layoutID: layoutID,
          url: url,
          originalException: originalException,
          stacktrace: stacktrace,
        );

  CodelesslyException.fileIoException({
    String? message,
    String? layoutID,
    String? url,
    dynamic originalException,
    StackTrace? stacktrace,
  }) : this(
          message,
          type: ErrorType.fileIoException,
          layoutID: layoutID,
          url: url,
          originalException: originalException,
          stacktrace: stacktrace,
        );

  CodelesslyException.networkException({
    String? message,
    String? layoutID,
    String? url,
    dynamic originalException,
    StackTrace? stacktrace,
  }) : this(
          message,
          type: ErrorType.networkException,
          layoutID: layoutID,
          url: url,
          originalException: originalException,
          stacktrace: stacktrace,
        );

  CodelesslyException.assertionError({
    String? message,
    String? layoutID,
    String? url,
    dynamic originalException,
    StackTrace? stacktrace,
  }) : this(
          message,
          type: ErrorType.assertionError,
          layoutID: layoutID,
          url: url,
          originalException: originalException,
          stacktrace: stacktrace,
        );

  CodelesslyException.notInitializedError({
    String? message,
    String? layoutID,
    String? url,
    dynamic originalException,
    StackTrace? stacktrace,
  }) : this(
          message,
          type: ErrorType.notInitializedError,
          layoutID: layoutID,
          url: url,
          originalException: originalException,
          stacktrace: stacktrace,
        );

  CodelesslyException.other({
    String? message,
    String? layoutID,
    String? url,
    dynamic originalException,
    StackTrace? stacktrace,
  }) : this(
          message,
          type: ErrorType.other,
          layoutID: layoutID,
          url: url,
          originalException: originalException,
          stacktrace: stacktrace,
        );

  @override
  String toString() {
    return 'CodelesslyException: $message';
  }
}
