import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../render/layout/design_scroll.dart';
import '../../render/node_tree.dart';
import '../../runtime/actions/runner.dart';
import '../../services/printing.dart' show PrintService;

/// Captures one fully visible node. Move a containing viewport first so a
/// badge larger than the visible part is never silently printed truncated.
Future<Uint8List> capturePrintNode(NodeBox box) async {
  if (!box.attached || !box.hasSize || box.size.isEmpty) {
    throw StateError('The print node is not rendered.');
  }
  RenderObject? ancestor = box.parent;
  while (ancestor != null) {
    if (ancestor is RenderDesignScroll && ancestor.interactive) {
      final rect = MatrixUtils.transformRect(
        box.getTransformTo(ancestor),
        ui.Offset.zero & box.size,
      );
      if (ancestor.axis == Axis.vertical) {
        ancestor.jumpBy(rect.top);
      } else {
        ancestor.jumpBy(rect.left);
      }
    }
    ancestor = ancestor.parent;
  }
  SchedulerBinding.instance.scheduleFrame();
  await SchedulerBinding.instance.endOfFrame;
  final view = RendererBinding.instance.renderViews.first;
  final rect = MatrixUtils.transformRect(
    box.getTransformTo(view),
    ui.Offset.zero & box.size,
  );
  final window = view.paintBounds;
  if (!window.contains(rect.topLeft) ||
      !window.inflate(.01).contains(rect.bottomRight)) {
    throw StateError(
      'The print node must fit in the viewport: $rect / $window.',
    );
  }
  // Check clipping ancestors too, rather than capturing adjacent UI in place
  // of the part of a badge outside its own scroll viewport.
  ancestor = box.parent;
  while (ancestor != null) {
    if (ancestor is RenderDesignScroll) {
      final viewport = MatrixUtils.transformRect(
        ancestor.getTransformTo(view),
        ui.Offset.zero & ancestor.size,
      );
      if (!viewport.inflate(.01).contains(rect.topLeft) ||
          !viewport.inflate(.01).contains(rect.bottomRight)) {
        throw StateError('The print node must fit in its scroll viewport.');
      }
    }
    ancestor = ancestor.parent;
  }
  // debugLayer is null in release builds. Flutter keeps its composited view
  // layer in every build; capture that retained layer without repainting or
  // moving the attached node into a second render tree.
  // ignore: invalid_use_of_protected_member
  final layer = view.layer;
  if (layer is! OffsetLayer) throw StateError('The app has not painted yet.');
  final image = await layer.toImage(
    rect,
    pixelRatio: 2 / view.configuration.devicePixelRatio,
  );
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

Future<void> printNodeAction(String nodeId, ActionRun run) async {
  final box = run.host.tree?.boxOf(nodeId);
  if (box == null) {
    throw StateError('There is no rendered print node "$nodeId".');
  }
  final printing = run.service<PrintService>();
  if (printing == null) throw StateError('Printing needs Services.');
  final png = await capturePrintNode(box);
  run.result = {'requested': await printing.printPng(png)};
}
