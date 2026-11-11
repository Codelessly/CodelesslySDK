import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/src/widgets/embedded_media_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

Node node(Map<String, Object?> props) => Node.fromJson({
  'type': 'embeddedVideo',
  'props': {'videoId': 'sample', 'source': 'youtube', ...props},
})!;
void main() {
  test('embedded controls are opt-in and remain sparse', () {
    final n = node({});
    expect(n.prop(EmbeddedVideoProps.playing), isNull);
    expect(n.prop(EmbeddedVideoProps.positionSeconds), isNull);
    expect(n.prop(EmbeddedVideoProps.volume), isNull);
    expect(embeddedCommands(n), isEmpty);
  });
  test('YouTube play, seek and volume requests use the command protocol', () {
    final n = node({'playing': true, 'positionSeconds': 2.375, 'volume': .4});
    expect(embeddedCommands(n), [
      {
        'event': 'command',
        'func': 'setVolume',
        'args': [40.0],
      },
      {
        'event': 'command',
        'func': 'seekTo',
        'args': [2.375, true],
      },
      {'event': 'command', 'func': 'playVideo', 'args': []},
    ]);
    expect(embeddedCommands(n, previous: n), isEmpty);
    final paused = node({'playing': false, 'positionSeconds': 3.0, 'volume': .4});
    expect(embeddedCommands(paused, previous: n).last, {'event': 'command', 'func': 'pauseVideo', 'args': []});
  });
  test('Vimeo requests use provider method names and normalized volume', () {
    final n = node({'source': 'vimeo', 'playing': false, 'positionSeconds': 1.25, 'volume': .6});
    expect(embeddedCommands(n), [
      {'method': 'setVolume', 'value': .6},
      {'method': 'setCurrentTime', 'value': 1.25},
      {'method': 'pause'},
    ]);
  });
  test('ready messages require the exact provider origin and valid provider event', () {
    expect(embeddedReady(EmbeddedVideoSource.youtube, 'https://www.youtube.com', '{"event":"onReady"}'), true);
    expect(
      embeddedReady(EmbeddedVideoSource.youtube, 'https://www.youtube.com.evil.test', '{"event":"onReady"}'),
      false,
    );
    expect(embeddedReady(EmbeddedVideoSource.youtube, 'https://player.vimeo.com', {'event': 'onReady'}), false);
    expect(embeddedReady(EmbeddedVideoSource.youtube, 'https://www.youtube.com', 'bad JSON'), false);
    expect(embeddedReady(EmbeddedVideoSource.vimeo, 'https://player.vimeo.com', {'event': 'ready'}), true);
    expect(embeddedReady(EmbeddedVideoSource.vimeo, 'https://player.vimeo.com', {'method': 'ping'}), true);
  });
  test('player URLs remain fixed provider HTTPS destinations, enable provider APIs and keep existing settings', () {
    final u = Uri.parse(
      embeddedPlayerUrl(node({'startAt': 3, 'endAt': 7, 'loop': true}), parentOrigin: 'https://site.example'),
    );
    expect(u.origin, 'https://www.youtube.com');
    expect(u.queryParameters['enablejsapi'], '1');
    expect(u.queryParameters['origin'], 'https://site.example');
    expect(u.queryParameters['start'], '3');
    expect(u.queryParameters['playlist'], 'sample');
    final v = Uri.parse(embeddedPlayerUrl(node({'source': 'vimeo', 'showControls': false})));
    expect(v.origin, 'https://player.vimeo.com');
    expect(v.queryParameters['api'], '1');
    expect(v.queryParameters['controls'], '0');
  });
  test('embedded pose control props round-trip with bounded values', () {
    final n = node({'playing': true, 'positionSeconds': 2.375, 'volume': 4});
    expect(n.prop(EmbeddedVideoProps.volume), 1);
    expect(Node.fromJson(n.toJson()), n);
  });
  test('controlled players wait for ready before playing and do not reload for control updates', () {
    final before = node({'autoPlay': true, 'playing': false});
    final after = node({'autoPlay': true, 'playing': true, 'positionSeconds': 3.5});
    expect(Uri.parse(embeddedPlayerUrl(before)).queryParameters['autoplay'], '0');
    expect(Uri.parse(embeddedPlayerUrl(after)).queryParameters['autoplay'], '0');
    expect(embeddedPlayerIdentity(before), embeddedPlayerIdentity(after));
  });
}
