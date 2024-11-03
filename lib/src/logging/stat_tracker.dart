import 'dart:async';
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import '../../codelessly_sdk.dart';
import '../utils/debouncer.dart';

/// A class that tracks statistics of various operations in the SDK.
///
/// This tracker sends stats to Codelessly's server to help monitor usage and performance.
/// Stats are batched and debounced to prevent overwhelming the server with requests.
///
/// Tracking can be disabled globally via [_kDisableStatReporting], per instance via [enabled],
/// or automatically when running in the editor via [clientType].
class StatTracker {
  final http.Client client;

  /// Whether this tracker should collect and send stats.
  /// Defaults to true. Set to false to disable all tracking for this instance.
  final bool enabled;

  StatTracker({
    required this.client,
    this.enabled = true,
  });

  Uri? serverUrl;

  /// The project ID to track the statistics for.
  String? projectId;

  /// Determines whether this tracker has been initialized.
  bool get didInitialize => projectId != null;

  /// The field name to track the number of each operation.
  final Map<String, int> statBatch = {};

  /// Debounces the batch sending of the stats to prevent spamming the server
  /// with too many writes.
  final DeBouncer debouncer = DeBouncer(const Duration(seconds: 1));

  bool get disabled => !enabled || projectId == null || serverUrl == null;

  @mustCallSuper
  void init({
    required String projectId,
    required Uri serverUrl,
  }) {
    this.projectId = projectId;
    this.serverUrl = serverUrl;

    // Send a batch if stats were tracked while this wasn't initialized yet.
    if (statBatch.isNotEmpty && !disabled) {
      sendBatch();
    }
  }

  /// Sends the batch of stats to the server.
  Future<void> sendBatch() => debouncer.run(
        () async {
          unawaited(client.post(
            serverUrl!,
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode({
              'projectId': projectId,
              'stats': statBatch,
            }),
          ));
          statBatch.clear();
        },
        forceRunAfter: 20,
      );

  void incrementField(String field) {
    statBatch[field] = (statBatch[field] ?? 0) + 1;
  }

  /// Tracks one complete visual view of a Codelessly CloudUI Layout.
  Future<void> trackView() {
    if (disabled) return Future.value();

    incrementField(viewsField);
    return sendBatch();
  }

  /// Tracks one document read operation.
  Future<void> trackRead(String label) {
    if (disabled) return Future.value();

    incrementField('$readsField/$label');
    return sendBatch();
  }

  /// Tracks one document write operation.
  Future<void> trackWrite(String label) {
    if (disabled) return Future.value();

    incrementField('$writesField/$label');
    return sendBatch();
  }

  /// Tracks one complete populated layout download operation.
  Future<void> trackPopulatedLayoutDownload(String label) {
    if (disabled) return Future.value();

    incrementField('$populatedLayoutDownloadsField/$label');
    return sendBatch();
  }

  /// Tracks a layout as being viewed, determined by the life cycle of the
  /// CodelesslyWidget.
  Future<void> trackLayoutView(String label) {
    if (disabled) return Future.value();

    incrementField('$layoutViewsField/$label');
    return sendBatch();
  }

  /// Tracks one bundle download operation from the CDN.
  Future<void> trackBundleDownload() {
    if (disabled) return Future.value();

    incrementField(bundleDownloadsField);
    return sendBatch();
  }

  /// Tracks one font download operation from the CDN.
  Future<void> trackFontDownload() {
    if (disabled) return Future.value();

    incrementField(fontDownloadsField);
    return sendBatch();
  }

  /// Tracks one action operation.
  Future<void> trackAction(ActionModel action) {
    if (disabled) return Future.value();

    incrementField('$actionsField/${action.type.name}');
    return sendBatch();
  }

  /// Tracks one cloud action operation.
  Future<void> trackCloudAction(ActionModel action) {
    if (disabled) return Future.value();

    incrementField('$cloudActionsField/${action.type.name}');
    return sendBatch();
  }
}
