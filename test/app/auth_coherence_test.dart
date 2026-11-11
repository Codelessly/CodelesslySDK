import 'dart:async';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart' show settle;

/// Auth operations finish immediately but user stream delivery is controlled.
class _DelayedAuth extends MemoryAuthService {
  _DelayedAuth({super.signedIn});
  final events = StreamController<AppUser?>.broadcast();
  @override
  Stream<AppUser?> get userChanges => events.stream;
  void deliver() => events.add(currentUser);
  @override
  void dispose() {
    events.close();
    super.dispose();
  }
}

Node _node(List<Json> actions) => Node.fromJson({
  'type': 'box',
  'actions': [
    {
      'trigger': {'type': 'click'},
      'actions': actions,
    },
  ],
}, id: 'action')!;
PublishBundle _bundle() {
  final layout = PublishLayout.fromJson({
    'schema': 2,
    'id': 'home',
    'roots': ['canvas'],
    'variables': {
      'canvas': [const Variable(name: 'seen', value: '').toJson(), const Variable(name: 'uid', value: '').toJson()],
    },
    'nodes': {
      'canvas': {
        'type': 'canvas',
        'layout': {'width': 390, 'height': 844},
        'slots': {'body': 'body'},
      },
      'body': {
        'type': 'stack',
        'layout': {
          'width': {'fill': 390},
          'height': {'fill': 844},
        },
        'children': ['signup', 'signout'],
      },
      'signup': {
        'type': 'box',
        'layout': {'width': 100, 'height': 50},
        'actions': [
          {
            'trigger': {'type': 'click'},
            'actions': [
              {'type': 'auth', 'operation': 'signUp', 'email': 'nova@example.test', 'password': 'Stargazer42', 'displayName': 'Nova Sky'},
              {
                'type': 'cloudDocuments',
                'operation': 'add',
                'path': 'users',
                'id': r'${auth.uid}',
                'document': r'{"displayName":"${auth.displayName}","email":"${auth.email}","uid":"${auth.uid}"}',
              },
              {'type': 'auth', 'operation': 'updateProfile', 'displayName': 'Nova Sky Updated'},
              {'type': 'setVariable', 'variable': 'seen', 'value': r'${auth.displayName}'},
              {'type': 'setVariable', 'variable': 'uid', 'value': r'${auth.uid}'},
            ],
          },
        ],
      },
      'signout': {
        'type': 'box',
        'layout': {
          'width': 100,
          'height': 50,
          'y': {'start': 60},
        },
        'actions': [
          {
            'trigger': {'type': 'click'},
            'actions': [
              {'type': 'auth', 'operation': 'signOut'},
              {'type': 'setVariable', 'variable': 'seen', 'value': r'${auth.displayName}'},
              {'type': 'setVariable', 'variable': 'uid', 'value': r'${auth.uid}'},
            ],
          },
        ],
      },
    },
  });
  return PublishBundle(
    model: PublishModel(projectId: 'sandbox', entryLayoutId: 'home', layouts: {'home': PublishLayoutInfo.of(layout)}),
    layouts: {'home': layout},
  );
}

