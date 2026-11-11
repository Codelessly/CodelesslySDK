import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';

/// Version [n] ([semver]) of a small managed sign in: a title, a header slot
/// and a button whose click signs in and then runs the `onSuccess` event.
ManagedComponentVersion version(int n, String semver, {String title = 'Sign in', String minSdk = '', bool badDigest = false}) {
  final payload = jsonEncode({
    'definition': {
      'name': 'Sign in',
      'document': {
        'roots': ['root'],
        'nodes': {
          'root': {
            'type': 'column',
            'children': ['header', 'title', 'button', if (n >= 2) 'footer'],
            'layout': {'width': 320},
          },
          'header': {
            'type': 'column',
            'children': ['logo'],
          },
          'logo': {
            'type': 'text',
            'props': {'text': 'Logo'},
          },
          'title': {
            'type': 'text',
            'props': {'text': title},
          },
          'button': {
            'type': 'text',
            'props': {'text': 'Go'},
            'actions': [
              {
                'trigger': {'type': 'click'},
                'actions': [
                  {'type': 'auth', 'operation': 'signIn', 'errorVariable': 'signInError'},
                  {'type': kComponentEventAction, 'event': 'onSuccess'},
                ],
              },
            ],
          },
          if (n >= 2)
            'footer': {
              'type': 'text',
              'props': {'text': 'v$n'},
            },
        },
      },
    },
    'contract': {
      'settings': [
        {
          'key': 'title',
          'label': 'Title',
          'type': 'string',
          'value': title,
          'targets': [
            {'node': 'title', 'path': 'props.text'},
          ],
        },
      ],
      'slots': [
        {'key': 'header', 'node': 'header'},
      ],
      'events': [
        {'key': 'onSuccess'},
      ],
      'variables': [
        {'name': 'signInError', 'type': 'text', 'value': ''},
      ],
    },
  });
  return ManagedComponentVersion.fromJson({
    'id': 'sign_in',
    'version': n,
    'semver': semver,
    'minSdk': minSdk,
    'payload': payload,
    'digest': badDigest ? 'f' * 64 : sha256.convert(utf8.encode(payload)).toString(),
  })!;
}

final versions = [
  version(1, '1.0.0'),
  version(2, '1.1.0', title: 'Sign in v2'),
  version(3, '2.0.0', title: 'Sign in v3'),
];

ManagedComponentMaster master({int stable1 = 2, List<int> blocked = const [], Map<String, Object?> extraVersions = const {}}) =>
    ManagedComponentMaster.fromJson({
      'versions': {
        '1': {'semver': '1.0.0'},
        '2': {'semver': '1.1.0'},
        '3': {'semver': '2.0.0'},
        ...extraVersions,
      },
      'channels': {
        'stable': {'1': stable1, '2': 3},
      },
      'blocked': blocked,
    }, id: 'sign_in')!;

/// A layout whose canvas holds an instance (`inst`) of version 1, built as
/// the editor's publish builds it: a title setting, a slot with the page's
/// own node, an onSuccess chain.
PublishLayout publishedLayout() {
  final ref = const ManagedComponentRef()
      .withValue('title', 'Welcome back')
      .withSlot('header', ['brand'])
      .withEvent('onSuccess', [ActionDef.fromJson({'type': 'setVariable', 'variable': 'done', 'value': 'yes'})!]);
  final build = buildManagedInstance(version: versions[0], topId: 'inst', ref: ref);
  return PublishLayout(
    document: LayoutDocument(id: 'home', roots: const [
      'c',
    ], nodes: {
      'c': const Node(id: 'c', type: 'canvas', children: ['inst']),
      for (final n in build.nodes) n.id: n,
      'brand': const Node(id: 'brand', type: 'text', props: Props.empty),
    }),
    variables: const {
      'c': {
        'managed_signInError': {'id': 'managed_signInError', 'name': 'signInError', 'type': 'text'},
      },
    },
  ).withManagedSnapshots();
}

String textOf(PublishLayout layout, String id) {
  final n = layout.document[id]!;
  return '${n.props.toJson(n.spec)['text']}';
}

