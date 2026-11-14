// Capturing what is on screen as a PNG (the captureScreenshot action): a
// shown layout, one of its nodes, or the whole host app when the host wraps
// it in a CodelesslyCaptureScope. Pure Flutter: RenderRepaintBoundary.toImage.
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../render/node_tree.dart';

/// Finds a repaint boundary when a capture is asked for (it may not be laid
/// out, or there, before).
typedef BoundaryFinder = RenderRepaintBoundary? Function();

/// Where a `captureScreenshot` action finds what to capture: the boundary
/// around each layout shown, and the ones the host put around its app. The
/// host registers them (a `CodelesslyWidget`, a `CodelesslyCaptureScope`);
/// the action only reads.
abstract final class CaptureRegistry {
  static final Expando<BoundaryFinder> _layouts = Expando('codelessly capture boundary');
  static final List<BoundaryFinder> _apps = [];

  /// The boundary around the layout [tree] draws.
  static void bindLayout(RenderTree tree, BoundaryFinder find) => _layouts[tree] = find;

  /// The boundary around [tree]'s layout, when it is on screen.
  static RenderRepaintBoundary? layoutOf(RenderTree? tree) => tree == null ? null : _attached(_layouts[tree]);

  /// Adds a boundary around the whole app; the last one added that is on
  /// screen is [app].
  static void addApp(BoundaryFinder find) => _apps.add(find);

  static void removeApp(BoundaryFinder find) => _apps.remove(find);

  /// The innermost app boundary on screen.
  static RenderRepaintBoundary? get app {
    for (final find in _apps.reversed) {
      final b = _attached(find);
      if (b != null) return b;
    }
    return null;
  }

  static RenderRepaintBoundary? _attached(BoundaryFinder? find) {
    final r = find?.call();
    return r != null && r.attached ? r : null;
  }
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
  final views = ui.PlatformDispatcher.instance.views;
  return views.isEmpty ? 1 : views.first.devicePixelRatio;
}
