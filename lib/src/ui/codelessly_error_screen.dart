import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logging/error_handler.dart';
import '../model/publish_source.dart';

/// A dialog UI that is displayed when something crashes in the SDK. This is
/// a graceful way of dealing with exceptions.
class CodelesslyErrorScreen extends StatefulWidget {
  final dynamic exception;
  final PublishSource publishSource;

  const CodelesslyErrorScreen({
    super.key,
    required this.exception,
    required this.publishSource,
  });

  @override
  State<CodelesslyErrorScreen> createState() => _CodelesslyErrorScreenState();
}

class _CodelesslyErrorScreenState extends State<CodelesslyErrorScreen> {
  bool detailsVisible = false;

  @override
  Widget build(BuildContext context) {
    // if (!publishSource.isPreview) return const SizedBox.shrink();

    final String message;
    String? title;
    if (widget.exception is CodelesslyException) {
      final CodelesslyException ce = widget.exception as CodelesslyException;
      title = ce.type.label;
      switch (ce.type) {
        case ErrorType.invalidAuthToken:
          message = '${ce.message ?? 'Invalid auth token!'}'
              '\nPlease change the token to a valid one.';
        case ErrorType.notAuthenticated:
          message = '${ce.message ?? 'Not authenticated!'}'
              '\nPlease authenticate with a valid token.';
        case ErrorType.projectNotFound:
          message = '${ce.message ?? 'Project not found!'}'
              '\nPlease check the provided auth token and try again.';
        case ErrorType.layoutFailed:
          message = '${ce.message ?? 'Layout not found.'}'
              '\nAre you sure the layout ID is correct? If yes, are you sure '
              'you published it successfully through the Codelessly publish '
              'menu?';
        case ErrorType.cacheStoreException:
          message = '${ce.message ?? 'Failed to store value in cache.'}'
              '\nDoes this device have enough storage space?'
              '\nDoes this app have storage access?';
        case ErrorType.cacheLookupException:
          message = '${ce.message ?? 'Failed to look up a value in cache.'}'
              '\nDoes this app have storage access?'
              '\nIs the app up to date?';
        case ErrorType.cacheClearException:
          message = '${ce.message ?? 'Failed to clear cache.'}'
              '\nDoes this app have storage access?';
        case ErrorType.fontDownloadException:
          message = '${ce.message ?? 'Failed to download a font.'}'
              '\nPlease check your internet connection and try again.';
        case ErrorType.fontLoadException:
          message = '${ce.message ?? 'Failed to load a font.'}'
              '\nDoes this device have enough storage space?'
              '\nDoes this app have storage access?';
        case ErrorType.fileIoException:
          message = '${ce.message ?? 'Failed to read/write to storage.'}'
              '\nDoes this device have enough storage space?'
              '\nDoes this app have storage access?';
        case ErrorType.networkException:
          message = '${ce.message ?? 'Failed to connect to the internet.'}'
              '\nPlease check your internet connection and try again.';
        case ErrorType.assertionError:
          message = (widget.exception as CodelesslyException).message ??
              'Assertion error!\nYou used the SDK incorrectly!.';
        case ErrorType.notInitializedError:
          message = (widget.exception as CodelesslyException).message ??
              'Not initialized error!\nYou used the SDK incorrectly!.';
        case ErrorType.other:
          message = (widget.exception as CodelesslyException).message ??
              'Unknown error!\nSorry this happened :(';
      }
    } else {
      message =
          'An unexpected error happened!${widget.exception != null ? '\n${widget.exception}' : ''}';
    }
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
              if (title != null) ...[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
              ],
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
                          message,
                          textAlign: TextAlign.left,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (widget.exception case CodelesslyException ex)
                          if (ex.originalException != null) ...[
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
                                                  '${ex.originalException}\n\n${ex.stacktrace}',
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
                                      duration:
                                          const Duration(milliseconds: 300),
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
                                            '${ex.originalException}\n\n${ex.stacktrace}',
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
