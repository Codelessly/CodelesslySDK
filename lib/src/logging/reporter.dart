import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'codelessly_event.dart';
import 'debug_logger.dart';
import 'error_logger.dart';

/// Abstraction for reporting exceptions and event to remote server.
abstract class ErrorReporter {
  /// Handles a single exception with an optional stacktrace.
  /// If [stacktrace] is not provided, the current stacktrace will be used.
  Future<void> captureException(dynamic throwable, {StackTrace? stacktrace});

  /// Handles a single event.
  Future<void> captureEvent(CodelesslyEvent event);

  /// Handles a single message with an optional stacktrace.
  Future<void> captureMessage(String message, {StackTrace? stacktrace});
}

/// Responsible for uploading events and exceptions to firestore database.
class FirestoreErrorReporter extends ErrorReporter {
  static const String name = 'FirestoreErrorReporter';

  /// The firestore instance to use for uploading events and exceptions.
  final FirebaseFirestore _firestore;
  final FirebaseApp _firebaseApp;

  /// The collection to use for uploading events and exceptions.
  static const _collection = 'sdk_errors';

  /// Creates a new [FirestoreErrorReporter] with the given firestore instance.
  FirestoreErrorReporter(this._firebaseApp, this._firestore);

  @override
  Future<void> captureEvent(CodelesslyEvent event) async {
    DebugLogger.instance.printFunction('captureEvent()', name: name);
    await event.populateDeviceMetadata();
    await _firestore
        .collection(_collection)
        .add(event.toJson())
        .whenComplete(() {
      DebugLogger.instance.printInfo('Event captured', name: name);
    });
  }

  @override
  Future<void> captureException(
    dynamic throwable, {
    StackTrace? stacktrace,
  }) async {
    DebugLogger.instance.printFunction('captureException()', name: name);
    final CodelesslyEvent event = CodelesslyEvent(
      message: throwable.toString(),
      stacktrace: stacktrace?.toString(),
      tags: ['error'],
    );
    DebugLogger.instance
        .printInfo('Stacktrace:\n${event.stacktrace}', name: name);
    await event.populateDeviceMetadata();
    await _firestore.collection(_collection).add(event.toJson()).then((doc) {
      DebugLogger.instance.printInfo(
        'Exception captured. ID: [${doc.id}]',
        name: name,
      );
      DebugLogger.instance.printInfo(
        'Exception URL: https://console.firebase.google.com/u/1/project/${_firebaseApp.options.projectId}/firestore/data/~2Fsdk_errors~2F${doc.id}',
        name: name,
      );
    });
  }

  @override
  Future<void> captureMessage(
    String message, {
    StackTrace? stacktrace,
  }) async {
    DebugLogger.instance.printFunction('captureMessage()', name: name);
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
      DebugLogger.instance.printInfo('Message captured', name: name);
    });
  }
}
