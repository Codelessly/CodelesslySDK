import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/cupertino.dart';

import '../../codelessly_sdk.dart';
import '../utils/constants.dart';

const String _label = 'Cloud Database';

const List<String> privateDocumentFields = [
  SDKConstants.id,
  SDKConstants.createdAt,
  SDKConstants.updatedAt,
];

/// Allows access to cloud storage. Implementations of this class should be
/// able to store and retrieve data from the cloud storage in secure manner.
/// This is mainly used to store data on cloud via actions for the SDK.
///
/// This abstraction provides access to the cloud storage that is NoSQL in
/// nature. The storage is organized in a tree like structure.
///
/// Each node in the tree is a document. Each document can have a list of
/// sub-Collections and each sub-Collection can have a list of documents.
///
/// Each document can have a list of key-value pairs. The key is a string and
/// the value is an object. The object can be any primitive type or a list or
/// map of primitive types depending on the implementation.
///
/// [identifier] is used to identify the instance of the cloud storage this
/// SDK session is using. This is used to separate data for different projects
/// and users. The actual identity of this [identifier] depends on the
/// implementation.
abstract class CloudDatabase extends ChangeNotifier {
  /// Used to identify the instance of the cloud storage this SDK session is
  /// using. This is used to separate data for different projects and users.
  /// The actual identity of this depends on the implementation.
  ///
  /// This cannot be an empty string.
  final String identifier;

  final PublishSource publishSource;

  /// Creates a new instance of with the given [identifier].
  /// The [identifier] cannot be empty. The actual identity of this depends on
  /// the implementation.
  ///
  /// It will throw an [AssertionError] if the [identifier] is empty.
  CloudDatabase(this.identifier, this.publishSource)
      : assert(identifier.isNotEmpty, 'identifier cannot be empty');

  /// Adds a document to the cloud storage at the given [path].
  ///
  /// The [path] is a string that represents the path to the document
  /// excluding the document id. The path must always resolve to a collection.
  /// If the [path] is empty, then the document is added to "default"
  /// collection. If the path ends in a document path, then "default" is
  /// suffixed to the path to make it a collection path.
  ///
  /// If the document does not exist, then it is created. If the document
  /// already exists, then we skip the creation of the document and return
  /// true if [skipCreationIfDocumentExists] is true. Otherwise it will be
  /// overwritten with given [value].
  ///
  /// If [autoGenerateId] is true, then the document id is auto generated and
  /// [documentId] is ignored. If [autoGenerateId] is false, then the document
  /// id is [documentId]. If [documentId] is null or empty, then "default" is
  /// used as the document id.
  ///
  /// [value] is the data to be stored in the document.
  Future<bool> addDocument(
    String path, {
    String? documentId,
    bool autoGenerateId = false,
    bool skipCreationIfDocumentExists = true,
    required Map<String, dynamic> value,
  });

  /// Updates a document in the cloud storage at the given [path] with the
  /// given [documentId].
  ///
  /// The [path] is a string that represents the path to the document
  /// excluding the document id. The path must always resolve to a collection.
  /// If the [path] is empty, then the document is added to "default"
  /// collection. If the path ends in a document path, then "default" is
  /// suffixed to the path to make it a collection path.
  ///
  /// [documentId] is the id of the document. If [documentId] is empty, then
  /// "default" is used as the document id.
  ///
  /// If the document does not exist, then it is created. If the document
  /// already exists, then we merge given [value] with existing document.
  Future<bool> updateDocument(
    String path, {
    required String documentId,
    required Map<String, dynamic> value,
  });

  /// Removes a document from the cloud storage at the given [path] with the
  /// given [documentId].
  ///
  /// The [path] is a string that represents the path to the document
  /// excluding the document id. The path must always resolve to a collection.
  /// If the [path] is empty, then the document is added to "default"
  /// collection. If the path ends in a document path, then "default" is
  /// suffixed to the path to make it a collection path.
  ///
  /// Path can be separated by '/' or '.'.
  ///
  /// [documentId] is the id of the document. If [documentId] is empty, then
  /// "default" is used as the document id.
  ///
  /// If the document does not exist, then it will return false. Otherwise
  /// it will return true.
  Future<bool> removeDocument(String path, String documentId);

  /// Retrieves the document data from the cloud storage at the given [path]
  /// with the given [documentId].
  ///
  /// The [path] is a string that represents the path to the document
  /// excluding the document id. The path must always resolve to a collection.
  /// If the [path] is empty, then the document is added to "default"
  /// collection. If the path ends in a document path, then "default" is
  /// suffixed to the path to make it a collection path.
  ///
  /// Path can be separated by '/' or '.'.
  ///
  /// [documentId] is the id of the document. If [documentId] is empty, then
  /// "default" is used as the document id.
  Future<Map<String, dynamic>> getDocumentData(String path, String documentId);

