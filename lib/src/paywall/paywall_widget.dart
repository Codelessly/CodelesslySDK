import 'package:flutter/material.dart';

import '../codelessly.dart';
import '../ui/codelessly_widget.dart';
import 'paywall_controller.dart';

/// Displays an already-published layout, forwarding its reserved paywall.*
/// callFunction actions to the store controller. A product change rebuilds
/// CodelesslyWidget with fresh scoped data (including localized store prices).
class CodelesslyPaywall extends StatefulWidget {
  final String layoutId;
  final PaywallController controller;
  final Codelessly? codelessly;

  const CodelesslyPaywall({
    super.key,
    required this.layoutId,
    required this.controller,
    this.codelessly,
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
  Widget build(BuildContext context) => CodelesslyWidget(
    layoutID: widget.layoutId,
    codelessly: widget.codelessly,
    data: widget.controller.variables,
    functions: {
      'paywall.purchase': (context, scope, params) =>
          widget.controller.purchase(slot: params['slot'] as String?),
      'paywall.restore': (context, scope, params) =>
          widget.controller.restore(),
      'paywall.selectProduct': (context, scope, params) =>
          widget.controller.selectProduct(params['slot'] as String),
      'paywall.closePaywall': (context, scope, params) =>
          widget.controller.close(),
    },
  );
}
