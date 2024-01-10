import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../codelessly_sdk.dart';

class PassiveTextTransformer extends NodeWidgetTransformer<TextNode> {
  PassiveTextTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    TextNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    final Widget child = PassiveTextWidget(node: node, settings: settings);
    if (kIsTestLayout) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red, width: 2),
        ),
        child: child,
      );
    } else {
      return child;
    }
  }
}

class PassiveTextWidget extends StatefulWidget {
  final TextNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;
  final bool clickable;

  const PassiveTextWidget({
    super.key,
    required this.node,
    required this.settings,
    this.variablesOverrides = const [],
    this.clickable = true,
  });

  @override
  State<PassiveTextWidget> createState() => _PassiveTextWidgetState();
}

class _PassiveTextWidgetState extends State<PassiveTextWidget> {
  /// Map of URL to TapGestureRecognizer.
  Map<String, TapGestureRecognizer> tapGestureRecognizerRegistry = {};

  @override
  void initState() {
    super.initState();
    initTapGestureRecognizers();
  }

  @override
  void didUpdateWidget(covariant PassiveTextWidget oldWidget) {
    disposeTapGestureRecognizers();
    initTapGestureRecognizers();
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    disposeTapGestureRecognizers();
    super.dispose();
  }

  /// Initializes TapGestureRecognizer for each link that's not empty and
  /// stores in a [tapGestureRecognizerRegistry].
  void initTapGestureRecognizers() {
    if (!widget.clickable) return;
    widget.node.textMixedProps.forEach((property) {
      String link = property.link;
      if (link.isNotEmpty) {
        TapGestureRecognizer tapGestureRecognizer =
            TapGestureRecognizer(debugOwner: link)
              ..onTap = () => launchUrl(Uri.parse(link));
        tapGestureRecognizerRegistry[link] = tapGestureRecognizer;
      }
    });
  }

  /// Disposes TapGestureRecognizer and resets [tapGestureRecognizerRegistry].
  void disposeTapGestureRecognizers() {
    if (!widget.clickable) return;
    tapGestureRecognizerRegistry.forEach(
        (link, tapGestureRecognizer) => tapGestureRecognizer.dispose());
    tapGestureRecognizerRegistry = {};
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveNodeBox(
      node: widget.node,
      child: TextUtils.buildTextForTextNode(
        context,
        widget.node,
        tapGestureRecognizers: tapGestureRecognizerRegistry,
        variablesOverrides: widget.variablesOverrides,
        nullSubstitutionMode: widget.settings.nullSubstitutionMode,
        replaceVariablesWithSymbol: widget.settings.isPreview,
      ),
    );
  }
}
