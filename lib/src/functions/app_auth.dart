import 'package:codelessly_api/codelessly_api.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';
import 'action_chain.dart';

/// Signs app users in and out for [AuthAction]s, and describes the signed-in
/// user to the `auth` variable.
abstract final class AppAuth {
  static const String name = 'AppAuth';

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
    };
  }

  /// A readable message for a Firebase Auth [error].
  static String messageFor(Object error) {
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
      }

      if (action.operation != AuthOperation.sendPasswordResetEmail) {
        await auth.currentUser?.reload();
        codelessly.refreshAppUser();
      }

      // A different user needs the project's claim before it can read or
      // write the project's data.
      if (action.operation
          case AuthOperation.signIn ||
              AuthOperation.signUp ||
              AuthOperation.signOut) {
        await codelessly.authManager.reauthenticate();
      }
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
