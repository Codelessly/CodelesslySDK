// The auth feature: the `auth` action (sign in, sign up, profile, password,
// providers, links) and the `auth` value expressions read (the user and
// their profile document, live). The core runtime doesn't import this:
// `authFeature` registers it through the plugin seam
// (runtime/actions/feature.dart).
import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart';

import '../../runtime/actions/context.dart' show setVariableIn;
import '../../runtime/actions/feature.dart';
import '../../runtime/actions/runner.dart';
import '../../runtime/contracts.dart';
import '../../runtime/expressions/scopes.dart';
import '../../services/analytics.dart';
import '../../services/auth.dart';
import '../../services/cloud/database.dart';

/// The `auth` action and the `auth` value.
const CodelesslyFeature authFeature = CodelesslyFeature(
  name: 'auth',
  actions: {AuthAction.typeName: _auth},
  scopes: {'auth': _authScope},
);

/// What the app shell attaches to an action context
/// (`RuntimeActionContext.extensions`) so a completed auth action shows in
/// the `auth` value before the next action of its chain reads it, without
/// waiting for the auth stream.
class AuthValuesRefresh {
  const AuthValuesRefresh(this.refresh);
  final void Function(AuthOperation operation) refresh;
}

Future<void> _auth(ActionDef action, ActionRun run) async {
  final a = action as AuthAction;
  final auth = run.require<AuthService>('Auth');
  final email = run.text(a.email).trim(), password = run.text(a.password);
  if (a.errorVariable.isNotEmpty) setVariableIn(run.context.scope, a.errorVariable, '');
  try {
    switch (a.operation) {
      case AuthOperation.signIn:
        run.result = (await auth.signIn(email: email, password: password)).uid;
      case AuthOperation.signUp:
        run.result = (await auth.signUp(email: email, password: password, displayName: run.text(a.displayName))).uid;
      case AuthOperation.signOut:
        await auth.signOut();
      case AuthOperation.updateProfile:
        // Empty authored fields are omitted, not destructive updates. A
        // supplied expression resolving to empty still explicitly clears it.
        await auth.updateProfile(
          displayName: a.displayName.isEmpty ? null : run.text(a.displayName),
          photoUrl: a.photoUrl.isEmpty ? null : run.text(a.photoUrl),
        );
      case AuthOperation.updatePhoto:
        await auth.updateProfile(photoUrl: run.text(a.photoUrl));
      case AuthOperation.sendPasswordResetEmail:
        await auth.sendPasswordResetEmail(email);
      case AuthOperation.sendEmailVerification:
        await auth.sendEmailVerification();
      case AuthOperation.updatePassword:
        if (a.currentPassword.isNotEmpty) await auth.reauthenticate(run.text(a.currentPassword));
        await auth.updatePassword(password);
      case AuthOperation.deleteAccount:
        if (a.currentPassword.isNotEmpty) await auth.reauthenticate(run.text(a.currentPassword));
        await auth.deleteAccount();
      case AuthOperation.signInWithGoogle:
        run.result = (await auth.signInWithProvider(AuthProviderKind.google)).uid;
      case AuthOperation.signInWithApple:
        run.result = (await auth.signInWithProvider(AuthProviderKind.apple)).uid;
      case AuthOperation.sendSignInLink:
        await auth.sendSignInLink(email, continueUrl: Uri.base.toString());
      case AuthOperation.completeSignInLink:
        run.result = (await auth.signInWithLink(email, Uri.base.toString())).uid;
      case AuthOperation.signInAnonymously:
        run.result = (await auth.signInAsGuest()).uid;
    }
    run.extension<AuthValuesRefresh>()?.refresh(a.operation);
  } catch (error) {
    if (a.errorVariable.isNotEmpty) {
      setVariableIn(run.context.scope, a.errorVariable, error is AuthFailure ? error.message : '$error');
    }
    rethrow;
  }
}

// --- the `auth` value -------------------------------------------------------------------

