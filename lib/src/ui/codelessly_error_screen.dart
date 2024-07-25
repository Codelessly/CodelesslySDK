import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../codelessly_sdk.dart';

/// A dialog UI that is displayed when something crashes in the SDK. This is
/// a graceful way of dealing with exceptions.
class CodelesslyErrorScreen extends StatefulWidget {
  final Object? exception;
  final StackTrace trace;
  final PublishSource publishSource;

  const CodelesslyErrorScreen({
    super.key,
    required this.exception,
    required this.trace,
    required this.publishSource,
  });

  @override
  State<CodelesslyErrorScreen> createState() => _CodelesslyErrorScreenState();
}

class _CodelesslyErrorScreenState extends State<CodelesslyErrorScreen> {
  bool detailsVisible = false;

  @override
  Widget build(BuildContext context) {
    // Don't show the error screen in production.
    // if (!widget.publishSource.isPreview) {
    //   return const SizedBox.shrink();
    // }

    final String title;
    final String message;
    if (widget.exception is CodelesslyException) {
      final CodelesslyException ce = widget.exception as CodelesslyException;
      title = ce.type.title;
      message = ce.message;
    } else {
      title = ErrorType.other.title;
      message = widget.exception.toString();
    }

    const surface = Colors.white;
    const onSurface = Colors.black;
    const errorColor = Colors.grey;
    const onError = Colors.grey;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            border: Border.all(
              color: errorColor,
              width: 2,
            ),
            color: surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_rounded,
                      color: errorColor,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: onSurface),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            textAlign: TextAlign.left,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: onSurface),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Material(
                  type: MaterialType.transparency,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setState(() {
                              detailsVisible = !detailsVisible;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16, right: 8),
                            child: Row(
                              children: [
                                Icon(
                                  detailsVisible
                                      ? Icons.arrow_drop_down_outlined
                                      : Icons.arrow_right_outlined,
                                  color: onError,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Details',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(color: onError),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  iconSize: 14,
                                  color: onError,
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(
                                        text:
                                            '''$title\n$message\n\n${widget.trace}''',
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRect(
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutQuart,
                            alignment: Alignment.topCenter,
                            heightFactor: detailsVisible ? 1 : 0,
                            child: Container(
                              constraints: const BoxConstraints(
                                maxHeight: 200,
                              ),
                              child: Column(
                                children: [
                                  const Divider(
                                    height: 1,
                                    color: onError,
                                  ),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.only(
                                        left: 16,
                                        right: 16,
                                        top: 16,
                                      ),
                                      child: Text(
                                        '${widget.trace}',
                                        textAlign: TextAlign.left,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: onError,
                                              fontSize: 10,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
