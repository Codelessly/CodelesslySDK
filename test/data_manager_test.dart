import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

class _StreamingRepository extends Fake implements NetworkDataRepository {
  _StreamingRepository(this.stream);

  final Stream<SDKPublishModel?> stream;

  @override
  Stream<SDKPublishModel?> streamPublishModel({
    required String projectID,
    required PublishSource source,
  }) => stream;
}

DataManager dataManager(Stream<SDKPublishModel?> stream) => DataManager(
  'test',
  config: CodelesslyConfig(authToken: 'token'),
  cacheManager: _FakeCache(),
  authManager: _FakeAuthManager(),
  networkDataRepository: _StreamingRepository(stream),
  localDataRepository: _FakeLocalRepository(),
  firebaseFirestore: _FakeFirestore(),
  errorLogger: ErrorLogger.instance,
);

class _FakeCache extends Fake implements CacheManager {}

class _FakeAuthManager extends Fake implements AuthManager {}

class _FakeLocalRepository extends Fake implements LocalDataRepository {}

class _FakeFirestore extends Fake implements FirebaseFirestore {}

void main() {
  test('the first publish model completes listenToPublishModel', () async {
    final model = SDKPublishModel(
      projectId: 'project',
      owner: 'owner',
      teams: const {},
      users: const {},
      roles: const {},
      public: false,
    );
    final manager = dataManager(Stream.value(model));
    expect(await manager.listenToPublishModel('project'), model);
  });

  test(
    'a stream error fails listenToPublishModel instead of hanging',
    () async {
      final manager = dataManager(
        Stream.error(FirebaseException(plugin: 'firestore', code: 'denied')),
      );
      await expectLater(
        manager
            .listenToPublishModel('project')
            .timeout(const Duration(seconds: 5)),
        throwsA(isA<FirebaseException>()),
      );
    },
  );
}
