import 'dart:async';

import 'codelessly_event.dart';
import 'codelessly_logger.dart';
import 'reporter.dart';

const String _label = 'Error Reporter';

/// A typedef that defines the callback for [CodelesslyErrorHandler].
/// It allows supplementary handling of any captured exceptions that the SDK
/// throws.
typedef ExceptionCallback = void Function(
  CodelesslyException exception,
  StackTrace stackTrace,
);

/// An enum to specify the type of error.
enum ErrorType {
  invalidAuthToken(
    'invalid-token',
    'Invalid auth token',
  ),
  noTokenForProject(
    'no-token-for-project',
    'No token found for the associated project',
  ),
  noProjectForSlug(
    'no-project-for-slug',
    'No project found for the provided slug',
  ),
  notAuthenticated(
    'not-authenticated',
    'The app has not been authenticated',
  ),
  layoutFailed(
    'layout-failed',
    'Layout failed',
  ),
  cacheInitException(
    'cache-init-exception',
    'Failed to initialize cache',
  ),
  cacheStoreException(
    'cache-store-exception',
    'Failed to store value in cache',
  ),
  cacheLookupException(
    'cache-lookup-exception',
    'Failed to look up a value in cache',
  ),
  cacheClearException(
    'cache-clear-exception',
    'Failed to clear cache',
  ),
  fontDownloadException(
    'font-download-exception',
    'Failed to download font',
  ),
  fontLoadException(
    'font-load-exception',
    'Failed to load font',
  ),
  fileIoException(
    'file-io-exception',
    'Failed to read/write to storage',
  ),
  networkException(
    'network-exception',
    'Connection failed',
  ),
  assertionError(
    'assertion-error',
    'Assertion error',
  ),
  notInitializedError(
    'not-initialized-error',
    'The Codelessly SDK has not been initialized',
  ),
  apiNotFound(
    'api-not-found',
    'The API endpoint was not found',
  ),
  other(
    'other',
    'Unknown error',
  );

  final String code;
  final String title;

  const ErrorType(this.code, this.title);

  static ErrorType fromCode(String? code) => code == null
      ? ErrorType.other
      : ErrorType.values.firstWhere(
          (ErrorType e) => e.code == code,
          orElse: () => ErrorType.other,
        );
}

/// Abstraction for handling any error that the SDK throws.
abstract class BaseErrorHandler {
  /// Allows to catch exceptions in the SDK.
  /// Also allows to specify optional [stacktrace] to stack back the exception.
  Future<void> captureException(
    dynamic throwable, {
    required StackTrace trace,
  });

  /// Allows to catch an event in the SDK. This could hold so much more data
  /// than [captureException]. This also can be use for logging non-throwing
  /// paths.
  Future<void> captureEvent(CodelesslyEvent event);
}

/// Can be used to capture all the exceptions, errors and events
/// inside the SDK.
///
/// This follows singleton pattern for easy accessibility. Must call
/// [CodelesslyErrorHandler.init] before using it.
///
class CodelesslyErrorHandler extends BaseErrorHandler {
  /// The reporter that will be used to report errors.
  final ErrorReporter? _reporter;

  /// The callback that will be called when an exception is thrown.
  final ExceptionCallback? onException;

  /// A stream controller that will be used to broadcast exceptions.
  final StreamController<(CodelesslyException, StackTrace)>
      exceptionController =
      StreamController<(CodelesslyException, StackTrace)>.broadcast();

  /// A stream that will be used to broadcast exceptions.
  Stream<(CodelesslyException, StackTrace)> get exceptionStream =>
      exceptionController.stream;

  CodelesslyException? lastException;
  StackTrace? lastTrace;

  /// Initializes an instance of this with given [reporter].
  CodelesslyErrorHandler({
    required ErrorReporter? reporter,
    this.onException,
  }) : _reporter = reporter;

  @override
  Future<void> captureEvent(CodelesslyEvent event) async {
    logger.log(_label, event.toString(), largePrint: true);
    _reporter?.captureEvent(event);
  }

  @override
  Future<void> captureException(
    dynamic throwable, {
    required StackTrace trace,
  }) async {
    final bool isAssertionError = throwable is AssertionError;
    final CodelesslyException exception = throwable is CodelesslyException
        ? throwable
        : isAssertionError
            ? CodelesslyException(
                ErrorType.assertionError,
                message: throwable.message.toString(),
                originalException: throwable,
              )
            : CodelesslyException(
                ErrorType.other,
                message: throwable.toString(),
                originalException: throwable,
              );

    onException?.call(exception, trace);
    exceptionController.add((exception, trace));
    lastException = exception;
    lastTrace = trace;

    logger.error(
      _label,
      exception.message,
      error: exception,
      stackTrace: trace,
    );

    _reporter?.captureException(
      exception,
      stacktrace: trace,
    );
  }
}

/// A generic exception intended to be used inside the SDK to throw exceptions
/// to user facing interfaces.
class CodelesslyException implements Exception {
  final ErrorType type;
  final String message;
  final Object? originalException;
  final Object? identifier;
  final bool blockAllLayouts;

  const CodelesslyException(this.type, {
    required this.message,
    this.identifier,
    this.originalException,
    this.blockAllLayouts = false,
  });

  const CodelesslyException.layout(
    this.type, {
    required String layoutID,
    required this.message,
    this.originalException,
    this.blockAllLayouts = false,
  }) : identifier = layoutID;

  const CodelesslyException.api(
    this.type, {
    required String apiID,
    required this.message,
    this.originalException,
    this.blockAllLayouts = false,
  }) : identifier = apiID;

  const CodelesslyException.wrap(
    this.type,
    this.originalException, {
    required this.message,
    this.identifier,
    this.blockAllLayouts = false,
  });

  CodelesslyException.fromCode(
    String? code, {
    required this.message,
    this.identifier,
    this.originalException,
    this.blockAllLayouts = false,
  }) : type = ErrorType.fromCode(code);

  @override
  String toString() => '${type.title}\n$message';
}
