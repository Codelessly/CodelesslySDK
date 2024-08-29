import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:http/http.dart';
import 'package:meta/meta.dart';

import '../../codelessly_sdk.dart';
import '../utils/debouncer.dart';

/// A class that tracks statistics of various operations in the SDK.
abstract class StatTracker {
  Uri? serverUrl;

  /// The project ID to track the statistics for.
  String? projectId;

  bool get didInitialize => projectId != null;

  @mustCallSuper
  void init({
    required String projectId,
    required Uri serverUrl,
  }) {
    this.projectId = projectId;
    this.serverUrl = serverUrl;
  }

  /// Tracks one document read operation.
  Future<void> trackRead(String label);

  /// Tracks one document write operation.
  Future<void> trackWrite(String label);

  /// Tracks one bundle download operation from the CDN.
  Future<void> trackBundleDownload();

  /// Tracks one font download operation from the CDN.
  Future<void> trackFontDownload();

  /// Tracks one action operation.
  Future<void> trackAction(ActionModel action);

  /// Tracks one cloud action operation.
  Future<void> trackCloudAction(ActionModel action);
}

/// A [StatTracker] implementation that sends the stats to Codelessly's server.
final class CodelesslyStatTracker extends StatTracker {
  @override
  void init({
    required String projectId,
    required Uri serverUrl,
  }) {
    super.init(projectId: projectId, serverUrl: serverUrl);

    // Send a batch if stats were tracked while this wasn't initialized yet.
    if (statBatch.isNotEmpty && !disabled) {
      sendBatch();
    }
  }

  /// The field name to track the number of each operation.
  final Map<String, int> statBatch = {};

  /// Debounces the batch sending of the stats to prevent spamming the server
  /// with too many writes.
  final DeBouncer debouncer = DeBouncer(const Duration(seconds: 1));

  bool get disabled =>
      clientType == kCodelesslyEditor || projectId == null || serverUrl == null;

  /// Sends the batch of stats to the server.
  Future<void> sendBatch() => debouncer.run(
        () async {
          // TODO(Saad): Use an HTTP client.
          post(
            serverUrl!,
            body: jsonEncode({
              'projectId': projectId,
              'stats': {
                for (final entry in statBatch.entries
                    .whereNot((entry) => entry.key == writesField))
                  entry.key: entry.value,

                // Account for this stat tracking operation as an additional write
                // operation.
                writesField: (statBatch[writesField] ?? 0) + 1,
              },
            }),
          );
          statBatch.clear();
        },
        forceRunAfter: 20,
      );

  void incrementField(String field) {
    statBatch[field] = (statBatch[field] ?? 0) + 1;
  }

  @override
  Future<void> trackRead(String label) {
    if (disabled) return Future.value();

    incrementField('$readsField/$label');
    return sendBatch();
  }

  @override
  Future<void> trackWrite(String label) {
    if (disabled) return Future.value();

    incrementField('$writesField/$label');
    return sendBatch();
  }

  @override
  Future<void> trackBundleDownload() {
    if (disabled) return Future.value();

    incrementField(bundleDownloadsField);
    return sendBatch();
  }

  @override
  Future<void> trackFontDownload() {
    if (disabled) return Future.value();

    incrementField(fontDownloadsField);
    return sendBatch();
  }

  @override
  Future<void> trackAction(ActionModel action) {
    if (disabled) return Future.value();

    incrementField('$actionsField/${action.type.name}');
    return sendBatch();
  }

  @override
  Future<void> trackCloudAction(ActionModel action) {
    if (disabled) return Future.value();

    incrementField('$cloudActionsField/${action.type.name}');
    return sendBatch();
  }
}
