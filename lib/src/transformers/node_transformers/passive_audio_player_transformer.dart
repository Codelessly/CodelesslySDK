import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../codelessly_sdk.dart';

/// The API validates HTTPS URL syntax, not DNS or redirects: these are handled
/// by the platform player and OS. A typed host policy for untrusted content is
/// owned by GenUI, not by this SDK transformer.
/// Adapter permits tests to exercise playback without a platform or network.
abstract class AudioPlayback {
  Stream<PlayerState> get playerStateStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Future<void> setUrl(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setLoop(bool loop);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

class _JustAudioPlayback implements AudioPlayback {
  final AudioPlayer _player = AudioPlayer();
  @override
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  @override
  Stream<Duration> get positionStream => _player.positionStream;
  @override
  Stream<Duration?> get durationStream => _player.durationStream;
  @override
  Future<void> setUrl(String url) async {
    await _player.setUrl(url);
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> setLoop(bool loop) =>
      _player.setLoopMode(loop ? LoopMode.one : LoopMode.off);
  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);
  @override
  Future<void> dispose() => _player.dispose();
}

/// Playback values an audio node takes from state through its variables
/// (see [AudioPlayerProperties.bindableKeys]); null when not bound.
class AudioBindings {
  const AudioBindings({this.url, this.volume, this.playing, this.playKey});

  final String? url;
  final double? volume;
  final bool? playing;
  final String? playKey;

  static AudioBindings of(BuildContext context, AudioPlayerNode node) {
    if (!node.variables.keys.any(AudioPlayerProperties.bindableKeys.contains)) {
      return const AudioBindings();
    }
    final ScopedValues scope = ScopedValues.of(context);
    Object? read(String key) => node.variables.containsKey(key)
        ? PropertyValueDelegate.getPropertyValue<Object>(
            node,
            key,
            scopedValues: scope,
          )
        : null;
    final Object? volume = read('volume');
    final Object? playing = read('playing');
    final Object? url = read('url');
    final Object? key = read('playKey');
    return AudioBindings(
      url: url?.toString().trim().isEmpty ?? true ? null : url.toString().trim(),
      volume: switch (volume) {
        num n => n.toDouble(),
        String s => double.tryParse(s.trim()),
        _ => null,
      },
      playing: switch (playing) {
        bool b => b,
        String s when s.trim() == 'true' => true,
        String s when s.trim() == 'false' || s.trim().isEmpty => false,
        num n => n != 0,
        _ => null,
      },
      playKey: node.variables.containsKey('playKey') ? '${key ?? ''}' : null,
    );
  }
}

class PassiveAudioPlayerTransformer
    extends NodeWidgetTransformer<AudioPlayerNode> {
  PassiveAudioPlayerTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    AudioPlayerNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) => PassiveAudioPlayerWidget(
    node: node,
    isPreview: settings.isPreview,
    bindings: AudioBindings.of(context, node),
  );
}

class PassiveAudioPlayerWidget extends StatefulWidget {
  const PassiveAudioPlayerWidget({
    super.key,
    required this.node,
    required this.isPreview,
    this.createPlayer,
    this.bindings = const AudioBindings(),
  });
  final AudioPlayerNode node;
  final bool isPreview;

  /// Values bound to state; they win over the node's own properties.
  final AudioBindings bindings;
  final AudioPlayback Function()? createPlayer;