void main() {
  testWidgets('published auth chains see signup/profile/signout snapshots before the user stream delivers', (tester) async {
    final auth = _DelayedAuth();
    final cloud = BackendCloudDatabase(backend: MemoryDocumentBackend());
    final errors = <Object>[];
    final app = Codelessly.fromBundle(
      _bundle(),
      config: CodelesslyConfig(
        services: Services(auth: auth, cloud: cloud, analytics: const NoAnalytics()),
      ),
      fonts: const NoFontFetcher(),
    );
    final controller = CodelesslyWidgetController();
    await tester.pumpWidget(
      MaterialApp(
        home: CodelesslyWidget(codelessly: app, controller: controller, onActionError: (e, s, a) => errors.add(e)),
      ),
    );
    await settle(tester);
    await controller.trigger('signup', 'click');
    final uid = auth.currentUser!.uid;
    final profile = await cloud.getDocument('users', uid);
    expect(profile!['displayName'], 'Nova Sky');
    expect(profile['email'], 'nova@example.test');
    expect(profile['uid'], uid);
    expect(profile['id'], uid);
    expect(controller.read('seen'), 'Nova Sky Updated');
    expect(controller.read('uid'), uid);
    expect(controller.read('auth.displayName'), 'Nova Sky Updated');
    await controller.trigger('signout', 'click');
    expect(controller.read('seen'), '');
    expect(controller.read('uid'), '');
    expect(controller.read('auth.isSignedIn'), false);
    expect(errors, isEmpty);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    app.dispose();
    auth.dispose();
    cloud.dispose();
  });
  testWidgets('native profile updates preserve omitted fields and expressions explicitly clear them', (tester) async {
    final auth = _DelayedAuth(
      signedIn: const AppUser(uid: 'sandbox', displayName: 'Original', photoUrl: 'https://sandbox.example/original.png'),
    );
    final app = Codelessly.fromBundle(
      _bundle(),
      config: CodelesslyConfig(
        services: Services(auth: auth, analytics: const NoAnalytics()),
      ),
      fonts: const NoFontFetcher(),
    );
    final controller = CodelesslyWidgetController();
    final errors = <Object>[];
    await tester.pumpWidget(
      MaterialApp(
        home: CodelesslyWidget(codelessly: app, controller: controller, onActionError: (e, s, a) => errors.add(e)),
      ),
    );
    await settle(tester);
    Future<void> update(Json fields) => const CodelesslyActions().trigger(
      _node([
        {'type': 'auth', 'operation': 'updateProfile', ...fields},
      ]),
      'click',
      controller.actionContext!,
    );
    await update({'displayName': 'Changed name'});
    expect(auth.currentUser!.displayName, 'Changed name');
    expect(auth.currentUser!.photoUrl, 'https://sandbox.example/original.png');
    expect(controller.read('auth.photoUrl'), 'https://sandbox.example/original.png');
    await update({'photoUrl': 'https://sandbox.example/changed.png'});
    expect(auth.currentUser!.displayName, 'Changed name');
    expect(controller.read('auth.displayName'), 'Changed name');
    expect(controller.read('auth.photoUrl'), 'https://sandbox.example/changed.png');
    await update({'displayName': r'${seen}'});
    expect(controller.read('auth.displayName'), '');
    expect(controller.read('auth.photoUrl'), 'https://sandbox.example/changed.png');
    await update({'displayName': 'Restored name'});
    await update({'photoUrl': r'${seen}'});
    expect(controller.read('auth.displayName'), 'Restored name');
    expect(controller.read('auth.photoUrl'), '');
    await update({'photoUrl': 'https://sandbox.example/final.png'});
    await const CodelesslyActions().trigger(
      _node([
        {'type': 'auth', 'operation': 'updatePhoto', 'photoUrl': ''},
      ]),
      'click',
      controller.actionContext!,
    );
    expect(controller.read('auth.displayName'), 'Restored name');
    expect(controller.read('auth.photoUrl'), '');
    expect(errors, isEmpty);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    app.dispose();
    auth.dispose();
  });
  test('stream failures stay fail-closed until an explicit successful sign-in recovers', () async {
    final auth = _DelayedAuth(
      signedIn: const AppUser(uid: 'old', email: 'old@example.test', displayName: 'Old'),
    );
    final app = Codelessly(
      config: CodelesslyConfig(
        services: Services(auth: auth, analytics: const NoAnalytics()),
      ),
    );
    final scope = app.appVariables;
    final context = RuntimeActionContext(scope: scope, services: app.services, refreshAuthValues: app.refreshAuthValues);
    expect(scope.read('auth.displayName'), 'Old');
    auth.events.addError(StateError('sandbox auth stream unavailable'));
    await pumpEventQueue();
    expect(auth.currentUser!.uid, 'old');
    expect(scope.read('auth.isSignedIn'), false);
    await const CodelesslyActions().trigger(
      _node([
        {'type': 'auth', 'operation': 'sendPasswordResetEmail', 'email': 'old@example.test'},
        {'type': 'auth', 'operation': 'updateProfile', 'displayName': 'Still stale'},
      ]),
      'click',
      context.withScope(ValuesScope({}, scope)),
    );
    expect(scope.read('auth.isSignedIn'), false, reason: 'non-sign-in operations cannot revive a stale service identity');
    await const CodelesslyActions().trigger(
      _node([
        {'type': 'auth', 'operation': 'signUp', 'email': 'new@example.test', 'password': 'Stargazer42', 'displayName': 'New'},
      ]),
      'click',
      context.withScope(ValuesScope({}, scope)),
    );
    expect(scope.read('auth.isSignedIn'), true);
    expect(scope.read('auth.email'), 'new@example.test');
    expect(scope.read('auth.displayName'), 'New');
    context.dispose();
    app.dispose();
    auth.dispose();
  });
  test('a refreshed new identity cannot inherit old profile data or queued snapshots', () async {
    final auth = _DelayedAuth();
    final cloud = BackendCloudDatabase(backend: MemoryDocumentBackend());
    final app = Codelessly(
      config: CodelesslyConfig(
        services: Services(auth: auth, cloud: cloud, analytics: const NoAnalytics()),
      ),
    );
    final scope = app.appVariables;
    await auth.signUp(email: 'first@example.test', password: 'Stargazer42', displayName: 'First');
    app.refreshAuthValues(AuthOperation.signUp);
    final first = auth.currentUser!;
    await cloud.addDocument('users', {'plan': 'annual'}, id: first.uid);
    auth.deliver();
    await pumpEventQueue();
    expect(scope.read('auth.profile.plan'), 'annual');
    await auth.updateProfile(displayName: 'First Updated');
    app.refreshAuthValues(AuthOperation.updateProfile);
    expect(scope.read('auth.displayName'), 'First Updated');
    expect(scope.read('auth.profile.plan'), 'annual', reason: 'a matching profile survives metadata refresh');
    await auth.signUp(email: 'second@example.test', password: 'Stargazer42', displayName: 'Second');
    app.refreshAuthValues(AuthOperation.signUp);
    final second = auth.currentUser!;
    expect(scope.read('auth.uid'), second.uid);
    expect(scope.read('auth.profile.plan'), isNull);
    auth.events.add(first);
    await pumpEventQueue();
    expect(scope.read('auth.uid'), second.uid, reason: 'queued events cannot overwrite a newer completed operation');
    expect(scope.read('auth.profile.plan'), isNull);
    auth.deliver();
    await pumpEventQueue();
    expect(scope.read('auth.uid'), second.uid);
    expect(scope.read('auth.displayName'), 'Second');
    app.dispose();
    auth.dispose();
    cloud.dispose();
  });
}