/// The `auth` value ([authValue]): the user and their profile document,
/// now and on every change of either.
Stream<Map<String, Object?>> watchAuthValue(AuthService auth, CloudDatabase cloud, AnalyticsService analytics) {
  late StreamController<Map<String, Object?>> controller;
  StreamSubscription<AppUser?>? users;
  StreamSubscription<Map<String, Object?>?>? profiles;
  AppUser? user;
  var generation = 0;
  controller = StreamController(
    onListen: () {
      users = auth.userChanges.listen((u) {
        user = u;
        final currentGeneration = ++generation;
        profiles?.cancel();
        controller.add(authValue(u));
        if (!AuthProfiles.hasProfile(u)) return;
        profiles = AuthProfiles.watch(cloud, u).listen(
          (profile) {
            if (currentGeneration == generation) controller.add(authValue(user, profile: profile));
          },
          onError: (Object error, StackTrace stack) =>
              analytics.logError(error, stackTrace: stack, message: 'Could not read the user profile', type: 'profile'),
        );
      }, onError: (Object error, StackTrace stack) {
        generation++;
        user = null;
        profiles?.cancel();
        profiles = null;
        controller.addError(error, stack);
      });
    },
    onCancel: () async {
      generation++;
      await profiles?.cancel();
      await users?.cancel();
    },
  );
  return controller.stream;
}

NamedScope _authScope(FeatureScopeHost host, ValueScope parent) => AuthScope(host, parent: parent);

/// `auth` in expressions: the live account and profile, owned by the app.
/// Tells the scopes that follow the account ([AccountBound]: entitlements)
/// whose it is now.
class AuthScope extends ValuesScope {
  AuthScope(this._host, {ValueScope? parent})
      : _service = _host.services.lookup<AuthService>(),
        super({'auth': authValue(_host.services.lookup<AuthService>()?.currentUser)}, parent) {
    final auth = _service;
    final cloud = _host.services.lookup<CloudDatabase>();
    if (auth == null || cloud == null) return;
    final analytics = _host.services.lookup<AnalyticsService>();
    _host.accountChanged(auth.currentUser?.uid);
    _auth = watchAuthValue(auth, cloud, analytics ?? const NoAnalytics()).listen(
      (value) {
        if (_disposed) return;
        final user = auth.currentUser;
        final uid = AuthProfiles.hasProfile(user) ? user!.uid : '';
        if (value['uid'] != uid) return; // A queued snapshot from an earlier identity.
        _authFailed = false;
        _account(user?.uid);
        set('auth', authValue(user, profile: _matchingProfile(value, user)));
      },
      onError: (Object error, StackTrace stack) {
        if (_disposed) return;
        _authFailed = true;
        _account(null, reset: true);
        set('auth', authValue(null));
        analytics?.logError(error, stackTrace: stack, type: 'auth_scope');
      },
    );
  }

  final FeatureScopeHost _host;
  final AuthService? _service;
  StreamSubscription<Map<String, Object?>>? _auth;
  bool _disposed = false;
  bool _authFailed = false;

  void _account(String? uid, {bool reset = false}) => _host.accountChanged(uid, reset: reset);

  Map<String, Object?>? _matchingProfile(Object? snapshot, AppUser? user) {
    if (!AuthProfiles.hasProfile(user) || snapshot is! Map || snapshot['uid'] != user!.uid) return null;
    final profile = snapshot['profile'];
    return profile is Map ? profile.cast<String, Object?>() : null;
  }

  /// Makes a completed native auth [operation] visible to the next action
  /// in the same chain, without waiting for the auth/profile stream.
  void refreshAuth(AuthOperation operation) {
    if (_disposed) return;
    final service = _service;
    if (service == null) return;
    final recovery = const {
      AuthOperation.signIn, AuthOperation.signUp, AuthOperation.signInWithGoogle,
      AuthOperation.signInWithApple, AuthOperation.completeSignInLink, AuthOperation.signInAnonymously,
    }.contains(operation);
    // A stale currentUser after an auth stream error is not proof of a live
    // session. Only an explicit successful sign-in can recover that identity.
    if (_authFailed && !recovery && operation != AuthOperation.signOut && operation != AuthOperation.deleteAccount) return;
    if (recovery) _authFailed = false;
    final user = service.currentUser;
    final profile = _matchingProfile(this['auth'], user);
    _account(user?.uid);
    set('auth', authValue(user, profile: profile));
  }

  @override
  void dispose() {
    _disposed = true;
    _auth?.cancel();
    super.dispose();
  }
}
