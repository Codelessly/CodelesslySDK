import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/tidepool.dart';

void main() {
  group('CanvasLocation', () {
    final SDKPublishModel model = tidepoolModel();

    test('matches a canvas by its path', () {
      final CanvasLocationMatch? match = CanvasLocation.match(
        model,
        '/guide/bat-star?from=tides&id=ignored',
      );
      expect(match?.layoutId, 'creature');
      expect(match?.params, {'id': 'bat-star', 'from': 'tides'});
      expect(CanvasLocation.match(model, 'journal/')?.canvasId, 'journal');
      expect(CanvasLocation.match(model, 'guide')?.canvasId, 'guide');
    });

    test('prefers literal segments over params', () {
      expect(CanvasLocation.match(model, 'guide/new')?.canvasId, 'newCreature');
    });

    test('matches nothing for the root or an unknown path', () {
      expect(CanvasLocation.match(model, ''), isNull);
      expect(CanvasLocation.match(model, '/'), isNull);
      expect(CanvasLocation.match(model, 'guide/bat-star/more'), isNull);
      expect(CanvasLocation.match(model, 'kraken'), isNull);
    });

    test('fills a path with params', () {
      expect(
        CanvasLocation.locationOf(model, 'creature', {
          'id': 'sea star',
          'from': 'tides',
          'none': null,
        }),
        'guide/sea%20star?from=tides',
      );
      expect(CanvasLocation.locationOf(model, 'journal', {}), 'journal');
      // The entry screen is at the root.
      expect(CanvasLocation.locationOf(model, 'tides', {}), '');
      expect(CanvasLocation.locationOf(model, 'tides', {'a': 1}), '?a=1');
      // No path, or a path param missing.
      expect(CanvasLocation.locationOf(model, 'settings', {}), isNull);
      expect(CanvasLocation.locationOf(model, 'creature', {}), isNull);
    });
  });

  group('catch-all', () {
    SDKPublishModel withLost() {
      final SDKPublishModel model = tidepoolModel();
      final SDKPublishLayout lost = testScreen('lost', path: '*');
      model.layouts[lost.id] = lost;
      return model;
    }

    test('a * screen catches unknown paths, naming them', () {
      final SDKPublishModel model = withLost();
      final CanvasLocationMatch? match = CanvasLocation.match(
        model,
        'guide/bat-star/more?x=1',
      );
      expect(match?.canvasId, 'lost');
      expect(match?.params, {'x': '1', 'path': '/guide/bat-star/more'});
      expect(CanvasLocation.match(model, 'kraken')?.params['path'], '/kraken');
    });

    test('known paths and screen ids still win', () {
      final SDKPublishModel model = withLost();
      expect(CanvasLocation.match(model, 'guide')?.canvasId, 'guide');
      expect(CanvasLocation.match(model, 'guide/x')?.canvasId, 'creature');
      // A link naming a screen by id isn't an unknown path.
      expect(CanvasLocation.match(model, 'settings'), isNull);
      expect(CanvasLocation.match(model, ''), isNull);
    });

    test('the catch-all screen shows at the path it caught', () {
      final SDKPublishModel model = withLost();
      expect(
        CanvasLocation.locationOf(model, 'lost', {'path': '/kraken/deep'}),
        'kraken/deep',
      );
    });
  });
}
