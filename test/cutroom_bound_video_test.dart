import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'cutroom_video_controls_test.dart' show FakeVideo;
import 'lists/support.dart' as support;

void main() {
  late VideoPlayerPlatform old;
  late FakeVideo fake;
  setUp(() {
    old = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = fake = FakeVideo();
  });
  tearDown(() => VideoPlayerPlatform.instance = old);
  testWidgets('a render-node binding applies a nonzero initial source time', (tester) async {
    final screen = await support.show(
      tester,
      {
        'col': {
          'type': 'video',
          'layout': {'width': 320, 'height': 180},
          'props': {'showControls': false, 'volume': 0},
          'actions': [
            support.reaction('changed', [
              {'type': 'setVariable', 'variable': 'status', 'value': r'${result}'},
            ]),
          ],
          'bind': {
            'props.url': r'${clip.url}',
            'props.positionSeconds': r'${clip.time}',
            'props.playing': r'${playing}',
          },
        },
      },
      variables: [
        support.v('clip', {'url': 'https://example.com/video.mp4', 'time': 1.25}, VariableType.map),
        support.v('playing', false, VariableType.boolean),
        support.v('status', {}, VariableType.map),
      ],
    );
    expect((screen['status'] as Map)['ready'], false);
    fake.ready(1);
    for (var i = 0; i < 12; i++) {
      await tester.pump();
    }
    expect(screen.tree.boxOf('col')!.node!.prop(VideoProps.positionSeconds), 1.25);
    expect(fake.seeks, contains(const Duration(milliseconds: 1250)));
    expect((screen['status'] as Map)['ready'], true);
    fake.events[1]!.addError(PlatformException(code: 'load-failed', message: 'Network failed'));
    for (var i = 0; i < 12; i++) {
      await tester.pump();
    }
    expect((screen['status'] as Map)['ready'], false);
    expect((screen['status'] as Map)['error'], isNotEmpty);
    await tester.pumpWidget(const SizedBox());
    screen.reactions.dispose();
    screen.tree.dispose();
    for (var i = 0; i < 12; i++) {
      await tester.pump();
    }
  });
}