  /// Streams document data from the cloud storage at the given [path]
  /// with the given [documentId].
  ///
  /// The [path] is a string that represents the path to the document
  /// excluding the document id. The path must always resolve to a collection.
  /// If the [path] is empty, then the document is added to "default"
  /// collection. If the path ends in a document path, then "default" is
  /// suffixed to the path to make it a collection path.
  ///
  /// Path can be separated by '/' or '.'.
  ///
  /// [documentId] is the id of the document. If [documentId] is empty, then
  /// "default" is used as the document id.
  Stream<Map<String, dynamic>> streamDocument(String path, String documentId);

  /// Streams document data from the cloud storage at the given [path]
  /// with the given [documentId] and updates the given [variable] with the
  /// data when there is an update.
  ///
  /// The [path] is a string that represents the path to the document
  /// excluding the document id. The path must always resolve to a collection.
  /// If the [path] is empty, then the document is added to "default"
  /// collection. If the path ends in a document path, then "default" is
  /// suffixed to the path to make it a collection path.
  ///
  /// Path can be separated by '/' or '.'.
  ///
  /// [documentId] is the id of the document. If [documentId] is empty, then
  /// "default" is used as the document id.
  void streamDocumentToVariable(
    String path,
    String documentId,
    Observable<VariableData> variable,
  );

  void reset();

  void streamCollectionToVariable(
    String path,
    Observable<VariableData> variable, {
    required List<WhereQueryFilter> whereFilters,
    required List<OrderByQueryFilter> orderByOperations,
    int? limit,
    required ScopedValues scopedValues,
    required NullSubstitutionMode nullSubstitutionMode,
  });
}

/// A implementation that uses Firestore as the backend.
/// This is used to store data via actions for the SDK.
class FirestoreCloudDatabase extends CloudDatabase {
  /// Reference to the root document for this session.
  late final DocumentReference<Map<String, dynamic>> rootRef =
      firestore.collection(_rootCollection).doc(identifier);

  String get _rootCollection => switch (publishSource) {
        PublishSource.publish => 'data',
        PublishSource.preview => 'preview_data',
        PublishSource.template => 'template_data',
      };

  /// Reference to the Firestore instance.
  final FirebaseFirestore firestore;

  /// Subscriptions to the streams that are being listened to.
  final List<StreamSubscription> _subscriptions = [];

  /// Creates a [FirestoreCloudDatabase] with the given [identifier] and
  /// [firestore] instance.
  FirestoreCloudDatabase(super.identifier, this.firestore, super.publishSource);

  void log(String message) => logger.log(_label, message);

  /// Initializes the cloud storage for the given [identifier]. This must be
  /// called and awaited before using the cloud storage.
  Future<void> init() async {
    logger.log(_label, 'Initializing for $identifier at [${rootRef.path}]');

    // Create project doc if missing.
    final snapshot = await rootRef.get();

    // Do nothing if project doc exists.
    if (snapshot.exists) return;

    // Create project doc if it does not exist.
    await rootRef.set({'project': identifier});

    logger.log(_label, 'Done initializing for $identifier');
  }

  /// Gives a collection reference for the given [path].
  ///
  /// The [path] is a string that represents the path to the document
  /// excluding the document id. The path must always resolve to a collection.
  /// If the [path] is empty, then the document is added to "default"
  /// collection. If the path ends in a document path, then "default" is
  /// suffixed to the path to make it a collection path.
  ///
  /// Path can be separated by '/' or '.'.
  CollectionReference<Map<String, dynamic>> getCollectionPath(String path) {
    path = path.trim();

    // Return default collection if path is empty.
    if (path.isEmpty) return rootRef.collection('default');

    // Split path by '/' or '.'.
    final pathParts = path.split(pathSeparatorRegex);

    // Construct collection reference by iterating over path parts.
    CollectionReference<Map<String, dynamic>>? ref;
    while (pathParts.isNotEmpty) {
      // Get the first part of the remaining path.
      final part = pathParts.removeAt(0);
      if (ref == null) {
        // Initialize ref with a collection reference to the first part of the
        // path if ref is null.
        ref = rootRef.collection(part);
      } else {
        // this means the ref represents a collection, so we add a collection
        // with the first part of the path as the id.
        final String id =
            pathParts.isNotEmpty ? pathParts.removeAt(0) : 'default';
        ref = ref.doc(part).collection(id);
      }
    }
    return ref!;
  }

  /// Gives a document reference for the given path.
  ///
  /// The [path] is a string that represents the path to the document
  /// excluding the document id. The path must always resolve to a collection.
  /// If the [path] is empty, then the document is added to "default"
  /// collection. If the path ends in a document path, then "default" is
  /// suffixed to the path to make it a collection path.
  ///
  /// Path can be separated by '/' or '.'.
  ///
  /// [documentId] is the id of the document. If [documentId] is null or empty,
  /// then "default" is used as the document id.
  DocumentReference<Map<String, dynamic>> getDocPath(
      String path, String? documentId) {
    // Use default if null.
    documentId ??= 'default';

    // Use default if empty.
    if (documentId.trim().isEmpty) documentId = 'default';
    return getCollectionPath(path).doc(documentId);
  }

