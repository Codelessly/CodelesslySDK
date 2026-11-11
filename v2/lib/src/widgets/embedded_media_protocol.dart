// Provider messages shared by browser iframes and native iframe web views.
import 'dart:convert';
import 'package:codelessly_api_v2/codelessly_api.dart';

String embeddedOrigin(EmbeddedVideoSource source) =>
    source == EmbeddedVideoSource.youtube ? 'https://www.youtube.com' : 'https://player.vimeo.com';

String embeddedPlayerUrl(Node node, {String? parentOrigin}) {
  final source = node.prop(EmbeddedVideoProps.source), id = node.prop(EmbeddedVideoProps.videoId);
  final autoplay = node.prop(EmbeddedVideoProps.playing) == null && node.prop(EmbeddedVideoProps.autoPlay);
  final muted = node.prop(EmbeddedVideoProps.mute);
  String flag(bool b) => b ? '1' : '0';
  if (source == EmbeddedVideoSource.youtube) {
    return Uri.https('www.youtube.com', '/embed/${Uri.encodeComponent(id)}', {
      'enablejsapi': '1',
      'autoplay': flag(autoplay),
      'mute': flag(muted),
      if (parentOrigin != null && Uri.tryParse(parentOrigin)?.hasScheme == true) 'origin': parentOrigin,
      if (node.prop(EmbeddedVideoProps.loop)) ...{'loop': '1', 'playlist': id},
      'controls': flag(node.prop(EmbeddedVideoProps.showControls)),
      'fs': flag(node.prop(EmbeddedVideoProps.showFullscreenButton)),
      'iv_load_policy': node.prop(EmbeddedVideoProps.showVideoAnnotations) ? '1' : '3',
      if (node.prop(EmbeddedVideoProps.showCaptions)) 'cc_load_policy': '1',
      'cc_lang_pref': node.prop(EmbeddedVideoProps.captionLanguage),
      'start': ?node.prop(EmbeddedVideoProps.startAt)?.toString(),
      'end': ?node.prop(EmbeddedVideoProps.endAt)?.toString(),
      'playsinline': '1',
    }).toString();
  }
  return Uri.https('player.vimeo.com', '/video/${Uri.encodeComponent(id)}', {
    'api': '1',
    'autoplay': flag(autoplay),
    'muted': flag(muted),
    'loop': flag(node.prop(EmbeddedVideoProps.loop)),
    'controls': flag(node.prop(EmbeddedVideoProps.showControls)),
    'fullscreen': flag(node.prop(EmbeddedVideoProps.showFullscreenButton)),
    'playsinline': '1',
  }).toString();
}

Map<String, Object?> embeddedHandshake(EmbeddedVideoSource source) => source == EmbeddedVideoSource.youtube
    ? {'event': 'listening', 'id': 'codelessly', 'channel': 'widget'}
    : {'method': 'ping'};

/// Untrusted provider events are ignored unless the transport verified the
/// iframe window and the exact provider origin before calling this function.
bool embeddedReady(EmbeddedVideoSource source, String origin, Object? data) {
  if (origin != embeddedOrigin(source)) return false;
  Object? decoded = data;
  if (data is String) {
    try {
      decoded = jsonDecode(data);
    } catch (_) {
      return false;
    }
  }
  if (decoded is! Map) return false;
  if (source == EmbeddedVideoSource.youtube)
    return decoded['event'] == 'onReady' || decoded['event'] == 'initialDelivery';
  return decoded['event'] == 'ready' || decoded['method'] == 'ping';
}

List<Map<String, Object?>> embeddedCommands(Node node, {Node? previous}) {
  final youtube = node.prop(EmbeddedVideoProps.source) == EmbeddedVideoSource.youtube;
  final commands = <Map<String, Object?>>[];
  void send(String method, List<Object?> args) {
    commands.add(
      youtube
          ? {'event': 'command', 'func': method, 'args': args}
          : {'method': method, if (args.isNotEmpty) 'value': args.first},
    );
  }

  final volume = node.prop(EmbeddedVideoProps.volume), muted = node.prop(EmbeddedVideoProps.mute);
  if (previous == null ||
      previous.prop(EmbeddedVideoProps.mute) != muted ||
      previous.prop(EmbeddedVideoProps.volume) != volume) {
    if (youtube) {
      if (volume != null) send('setVolume', [volume * 100]);
      // An explicitly unmuted update also restores the provider's sound.
      if (muted || previous?.prop(EmbeddedVideoProps.mute) == true) send(muted ? 'mute' : 'unMute', []);
    } else if (volume != null || muted || previous?.prop(EmbeddedVideoProps.mute) == true) {
      send('setVolume', [muted ? 0 : volume ?? 1]);
    }
  }
  final position = node.prop(EmbeddedVideoProps.positionSeconds);
  if (position != null && (previous == null || previous.prop(EmbeddedVideoProps.positionSeconds) != position))
    send(youtube ? 'seekTo' : 'setCurrentTime', youtube ? [position, true] : [position]);
  final playing = node.prop(EmbeddedVideoProps.playing);
  if (playing != null && (previous == null || previous.prop(EmbeddedVideoProps.playing) != playing))
    send(youtube ? (playing ? 'playVideo' : 'pauseVideo') : (playing ? 'play' : 'pause'), []);
  return commands;
}

/// Static player settings determine whether an existing iframe must reload;
/// a controlled play/pause request is delivered as a command instead.
String embeddedPlayerIdentity(Node node) => embeddedPlayerUrl(node.withProp(EmbeddedVideoProps.playing, null));
