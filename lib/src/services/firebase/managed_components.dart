// Linked, Codelessly-managed components on Cloud Firestore: masters at
// `managed_components/{id}`, immutable versions at `.../versions/{n}`. Both
// are public reads (signed out too); only Codelessly's release functions
// write them.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';

import '../../app/managed_components.dart';

/// A [ManagedComponentSource] reading [firestore] (Codelessly's Firebase
/// app, where the editor publishes).
class FirestoreManagedComponentSource implements ManagedComponentSource {
  const FirestoreManagedComponentSource(this.firestore);

  final FirebaseFirestore firestore;

  @override
  Future<ManagedComponentMaster?> loadMaster(String id) async {
    final doc = await firestore.collection(kManagedComponentsCollection).doc(id).get();
    final data = doc.data();
    return data == null ? null : ManagedComponentMaster.fromJson(data, id: id);
  }

  @override
  Future<ManagedComponentVersion?> loadVersion(String id, int version) async {
    final doc = await firestore.collection(kManagedComponentsCollection).doc(id).collection('versions').doc('$version').get();
    final data = doc.data();
    return data == null ? null : ManagedComponentVersion.fromJson(data, id: id, version: version);
  }
}
