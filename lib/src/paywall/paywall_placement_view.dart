import 'package:flutter/material.dart';

import '../codelessly.dart';
import 'paywall_controller.dart';

/// Placement-only widget: resolves and presents the published placement via
/// the SDK, calls [onResult] once, and never exposes a raw unverified CTA.
/// The widget owns its nested route and closes it when removed.
class CodelesslyPaywallPlacement extends StatefulWidget {
  final String placement;
  final ValueChanged<PaywallResult>? onResult;
  final Future<PaywallResult> Function(BuildContext context, String placement)?
  presenter;

  const CodelesslyPaywallPlacement({
    super.key,
    required this.placement,
    this.onResult,
    this.presenter,
  });

  @override
  State<CodelesslyPaywallPlacement> createState() => _PlacementState();
}

class _PlacementState extends State<CodelesslyPaywallPlacement> {
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final result =
          await (widget.presenter?.call(context, widget.placement) ??
              Codelessly.paywall(
                context: context,
                placement: widget.placement,
              ));
      if (mounted) widget.onResult?.call(result);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A route factory which returns a typed result and handles a back gesture as
/// cancellation. The nested presentation is removed before this route pops.
Route<PaywallResult> paywallRoute({
  required String placement,
  Future<PaywallResult> Function(BuildContext context, String placement)?
  presenter,
}) => MaterialPageRoute<PaywallResult>(
  builder: (_) => _PlacementRoute(placement: placement, presenter: presenter),
);

class _PlacementRoute extends StatefulWidget {
  final String placement;
  final Future<PaywallResult> Function(BuildContext context, String placement)?
  presenter;
  const _PlacementRoute({required this.placement, this.presenter});
  @override
  State<_PlacementRoute> createState() => _PlacementRouteState();
}

class _PlacementRouteState extends State<_PlacementRoute> {
  bool _exiting = false;
  @override
  Widget build(BuildContext context) => PopScope<PaywallResult>(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (didPop || _exiting || !mounted) return;
      _exiting = true;
      Navigator.of(context).pop(const PaywallResult(PaywallOutcome.cancelled));
    },
    child: Scaffold(
      body: CodelesslyPaywallPlacement(
        placement: widget.placement,
        presenter: widget.presenter,
        onResult: (result) {
          if (_exiting || !mounted) return;
          _exiting = true;
          Navigator.of(context).pop(result);
        },
      ),
    ),
  );
}
