// A Codelessly instance on Codelessly's Firebase.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../app/codelessly.dart';
import '../../app/config.dart';
import '../../app/fonts.dart';
import '../../app/loader.dart';
import '../auth.dart';
import 'managed_components.dart';
import 'project_auth.dart';
import 'publish_loader.dart';

/// A [Codelessly] reading its publish from Firestore ([firestore]: the
/// Firebase app the project publishes to):
///
/// * With [CodelesslyConfig.authToken], the app authenticates with its
///   project ([FirebaseProjectAuth] on [auth], unless [projectAuth] is
///   given): the backend names the token's project and grants the claim the
///   publish paths' security rules check. Then [FirestorePublishLoader]
///   reads `publish/{projectId}` (`publish_preview/...` with
///   [PublishSource.preview], `templates/...` for a template project) and
///   its layouts, and follows the model for live updates.
/// * With a [CodelesslyConfig.projectId] and no token: the same paths, read
///   without authenticating (for projects whose rules allow it).
/// * With only a [CodelesslyConfig.slug]: the slug's bundle from storage,
///   as without Firebase.
///
/// Linked, Codelessly-managed components follow their channel
/// ([FirestoreManagedComponentSource] on [firestore]).
///
/// [cache] keeps the last publish between runs (default: memory).
Codelessly codelesslyOnFirebase({
  required FirebaseFirestore firestore,
  FirebaseAuth? auth,
  CodelesslyConfig config = const CodelesslyConfig(),
  ProjectAuth? projectAuth,
  PublishCache? cache,
  FontFetcher? fonts,
  Map<String, Object?> data = const {},
}) {
  final token = config.authToken;
  final access = projectAuth ??
      (token == null || token.isEmpty
          ? null
          : FirebaseProjectAuth(
              config: ProjectAuthConfig(authToken: token, slug: config.slug),
              auth: auth ?? FirebaseAuth.instanceFor(app: firestore.app),
            ));
  final PublishLoader? loader = access != null || config.projectId != null
      ? FirestorePublishLoader(firestore, projectId: config.projectId, auth: access)
      : null;
  return Codelessly(
    config: config,
    loader: loader,
    cache: cache,
    fonts: fonts,
    data: data,
    managedComponents: FirestoreManagedComponentSource(firestore),
  );
}
