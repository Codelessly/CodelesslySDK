// The first real managed component, "Sign in" 1.0.0, as the editor releases
// it (test/fixtures/managed/sign_in_1.0.0.json: CodelesslyEditor's
// lib/editor/managed_prebuilts.dart `signInPrebuilt().request()`), built
// and run here: its auth signIn, its error text and the instance's events.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';

/// The release as the publishManagedComponent function stores it.
ManagedComponentVersion signIn({int version = 1, String? semver, Map<String, Object?> Function(Map<String, Object?>)? edit}) {
  var release = (jsonDecode(File('test/fixtures/managed/sign_in_1.0.0.json').readAsStringSync()) as Map).cast<String, Object?>();
  if (edit != null) release = edit(release);
  final payload = jsonEncode({'definition': {...(release['definition'] as Map), 'id': release['id']}, 'contract': release['contract']});
  return ManagedComponentVersion.fromJson({
    'id': release['id'],
    'version': version,
    'semver': semver ?? release['semver'],
    'payload': payload,
    'digest': sha256.convert(utf8.encode(payload)).toString(),
  })!;
}

/// The instance an app user placed: a title, and chains after onSuccess and
/// onError.
final ref = const ManagedComponentRef()
    .withValue('title', 'Welcome back')
    .withEvent('onSuccess', [ActionDef.fromJson({'type': 'setVariable', 'variable': 'signedIn', 'value': 'yes'})!])
    .withEvent('onError', [ActionDef.fromJson({'type': 'setVariable', 'variable': 'errorSeen', 'value': r'${signInError}'})!]);

class Harness {
  Harness(ManagedComponentVersion version, {required this.auth}) {
    build = buildManagedInstance(version: version, topId: 'si', ref: ref);
    scope = VariableScope([
      ...build.variables,
      const Variable(name: 'signedIn', value: ''),
      const Variable(name: 'errorSeen', value: ''),
    ]);
    context = RuntimeActionContext(scope: scope, services: Services(auth: auth), onError: (e, s, a) => errors.add(e));
  }

  final MemoryAuthService auth;
  late final ManagedBuild build;
  late final VariableScope scope;
  late final RuntimeActionContext context;
  final List<Object> errors = [];

  Node node(String id) => build.nodes.firstWhere((n) => n.id == 'si__$id');
  Object? operator [](String name) => scope.read(name);
  void set(String name, Object? value) => scope.set(name, value);
  Future<void> fire(String id, String trigger) => const CodelesslyActions().run(node(id), trigger, context);
  Object? evaluate(String expression) => const Expressions().evaluate(expression, scope);
}

void main() {
  test('the release decodes with its contract', () {
    final v = signIn();
    expect(v.semver, '1.0.0');
    expect(v.contract.flatSettings.map((s) => s.effectiveKey), ['title', 'buttonLabel', 'showSignUpLink', 'signUpLabel']);
    expect(v.contract.events.map((e) => e.key), ['onSuccess', 'onError', 'onSignUp']);
    expect(v.contract.variables.map((x) => x.name), ['signInEmail', 'signInPassword', 'signInError']);
  });

  test('signing in runs the auth signIn, then the instance\'s onSuccess', () async {
    final auth = MemoryAuthService();
    await auth.signUp(email: 'ada@example.org', password: 'secret12');
    await auth.signOut();
    final h = Harness(signIn(), auth: auth);
    expect(h.node('title').prop(TextProps.text), 'Welcome back');
    h.set('signInEmail', 'ada@example.org');
    h.set('signInPassword', 'secret12');
    await h.fire('submit', 'click');
    expect(h.errors, isEmpty);
    expect(auth.currentUser?.email, 'ada@example.org');
    expect(h['signedIn'], 'yes');
    expect(h['signInError'], '');
    expect(h.evaluate(h.node('error').bind['visible']!), isFalse);
  });

  test('a failure shows its message and runs onError, not onSuccess', () async {
    final auth = MemoryAuthService();
    await auth.signUp(email: 'ada@example.org', password: 'secret12');
    await auth.signOut();
    final h = Harness(signIn(), auth: auth);
    h.set('signInEmail', 'ada@example.org');
    h.set('signInPassword', 'wrong');
    await h.fire('submit', 'click');
    expect(h['signedIn'], '');
    final message = h['signInError'];
    expect(message, isA<String>());
    expect(message, isNotEmpty);
    expect(h.evaluate(h.node('error').bind['props.text']!), message);
    expect(h.evaluate(h.node('error').bind['visible']!), isTrue);
    // The error text's valueChanged reaction (fired by the screen when
    // signInError changes) runs the instance's onError chain.
    await h.fire('error', 'valueChanged');
    expect(h['errorSeen'], message);
  });

  test('a newer 1.x release keeps the instance\'s title and events', () async {
    final v11 = signIn(
      version: 2,
      semver: '1.1.0',
      edit: (r) {
        final json = jsonDecode(jsonEncode(r)) as Map<String, Object?>;
        final nodes = ((json['definition'] as Map)['document'] as Map)['nodes'] as Map;
        ((nodes['submit'] as Map)['props'] as Map)['label'] = 'Continue';
        ((nodes['title'] as Map)['props'] as Map)['text'] = 'Hello again';
        return json;
      },
    );
    final first = buildManagedInstance(version: signIn(), topId: 'si', ref: ref);
    final layout = PublishLayout(
      document: LayoutDocument(id: 'login', roots: const ['c'], nodes: {
        'c': const Node(id: 'c', type: 'canvas', children: ['si']),
        for (final n in first.nodes) n.id: n,
      }),
    ).withManagedSnapshots();
    final master = ManagedComponentMaster.fromJson({
      'versions': {
        '1': {'semver': '1.0.0'},
        '2': {'semver': '1.1.0'},
      },
      'channels': {
        'stable': {'1': 2},
      },
    }, id: 'sign_in')!;
    final resolved = await ManagedComponentResolver(
      source: MemoryManagedComponentSource(masters: {'sign_in': master}, versions: [signIn(), v11]),
    ).resolve(layout);
    final doc = resolved.document;
    expect(doc['si']!.component!.version, 2);
    expect(doc['si__submit']!.prop(ButtonProps.label), 'Continue');
    expect(doc['si__title']!.prop(TextProps.text), 'Welcome back');
    expect(doc['si__submit']!.actions.single.actions.map((a) => a.type), ['auth', 'setVariable']);
    expect((resolved.variables['c'] as Map).length, 3);
  });
}
