import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'responsive_variance_test.dart'
    show builtRectangles, idsOf, responsivePage, screens;

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

class _FakeNetworkRepository extends Fake implements NetworkDataRepository {}

class _FakeFirestore extends Fake implements FirebaseFirestore {}

class _FakeLocalDatabase extends Fake implements LocalDatabase {}

class _TestDataManager extends DataManager {
  _TestDataManager(SDKPublishModel model, CodelesslyConfig config)
    : super(
        'test',
        config: config,
        cacheManager: _FakeCache(),
        authManager: _FakeAuthManager(),
        networkDataRepository: _FakeNetworkRepository(),
        localDataRepository: _FakeLocalRepository(),
        firebaseFirestore: _FakeFirestore(),
        errorLogger: ErrorLogger.instance,
        publishModel: model,
      );

  @override
  LocalDatabase get localDatabase => _FakeLocalDatabase();
}

/// The responsive page as the editor publishes it: the layout serialized to
/// JSON and read back, as the preview downloads it.
SDKPublishLayout publishedLayout(PrivacyBase privacy) {
  final layout = SDKPublishLayout.private(
    id: 'layout',
    projectId: 'project',
    pageId: 'page',
    lastUpdated: DateTime(2026),
    canvases: {'canvas': responsivePage()},
    breakpoints: [const Breakpoint(nodeId: 'canvas')],
    privacy: privacy,
  );
  return SDKPublishLayout.fromJson(
    jsonDecode(jsonEncode(layout.toJson())) as Map<String, dynamic>,
  );
}

/// A responsive variance published and opened as the editor's Preview page
/// opens it: a CodelesslyWidget whose config has `isPreview` (which reads the
/// preview data source; the build settings' `isPreview` stays false, it is
/// only for the editor's settings-panel previews).
void main() {
  final expected = {
    390.0: (ScreenBreakpoint.mobile, 2),
    834.0: (ScreenBreakpoint.tablet, 3),
    1440.0: (ScreenBreakpoint.desktop, 4),
  };
  group('a published responsive variance in a preview CodelesslyWidget', () {
    for (final screen in screens) {
      testWidgets('${screen.width.toInt()}', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = screen;
        addTearDown(tester.view.reset);

        final model = SDKPublishModel(
          projectId: 'project',
          owner: 'owner',
          teams: const {},
          users: const {},
          roles: const {},
          public: false,
        );
        final layout = publishedLayout(model);
        model.layouts[layout.id] = layout;
        final config = CodelesslyConfig(authToken: 'token', isPreview: true);
        final codelessly = Codelessly(
          config: config,
          publishDataManager: _TestDataManager(model, config)
            ..status = CStatus.loaded(),
          previewDataManager: _TestDataManager(model, config)
            ..status = CStatus.loaded(),
        )..status = CStatus.loaded();

        await tester.pumpWidget(
          MaterialApp(
            home: CodelesslyWidget(codelessly: codelessly, layoutID: 'layout'),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
        final (breakpoint, count) = expected[screen.width]!;
        expect(
          builtRectangles(layout.canvases['canvas']!),
          idsOf(breakpoint, count),
        );
      });
    }
  });
}
