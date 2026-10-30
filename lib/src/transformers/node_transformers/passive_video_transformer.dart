import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../codelessly_sdk.dart';

/// Native MP4 playback. Embedded YouTube/Vimeo video is a different node.
class PassiveVideoTransformer extends NodeWidgetTransformer<VideoNode> {
  PassiveVideoTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    VideoNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) => PassiveVideoWidget(node: node, isPreview: settings.isPreview);
}

class PassiveVideoWidget extends StatefulWidget {
  const PassiveVideoWidget({
    super.key,
    required this.node,
    required this.isPreview,
  });

  final VideoNode node;
  final bool isPreview;

  @override
  State<PassiveVideoWidget> createState() => _PassiveVideoWidgetState();
}

class _PassiveVideoWidgetState extends State<PassiveVideoWidget> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PassiveVideoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPreview != widget.isPreview ||
        oldWidget.node.properties.url != widget.node.properties.url) {
      _load();
    }
  }

  void _load() {
    final generation = ++_generation;
    final old = _controller;
    _controller = null;
    _ready = false;
    _failed = false;
    if (old != null) {
      old.removeListener(_onPlayerChange);
      old.dispose();
    }
    final url = widget.node.properties.url;
    if (widget.isPreview || url == null || !isRemoteMp4Url(url)) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    controller.addListener(_onPlayerChange);
    controller
        .initialize()
        .then((_) {
          if (!mounted || generation != _generation) return;
          setState(() => _ready = true);
          // Never autoplay a remote URL, even if autoPlay was requested by content.
        })
        .catchError((Object error) {
          if (!mounted || generation != _generation) return;
          setState(() => _failed = true);
        });
  }

  void _onPlayerChange() {
    if (mounted && _controller?.value.hasError == true && !_failed) {
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    ++_generation;
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onPlayerChange);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final Widget content;
    if (widget.isPreview || widget.node.properties.url == null) {
      content = const Center(
        child: Icon(Icons.movie_outlined, semanticLabel: 'Video preview'),
      );
    } else if (_failed || controller == null) {
      content = const Center(
        child: Icon(Icons.error_outline, semanticLabel: 'Video unavailable'),
      );
    } else if (!_ready) {
      content = const Center(child: CircularProgressIndicator());
    } else {
      content = Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio > 0
                  ? controller.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(controller),
            ),
          ),
          if (widget.node.properties.showControls)
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, child) => IconButton(
                tooltip: value.isPlaying ? 'Pause video' : 'Play video',
                icon: Icon(
                  value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                ),
                onPressed: () =>
                    value.isPlaying ? controller.pause() : controller.play(),
              ),
            ),
        ],
      );
    }
    return AdaptiveNodeBox(
      node: widget.node,
      child: ColoredBox(color: Colors.black12, child: content),
    );
  }
}
