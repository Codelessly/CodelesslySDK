import 'dart:convert';
import 'dart:io';

import 'package:codelessly_genui/codelessly_genui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const GenUiTheme testTheme = GenUiTheme(fontFamily: 'GenUiTestSans');

List<Map<String, Object?>> fixture(String name) =>
    (jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as List)
        .cast<Map<String, Object?>>();

Map<String, Object?> create(String id) => {
  'version': 'v0.9.1',
  'createSurface': {'surfaceId': id, 'catalogId': kGenUiCatalogId, 'sendDataModel': true},
};

Map<String, Object?> data(String id, Object? value, [String path = '/']) => {
  'version': 'v0.9.1',
  'updateDataModel': {'surfaceId': id, 'path': path, 'value': value},
};

Map<String, Object?> components(String id, List<Map<String, Object?>> list) => {
  'version': 'v0.9.1',
  'updateComponents': {'surfaceId': id, 'components': list},
};

Future<void> pumpSurfaces(
  WidgetTester tester,
  GenUiSession session, {
  Size size = const Size(440, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'GenUiTestSans'),
      home: Scaffold(
        backgroundColor: const Color(0xFFF5F6F8),
        body: ValueListenableBuilder(
          valueListenable: session.surfaces,
          builder: (context, surfaces, _) => SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final s in surfaces)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GenUiSurfaceView(surface: s),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
