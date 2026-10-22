import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';
import 'action_chain.dart';

/// Signs app users in and out for [AuthAction]s, and describes the signed-in
/// user to the `auth` variable.
abstract final class AppAuth {
  static const String name = 'AppAuth';

  /// The collection of the app users' profiles: `users/{uid}`.
  static const String profilesCollection = 'users';

  /// The local storage key of the email a sign-in link was sent to.
  static const String linkEmailKey = 'codelessly_sign_in_link_email';

  /// The fields a new profile starts with for [user], before the defaults
  /// of the `users` collection's schema: who they are and the `user` role.
  static Map<String, dynamic> newProfile(User user) => {
    'uid': user.uid,
    'email': user.email ?? '',
    'displayName': user.displayName ?? '',
    'photoUrl': user.photoURL ?? '',
    'role': 'user',
  };

  /// Creates the signed-in user's profile document, `users/{uid}`, when it
  /// doesn't exist yet, with the fields of [newProfile] and the defaults of
  /// the `users` schema. `${auth.profile}` and `${auth.role}` read it.
  static Future<void> ensureProfile(Codelessly codelessly) async {
    final User? user = codelessly.firebaseAuth.currentUser;
    final CloudDatabase? database = codelessly.cloudDatabase;
    if (user == null || user.isAnonymous) return;
    if (database is! FirestoreCloudDatabase) return;
    final ref = database.getCollectionPath(profilesCollection).doc(user.uid);
    final snapshot = await ref.get();
    if (snapshot.exists) return;
    // The schema's defaults; fields only the builder can fill stay empty.
    final CollectionSchema? schema = database.rules.schemaFor(
      profilesCollection,
    );
    final Map<String, dynamic> data = {
      if (schema != null)
        ...CloudFieldValues.buildWrite(
          fields: const [],
          schema: schema.copyWith(
            fields: [
              for (final SchemaField field in schema.fields)
                field.copyWith(required: false),
            ],
          ),
          evaluate: (value) => value,
          create: true,
        ),
      ...newProfile(user),
      'createdAt': Timestamp.now(),
    };
    await ref.set(
      database.rules.prepareWrite(profilesCollection, data, user.uid),
    );
  }

  /// Signs in with [provider]: a popup on the web, the platform's flow
  /// elsewhere.
  static Future<UserCredential> _signInWithProvider(
    FirebaseAuth auth,
    AuthProvider provider,
  ) => kIsWeb
      ? auth.signInWithPopup(provider)
      : auth.signInWithProvider(provider);

  /// The `auth` variable's value for [user]. Anonymous users, which the SDK
  /// signs in on its own to read published data, count as signed out.
  static Map<String, dynamic> userToMap(User? user) {
    final bool signedIn = user != null && !user.isAnonymous;
    final String displayName = signedIn ? user.displayName ?? '' : '';
    final String email = signedIn ? user.email ?? '' : '';
    final String initialSource = displayName.isNotEmpty ? displayName : email;
    return {
      'isSignedIn': signedIn,
      'uid': signedIn ? user.uid : '',
      'email': email,
      'displayName': displayName,
      'initial': initialSource.isEmpty
          ? ''
          : initialSource.characters.first.toUpperCase(),
      'photoUrl': signedIn ? user.photoURL ?? '' : '',
      'emailVerified': signedIn && user.emailVerified,
      'providers': signedIn
          ? [for (final info in user.providerData) info.providerId]
          : <String>[],
    };
  }

  /// The `auth` variable's `profile` and `role` for a [profile] document.
  /// A signed-in user without a role is a `user`; signed out, the role is
  /// empty.
  static Map<String, dynamic> profileFields(
    Map<String, dynamic>? profile, {
    bool signedIn = false,
  }) => {
    'profile': profile ?? <String, dynamic>{},
    'role': '${profile?['role'] ?? (signedIn ? 'user' : '')}',
  };

