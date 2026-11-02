import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingNetwork extends Fake implements NetworkDataRepository {
  @override
  Future<SDKPublishModel?> downloadCompletePublishBundle({
    required String slug,
    required PublishSource source,
  }) async => null;
}

class _EmptyLocal extends Fake implements LocalDataRepository {
  @override
  SDKPublishModel? fetchPublishModel({required PublishSource source}) => null;
}

class _FakeCache extends Fake implements CacheManager {}

class _FakeAuthManager extends Fake implements AuthManager {}

class _FakeFirestore extends Fake implements FirebaseFirestore {}

/// A site (a slug) whose published app can't be downloaded, with nothing
/// cached, fails to start instead of loading forever.
void main() {
  test('a slug whose bundle fails to download fails init', () async {
    final manager = DataManager(
      'test',
      config: CodelesslyConfig(authToken: '', slug: 'brass-knight'),
      cacheManager: _FakeCache(),
      authManager: _FakeAuthManager(),
      networkDataRepository: _FailingNetwork(),
      localDataRepository: _EmptyLocal(),
      firebaseFirestore: _FakeFirestore(),
      errorLogger: ErrorLogger.instance,
    );
    await expectLater(
      manager.init(layoutID: null).timeout(const Duration(seconds: 5)),
      throwsA(
        isA<Exception>().having(
          (e) => '$e',
          'message',
          contains('Could not download the published app "brass-knight"'),
        ),
      ),
    );
  });
}
