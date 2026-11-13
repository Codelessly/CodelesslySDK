import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/src/features/media/embedded_media_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

Node node(Map<String, Object?> props) => Node.fromJson({
  'type': 'embeddedVideo',
  'props': {'videoId': 'sample', 'source': 'youtube', ...props},
})!;
void main() {
  test('a YouTube player is sent play, seek and volume commands', () {
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
  test('a Vimeo player is sent its own commands, with volume from 0 to 1', () {
    final n = node({'source': 'vimeo', 'playing': false, 'positionSeconds': 1.25, 'volume': .6});
    expect(embeddedCommands(n), [
      {'method': 'setVolume', 'value': .6},
      {'method': 'setCurrentTime', 'value': 1.25},
      {'method': 'pause'},
    ]);
  });
  test('a ready message counts only from the provider\'s own origin', () {
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
  test('a controlled player waits until it is ready before playing and does not reload on a control change', () {
    final before = node({'autoPlay': true, 'playing': false});
    final after = node({'autoPlay': true, 'playing': true, 'positionSeconds': 3.5});
    expect(Uri.parse(embeddedPlayerUrl(before)).queryParameters['autoplay'], '0');
    expect(Uri.parse(embeddedPlayerUrl(after)).queryParameters['autoplay'], '0');
    expect(embeddedPlayerIdentity(before), embeddedPlayerIdentity(after));
  });
}
