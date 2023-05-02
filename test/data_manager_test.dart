import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/auth/auth_manager.dart';
import 'package:codelessly_sdk/src/cache/cache_manager.dart';
import 'package:codelessly_sdk/src/data/local_data_repository.dart';
import 'package:codelessly_sdk/src/data/network_data_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'data_manager_test.mocks.dart';

final mockSDKPublishModel = SDKPublishModel(
  projectId: 'mockProjectId',
  owner: 'mockOwnerId',
  layouts: {
    'mockLayoutId': mockSDKPublishLayout,
  },
);
final mockSDKPublishLayout = SDKPublishLayout(
  id: 'mockLayoutId',
  canvasId: 'mockCanvasId',
  pageId: 'mockPageId',
  projectId: 'mockProjectId',
  owner: 'mockOwnerId',
  nodes: {},
  lastUpdated: DateTime.now(),
);
final mockAuthData = AuthData(
  authToken: 'mockToken',
  projectId: 'mockProjectId',
  ownerId: 'mockOwnerId',
  timestamp: DateTime.now(),
);

@GenerateNiceMocks([
  MockSpec<NetworkDataRepository>(),
  MockSpec<LocalDataRepository>(),
  MockSpec<CacheManager>(unsupportedMembers: {Symbol('get')}),
  MockSpec<AuthManager>(),
])
Future main() async {
  final config = CodelesslyConfig(authToken: 'mockToken');

  test('Local cached model', () async {
    final MockAuthManager authManager = MockAuthManager();
    final MockNetworkDataRepository networkDataRepository =
        MockNetworkDataRepository();
    final MockLocalDataRepository localDataRepository =
        MockLocalDataRepository();

    when(authManager.authData).thenReturn(mockAuthData);
    when(localDataRepository.fetchPublishModel(isPreview: false))
        .thenReturn(mockSDKPublishModel);

    final DataManager dataManager = DataManager(
      config: config,
      authManager: authManager,
      networkDataRepository: networkDataRepository,
      localDataRepository: localDataRepository,
    );
    await expectLater(dataManager.init(layoutID: null), completes);
    expect(dataManager.publishModel, mockSDKPublishModel);

    verify(localDataRepository.fetchPublishModel(
      isPreview: anyNamed('isPreview'),
    )).called(1);
    verifyNever(localDataRepository.fetchFontBytes(
      fontID: anyNamed('fontID'),
      isPreview: anyNamed('isPreview'),
    ));

    verifyNever(networkDataRepository.downloadLayoutModel(
      projectID: anyNamed('projectID'),
      layoutID: anyNamed('layoutID'),
      isPreview: anyNamed('isPreview'),
    ));
    verifyNever(networkDataRepository.downloadLayoutModels(
      projectID: anyNamed('projectID'),
      layoutIDs: anyNamed('layoutIDs'),
      isPreview: anyNamed('isPreview'),
    ));
    verifyNever(networkDataRepository.downloadFontBytes(url: anyNamed('url')));
    verifyNever(networkDataRepository.downloadFontModels(
      projectID: anyNamed('projectID'),
      fontIDs: anyNamed('fontIDs'),
      isPreview: anyNamed('isPreview'),
    ));
    verifyNever(networkDataRepository.downloadFontModel(
      projectID: anyNamed('projectID'),
      fontID: anyNamed('fontID'),
      isPreview: anyNamed('isPreview'),
    ));
  });

  test('Local no cached model', () async {
    final MockAuthManager authManager = MockAuthManager();
    final MockNetworkDataRepository networkDataRepository =
        MockNetworkDataRepository();
    final MockLocalDataRepository localDataRepository =
        MockLocalDataRepository();

    when(authManager.authData).thenReturn(mockAuthData);
    when(localDataRepository.fetchPublishModel(isPreview: false))
        .thenReturn(null);
    when(
      networkDataRepository.streamPublishModel(
        projectID: anyNamed('projectID'),
        isPreview: anyNamed('isPreview'),
      ),
    ).thenAnswer((_) => Stream.value(null));

    final DataManager dataManager = DataManager(
      config: config,
      authManager: authManager,
      networkDataRepository: networkDataRepository,
      localDataRepository: localDataRepository,
    );
    // Expected to time out because the stream will never return a value, it's
    // going to keep initialization stalled until the stream returns a value.
    await expectLater(
      dataManager
          .init(layoutID: null)
          .timeout(Duration(milliseconds: 100), onTimeout: () {}),
      completes,
    );
    expect(dataManager.publishModel, null);

    verify(localDataRepository.fetchPublishModel(
      isPreview: anyNamed('isPreview'),
    )).called(1);
    verifyNever(localDataRepository.fetchFontBytes(
      fontID: anyNamed('fontID'),
      isPreview: anyNamed('isPreview'),
    ));

    verifyNever(networkDataRepository.downloadLayoutModel(
      projectID: anyNamed('projectID'),
      layoutID: anyNamed('layoutID'),
      isPreview: anyNamed('isPreview'),
    ));
    verifyNever(networkDataRepository.downloadLayoutModels(
      projectID: anyNamed('projectID'),
      layoutIDs: anyNamed('layoutIDs'),
      isPreview: anyNamed('isPreview'),
    ));
    verifyNever(networkDataRepository.downloadFontBytes(url: anyNamed('url')));
    verifyNever(networkDataRepository.downloadFontModels(
      projectID: anyNamed('projectID'),
      fontIDs: anyNamed('fontIDs'),
      isPreview: anyNamed('isPreview'),
    ));
    verifyNever(networkDataRepository.downloadFontModel(
      projectID: anyNamed('projectID'),
      fontID: anyNamed('fontID'),
      isPreview: anyNamed('isPreview'),
    ));
  });

  test('Stream first event model', () async {
    final MockAuthManager authManager = MockAuthManager();
    final MockNetworkDataRepository networkDataRepository =
    MockNetworkDataRepository();
    final MockLocalDataRepository localDataRepository =
    MockLocalDataRepository();

    when(authManager.authData).thenReturn(mockAuthData);
    when(
      localDataRepository.fetchPublishModel(isPreview: anyNamed('isPreview')),
    ).thenReturn(null);
    when(
      networkDataRepository.streamPublishModel(
        projectID: anyNamed('projectID'),
        isPreview: anyNamed('isPreview'),
      ),
    ).thenAnswer((_) => Stream.value(mockSDKPublishModel));

    final DataManager dataManager = DataManager(
      config: config,
      authManager: authManager,
      networkDataRepository: networkDataRepository,
      localDataRepository: localDataRepository,
    );

    await expectLater(dataManager.init(layoutID: null), completes);
    expect(dataManager.publishModel, mockSDKPublishModel);

    verify(localDataRepository.fetchPublishModel(
      isPreview: anyNamed('isPreview'),
    )).called(1);
    verifyNever(localDataRepository.fetchFontBytes(
      fontID: anyNamed('fontID'),
      isPreview: anyNamed('isPreview'),
    ));

    verifyNever(networkDataRepository.downloadLayoutModel(
      projectID: anyNamed('projectID'),
      layoutID: anyNamed('layoutID'),
      isPreview: anyNamed('isPreview'),
    ));
    verifyNever(networkDataRepository.downloadLayoutModels(
      projectID: anyNamed('projectID'),
      layoutIDs: anyNamed('layoutIDs'),
      isPreview: anyNamed('isPreview'),
    ));
    verifyNever(networkDataRepository.downloadFontBytes(url: anyNamed('url')));
    verifyNever(networkDataRepository.downloadFontModels(
      projectID: anyNamed('projectID'),
      fontIDs: anyNamed('fontIDs'),
      isPreview: anyNamed('isPreview'),
    ));
    verifyNever(networkDataRepository.downloadFontModel(
      projectID: anyNamed('projectID'),
      fontID: anyNamed('fontID'),
      isPreview: anyNamed('isPreview'),
    ));
  });
}
