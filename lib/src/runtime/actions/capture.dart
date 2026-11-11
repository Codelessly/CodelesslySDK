// Capturing what is on screen as a PNG (the captureScreenshot action): a
// shown layout, one of its nodes, or the whole host app when the host wraps
// it in a CodelesslyCaptureScope. Pure Flutter: RenderRepaintBoundary.toImage.
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../render/node_tree.dart';

/// Where captures come from: each shown layout's boundary (by its node
/// tree) and the app's capture scope.
abstract final class CaptureRegistry {
  static final Expando<GlobalKey> _layouts = Expando('codelessly capture boundary');
  static final List<GlobalKey> _apps = [];

  /// Layout [tree] is painted in the [RepaintBoundary] keyed [key].
  static void bindLayout(NodeTree tree, GlobalKey key) => _layouts[tree] = key;

  /// The boundary layout [tree] is painted in, while shown.
  static RenderRepaintBoundary? layoutOf(NodeTree? tree) => tree == null ? null : _boundary(_layouts[tree]);

  /// The innermost [CodelesslyCaptureScope] shown (the app's), if any.
  static RenderRepaintBoundary? get app {
    for (final key in _apps.reversed) {
      final b = _boundary(key);
      if (b != null) return b;
    }
    return null;
  }

  static RenderRepaintBoundary? _boundary(GlobalKey? key) {
    final r = key?.currentContext?.findRenderObject();
    return r is RenderRepaintBoundary && r.attached ? r : null;
  }
}

/// Wraps the host app (or any part of it) so that a `captureScreenshot`
/// action with `target: app` captures it, including what isn't a Codelessly
/// layout. `CodelesslyOverlay` adds one.
class CodelesslyCaptureScope extends StatefulWidget {
  const CodelesslyCaptureScope({super.key, required this.child});

  final Widget child;

  @override
  State<CodelesslyCaptureScope> createState() => _CodelesslyCaptureScopeState();
}

class _CodelesslyCaptureScopeState extends State<CodelesslyCaptureScope> {
  final GlobalKey _key = GlobalKey(debugLabel: 'Codelessly capture scope');

  @override
  void initState() {
    super.initState();
    CaptureRegistry._apps.add(_key);
  }

  @override
  void dispose() {
    CaptureRegistry._apps.remove(_key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(key: _key, child: widget.child);
}

/// [boundary] (or, with [box], the part of it [box] covers) as a PNG:
/// `{"image": "data:image/png;base64,...", "width", "height"}`, in pixels at
/// [pixelRatio] (0: the device's).
Future<Map<String, Object?>> captureImage(RenderRepaintBoundary boundary, {RenderBox? box, double pixelRatio = 0}) async {
  final ratio = pixelRatio > 0 ? pixelRatio : _devicePixelRatio();
  var image = await boundary.toImage(pixelRatio: ratio);
  try {
    if (box != null && box.attached && box.hasSize) {
      final topLeft = box.localToGlobal(Offset.zero, ancestor: boundary);
      final rect = (topLeft & box.size).intersect(Offset.zero & boundary.size);
      if (rect.isEmpty) throw StateError('The node is not on screen');
      final source = Rect.fromLTRB(rect.left * ratio, rect.top * ratio, rect.right * ratio, rect.bottom * ratio);
      final width = source.width.round().clamp(1, 1 << 15), height = source.height.round().clamp(1, 1 << 15);
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
          image, source, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..filterQuality = FilterQuality.high);
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(width, height);
      picture.dispose();
      image.dispose();
      image = cropped;
    }
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('The capture could not be encoded');
    return {
      'image': 'data:image/png;base64,${base64Encode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes))}',
      'width': image.width,
      'height': image.height,
    };
  } finally {
    image.dispose();
  }
}

double _devicePixelRatio() {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  return views.isEmpty ? 1 : views.first.devicePixelRatio;
}
