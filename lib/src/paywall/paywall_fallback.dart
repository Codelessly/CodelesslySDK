import 'package:flutter/material.dart';

/// Bundled safe fallback: no product price or purchase button can be shown
/// until store metadata and a compliant published layout are available.
class PaywallUnavailableFallback extends StatelessWidget {
  final VoidCallback onClose;
  const PaywallUnavailableFallback({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Plans are temporarily unavailable'),
            const Text('Connect to the internet and try again later.'),
            TextButton(onPressed: onClose, child: const Text('Close')),
          ],
        ),
      ),
    ),
  );
}
