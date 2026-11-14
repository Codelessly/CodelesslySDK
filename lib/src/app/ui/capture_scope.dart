// The widget a host puts around its app so a `captureScreenshot` action
// with `target: app` captures all of it.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../runtime/actions/capture.dart';

/// [key]'s repaint boundary, for [CaptureRegistry].
RenderRepaintBoundary? boundaryOf(GlobalKey key) {
  final r = key.currentContext?.findRenderObject();
  return r is RenderRepaintBoundary ? r : null;
}

/// Makes [child] what `captureScreenshot` with `target: app` captures.
class CodelesslyCaptureScope extends StatefulWidget {
  const CodelesslyCaptureScope({super.key, required this.child});

  final Widget child;

  @override
  State<CodelesslyCaptureScope> createState() => _CodelesslyCaptureScopeState();
}

class _CodelesslyCaptureScopeState extends State<CodelesslyCaptureScope> {
  final GlobalKey _key = GlobalKey(debugLabel: 'Codelessly capture scope');

  RenderRepaintBoundary? _find() => boundaryOf(_key);

  @override
  void initState() {
    super.initState();
    CaptureRegistry.addApp(_find);
  }

  @override
  void dispose() {
    CaptureRegistry.removeApp(_find);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(key: _key, child: widget.child);
}
