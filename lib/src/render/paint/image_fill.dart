// Images painted by render objects: image fills and image icons. Raster
// images resolve through Flutter's image cache (`NetworkImage`,
// `MemoryImage` for data URLs); SVGs through flutter_svg's picture loader.
// A render object that paints images mixes in [ImageClient]: it repaints
// when one it shows arrives.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

import '../convert.dart';

/// One image source, loaded once and shared.
class LoadedImage {
  LoadedImage._(this.url) : isSvg = _isSvg(url);

  final String url;

  /// Drawn from vectors ([picture]) rather than pixels ([image]).
  final bool isSvg;

  ImageInfo? image;
  PictureInfo? picture;
  bool failed = false;
  bool _started = false;
  final Set<ImageClient> _clients = {};
  ImageStream? _stream;
  ImageStreamListener? _listener;

  bool get ready => image != null || picture != null;

  /// Width / height of the source, in logical pixels at scale 1.
  Size? get size {
    if (picture case final p?) return p.size;
    if (image case final i?) return Size(i.image.width.toDouble(), i.image.height.toDouble());
    return null;
  }

  static bool _isSvg(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme == 'data') return uri.path.startsWith('image/svg');
    return uri.path.toLowerCase().endsWith('.svg');
  }

  void _start() {
    if (_started) return;
    _started = true;
    if (isSvg) {
      _loadSvg().then((p) {
        picture = p;
        _changed();
      }, onError: (Object _) {
        failed = true;
        _changed();
      });
      return;
    }
    final ImageProvider provider;
    if (url.startsWith('data:')) {
      try {
        provider = MemoryImage(UriData.parse(url).contentAsBytes());
      } on FormatException {
        failed = true;
        return;
      }
    } else {
      provider = NetworkImage(url);
    }
    final stream = provider.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((info, _) {
      image?.dispose();
      image = info;
      _changed();
    }, onError: (Object _, StackTrace? _) {
      failed = true;
      _changed();
    });
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  // Fetched here rather than by flutter_svg's network loader, whose cache
  // leaves a failed request's error unhandled.
  Future<PictureInfo> _loadSvg() async {
    final Uint8List bytes;
    if (url.startsWith('data:')) {
      bytes = UriData.parse(url).contentAsBytes();
    } else {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw http.ClientException('HTTP ${response.statusCode}', Uri.parse(url));
      bytes = response.bodyBytes;
    }
    return vg.loadPicture(SvgBytesLoader(bytes), null);
  }

  // Delivered after the current frame's work: an image already in the
  // cache arrives synchronously, possibly while a client paints.
  void _changed() => scheduleMicrotask(() {
        for (final c in _clients.toList()) {
          c.markNeedsPaint();
        }
      });

  void _release() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _stream = null;
    _listener = null;
    image?.dispose();
    image = null;
    picture?.picture.dispose();
    picture = null;
  }
}

/// The images render objects show, by URL. Entries no render object shows
/// are let go of (raster images stay in Flutter's image cache).
abstract final class PaintImages {
  static final Map<String, LoadedImage> _entries = {};

  /// Whether [url] can be loaded (not empty, not an unresolved binding).
  static bool loadable(String? url) => url != null && url.trim().isNotEmpty && !url.contains(r'${');

  static LoadedImage _acquire(String url, ImageClient client) {
    final e = _entries.putIfAbsent(url, () => LoadedImage._(url));
    e._clients.add(client);
    e._start();
    return e;
  }

  static void _release(LoadedImage e, ImageClient client) {
    e._clients.remove(client);
    if (e._clients.isNotEmpty) return;
    // Kept a moment, so a node rebuilt in the same frame keeps its image.
    scheduleMicrotask(() {
      if (e._clients.isEmpty && identical(_entries[e.url], e)) {
        _entries.remove(e.url);
        e._release();
      }
    });
  }

  @visibleForTesting
  static int get debugEntries => _entries.length;
}

