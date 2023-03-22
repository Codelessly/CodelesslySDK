import '../../firedart.dart';
import 'codelessly_event.dart';
import 'error_handler.dart';

/// Abstraction for reporting exceptions and event to remote server.
abstract class ErrorReporter {
  Future<void> captureException(Exception throwable, {StackTrace? stacktrace});

  Future<void> captureEvent(CodelesslyEvent event);

  Future<void> captureMessage(String message, {StackTrace? stacktrace});
}

// TODO: Maybe use an isolate to make this calls to avoid
// trafficking network IO.
/// Responsible for uploading events and exceptions to firestore database.
class FirestoreErrorReporter extends ErrorReporter {
  final Firestore _firestore;

  static const _collection = 'sdk_errors';

  FirestoreErrorReporter(this._firestore);

  @override
  Future<void> captureEvent(CodelesslyEvent event) async {
    await event.populateDeviceMetadata();
    await _firestore
        .collection(_collection)
        .add(event.toJson())
        .whenComplete(() {
      print('Event captured');
    });
  }

  @override
  Future<void> captureException(
    Exception throwable, {
    StackTrace? stacktrace,
  }) async {
    final CodelesslyEvent event = CodelesslyEvent(
      message: throwable is CodelesslyException
          ? throwable.message
          : throwable.toString(),
      stacktrace: throwable is CodelesslyException
          ? throwable.stacktrace?.toString() ?? stacktrace?.toString()
          : stacktrace?.toString(),
      tags: ['exception'],
    );
    print('Stacktrace:\n${event.stacktrace}');
    await event.populateDeviceMetadata();
    await _firestore.collection(_collection).add(event.toJson()).then((doc) {
      print('Exception captured. ID: [${doc.id}]');
      print(
          'Exception URL: https://console.firebase.google.com/u/1/project/codeless-dev/firestore/data/~2Fsdk_errors~2F${doc.id}');
    });
  }

  @override
  Future<void> captureMessage(
    String message, {
    StackTrace? stacktrace,
  }) async {
    final event = CodelesslyEvent(
      message: message,
      stacktrace: stacktrace?.toString(),
      tags: ['message'],
    );

    await event.populateDeviceMetadata();
    await _firestore
        .collection(_collection)
        .add(event.toJson())
        .whenComplete(() {
      print('Message captured');
    });
  }
}
