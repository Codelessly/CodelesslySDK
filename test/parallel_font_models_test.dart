import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCache extends Fake implements CacheManager {}

class _FakeAuthManager extends Fake implements AuthManager {
  @override
  AuthData? get authData => AuthData(
    authToken: 'token',
    projectId: 'project',
    timestamp: DateTime(2026),
    owner: 'owner',
    teams: const {},
    users: const {},
    roles: const {},
  );
}

class _FakeLocalRepository extends Fake implements LocalDataRepository {}

class _FakeFirestore extends Fake implements FirebaseFirestore {}

/// Font model downloads that finish only when the test completes them.
class _SlowNetwork extends Fake implements NetworkDataRepository {
  final Map<String, Completer<SDKPublishFont?>> pending = {};

  @override
  Future<SDKPublishFont?> downloadFontModel({
    required String projectID,
    required String fontID,
    required PublishSource source,
  }) => (pending[fontID] = Completer<SDKPublishFont?>()).future;
}

SDKPublishFont _font(String id) => SDKPublishFont(
  id: id,
  url: 'https://example.com/$id.ttf',
  family: 'Fraunces',
  weight: '300',
  owner: 'owner',
  teams: const {},
  users: const {},
  roles: const {},
  public: false,
);

void main() {
  test(
    'a layout\'s font models download together, and a failure is skipped',
    () async {
      final network = _SlowNetwork();
      final model = SDKPublishModel(
        projectId: 'project',
        owner: 'owner',
        teams: const {},
        users: const {},
        roles: const {},
        public: false,
      );
      model.fonts['cached'] = _font('cached');
      final manager = DataManager(
        'test',
        config: CodelesslyConfig(authToken: 'token'),
        cacheManager: _FakeCache(),
        authManager: _FakeAuthManager(),
        networkDataRepository: network,
        localDataRepository: _FakeLocalRepository(),
        firebaseFirestore: _FakeFirestore(),
        errorLogger: ErrorLogger.instance,
        publishModel: model,
      );

      final Future<Set<SDKPublishFont>> fonts = manager.getOrFetchFontModels(
        fontIDs: {'cached', 'a', 'b', 'c'},
      );
      await Future<void>.delayed(Duration.zero);

      // All three downloads started before any of them finished.
      expect(network.pending.keys.toSet(), {'a', 'b', 'c'});

      network.pending['c']!.complete(_font('c'));
      network.pending['a']!.complete(_font('a'));
      network.pending['b']!.completeError(Exception('offline'));

      expect((await fonts).map((SDKPublishFont font) => font.id).toSet(), {
        'cached',
        'a',
        'c',
      });
    },
  );
}
