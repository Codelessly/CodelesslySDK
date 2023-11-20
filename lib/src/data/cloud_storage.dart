import 'dart:async';
import 'dart:developer';

import 'package:flutter/cupertino.dart';

import '../../firedart.dart';

abstract class CloudStorage extends ChangeNotifier {
  final Map<String, CloudStorageListenable> _notifiers = {};
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

  Listenable getNotifier(String? key);

  Future<bool> updateDocument(
    String path, {
    required String documentId,
    required Map<String, dynamic> value,
  });

  Future<bool> removeDocument(String path, String documentId);

  Future<Map<String, dynamic>> getDocumentData(String path, String documentId);
}

class FirestoreCloudStorage extends CloudStorage {
  late final DocumentReference rootRef =
      firestore.collection('data').document(identifier);

  final Firestore firestore;

  FirestoreCloudStorage(super.identifier, this.firestore);

  Future<void> init() async {
    print(
        'Initializing FirestoreCloudStorage for $identifier at ${rootRef.path}');
    // Create project doc if missing.
    if (await rootRef.exists) return;
    await rootRef.create({'project': identifier});
  }

  @override
  Listenable getNotifier(String? key) {
    if (key == null) return this;
    if (_notifiers.containsKey(key)) return _notifiers[key]!;

    final notifier = CloudStorageListenable._(key);
    _notifiers[key] = notifier;
    return notifier;
  }

  @override
  void dispose() {
    _notifiers.values.forEach((notifier) => notifier.dispose());
    _notifiers.clear();
    super.dispose();
  }

  // Gives a collection reference for the given path.
  CollectionReference getCollectionPath(String path) {
    if (path.trim().isNotEmpty) {
      // path is provided.
      final pathParts = path.split('.');
      CollectionReference? ref;
      while (pathParts.isNotEmpty) {
        final part = pathParts.removeAt(0);
        if (ref == null) {
          ref = rootRef.collection(part);
        } else {
          final String id =
              pathParts.isNotEmpty ? pathParts.removeAt(0) : 'default';
          ref = ref.document(part).collection(id);
        }
      }
      return ref!;
    } else {
      return rootRef.collection('default');
    }
  }

  /// Gives a document reference for the given path. If docId is null, then
  /// 'default' is used as the document id.
  DocumentReference getDocPath(String path, String? docId) {
    docId ??= 'default';
    if (docId.trim().isEmpty) docId = 'default';
    return getCollectionPath(path).document(docId);
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
    if (skipCreationIfDocumentExists && await docRef.exists) {
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

    if (!await docRef.exists) {
      // Document does not exist, so create it.
      await docRef.set(value);
    }

    await docRef.update(value);
    print('Document updated: ${docRef.path}/$documentId');
    return true;
  }

  @override
  Future<bool> removeDocument(String path, String documentId) async {
    final docRef = getDocPath(path, documentId);
    if (!await docRef.exists) return false;
    await docRef.delete();
    return true;
  }

  @override
  Future<Map<String, dynamic>> getDocumentData(
      String path, String documentId) async {
    final docRef = getDocPath(path, documentId);
    if (!await docRef.exists) return {};
    final doc = await docRef.get();
    return doc.map;
  }
}

class CloudStorageListenable extends ChangeNotifier {
  final String? _key;

  CloudStorageListenable._(this._key);

  void notify() {
    log('notifying storage changed for key: $_key');
    notifyListeners();
  }
}
