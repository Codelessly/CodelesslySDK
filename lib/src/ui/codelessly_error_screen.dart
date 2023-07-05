import 'package:flutter/material.dart';

import '../logging/error_handler.dart';
import '../model/publish_source.dart';

/// A dialog UI that is displayed when something crashes in the SDK. This is
/// a graceful way of dealing with exceptions.
class CodelesslyErrorScreen extends StatelessWidget {
  final dynamic exception;
  final PublishSource publishSource;

  const CodelesslyErrorScreen({
    super.key,
    required this.exception,
    required this.publishSource,
  });

  @override
  Widget build(BuildContext context) {
    if (publishSource.isPreview) return const SizedBox.shrink();

    final String message;
    String? title;
    if (exception is CodelesslyException) {
      final CodelesslyException ce = exception as CodelesslyException;
      title = ce.type.label;
      switch (ce.type) {
        case ErrorType.invalidAuthToken:
          message = '${ce.message ?? 'Invalid auth token!'}'
              '\nPlease change the token to a valid one.';
          break;
        case ErrorType.notAuthenticated:
          message = '${ce.message ?? 'Not authenticated!'}'
              '\nPlease authenticate with a valid token.';
          break;
        case ErrorType.projectNotFound:
          message = '${ce.message ?? 'Project not found!'}'
              '\nPlease check the provided auth token and try again.';
          break;
        case ErrorType.layoutNotFound:
          message = '${ce.message ?? 'Layout not found.'}'
              '\nAre you sure the layout ID is correct? If yes, are you sure '
              'you published it successfully through the Codelessly publish '
              'menu?';
          break;
        case ErrorType.cacheStoreException:
          message = '${ce.message ?? 'Failed to store value in cache.'}'
              '\nDoes this device have enough storage space?'
              '\nDoes this app have storage access?';
          break;
        case ErrorType.cacheLookupException:
          message = '${ce.message ?? 'Failed to look up a value in cache.'}'
              '\nDoes this app have storage access?'
              '\nIs the app up to date?';
          break;
        case ErrorType.cacheClearException:
          message = '${ce.message ?? 'Failed to clear cache.'}'
              '\nDoes this app have storage access?';
          break;
        case ErrorType.fontDownloadException:
          message = '${ce.message ?? 'Failed to download a font.'}'
              '\nPlease check your internet connection and try again.';
          break;
        case ErrorType.fontLoadException:
          message = '${ce.message ?? 'Failed to load a font.'}'
              '\nDoes this device have enough storage space?'
              '\nDoes this app have storage access?';
          break;
        case ErrorType.fileIoException:
          message = '${ce.message ?? 'Failed to read/write to storage.'}'
              '\nDoes this device have enough storage space?'
              '\nDoes this app have storage access?';
          break;
        case ErrorType.networkException:
          message = '${ce.message ?? 'Failed to connect to the internet.'}'
              '\nPlease check your internet connection and try again.';
          break;
        case ErrorType.assertionError:
          message = (exception as CodelesslyException).message ??
              'Assertion error!\nYou used the SDK incorrectly!.';
          break;
        case ErrorType.notInitializedError:
          message = (exception as CodelesslyException).message ??
              'Not initialized error!\nYou used the SDK incorrectly!.';
          break;
        case ErrorType.other:
          message = (exception as CodelesslyException).message ??
              'Unknown error!\nSorry this happened :(';
          break;
      }
    } else {
      message = 'An unexpected error happened!\n$exception';
    }
    return Material(
      color: Colors.white,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              'packages/codelessly_sdk/assets/codelessly_logo.png',
              width: 400,
              height: 400,
              color: Theme.of(context).primaryColor.withOpacity(0.1),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Uh oh!', style: Theme.of(context).textTheme.titleLarge),
                SizedBox(height: 16),
                if (title != null) ...[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 16),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  constraints: BoxConstraints(maxWidth: 500, maxHeight: 500),
                  child: SingleChildScrollView(
                    primary: false,
                    padding: EdgeInsets.zero,
                    child: SelectableText(
                      message,
                      textAlign: TextAlign.left,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
