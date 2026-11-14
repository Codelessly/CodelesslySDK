// Images painted by render objects: image fills and image icons. Raster
// images resolve through Flutter's image cache (`NetworkImage`,
// `MemoryImage` for data URLs); SVGs through flutter_svg's picture loader,
// their bytes fetched by the [ImageBytesLoader] of the tree that shows them
// (the render core doesn't fetch on its own).
// A render object that paints images mixes in [ImageClient]: it repaints
// when one it shows arrives.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../contracts.dart';
import '../convert.dart';
import '../node_tree.dart' show NodeBox;
import 'noise.dart' show noiseTileUrl;
import 'svg_fonts.dart';

/// Loads the image at [url] into Flutter's image cache (where image fills
/// find it), completing with whether it loaded. SVGs and data URLs aren't
/// preloaded (they're read when first drawn) and count as loaded.
Future<bool> preloadImage(String url) {
  final u = url.trim();
  if (u.isEmpty || u.contains(r'${')) return Future.value(false);
  if (LoadedImage._isSvg(u) || u.startsWith('data:')) return Future.value(true);
  final done = Completer<bool>();
  final stream = NetworkImage(u).resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener((_, _) {
    if (!done.isCompleted) done.complete(true);
    stream.removeListener(listener);
  }, onError: (Object _, StackTrace? _) {
    if (!done.isCompleted) done.complete(false);
    stream.removeListener(listener);
  });
  stream.addListener(listener);
  return done.future;
}

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

  /// Failed loads are tried again (after 1, 2, 4 s) while something still
  /// shows the image: a dropped connection mustn't blank the URL for every
  /// node that shares it for as long as one of them is on screen.
  static const maxAttempts = 4;
  int _attempts = 0;
  Timer? _retry;
  bool _released = false;

  void _fail() {
    failed = true;
    _changed();
    if (_attempts < maxAttempts && _clients.isNotEmpty && !_released) {
      _retry?.cancel();
      _retry = Timer(Duration(seconds: 1 << (_attempts - 1)), () {
        if (_released || _clients.isEmpty || ready) return;
        if (_listener != null) _stream?.removeListener(_listener!);
        _stream = null;
        _listener = null;
        if (!isSvg && !url.startsWith('data:')) {
          // Flutter's image cache keeps a failed completer: drop it.
          NetworkImage(url).evict();
        }
        _started = false;
        failed = false;
        _start();
      });
    }
  }

  void _start() {
    if (_started) return;
    _started = true;
    _attempts++;
    if (isSvg) {
      _loadSvg().then((p) {
        if (_released) {
          p.picture.dispose();
          return;
        }
        picture = p;
        _changed();
      }, onError: (Object _) => _fail());
      return;
    }
    final ImageProvider provider;
    if (url.startsWith('data:')) {
      try {
        provider = MemoryImage(UriData.parse(url).contentAsBytes());
      } on FormatException {
        _attempts = maxAttempts; // bad data: no point retrying
        _fail();
        return;
      }
    } else if (!_hasScheme(url)) {
      // A path with no scheme (a site's `images/7.jpg`, often built by a
      // binding) is read by the tree's loader, which knows the site's files.
      _fetch(url).then((bytes) {
        if (!_released) _resolve(MemoryImage(bytes));
      }, onError: (Object _) => _fail());
      return;
    } else {
      provider = NetworkImage(url);
    }
    _resolve(provider);
  }

  static bool _hasScheme(String url) => Uri.tryParse(url.trim())?.hasScheme ?? true;

  void _resolve(ImageProvider provider) {
    final stream = provider.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((info, _) {
      image?.dispose();
      image = info;
      _changed();
    }, onError: (Object _, StackTrace? _) => _fail());
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  static const _svgCacheSize = 256;
  static final Map<String, Uint8List> _svgBytes = {};

  @visibleForTesting
  static void debugClearSvgCache() => _svgBytes.clear();

  @visibleForTesting
  static bool debugSvgCached(String url) => _svgBytes.containsKey(url);

  /// Fetched by the loader of a render object that shows it; fails (and is
  /// tried again, as any failed load) while none of them has one.
  Future<Uint8List> _fetch(String url) {
    for (final c in _clients) {
      final loader = c._loader();
      if (loader != null) return loader.load(url);
    }
    return Future.error(StateError('No image loader for $url'));
  }

  // Fetched here rather than by flutter_svg's network loader, whose cache
  // leaves a failed request's error unhandled.
  Future<PictureInfo> _loadSvg() async {
    final Uint8List bytes;
    if (url.startsWith('data:')) {
      bytes = UriData.parse(url).contentAsBytes();
    } else {
      bytes = _svgBytes.remove(url) ?? await _fetch(url);
      // Most recently used last; a bounded set of SVGs (icons swapped by a
      // binding) is kept, so showing one again doesn't fetch it again.
      _svgBytes[url] = bytes;
      while (_svgBytes.length > _svgCacheSize) {
        _svgBytes.remove(_svgBytes.keys.first);
      }
    }
    // Its text in the site's fonts (SvgFonts): the families it names are
    // asked for and waited on, so the picture isn't recorded in a fallback.
    final resolved = SvgFonts.resolveBytes(bytes, defaultFamily: _textFamily(), url: url);
    if (!identical(resolved, bytes)) {
      await FontDemand.settled().timeout(const Duration(seconds: 5), onTimeout: () {});
    }
    return vg.loadPicture(SvgBytesLoader(Uint8List.fromList(resolved)), null);
  }

  /// The default font family of the trees that show this image (the
  /// theme's `fontFamily`): what an SVG's text is drawn in.
  String? _textFamily() {
    for (final c in _clients) {
      for (RenderObject? p = c; p != null; p = p.parent) {
        if (p is NodeBox) {
          if (p.tree.textDefault?.fontFamily case final String f) return f;
          break;
        }
      }
    }
    return null;
  }

  // Delivered after the current frame's work: an image already in the
  // cache arrives synchronously, possibly while a client paints.
  void _changed() => scheduleMicrotask(() {
        for (final c in _clients.toList()) {
          c._imageChanged();
        }
      });

  void _release() {
    _released = true;
    _retry?.cancel();
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

  /// Whether an image a render object shows is still loading.
  static bool get loading => _entries.values.any((e) => e._started && !e.ready && !e.failed);

  /// Completes once no shown image is loading, or after [timeout]: a
  /// screenshot taken then has every icon and image that will arrive.
  static Future<void> settled({Duration timeout = const Duration(seconds: 5)}) async {
    final end = DateTime.now().add(timeout);
    while (loading && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }
}

/// A render object that paints images: it holds the ones it shows while
/// attached and repaints when they arrive.
mixin ImageClient on RenderObject {
  final Map<String, LoadedImage> _images = {};
  Set<String> _wanted = const {};

  final Map<String, String> _reported = {};
  bool _statusQueued = false;

  /// Fetches the images Flutter's image cache doesn't (SVG documents) when
  /// this object isn't inside a tree that has a loader
  /// ([RenderTree.imageLoader]): an icon in an overlay, or in a widget used
  /// on its own.
  ImageBytesLoader? imageLoader;

  /// The loader of the nearest tree around this object, else its own.
  ImageBytesLoader? _loader() {
    for (RenderObject? p = this; p != null; p = p.parent) {
      if (p is NodeBox) {
        final loader = p.tree.imageLoader;
        if (loader != null) return loader;
      }
    }
    return imageLoader;
  }

  /// Actual fetch state for each image URL; delivered outside layout and
  /// paint so a reaction can safely change another node's bindings.
  void Function(String status, String url)? onImageState;

  void _imageChanged() {
    markNeedsPaint();
    _queueStatus();
    // On the web (CanvasKit) the first draw of a just-decoded image can't
    // use its mipmaps yet, so a big image drawn small comes out aliased
    // until something repaints it; a Flutter `Image` that repaints later
    // looks smoother. Paint once more after the frame that shows it, so a
    // still screen settles on the filtered image.
    if (repaintAfterLoad) _repaintAfterFrame();
  }

  /// Whether a client paints once more after an image arrives (on the web).
  @visibleForTesting
  static bool repaintAfterLoad = kIsWeb;

  bool _repaintQueued = false;

  void _repaintAfterFrame() {
    if (_repaintQueued) return;
    _repaintQueued = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _repaintQueued = false;
      if (attached) markNeedsPaint();
    });
  }

  void _queueStatus() {
    if (_statusQueued || onImageState == null) return;
    _statusQueued = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _statusQueued = false;
      if (!attached) return;
      _reported.removeWhere((url, _) => !_wanted.contains(url));
      for (final url in _wanted.toList()) {
        final image = _images[url];
        final status = image?.failed == true
            ? 'error'
            : image?.ready == true
            ? 'loaded'
            : 'loading';
        if (_reported[url] == status) continue;
        _reported[url] = status;
        onImageState?.call(status, url);
      }
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

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

  /// Whether [url] couldn't be loaded.
  bool imageFailed(String? url) => url != null && _images[url]?.failed == true;

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
    _queueStatus();
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

/// The URL an image paint shows (a noise paint: its tile's).
String? imageUrlOf(api.Paint p) => switch (p.type) {
      api.PaintType.image => p.image?.url,
      api.PaintType.noise => noiseTileUrl(p),
      _ => null,
    };

/// Paints noise paint [p] in [rrect]: its tile repeated from the box's top
/// left (a shader: no seams between tiles), its opacity and blend mode
/// applied, inside the rounded corners.
void paintNoiseFill(Canvas canvas, RRect rrect, api.Paint p, ImageClient client) {
  final url = noiseTileUrl(p);
  final info = client.imageFor(url)?.image;
  if (info == null) return;
  final box = rrect.outerRect;
  final paint = Paint()
    ..shader = ImageShader(info.image, TileMode.repeated, TileMode.repeated,
        Matrix4.translationValues(box.left, box.top, 0).storage, filterQuality: FilterQuality.none)
    ..color = Color.fromRGBO(0, 0, 0, p.opacity.clamp(0.0, 1.0))
    ..blendMode = blendMode(p.blendMode);
  if (rrect.isRect) {
    canvas.drawRect(box, paint);
  } else {
    canvas.drawRRect(rrect, paint);
  }
}

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

/// Whether an image or icon drawn under [root] (its render subtree) is
/// still loading: what a capture of it waits for.
bool imagesPendingUnder(RenderObject root) {
  var pending = false;
  void visit(RenderObject o) {
    if (pending) return;
    if (o is ImageClient && o.imagesPending) {
      pending = true;
      return;
    }
    o.visitChildren(visit);
  }

  visit(root);
  return pending;
}
