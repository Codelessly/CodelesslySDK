// The media feature's image actions: capturing a screenshot (the layout, a
// node, or the app's capture scope) and preloading images.
import 'package:codelessly_api/media.dart';
import 'package:flutter/rendering.dart' show RenderBox;
import 'package:flutter/scheduler.dart' show SchedulerBinding;

import '../../render/paint/image_fill.dart' show preloadImage;
import '../../runtime/actions/capture.dart';
import '../../runtime/actions/runner.dart';
import '../../runtime/expressions/variable_writes.dart' show setVariableIn;

/// `captureScreenshot`: `${result}` is the image (a data URL and its size).
Future<void> captureScreenshotAction(ActionDef action, ActionRun run) async {
  run.result = await _captureScreenshot(action as CaptureScreenshotAction, run);
}

/// `preloadImages`: `${result}` counts the images loaded and failed.
Future<void> preloadImagesAction(ActionDef action, ActionRun run) async {
  run.result = await _preloadImages(action as PreloadImagesAction, run);
}

Future<Object?> _captureScreenshot(CaptureScreenshotAction a, ActionRun run) async {
  // Let a change the chain just made paint first.
  if (SchedulerBinding.instance.hasScheduledFrame) await SchedulerBinding.instance.endOfFrame;
  final tree = run.host.tree;
  final layout = CaptureRegistry.layoutOf(tree);
  final boundary = a.target == CaptureTarget.app ? CaptureRegistry.app ?? layout : layout ?? CaptureRegistry.app;
  if (boundary == null) throw StateError('Nothing to capture: no layout or capture scope is shown');
  RenderBox? box;
  if (a.target == CaptureTarget.node) {
    final id = run.text(a.node).trim();
    box = tree?.boxOf(id);
    if (box == null) throw StateError('No node [$id] on screen to capture');
  }
  return captureImage(boundary, box: box, pixelRatio: a.pixelRatio);
}

Future<Json> _preloadImages(PreloadImagesAction a, ActionRun run) async {
  // A list from an expression, or comma-separated text.
  final Object? value = a.urls.contains(r'${') ? run.evaluate(a.urls) : a.urls;
  final urls = <String>{
    ...switch (value) {
      final List<Object?> l => [for (final u in l) if (u != null) '$u'],
      final String t => t.split(','),
      _ => const <String>[],
    }.map((u) => u.trim()).where((u) => u.isNotEmpty),
  }.toList();
  final progress = a.progressVariable.trim();
  var done = 0, failed = 0;
  void report() {
    if (progress.isNotEmpty && !run.isCanceled) setVariableIn(run.context.scope, progress, urls.isEmpty ? 1.0 : done / urls.length);
  }

  report();
  await Future.wait(urls.map((u) async {
    final ok = await preloadImage(u);
    done++;
    if (!ok) failed++;
    report();
  }));
  return {'loaded': done - failed, 'failed': failed, 'total': urls.length};
}
