import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _layout(String id, List<String> canvasIds) => {
  'id': id,
  'owner': 'o',
  'users': ['o'],
  'roles': {'o': 'owner'},
  'teams': [],
  'public': false,
  'pageId': 'page',
  'projectId': 'project',
  'canvases': <String, dynamic>{
    for (final String canvasId in canvasIds)
      // Each canvas maps its node IDs to node JSON.
      canvasId: <String, dynamic>{
        canvasId: <String, dynamic>{
          'id': canvasId,
          'name': canvasId,
          'type': 'canvas',
          'basicBoxLocal': [0, 0, 390, 844],
          'children': <String>[],
          'properties': <String, dynamic>{'bodyId': '$canvasId-body'},
        },
      },
  },
  'breakpoints': [],
  'lastUpdated': 0,
  'canvasIds': canvasIds,
};

void main() {
  // Sites open a screen from a link (?screen=<canvas id>), so a canvas ID
  // must find the layout that holds it.
  final SDKPublishModel model = SDKPublishModel.fromJson({
    'owner': 'o',
    'users': ['o'],
    'roles': {'o': 'owner'},
    'teams': [],
    'public': false,
    'projectId': 'project',
    'pages': ['page'],
    'layoutIDMap': <String, dynamic>{},
    'disabledLayouts': [],
    'entryLayoutId': 'layout-trips',
    'layouts': {
      'layout-trips': _layout('layout-trips', ['canvas-trips']),
      'layout-route': _layout('layout-route', ['canvas-route']),
    },
  });

  test('a layout ID resolves to itself', () {
    expect(model.resolveLayoutId('layout-route'), 'layout-route');
  });

  test('a canvas ID resolves to the layout holding it', () {
    expect(model.resolveLayoutId('canvas-route'), 'layout-route');
  });

  test('unknown and empty IDs resolve to nothing', () {
    expect(model.resolveLayoutId('nope'), isNull);
    expect(model.resolveLayoutId(''), isNull);
    expect(model.resolveLayoutId(null), isNull);
  });
}
