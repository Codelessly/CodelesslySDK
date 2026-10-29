import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../codelessly.dart';
import '../ui/codelessly_widget.dart';
import 'paywall_controller.dart';

/// Displays an already-published layout, forwarding native paywall actions
/// to the scoped controller. A product change rebuilds
/// CodelesslyWidget with fresh scoped data (including localized store prices).
class CodelesslyPaywall extends StatefulWidget {
  final String layoutId;
  final PaywallController controller;
  final Codelessly? codelessly;
  final VoidCallback? onView;

  const CodelesslyPaywall({
    super.key,
    required this.layoutId,
    required this.controller,
    this.codelessly,
    this.onView,
  });

  @override
  State<CodelesslyPaywall> createState() => _CodelesslyPaywallState();
}

class _CodelesslyPaywallState extends State<CodelesslyPaywall> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updated);
    widget.controller.load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onView?.call();
    });
  }

  void _updated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updated);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ChangeNotifierProvider<PaywallController>.value(
        value: widget.controller,
        child: CodelesslyWidget(
          layoutID: widget.layoutId,
          codelessly: widget.codelessly,
          data: widget.controller.variables,
        ),
      );
}