  @override
  Future<bool> addDocument(
    String path, {
    String? documentId,
    bool autoGenerateId = false,
    bool skipCreationIfDocumentExists = true,
    required Map<String, dynamic> value,
  }) async {
    // Auto generate id if desired.
    if (autoGenerateId) {
      // if autoGenerateId is true, then skipCreationIfDocumentExists and docId is ignored.
      final document = await rootRef.collection(path).add(value);
      logger.log(_label, 'Document added: ${document.path}');

      // Sanitize data afterwards because we didn't have the docId before.
      value = sanitizeCloudDataToSend(value, docId: document.id);
      await document.set(value);

      return true;
    }

    // Since we're not auto-generating ids at this point, we can sanitize
    // the data before we do anything, ahead of time.
    value = sanitizeCloudDataToSend(value, docId: documentId);

    // Get doc reference.
    final DocumentReference docRef = getDocPath(path, documentId);

    // Get snapshot to check if document exists.
    final snapshot = await docRef.get();
    if (skipCreationIfDocumentExists && snapshot.exists) {
      // if skipCreationIfDocumentExists is true, check if document exists.
      // if document exists, then return.
      logger.log(_label, 'Document already exists: ${docRef.path}');
      return true;
    }

    // Set document.
    await docRef.set(value);
    logger.log(_label, 'Document added: ${docRef.path}/$documentId');
    return true;
  }

  @override
  Future<bool> updateDocument(
    String path, {
    required String documentId,
    required Map<String, dynamic> value,
  }) async {
    final DocumentReference docRef = getDocPath(path, documentId);
    // final snapshot = await docRef.get();
    // if (!snapshot.exists) {
    //   // Document does not exist, so create it.
    //   await docRef.set(value);
    // }

    // Sanitize data.
    value = sanitizeCloudDataToSend(value, docId: documentId);

    // TODO: Should we do update instead of set?
    await docRef.set(value, SetOptions(merge: true));
    logger.log(_label, 'Document updated: ${docRef.path}');
    return true;
  }

  @override
  Future<bool> removeDocument(String path, String documentId) async {
    final docRef = getDocPath(path, documentId);
    final snapshot = await docRef.get();
    // TODO: Do we have to check for existence?
    if (!snapshot.exists) return false;
    await docRef.delete();
    return true;
  }

  @override
  Future<Map<String, dynamic>> getDocumentData(
      String path, String documentId) async {
    final docRef = getDocPath(path, documentId);
    final snapshot = await docRef.get();
    final data = snapshot.data() ?? {};
    return sanitizeCloudDataForUse(data, docId: snapshot.id);
  }

  @override
  Stream<Map<String, dynamic>> streamDocument(String path, String documentId) {
    final docRef = getDocPath(path, documentId);
    return docRef.snapshots().map((snapshot) =>
        snapshot.data()?.let(
            (value) => sanitizeCloudDataForUse(value, docId: snapshot.id)) ??
        {});
  }

  @override
  void streamDocumentToVariable(
    String path,
    String documentId,
    Observable<VariableData> variable,
  ) {
    // Get doc reference.
    final docRef = getDocPath(path, documentId);

    // Stream document.
    final stream = docRef.snapshots().map((snapshot) => snapshot.data() ?? {});

    // Listen to the stream and update the variable.
    final subscription = stream.listen(
      (data) {
        logger.log(_label,
            'Document stream update from cloud storage: $path/$documentId');
        logger.log(_label,
            'Updating variable ${variable.value.name} with success state.');

        data = sanitizeCloudDataForUse(data, docId: documentId);

        // Set the variable with success state.
        variable.set(
          variable.value
              .copyWith(value: CloudDatabaseVariableUtils.success(data)),
        );
      },
      onError: (error) {
        logger.log(_label,
            'Error loading document from cloud storage: $path/$documentId');
        // Set the variable with error state.
        variable.set(
          variable.value.copyWith(
            value: CloudDatabaseVariableUtils.error(error.toString()),
          ),
        );
      },
    );

    // Add subscription to the list of subscriptions.
    _subscriptions.add(subscription);
  }

  @override
  void reset() {
    // Cancel all subscriptions.
    _subscriptions.forEach((sub) => sub.cancel());
  }

  @override
  void dispose() {
    // Cancel all subscriptions.
    _subscriptions.forEach((sub) => sub.cancel());
    super.dispose();
  }

