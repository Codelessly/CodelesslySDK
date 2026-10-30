import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';

void main() {
  VideoNode node({String? url}) => VideoNode(
    id: 'native-video',
    name: 'Video',
    basicBoxLocal: NodeBox(0, 0, 320, 180),
    properties: VideoProperties(url: url, autoPlay: true),
  );

  testWidgets(
    'native video preview is deterministic and never embeds a web view',
    (tester) async {
      final video = node(url: 'https://example.com/movie.mp4');
      final manager = PassiveNodeTransformerManager(
        (id) => video,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
      expect(
        manager.getTransformerByNode(video),
        isA<PassiveVideoTransformer>(),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: CodelesslyContext.empty(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  video,
                  context,
                  settings: const WidgetBuildSettings(
                    debugLabel: 'video',
                    isPreview: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(PassiveVideoWidget), findsOneWidget);
      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
      expect(find.byType(VideoPlayer), findsNothing);
      expect(find.byType(WebViewWidget), findsNothing);
    },
  );

  testWidgets('missing URL shows a placeholder without a player', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PassiveVideoWidget(node: node(), isPreview: false),
        ),
      ),
    );
    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
    expect(find.byType(VideoPlayer), findsNothing);
    expect(find.byType(WebViewWidget), findsNothing);
  });
}