/// A render object that paints images: it holds the ones it shows while
/// attached and repaints when they arrive.
mixin ImageClient on RenderObject {
  final Map<String, LoadedImage> _images = {};
  Set<String> _wanted = const {};

  /// Sets the image URLs this object shows.
  void showImages(Iterable<String?> urls) {
    _wanted = {for (final u in urls) if (PaintImages.loadable(u)) u!};
    if (attached) _sync();
  }

  /// Whether an image it shows is still loading.
  bool get imagesPending => _wanted.any((u) {
        final e = _images[u];
        return e == null || (!e.ready && !e.failed);
      });

  /// The loaded image for [url], or null while it loads (or can't).
  LoadedImage? imageFor(String? url) {
    final e = url == null ? null : _images[url];
    return e != null && e.ready ? e : null;
  }

  void _sync() {
    for (final u in _images.keys.toList()) {
      if (!_wanted.contains(u)) PaintImages._release(_images.remove(u)!, this);
    }
    for (final u in _wanted) {
      _images[u] ??= PaintImages._acquire(u, this);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _sync();
  }

  @override
  void detach() {
    for (final e in _images.values) {
      PaintImages._release(e, this);
    }
    _images.clear();
    super.detach();
  }
}

/// A color matrix scaling saturation by [s] (Rec. 709 luminance).
List<double> saturationMatrix(double s) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  final i = 1 - s;
  return <double>[
    r * i + s, g * i, b * i, 0, 0, //
    r * i, g * i + s, b * i, 0, 0, //
    r * i, g * i, b * i + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

/// The URL an image paint shows.
String? imageUrlOf(api.Paint p) => p.type == api.PaintType.image ? p.image?.url : null;

/// Paints image fill [p] in [rrect] (the box, its corners rounded): placed by its fit and alignment (or its own rect),
/// repeated, scaled, flipped, saturated, tinted and faded, inside the
/// rounded corners.
void paintImageFill(Canvas canvas, RRect rrect, api.Paint p, ImageClient client) {
  final img = p.image;
  if (img == null || !p.visible) return;
  final loaded = client.imageFor(img.url);
  if (loaded == null) return;
  final box = rrect.outerRect;
  final rect = img.rect == null
      ? box
      : Rect.fromLTWH(box.left + img.rect![0], box.top + img.rect![1], img.rect![2], img.rect![3]);
  final ColorFilter? filter = img.tint != null
      ? ColorFilter.mode(img.tint!.flutter, BlendMode.srcIn)
      : img.saturation != 1
          ? ColorFilter.matrix(saturationMatrix(img.saturation))
          : null;
  canvas.save();
  if (!rrect.isRect) canvas.clipRRect(rrect);
  if (img.flipY) {
    canvas
      ..translate(0, rect.center.dy * 2)
      ..scale(1, -1);
  }
  paintLoaded(
    canvas,
    rect,
    loaded,
    fit: BoxFit.values.byName(img.fit.name),
    alignment: img.alignment.flutter,
    repeat: ImageRepeat.values.byName(img.repeat.name),
    scale: img.scale,
    colorFilter: filter,
    opacity: p.opacity,
    flipX: img.flipX,
  );
  canvas.restore();
}

/// Paints [loaded] in [rect] by [fit] and [alignment]: a raster image with
/// Flutter's `paintImage`, an SVG as its picture.
void paintLoaded(
  Canvas canvas,
  Rect rect,
  LoadedImage loaded, {
  BoxFit fit = BoxFit.contain,
  Alignment alignment = Alignment.center,
  ImageRepeat repeat = ImageRepeat.noRepeat,
  double scale = 1,
  ColorFilter? colorFilter,
  double opacity = 1,
  bool flipX = false,
}) {
  if (rect.isEmpty) return;
  if (loaded.image case final info?) {
    paintImage(
      canvas: canvas,
      rect: rect,
      image: info.image,
      scale: info.scale * (scale <= 0 ? 1 : scale),
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      colorFilter: colorFilter,
      opacity: opacity.clamp(0.0, 1.0),
      flipHorizontally: flipX,
      filterQuality: FilterQuality.medium,
    );
    return;
  }
  final picture = loaded.picture;
  if (picture == null || picture.size.isEmpty) return;
  final fitted = applyBoxFit(fit, picture.size, rect.size);
  final dst = alignment.inscribe(fitted.destination, rect);
  final src = alignment.inscribe(fitted.source, Offset.zero & picture.size);
  canvas.save();
  canvas.clipRect(dst);
  final layered = colorFilter != null || opacity < 1;
  if (layered) {
    canvas.saveLayer(
        dst,
        Paint()
          ..colorFilter = colorFilter
          ..color = Color.fromRGBO(0, 0, 0, opacity.clamp(0.0, 1.0)));
  }
  if (flipX) {
    canvas
      ..translate(dst.center.dx * 2, 0)
      ..scale(-1, 1);
  }
  canvas
    ..translate(dst.left, dst.top)
    ..scale(dst.width / math.max(src.width, 1e-9), dst.height / math.max(src.height, 1e-9))
    ..translate(-src.left, -src.top)
    ..drawPicture(picture.picture);
  if (layered) canvas.restore();
  canvas.restore();
}