  @override
  void streamCollectionToVariable(
    String path,
    Observable<VariableData> variable, {
    required List<WhereQueryFilter> whereFilters,
    required List<OrderByQueryFilter> orderByOperations,
    int? limit,
    required ScopedValues scopedValues,
    required NullSubstitutionMode nullSubstitutionMode,
  }) {
    // Get doc reference.
    final collectionRef = getCollectionPath(path);

    final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
    // build query if required
    if (whereFilters.isNotEmpty || orderByOperations.isNotEmpty) {
      final query = constructQueryFromRef(
        collectionRef,
        whereFilters: whereFilters,
        orderByOperations: orderByOperations,
        limit: limit,
        scopedValues: scopedValues,
        nullSubstitutionMode: nullSubstitutionMode,
      );
      stream = query.snapshots();
    } else {
      // Stream document.
      stream = collectionRef.snapshots();
    }

    // Listen to the stream and update the variable.
    final subscription = stream.listen(
      (snapshot) {
        final docs = snapshot.docs
            .map((doc) => sanitizeCloudDataForUse(doc.data(), docId: doc.id))
            .toList();
        logger.log(_label, 'Document stream update from cloud storage: $path');
        logger.log(_label,
            'Updating variable ${variable.value.name} with success state.');
        // Set the variable with success state.
        variable.set(
          variable.value
              .copyWith(value: CloudDatabaseVariableUtils.success(docs)),
        );
      },
      onError: (error) {
        logger.log(_label, 'Error loading document from cloud storage: $path');
        // Set the variable with error state.
        variable.set(
          variable.value.copyWith(
            value: CloudDatabaseVariableUtils.error(error.toString()),
          ),
        );
      },
    );

    // Add subscription to the list of subscriptions.
    _subscriptions.add(subscription);
  }
}

/// Returns a sanitized version of the given [data] to be used in the SDK
/// and variables.
/// Updates the [SDKConstants.createdAt] and [SDKConstants.updatedAt] fields
/// with the current time.
Map<String, dynamic> sanitizeCloudDataForUse(
  Map<String, dynamic> data, {
  required String docId,
}) {
  if (data.isEmpty) return data;
  // breaks reference and allows to modify the data.
  data = {...data};

  // Late because it can potentially be unused;
  late final DateTime now = DateTime.now();

  data[SDKConstants.createdAt] =
      deserializeCosmicValue(data[SDKConstants.createdAt] ?? now);
  data[SDKConstants.updatedAt] =
      deserializeCosmicValue(data[SDKConstants.updatedAt] ?? now);
  data[SDKConstants.id] = docId;

  // Sort private fields to the bottom.
  for (final field in privateDocumentFields) {
    if (data.containsKey(field)) {
      final value = data.remove(field);
      data[field] = value;
    }
  }

  return data;
}

/// Returns a sanitized version of the given [data] to be sent to the cloud
/// storage.
/// Updates the [SDKConstants.createdAt] and [SDKConstants.updatedAt] fields
/// with the current time.
Map<String, dynamic> sanitizeCloudDataToSend(
  Map<String, dynamic> data, {
  required String? docId,
  bool hidePrivateFields = false,
}) {
  if (data.isEmpty) return data;

  // Breaks reference and allows to modify the data.
  data = {...data};

  // Remove private fields.
  if (hidePrivateFields) {
    for (final field in privateDocumentFields) {
      data.remove(field);
    }
  } else {
    // Late because it can potentially be unused;
    late final DateTime now = DateTime.now();

    data[SDKConstants.createdAt] =
        serializedCosmicValue(data[SDKConstants.createdAt] ?? now);
    data[SDKConstants.updatedAt] = serializedCosmicValue(now);

    if (docId != null) {
      data[SDKConstants.id] = docId;
    }

    // Sort private fields to the bottom.
    for (final field in privateDocumentFields) {
      if (data.containsKey(field)) {
        final value = data.remove(field);
        data[field] = value;
      }
    }
  }

  return data;
}

/// Returns a sanitized date string from the given [value].
/// Converts different representation of date to a string representation.
String? serializedCosmicValue(Object? value) {
  return switch (value) {
    Timestamp timestamp => timestamp.toDate().toUtc().toIso8601String(),
    DateTime dateTime => dateTime.toUtc().toIso8601String(),
    String string => DateTime.tryParse(string)?.toUtc().toIso8601String(),
    int millisecondsSinceEpoch =>
      DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch)
          .toUtc()
          .toIso8601String(),
    _ => null,
  };
}

DateTime? deserializeCosmicValue(Object? value) {
  return switch (value) {
    Timestamp timestamp => timestamp.toDate().toUtc(),
    DateTime dateTime => dateTime.toUtc(),
    String string => DateTime.tryParse(string)?.toUtc(),
    int millisecondsSinceEpoch =>
      DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch).toUtc(),
    _ => null,
  };
}
