import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/cupertino.dart';

import '../../codelessly_sdk.dart';

abstract class CloudStorage extends ChangeNotifier {
  final String identifier;

  CloudStorage(this.identifier)
      : assert(identifier.isNotEmpty, 'identifier cannot be empty');

  Future<bool> addDocument(
    String path, {
    String? documentId,
    bool autoGenerateId = false,
    bool skipCreationIfDocumentExists = true,
    required Map<String, dynamic> value,
  });

  Future<bool> updateDocument(
    String path, {
    required String documentId,
    required Map<String, dynamic> value,
  });

  Future<bool> removeDocument(String path, String documentId);

  Future<Map<String, dynamic>> getDocumentData(String path, String documentId);

  Stream<Map<String, dynamic>> streamDocument(String path, String documentId);

  void streamDocumentToVariable(
    String path,
    String documentId,
    Observable<VariableData> variable,
  );
}

class FirestoreCloudStorage extends CloudStorage {
  late final DocumentReference<Map<String, dynamic>> rootRef =
      firestore.collection('data').doc(identifier);

  final FirebaseFirestore firestore;

  final List<StreamSubscription> _subscriptions = [];

  FirestoreCloudStorage(super.identifier, this.firestore);

  Future<void> init() async {
    print(
        'Initializing FirestoreCloudStorage for $identifier at ${rootRef.path}');
    // Create project doc if missing.
    final snapshot = await rootRef.get();
    if (snapshot.exists) return;
    await rootRef.set({'project': identifier});
  }

  // Gives a collection reference for the given path.
  CollectionReference<Map<String, dynamic>> getCollectionPath(String path) {
    if (path.trim().isNotEmpty) {
      // path is provided.
      final pathParts = path.split(pathSeparatorRegex);
      CollectionReference<Map<String, dynamic>>? ref;
      while (pathParts.isNotEmpty) {
        final part = pathParts.removeAt(0);
        if (ref == null) {
          ref = rootRef.collection(part);
        } else {
          final String id =
              pathParts.isNotEmpty ? pathParts.removeAt(0) : 'default';
          ref = ref.doc(part).collection(id);
        }
      }
      return ref!;
    } else {
      return rootRef.collection('default');
    }
  }

  /// Gives a document reference for the given path. If docId is null, then
  /// 'default' is used as the document id.
  DocumentReference<Map<String, dynamic>> getDocPath(
      String path, String? docId) {
    docId ??= 'default';
    if (docId.trim().isEmpty) docId = 'default';
    return getCollectionPath(path).doc(docId);
  }

  @override
  Future<bool> addDocument(
    String path, {
    String? documentId,
    bool autoGenerateId = false,
    bool skipCreationIfDocumentExists = true,
    required Map<String, dynamic> value,
  }) async {
    if (autoGenerateId) {
      // if autoGenerateId is true, then skipCreationIfDocumentExists and docId is ignored.
      final document = await rootRef.collection(path).add(value);
      print('Document added: ${document.path}');
      return true;
    }
    final DocumentReference docRef = getDocPath(path, documentId);
    final snapshot = await docRef.get();
    if (skipCreationIfDocumentExists && snapshot.exists) {
      // if skipCreationIfDocumentExists is true, check if document exists.
      // if document exists, then return.
      // TODO: should we update doc in this case?
      print('Document already exists: ${docRef.path}');
      return true;
    }

    await docRef.set(value);
    print('Document added: ${docRef.path}/$documentId');
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

    // TODO: Should we do update instead of set?
    await docRef.set(value, SetOptions(merge: true));
    print('Document updated: ${docRef.path}/$documentId');
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
    return snapshot.data() ?? {};
  }

  @override
  Stream<Map<String, dynamic>> streamDocument(String path, String documentId) {
    final docRef = getDocPath(path, documentId);
    return docRef.snapshots().map((snapshot) => snapshot.data() ?? {});
  }

  @override
  void streamDocumentToVariable(
    String path,
    String documentId,
    Observable<VariableData> variable,
  ) {
    final docRef = getDocPath(path, documentId);
    final stream = docRef.snapshots().map((snapshot) => snapshot.data() ?? {});
    final subscription = stream.listen(
      (data) {
        print('Document stream update from cloud storage: $path/$documentId');
        print('Updating variable ${variable.value.name} with success state.');
        variable.set(
          variable.value
              .copyWith(value: CloudStorageVariableUtils.success(data)),
        );
      },
      onError: (error) {
        print('Error loading document from cloud storage: $path/$documentId');
        variable.set(
          variable.value.copyWith(
            value: CloudStorageVariableUtils.error(error.toString()),
          ),
        );
      },
    );
    _subscriptions.add(subscription);
  }

  @override
  void dispose() {
    _subscriptions.forEach((sub) => sub.cancel());
    super.dispose();
  }
}
