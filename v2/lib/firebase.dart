/// Codelessly on Firebase. The rest of the SDK never imports Firebase.
///
/// **A project token is all an app needs** ([codelesslyWithToken]): it opens
/// Codelessly's Firebase project as a secondary app
/// ([codelesslyFirebaseApp], [CodelesslyFirebaseOptions]), authenticates
/// the token and reads the publish from Cloud Firestore, with live updates.
///
/// ```dart
/// import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
/// import 'package:codelessly_sdk_v2/firebase.dart';
///
/// final codelessly = await codelesslyWithToken('<project token>');
/// runApp(MaterialApp(home: CodelesslyWidget(codelessly: codelessly)));
/// ```
///
/// The pieces, for apps that assemble them themselves (another Firebase
/// project, their own auth): the published app ([FirestorePublishLoader];
/// [codelesslyOnFirebase] sets a [Codelessly] up on it), the project's
/// access ([FirebaseProjectAuth]), app user accounts
/// ([FirebaseAuthService]), cloud data ([FirestoreDocumentBackend]), cloud
/// files ([FirebaseFileStorage]) and the paywall server
/// ([FirebasePaywallBackend]). [codelesslyCloudServices] builds the
/// services of a project:
///
/// ```dart
/// final app = await codelesslyFirebaseApp();
/// final services = codelesslyCloudServices(
///   projectId: projectId,
///   firestore: FirebaseFirestore.instanceFor(app: app),
///   auth: FirebaseAuth.instanceFor(app: app),
///   storage: FirebaseStorage.instanceFor(app: app),
/// );
/// ```
library;

// The Firebase types the functions here take, so an app that only uses
// Codelessly's Firebase needs no Firebase package of its own.
export 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
export 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
export 'package:firebase_core/firebase_core.dart' show Firebase, FirebaseApp, FirebaseOptions;
export 'package:firebase_storage/firebase_storage.dart' show FirebaseStorage;

export 'src/services/firebase/auth.dart';
export 'src/services/firebase/codelessly_app.dart';
export 'src/services/firebase/codelessly_firebase.dart';
export 'src/services/firebase/firestore.dart';
export 'src/services/firebase/paywall.dart';
export 'src/services/firebase/project_auth.dart';
export 'src/services/firebase/publish_loader.dart';
export 'src/services/firebase/storage.dart';