  /// A readable message for a Firebase Auth [error].
  static String messageFor(Object error) {
    if (error is StateError) return error.message;
    if (error is! FirebaseAuthException) return error.toString();
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' ||
      'INVALID_LOGIN_CREDENTIALS' => 'Wrong email or password.',
      'email-already-in-use' => 'An account already exists for that email.',
      'weak-password' => 'Password must be at least 6 characters.',
      'invalid-email' => 'That email address is not valid.',
      'missing-password' => 'Enter your password.',
      'user-disabled' => 'This account has been disabled.',
      'too-many-requests' => 'Too many attempts. Try again later.',
      'network-request-failed' => 'Network error. Check your connection.',
      'requires-recent-login' => 'Sign in again, then try this again.',
      _ => error.message ?? error.code,
    };
  }

  /// The signed-in user, or an error saying the operation needs one.
  static User _signedInUser(FirebaseAuth auth) {
    final User? user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Sign in first.');
    }
    return user;
  }

  /// Performs [action]. Throws when it fails, so the actions after it in the
  /// chain don't run, after writing the message to its error variable.
  static Future<bool> perform(BuildContext context, AuthAction action) async {
    final ScopedValues scopedValues = ActionChain.scopedValuesOf(context);
    final Codelessly codelessly = context.read<Codelessly>();
    final CodelesslyContext codelesslyContext = context
        .read<CodelesslyContext>();

    String eval(String value) => PropertyValueDelegate.substituteVariables(
      value,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
      scopedValues: scopedValues,
    ).trim();

    void setError(String message) {
      final VariableData? variable = action.errorVariable;
      if (variable == null) return;
      final notifier = codelesslyContext.findVariableByName(variable.name);
      notifier?.set(notifier.value.copyWith(value: message));
    }

    final FirebaseAuth auth = codelessly.firebaseAuth;
    final String email = eval(action.email);
    final String displayName = eval(action.displayName);
    DebugLogger.instance.printInfo(
      'Auth action ${action.operation.name} for [$email]',
      name: name,
    );

    try {
      switch (action.operation) {
        case AuthOperation.signIn:
          await auth.signInWithEmailAndPassword(
            email: email,
            password: eval(action.password),
          );
        case AuthOperation.signUp:
          final UserCredential credential = await auth
              .createUserWithEmailAndPassword(
                email: email,
                password: eval(action.password),
              );
          if (displayName.isNotEmpty) {
            await credential.user?.updateDisplayName(displayName);
          }
        case AuthOperation.signOut:
          await auth.signOut();
          // The SDK needs a user to read the project's data.
          await auth.signInAnonymously();
        case AuthOperation.updateProfile:
          await auth.currentUser?.updateDisplayName(displayName);
        case AuthOperation.sendPasswordResetEmail:
          await auth.sendPasswordResetEmail(email: email);
        case AuthOperation.sendEmailVerification:
          await _signedInUser(auth).sendEmailVerification();
        case AuthOperation.updatePassword:
          await _signedInUser(auth).updatePassword(eval(action.password));
        case AuthOperation.deleteAccount:
          await _signedInUser(auth).delete();
          // The SDK needs a user to read the project's data.
          await auth.signInAnonymously();
        case AuthOperation.signInWithGoogle:
          await _signInWithProvider(auth, GoogleAuthProvider());
        case AuthOperation.signInWithApple:
          await _signInWithProvider(
            auth,
            AppleAuthProvider()
              ..addScope('email')
              ..addScope('name'),
          );
        case AuthOperation.sendSignInLink:
          if (email.isEmpty) throw StateError('Enter your email.');
          await auth.sendSignInLinkToEmail(
            email: email,
            actionCodeSettings: ActionCodeSettings(
              // Back to the page the app runs on, which finishes signing in.
              url: kIsWeb ? Uri.base.toString() : 'https://codelessly.com',
              handleCodeInApp: true,
            ),
          );
          await codelessly.localDatabase.put(linkEmailKey, email);
        case AuthOperation.completeSignInLink:
          final String link = Uri.base.toString();
          if (!auth.isSignInWithEmailLink(link)) return true;
          final String linkEmail = email.isNotEmpty
              ? email
              : '${codelessly.localDatabase.get(linkEmailKey) ?? ''}';
          if (linkEmail.isEmpty) {
            throw StateError('Enter the email the link was sent to.');
          }
          await auth.signInWithEmailLink(email: linkEmail, emailLink: link);
          await codelessly.localDatabase.remove(linkEmailKey);
        case AuthOperation.updatePhoto:
          await _signedInUser(auth).updatePhotoURL(eval(action.photoUrl));
      }

      if (action.operation
          case != AuthOperation.sendPasswordResetEmail &&
              != AuthOperation.sendEmailVerification) {
        await auth.currentUser?.reload();
        codelessly.refreshAppUser();
      }

      // A different user needs the project's claim before it can read or
      // write the project's data.
      if (action.operation.signsIn ||
          action.operation == AuthOperation.signOut ||
          action.operation == AuthOperation.deleteAccount) {
        await codelessly.authManager.reauthenticate();
      }
      if (action.operation.signsIn) await ensureProfile(codelessly);
    } catch (error) {
      final String message = messageFor(error);
      DebugLogger.instance.printInfo(
        'Auth action ${action.operation.name} failed: $message',
        name: name,
      );
      setError(message);
      rethrow;
    }

    setError('');
    ActionChain.setResult(userToMap(auth.currentUser));
    return true;
  }
}
