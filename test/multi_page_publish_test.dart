import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

// A project published one page at a time: page A's layouts must survive a
// publish of page B, and a screen of one page must be able to open a screen
// of the other.

SDKPublishLayout layout(String id, String pageId, List<String> canvasIds) =>
    SDKPublishLayout(
      id: id,
      pageId: pageId,
      projectId: 'project',
      canvases: {
        for (final String canvasId in canvasIds)
          canvasId: {
            canvasId: CanvasNode(
              id: canvasId,
              name: canvasId,
              basicBoxLocal: NodeBox(0, 0, 390, 844),
              properties: CanvasProperties(bodyId: canvasId),
              children: const [],
            ),
          },
      },
      lastUpdated: DateTime(2026),
      owner: 'owner',
      teams: const {},
      users: const {},
      roles: const {},
      public: false,
    );

SDKPublishModel model({
  Map<String, SDKPublishLayout> layouts = const {},
  SDKPublishUpdates? updates,
}) {
  final SDKPublishModel published = SDKPublishModel(
    projectId: 'project',
    updates: updates,
    owner: 'owner',
    teams: const {},
    users: const {},
    roles: const {},
    public: false,
  );
  layouts.forEach((String id, SDKPublishLayout layout) {
    published.layouts[id] = layout;
  });
  return published;
}

void main() {
  group('SDKPublishUpdates.merge', () {
    final DateTime t1 = DateTime(2026, 1, 1);
    final DateTime t2 = DateTime(2026, 2, 1);

    // Page A was published first: layout a1 (fonts f1, api p1).
    final SDKPublishUpdates pageA = SDKPublishUpdates(
      layouts: {'a1': t1},
      fonts: {'f1': t1},
      apis: {'p1': t1},
      variables: {'a1': t1},
      conditions: {'a1': t1},
      layoutFonts: {
        'a1': {'f1'},
      },
      layoutApis: {
        'a1': {'p1'},
      },
      layoutCanvases: {
        'a1': {'canvasA'},
      },
    );

    test('a publish of another page keeps the first page\'s layouts', () {
      final SDKPublishUpdates pageB = SDKPublishUpdates(
        layouts: {'b1': t2},
        fonts: {'f2': t2},
        variables: {'b1': t2},
        layoutFonts: {
          'b1': {'f2'},
        },
        layoutApis: {'b1': <String>{}},
        layoutCanvases: {
          'b1': {'canvasB'},
        },
      );

      final SDKPublishUpdates merged = pageA.merge(pageB);

      expect(merged.layouts, {'a1': t1, 'b1': t2});
      expect(merged.fonts, {'f1': t1, 'f2': t2});
      expect(merged.apis, {'p1': t1});
      expect(merged.variables, {'a1': t1, 'b1': t2});
      expect(merged.conditions, {'a1': t1});
      // These were replaced by the newer publish's maps, which dropped the
      // fonts and apis of page A's layouts.
      expect(merged.layoutFonts, {
        'a1': {'f1'},
        'b1': {'f2'},
      });
      expect(merged.layoutApis, {
        'a1': {'p1'},
        'b1': <String>{},
      });
      expect(merged.layoutCanvases, {
        'a1': {'canvasA'},
        'b1': {'canvasB'},
      });
    });

    test('a republished layout takes the newer entries', () {
      final SDKPublishUpdates again = SDKPublishUpdates(
        layouts: {'a1': t2},
        layoutFonts: {'a1': <String>{}},
        layoutCanvases: {
          'a1': {'canvasA', 'canvasA2'},
        },
      );

      final SDKPublishUpdates merged = pageA.merge(again);

      expect(merged.layouts, {'a1': t2});
      expect(merged.layoutFonts, {'a1': <String>{}});
      expect(merged.layoutApis, {
        'a1': {'p1'},
      });
      expect(merged.layoutCanvases['a1'], {'canvasA', 'canvasA2'});
    });

    test('a canvas listed by a newer layout leaves its old layout', () {
      final SDKPublishUpdates old = SDKPublishUpdates(
        layoutCanvases: {
          'a1': {'canvasA'},
          'a2': {'canvasMoved', 'canvasStays'},
        },
      );
      final SDKPublishUpdates merged = old.merge(
        SDKPublishUpdates(
          layoutCanvases: {
            'b1': {'canvasMoved'},
          },
        ),
      );

      expect(merged.layoutCanvases, {
        'a1': {'canvasA'},
        'a2': {'canvasStays'},
        'b1': {'canvasMoved'},
      });
      expect(merged.layoutIdForCanvas('canvasMoved'), 'b1');
    });

    test('layoutCanvases round-trips through JSON', () {
      final SDKPublishUpdates decoded = SDKPublishUpdates.fromJson(
        pageA.toJson(),
      );
      expect(decoded.layoutCanvases, pageA.layoutCanvases);
      // Models published before the index existed still parse.
      expect(
        SDKPublishUpdates.fromJson(<String, dynamic>{}).layoutCanvases,
        isEmpty,
      );
    });
  });

  group('resolveLayoutIdForCanvas', () {
    test('finds a downloaded layout of any page by its canvas', () {
      final SDKPublishModel published = model(
        layouts: {
          'a1': layout('a1', 'pageA', ['canvasA']),
          'b1': layout('b1', 'pageB', ['canvasB1', 'canvasB2']),
        },
      );

      expect(
        FunctionsRepository.resolveLayoutIdForCanvas(published, 'canvasA'),
        'a1',
      );
      expect(
        FunctionsRepository.resolveLayoutIdForCanvas(published, 'canvasB2'),
        'b1',
      );
      // A layout id works as a destination too.
      expect(
        FunctionsRepository.resolveLayoutIdForCanvas(published, 'b1'),
        'b1',
      );
    });

    test('finds a layout that is not downloaded yet from the index', () {
      final SDKPublishModel published = model(
        layouts: {
          'a1': layout('a1', 'pageA', ['canvasA']),
        },
        updates: SDKPublishUpdates(
          layoutCanvases: {
            'a1': {'canvasA'},
            'b1': {'canvasB'},
          },
        ),
      );

      expect(
        FunctionsRepository.resolveLayoutIdForCanvas(published, 'canvasB'),
        'b1',
      );
    });

    test('is null for an unknown canvas', () {
      final SDKPublishModel published = model(
        layouts: {
          'a1': layout('a1', 'pageA', ['canvasA']),
        },
      );
      expect(
        FunctionsRepository.resolveLayoutIdForCanvas(published, 'nope'),
        isNull,
      );
      expect(
        FunctionsRepository.resolveLayoutIdForCanvas(published, ''),
        isNull,
      );
      expect(
        FunctionsRepository.resolveLayoutIdForCanvas(null, 'canvasA'),
        isNull,
      );
    });
  });
}
