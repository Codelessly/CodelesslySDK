import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logging/error_logger.dart';
import '../model/publish_source.dart';

/// A dialog UI that is displayed when something crashes in the SDK. This is
/// a graceful way of dealing with exceptions.
class CodelesslyErrorScreen extends StatefulWidget {
  final List<ErrorLog> errors;
  final PublishSource publishSource;

  const CodelesslyErrorScreen({
    super.key,
    required this.errors,
    required this.publishSource,
  });

  @override
  State<CodelesslyErrorScreen> createState() => _CodelesslyErrorScreenState();
}

class _CodelesslyErrorScreenState extends State<CodelesslyErrorScreen> {
  int selectedErrorIndex = 0;
  bool detailsVisible = false;

  @override
  Widget build(BuildContext context) {
    if (widget.errors.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentError = widget.errors[selectedErrorIndex];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Uh oh!',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (widget.errors.length > 1) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: selectedErrorIndex > 0
                          ? () => setState(() => selectedErrorIndex--)
                          : null,
                    ),
                    Text(
                      'Error ${selectedErrorIndex + 1} of ${widget.errors.length}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: selectedErrorIndex < widget.errors.length - 1
                          ? () => setState(() => selectedErrorIndex++)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Text(
                currentError.type,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                constraints:
                    const BoxConstraints(maxWidth: 500, maxHeight: 500),
                child: SingleChildScrollView(
                  primary: false,
                  padding: EdgeInsets.zero,
                  child: SelectionArea(
                    child: Column(
                      children: [
                        Text(
                          currentError.message,
                          textAlign: TextAlign.left,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (currentError.originalError != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .tertiaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.only(
                              top: 8,
                              left: 16,
                              right: 16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Error Details',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy),
                                      iconSize: 14,
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(
                                            text:
                                                '${currentError.originalError}\n\n${currentError.stackTrace}',
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        detailsVisible
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                      ),
                                      iconSize: 14,
                                      onPressed: () {
                                        setState(() {
                                          detailsVisible = !detailsVisible;
                                        });
                                      },
                                    )
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRect(
                                  child: AnimatedAlign(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutQuart,
                                    alignment: Alignment.topCenter,
                                    heightFactor: detailsVisible ? 1 : 0,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxHeight: 200,
                                      ),
                                      child: SingleChildScrollView(
                                        padding: EdgeInsets.zero,
                                        child: Text(
                                          '${currentError.originalError}\n\n${currentError.stackTrace}',
                                          textAlign: TextAlign.left,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
