import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'codelessly_event.dart';
import 'codelessly_logger.dart';
import 'error_handler.dart';

const String _label = 'Firestore Error Reporter';

/// Abstraction for reporting exceptions and event to remote server.
abstract class ErrorReporter {
  /// Handles a single exception with an optional stacktrace.
  /// If [stacktrace] is not provided, the current stacktrace will be used.
  Future<void> captureException(Exception throwable, {StackTrace? stacktrace});

  /// Handles a single event.
  Future<void> captureEvent(CodelesslyEvent event);

  /// Handles a single message with an optional stacktrace.
  Future<void> captureMessage(String message, {StackTrace? stacktrace});
}

/// Responsible for uploading events and exceptions to firestore database.
class FirestoreErrorReporter extends ErrorReporter {
  /// The firestore instance to use for uploading events and exceptions.
  final FirebaseFirestore _firestore;
  final FirebaseApp _firebaseApp;

  /// The collection to use for uploading events and exceptions.
  static const _collection = 'sdk_errors';

  /// Creates a new [FirestoreErrorReporter] with the given firestore instance.
  FirestoreErrorReporter(this._firebaseApp, this._firestore);

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
      tags: ['error'],
    );
    print('Stacktrace:\n${event.stacktrace}');
    await event.populateDeviceMetadata();
    await _firestore.collection(_collection).add(event.toJson()).then((doc) {
      logger.log(_label, 'Exception captured. ID: [${doc.id}]');
      logger.log(_label,
          'Exception URL: https://console.firebase.google.com/u/1/project/${_firebaseApp.options.projectId}/firestore/data/~2Fsdk_errors~2F${doc.id}');
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
      logger.log(_label, 'Message captured');
    });
  }
}
