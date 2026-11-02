import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a layout over the document limit round-trips through gzip', () {
    final FrameNode frame = FrameNode(
      id: 'f',
      name: 'Sheet',
      basicBoxLocal: NodeBox(0, 0, 100, 100),
      children: const [],
    )..variables['data'] = '\${= ${List.filled(4000, 'item.w * 20').join(' + ')}}';
    final SDKPublishLayout layout = SDKPublishLayout(
      id: 'l',
      pageId: 'p',
      projectId: 'pr',
      canvases: {
        'c': {'f': frame},
      },
      lastUpdated: DateTime(2026, 10, 30),
      owner: 'o',
      teams: const {},
      users: const {'o'},
      roles: const {'o': Role.admin},
      public: false,
    );
    final Map<String, dynamic> full = jsonDecode(jsonEncode(layout.toJson()));
    final Map<String, dynamic> zipped = SDKPublishLayout.compressCanvases(full);
    expect(zipped.containsKey('canvases'), isFalse);
    expect(jsonEncode(zipped).length, lessThan(jsonEncode(full).length ~/ 10));
    final SDKPublishLayout back = SDKPublishLayout.fromJson(zipped);
    expect(back.canvasIds, {'c'});
    expect((back.canvases['c']!['f']! as FrameNode).variables['data'], frame.variables['data']);
  });

  test('an uncompressed layout reads as before', () {
    final Map<String, dynamic> json = {'id': 'l', 'canvases': {}};
    expect(SDKPublishLayout.expandCompressedCanvases(json), same(json));
  });
}
