import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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
        TapGestureRecognizer tapGestureRecognizer = TapGestureRecognizer(
          debugOwner: link,
        )..onTap = () => FunctionsRepository.openLink(link);
        tapGestureRecognizerRegistry[link] = tapGestureRecognizer;
      }
    });
  }

  /// Disposes TapGestureRecognizer and resets [tapGestureRecognizerRegistry].
  void disposeTapGestureRecognizers() {
    if (!widget.clickable) return;
    tapGestureRecognizerRegistry.forEach(
      (link, tapGestureRecognizer) => tapGestureRecognizer.dispose(),
    );
    tapGestureRecognizerRegistry = {};
  }

  @override
  Widget build(BuildContext context) {
    return TextNodeBox(
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

/// Sizes a text node's box and places its text inside it.
///
/// Width follows the node's horizontal fit, like any other leaf
/// ([AdaptiveSizeFitBox]).
///
/// Height: a fixed (or locked or flexible) height is the box's minimum, not
/// its exact size. The editor measured the text with its fonts at the design
/// width, but at runtime the text can wrap to more lines (a narrower screen,
/// another font, a larger text scale). The box then grows to fit the text
/// as far as the incoming constraints allow, and whatever contains it grows
/// with it or reports an overflow, instead of the lines being clipped
/// without a trace. Where the parent fixes the height (tight constraints),
/// that height still wins. Shrink-wrap hugs the text and expanded fills the
/// parent, as before.
///
/// The text sits inside that box per its horizontal and vertical text
/// alignment, so a text box larger than its text (pinned on all sides,
/// expanded, or a fixed size) shows it centered, at the bottom, and so on.
class TextNodeBox extends StatelessWidget {
  final TextNode node;
  final Widget child;

  const TextNodeBox({super.key, required this.node, required this.child});

  /// Where text sits in its box for [node]'s text alignment. Start and end
  /// follow the text direction, like [TextAlign.start] and [TextAlign.end].
  static AlignmentGeometry alignmentOf(TextNode node) {
    final double y = switch (node.textAlignVertical) {
      TextAlignVerticalEnum.top => -1,
      TextAlignVerticalEnum.center => 0,
      TextAlignVerticalEnum.bottom => 1,
    };
    return switch (node.textAlignHorizontal) {
      TextAlignHorizontalEnum.left ||
      TextAlignHorizontalEnum.justified => Alignment(-1, y),
      TextAlignHorizontalEnum.center => Alignment(0, y),
      TextAlignHorizontalEnum.right => Alignment(1, y),
      TextAlignHorizontalEnum.start => AlignmentDirectional(-1, y),
      TextAlignHorizontalEnum.end => AlignmentDirectional(1, y),
    };
  }

  @override
  Widget build(BuildContext context) {
    final SizeFit hFit = node.horizontalFit;
    final SizeFit vFit = node.verticalFit;
    final bool minHeight =
        vFit != SizeFit.shrinkWrap && vFit != SizeFit.expanded;

    Widget box = Align(
      alignment: alignmentOf(node),
      // Hug the text on an axis that does not fill its parent, so a loose
      // parent does not stretch the box; tight constraints still size it.
      widthFactor: hFit == SizeFit.shrinkWrap ? 1 : null,
      heightFactor: vFit == SizeFit.expanded ? null : 1,
      child: child,
    );
    if (minHeight) {
      box = ConstrainedBox(
        constraints: BoxConstraints(minHeight: node.basicBoxLocal.height),
        child: box,
      );
    }
    return SizedBox(
      width: switch (hFit) {
        SizeFit.shrinkWrap => null,
        SizeFit.expanded => double.infinity,
        _ => node.basicBoxLocal.width,
      },
      height: vFit == SizeFit.expanded ? double.infinity : null,
      child: box,
    );
  }
}