  @override
  State<PassiveAudioPlayerWidget> createState() =>
      _PassiveAudioPlayerWidgetState();
}

class _PassiveAudioPlayerWidgetState extends State<PassiveAudioPlayerWidget>
    with WidgetsBindingObserver {
  AudioPlayback? _player;
  bool _ready = false;
  bool _failed = false;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  int _generation = 0;
  final _subscriptions = <dynamic>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      final player = _player;
      if (player != null) {
        _run(player.pause);
      }
    }
  }

  @override
  void didUpdateWidget(covariant PassiveAudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPreview != widget.isPreview ||
        _urlOf(oldWidget) != _url ||
        oldWidget.createPlayer != widget.createPlayer) {
      _load();
      return;
    }
    _applyState(previous: oldWidget);
  }

  static String? _urlOf(PassiveAudioPlayerWidget w) =>
      w.bindings.url ?? w.node.properties.url;

  String? get _url => _urlOf(widget);

  double get _volume =>
      (widget.bindings.volume ?? widget.node.properties.volume).clamp(0, 1);

  /// Applies loop, volume and the bound play state to a loaded player.
  /// A bound `playing` plays or pauses to follow it; a changed `playKey`
  /// plays again from the start.
  void _applyState({PassiveAudioPlayerWidget? previous}) {
    final player = _player;
    if (player == null || !_ready) return;
    final props = widget.node.properties;
    if (previous == null || previous.node.properties.loop != props.loop) {
      _run(() => player.setLoop(props.loop));
    }
    if (previous == null || _volumeOf(previous) != _volume) {
      _run(() => player.setVolume(_volume));
    }
    final bindings = widget.bindings;
    final bool restarted =
        previous != null &&
        bindings.playKey != null &&
        previous.bindings.playKey != bindings.playKey;
    final bool wantsPlay = bindings.playing ?? bindings.playKey != null;
    if (restarted && wantsPlay) {
      _run(() async {
        await player.seek(Duration.zero);
        await player.play();
      });
      return;
    }
    if (bindings.playing case final bool playing
        when previous == null || previous.bindings.playing != playing) {
      _run(playing ? player.play : player.pause);
    }
  }

  static double _volumeOf(PassiveAudioPlayerWidget w) =>
      (w.bindings.volume ?? w.node.properties.volume).clamp(0, 1);

  void _release() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    final player = _player;
    _player = null;
    if (player != null) {
      // Stop output before releasing the native player; errors on a stale player
      // cannot affect the new generation.
      player
          .pause()
          .catchError((Object _) {})
          .whenComplete(() => player.dispose());
    }
  }

  void _load() {
    final generation = ++_generation;
    _release();
    _ready = false;
    _failed = false;
    _playing = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    final url = _url;
    // Preview and invalid URLs never create a platform player or make requests.
    if (widget.isPreview || url == null || !isRemoteAudioUrl(url)) {
      return;
    }
    final player = (widget.createPlayer ?? _JustAudioPlayback.new)();
    _player = player;
    _subscriptions.add(
      player.playerStateStream.listen((state) {
        if (!mounted || generation != _generation) {
          return;
        }
        setState(() {
          _playing =
              state.playing &&
              state.processingState != ProcessingState.completed;
          if (state.processingState == ProcessingState.completed) {
            _position = Duration.zero;
          }
        });
      }, onError: (Object _) => _onError(generation)),
    );
    _subscriptions.add(
      player.positionStream.listen((position) {
        if (mounted && generation == _generation) {
          setState(() => _position = position);
        }
      }, onError: (Object _) => _onError(generation)),
    );
    _subscriptions.add(
      player.durationStream.listen((duration) {
        if (mounted && generation == _generation) {
          setState(() => _duration = duration ?? Duration.zero);
        }
      }, onError: (Object _) => _onError(generation)),
    );
    player
        .setUrl(url)
        .then((_) {
          if (mounted && generation == _generation) {
            setState(() => _ready = true);
            _applyState();
          }
          // Untrusted content's autoPlay flag is intentionally ignored; a
          // layout plays on its own only through a bound `playing`.
        })
        .catchError((Object _) => _onError(generation));
  }

  void _onError(int generation) {
    if (mounted && generation == _generation) setState(() => _failed = true);
  }

  void _run(Future<void> Function() action) {
    final generation = _generation;
    action().catchError((Object _) => _onError(generation));
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }

  String _clock(Duration duration) =>
      '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    // A background sound has no player to show. The design canvas marks it
    // so it can still be found and selected.
    if (widget.node.properties.background) {
      return AdaptiveNodeBox(
        node: widget.node,
        child: widget.isPreview
            ? const FittedBox(
                child: Icon(Icons.graphic_eq, semanticLabel: 'Background audio'),
              )
            : const SizedBox.shrink(),
      );
    }
    final description = widget.node.properties.description;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return AdaptiveNodeBox(
      node: widget.node,
      child: ColoredBox(
        color: colors.surfaceContainerHigh,
        child: Row(
          children: [
            if (widget.isPreview || _url == null)
              const IconButton.filledTonal(
                tooltip: 'Play audio',
                onPressed: null,
                icon: Icon(Icons.play_arrow),
              )
            else if (_failed || _player == null)
              const Icon(
                Icons.error_outline,
                semanticLabel: 'Audio unavailable',
              )
            else if (!_ready)
              const CircularProgressIndicator()
            else if (widget.node.properties.showControls)
              IconButton(
                tooltip: _playing ? 'Pause audio' : 'Play audio',
                onPressed: () =>
                    _run(_playing ? _player!.pause : _player!.play),
                icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle),
              )
            else
              const Icon(Icons.audiotrack_outlined, semanticLabel: 'Audio'),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description?.isNotEmpty == true ? description! : 'Audio',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  if (!_failed && widget.node.properties.showControls)
                    SizedBox(
                      height: 24,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                            disabledThumbRadius: 5,
                            elevation: 0,
                            pressedElevation: 0,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                          activeTrackColor: colors.primary,
                          thumbColor: colors.primary,
                          inactiveTrackColor: colors.surfaceContainerHighest,
                          disabledActiveTrackColor: colors.onSurface.withValues(
                            alpha: 0.24,
                          ),
                          disabledInactiveTrackColor: colors.onSurface
                              .withValues(alpha: 0.12),
                          disabledThumbColor: colors.onSurfaceVariant,
                        ),
                        child: Slider(
                          value: _position.inMilliseconds
                              .clamp(0, _duration.inMilliseconds)
                              .toDouble(),
                          max: _duration.inMilliseconds > 0
                              ? _duration.inMilliseconds.toDouble()
                              : 1,
                          onChanged: _ready && _duration > Duration.zero
                              ? (value) => _run(
                                  () => _player!.seek(
                                    Duration(milliseconds: value.round()),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  if (!_failed && widget.node.properties.showControls)
                    Text(
                      '${_clock(_position)} / ${_duration > Duration.zero ? _clock(_duration) : '--:--'}',
                      style: theme.textTheme.labelSmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
