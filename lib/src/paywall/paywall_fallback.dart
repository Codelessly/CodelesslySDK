import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'paywall_controller.dart';

/// Non-purchasing fallback: price and purchase controls stay absent until the
/// published layout and store metadata are available. Restore still requires
/// server verification through the supplied [PurchaseService].
class PaywallUnavailableFallback extends StatefulWidget {
  final VoidCallback onClose;
  final PurchaseService? restoreService;
  final Uri? termsUrl;
  final Uri? privacyUrl;
  final Future<bool> Function(Uri url)? openLegal;
  const PaywallUnavailableFallback({
    super.key,
    required this.onClose,
    this.restoreService,
    this.termsUrl,
    this.privacyUrl,
    this.openLegal,
  });

  @override
  State<PaywallUnavailableFallback> createState() =>
      _PaywallUnavailableFallbackState();
}

class _PaywallUnavailableFallbackState
    extends State<PaywallUnavailableFallback> {
  StreamSubscription<PaywallResult>? _subscription;
  bool _restoring = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _subscription = widget.restoreService?.updates.listen(
      (result) {
        if (!mounted) return;
        if (result.outcome == PaywallOutcome.restored &&
            result.entitlementId != null &&
            result.entitlementId!.isNotEmpty) {
          setState(() {
            _restoring = false;
            _message = 'Purchases restored';
          });
        } else if (result.outcome == PaywallOutcome.restoreNothing) {
          setState(() {
            _restoring = false;
            _message = 'No purchases found';
          });
        } else if (result.outcome == PaywallOutcome.failed) {
          setState(() {
            _restoring = false;
            _message = 'Restore unavailable. Try again later.';
          });
        }
      },
      onError: (Object _) {
        if (mounted) {
          setState(() {
            _restoring = false;
            _message = 'Restore unavailable. Try again later.';
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _restore() async {
    if (_restoring || widget.restoreService == null) return;
    setState(() {
      _restoring = true;
      _message = null;
    });
    try {
      await widget.restoreService!.restore();
    } catch (_) {
      if (mounted) {
        setState(() {
          _restoring = false;
          _message = 'Restore unavailable. Try again later.';
        });
      }
    }
  }

  Future<void> _legal(Uri? url) async {
    if (url == null || url.scheme != 'https' || url.host.isEmpty) return;
    final launch =
        widget.openLegal ??
        (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!await launch(url) && mounted) {
      setState(() {
        _message = 'Unable to open legal information';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Plans are temporarily unavailable',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Connect to the internet and try again later.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (_restoring) const CircularProgressIndicator(),
                TextButton(
                  onPressed: widget.restoreService == null || _restoring
                      ? null
                      : _restore,
                  child: const Text('Restore purchases'),
                ),
                if (_message != null)
                  Text(_message!, textAlign: TextAlign.center),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton(
                      onPressed: widget.termsUrl?.scheme == 'https'
                          ? () => _legal(widget.termsUrl)
                          : null,
                      child: const Text('Terms of service'),
                    ),
                    TextButton(
                      onPressed: widget.privacyUrl?.scheme == 'https'
                          ? () => _legal(widget.privacyUrl)
                          : null,
                      child: const Text('Privacy policy'),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: widget.onClose,
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
