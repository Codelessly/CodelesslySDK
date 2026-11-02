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

    test("an app's not found screen takes every unknown path", () {
      final SDKPublishModel withLost = tidepoolModel(withNotFound: true);
      final CanvasLocationMatch? lost = CanvasLocation.match(
        withLost,
        '/amp/room?x=1',
      );
      expect(lost?.canvasId, 'lost');
      expect(lost?.params, {'x': '1', 'path': 'amp/room'});
      // Known paths still win, and the root is still the entry screen.
      expect(
        CanvasLocation.match(withLost, 'guide/new')?.canvasId,
        'newCreature',
      );
      expect(CanvasLocation.match(withLost, 'journal')?.canvasId, 'journal');
      expect(CanvasLocation.match(withLost, '/'), isNull);
      // It has no location of its own: it is opened by its id.
      expect(CanvasLocation.locationOf(withLost, 'lost', {}), isNull);
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

  group('catch-all paths', () {
    final SDKPublishModel model = tidepoolModel()
      ..layouts['notFound'] = testScreen('notFound', path: '*path')
      ..layouts['docs'] = testScreen('docs', path: 'docs/*rest');

    test('take any path no other screen matches, with the rest', () {
      final CanvasLocationMatch? lost = CanvasLocation.match(
        model,
        'kraken/deep?x=1',
      );
      expect(lost?.canvasId, 'notFound');
      expect(lost?.params, {'path': 'kraken/deep', 'x': '1'});
      expect(CanvasLocation.match(model, 'docs/a/b')?.params, {'rest': 'a/b'});
      // Too short for docs/*rest: the catch-all takes it.
      expect(CanvasLocation.match(model, 'docs')?.canvasId, 'notFound');
    });

    test('lose to every other match', () {
      expect(CanvasLocation.match(model, 'guide')?.canvasId, 'guide');
      expect(
        CanvasLocation.match(model, 'guide/bat-star')?.canvasId,
        'creature',
      );
      expect(CanvasLocation.match(model, ''), isNull);
    });

    test('fill a path with the rest', () {
      expect(
        CanvasLocation.locationOf(model, 'docs', {'rest': 'a/b', 'q': 1}),
        'docs/a/b?q=1',
      );
      expect(CanvasLocation.locationOf(model, 'notFound', {}), isNull);
    });
  });
}