void main() {
  test('the SDK version constant is the pubspec version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(RegExp(r'^version: (\S+)$', multiLine: true).firstMatch(pubspec)![1], kCodelesslySdkVersion);
  });

  test('a newer minor on the channel applies, with the instance\'s settings, slots and events', () async {
    final source = MemoryManagedComponentSource(masters: {'sign_in': master()}, versions: versions);
    final r = ManagedComponentResolver(source: source);
    final layout = await r.resolve(publishedLayout(), projectId: 'p');
    final top = layout.document['inst']!;
    expect(top.component!.version, 2);
    expect(top.component!.managed!.semver, '1.1.0');
    // v2's new node is there; the instance's title survives the update.
    expect(textOf(layout, 'inst__footer'), 'v2');
    expect(textOf(layout, 'inst__title'), 'Welcome back');
    // The slot keeps the page's node; the default logo stays out.
    expect(layout.document['inst__header']!.children, ['brand']);
    expect(layout.document['brand'], isNotNull);
    expect(layout.document['inst__logo'], isNull);
    // The event chain is spliced into v2's click.
    final chain = layout.document['inst__button']!.actions.single.actions;
    expect(chain.map((a) => a.type), ['auth', 'setVariable']);
    // Still a child of the canvas, one variable declared.
    expect(layout.document.parentOf('inst'), 'c');
    expect((layout.variables['c'] as Map).length, 1);
    expect(source.calls, ['master:sign_in', 'version:sign_in/2']);
  });

  test('a new major does not apply', () async {
    final source = MemoryManagedComponentSource(masters: {'sign_in': master(stable1: 1)}, versions: versions);
    final layout = await ManagedComponentResolver(source: source).resolve(publishedLayout());
    expect(layout.document['inst']!.component!.version, 1);
    expect(source.calls, ['master:sign_in']);
    expect(master(stable1: 1).newerMajor(1), 3);
  });

  test('a blocked version is skipped', () async {
    final source = MemoryManagedComponentSource(
      masters: {
        'sign_in': master(stable1: 4, blocked: [4], extraVersions: {
          '4': {'semver': '1.2.0'},
        }),
      },
      versions: [...versions, version(4, '1.2.0')],
    );
    final layout = await ManagedComponentResolver(source: source).resolve(publishedLayout());
    expect(layout.document['inst']!.component!.version, 2);
    expect(source.calls, isNot(contains('version:sign_in/4')));
  });

  test('a blocked snapshot rolls back to the channel\'s version', () async {
    final at2 = await ManagedComponentResolver(
      source: MemoryManagedComponentSource(masters: {'sign_in': master()}, versions: versions),
    ).resolve(publishedLayout());
    final back = await ManagedComponentResolver(
      source: MemoryManagedComponentSource(masters: {'sign_in': master(stable1: 1, blocked: [2])}, versions: versions),
    ).resolve(at2);
    expect(back.document['inst']!.component!.version, 1);
    expect(back.document['inst__footer'], isNull);
    expect(textOf(back, 'inst__title'), 'Welcome back');
  });

  test('an SDK below minSdk keeps the version it can run', () async {
    final source = MemoryManagedComponentSource(
      masters: {
        'sign_in': master(stable1: 4, extraVersions: {
          '4': {'semver': '1.2.0', 'minSdk': '99.0.0'},
        }),
      },
      versions: [...versions, version(4, '1.2.0', minSdk: '99.0.0')],
    );
    final layout = await ManagedComponentResolver(source: source).resolve(publishedLayout());
    expect(layout.document['inst']!.component!.version, 2);
  });

  test('a pinned instance stays', () async {
    final pinned = publishedLayout();
    final top = pinned.document['inst']!;
    final layout = pinned.copyWith(
      document: pinned.document.copyWith(nodes: {
        ...pinned.document.nodes,
        'inst': top.withComponent(top.component!.copyWith(managed: top.component!.managed!.copyWith(pin: () => 1))),
      }),
    );
    final resolved = await ManagedComponentResolver(
      source: MemoryManagedComponentSource(masters: {'sign_in': master()}, versions: versions),
    ).resolve(layout);
    expect(resolved.document['inst']!.component!.version, 1);
  });

  group('failures fall back to the snapshot', () {
    Future<(PublishLayout, List<Object>)> run(MemoryManagedComponentSource source, {PublishCache? cache}) async {
      final errors = <Object>[];
      final layout = await ManagedComponentResolver(
        source: source,
        cache: cache,
        timeout: const Duration(milliseconds: 50),
        onError: (_, e) => errors.add(e),
      ).resolve(publishedLayout());
      return (layout, errors);
    }

    test('the source fails', () async {
      final (layout, errors) = await run(MemoryManagedComponentSource()..failWith = StateError('offline'));
      expect(layout.document['inst']!.component!.version, 1);
      expect(textOf(layout, 'inst__title'), 'Welcome back');
      expect(errors.single, isA<StateError>());
    });

    test('the source times out', () async {
      final (layout, errors) = await run(
        MemoryManagedComponentSource(masters: {'sign_in': master()}, versions: versions)
          ..delay = const Duration(milliseconds: 200),
      );
      expect(layout.document['inst']!.component!.version, 1);
      expect(errors.single, isA<TimeoutException>());
    });

    test('the version is missing or does not match its digest', () async {
      final (missing, _) = await run(MemoryManagedComponentSource(masters: {'sign_in': master()}));
      expect(missing.document['inst']!.component!.version, 1);
      final (tampered, errors) = await run(MemoryManagedComponentSource(
        masters: {'sign_in': master()},
        versions: [version(2, '1.1.0', badDigest: true)],
      ));
      expect(tampered.document['inst']!.component!.version, 1);
      expect(errors.single, isA<ManagedDigestException>());
    });

    test('offline, the cached master and version still apply', () async {
      final cache = MemoryPublishCache();
      final online = MemoryManagedComponentSource(masters: {'sign_in': master()}, versions: versions);
      await run(online, cache: cache);
      expect(cache.entries.keys, containsAll(['managed_components/sign_in', 'managed_components/sign_in/versions/2']));
      final (layout, errors) = await run(MemoryManagedComponentSource()..failWith = StateError('offline'), cache: cache);
      expect(layout.document['inst']!.component!.version, 2);
      expect(errors, isEmpty);
    });
  });

  test('masters are fetched once per TTL; versions once', () async {
    var now = DateTime.utc(2026);
    final source = MemoryManagedComponentSource(masters: {'sign_in': master()}, versions: versions);
    final r = ManagedComponentResolver(source: source, clock: () => now);
    await r.resolve(publishedLayout());
    await r.resolve(publishedLayout());
    expect(source.calls, ['master:sign_in', 'version:sign_in/2']);
    now = now.add(const Duration(minutes: 6));
    await r.resolve(publishedLayout());
    expect(source.calls, ['master:sign_in', 'version:sign_in/2', 'master:sign_in']);
  });

  test('a Codelessly with a source loads layouts resolved; the cache keeps the snapshot', () async {
    final layout = publishedLayout();
    final bundle = PublishBundle(
      model: PublishModel(
        projectId: 'p',
        entryLayoutId: 'home',
        layouts: {'home': const PublishLayoutInfo(id: 'home', canvases: [PublishCanvas(id: 'c')])},
      ),
      layouts: {'home': layout},
    );
    final cache = MemoryPublishCache();
    final source = MemoryManagedComponentSource(masters: {'sign_in': master()}, versions: versions);
    final c = Codelessly(
      config: const CodelesslyConfig(projectId: 'p'),
      loader: MemoryPublishLoader(bundle),
      cache: cache,
      fonts: const NoFontFetcher(),
      managedComponents: source,
    );
    final loaded = await c.loadLayout('home');
    expect(loaded.document['inst']!.component!.version, 2);
    expect(PublishLayout.fromJson(cache.entries['publish/p/layouts/home']).document['inst']!.component!.version, 1);

    // A rollback: refreshing asks again, and the layout loads on the rolled back version.
    source.masters['sign_in'] = master(stable1: 1, blocked: [2]);
    c.refreshManagedComponents();
    expect((await c.loadLayout('home')).document['inst']!.component!.version, 1);

    // Without a source: the snapshot.
    final plain = Codelessly(config: const CodelesslyConfig(projectId: 'p'), loader: MemoryPublishLoader(bundle), fonts: const NoFontFetcher());
    expect((await plain.loadLayout('home')).document['inst']!.component!.version, 1);
    c.dispose();
    plain.dispose();
  });
}
