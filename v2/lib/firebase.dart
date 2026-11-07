/// Codelessly services on Firebase: app user accounts (Firebase Auth), the
/// project's access, cloud data (Cloud Firestore), cloud files (Firebase
/// Storage) and the paywall server (Cloud Functions). The rest of the SDK
/// never imports Firebase.
///
/// ```dart
/// final firestore = FirebaseFirestore.instance;
/// final auth = FirebaseAuth.instance;
/// final services = Services(
///   auth: FirebaseAuthService(auth),
///   cloud: BackendCloudDatabase(
///     backend: FirestoreDocumentBackend(firestore),
///     root: firestoreRoot(projectId),
///     rulesSource: firestoreDataRules(firestore, projectId),
///     userId: () => auth.currentUser?.uid,
///   ),
///   files: FirebaseFileStorage(FirebaseStorage.instance, root: firestoreRoot(projectId)),
/// );
/// ```
library;

export 'src/services/firebase/auth.dart';
export 'src/services/firebase/firestore.dart';
export 'src/services/firebase/paywall.dart';
export 'src/services/firebase/project_auth.dart';
export 'src/services/firebase/storage.dart';
