import 'dart:async';
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import '../../codelessly_sdk.dart';
import '../utils/debouncer.dart';

const _kDisableStatReporting = false;

/// A class that tracks statistics of various operations in the SDK.
abstract class StatTracker {
  final http.Client client;

  StatTracker({required this.client});

  Uri? serverUrl;

  /// The project ID to track the statistics for.
  String? projectId;

  /// Determines whether this tracker has been initialized.
  bool get didInitialize => projectId != null;

  @mustCallSuper
  void init({
    required String projectId,
    required Uri serverUrl,
  }) {
    this.projectId = projectId;
    this.serverUrl = serverUrl;
  }

  /// Tracks one complete visual view of a Codelessly CloudUI Layout.
  Future<void> trackView();

  /// Tracks one document read operation.
  Future<void> trackRead(String label);

  /// Tracks one document write operation.
  Future<void> trackWrite(String label);

  /// Tracks one complete populated layout download operation.
  Future<void> trackPopulatedLayoutDownload(String label);

  /// Tracks a layout as being viewed, determined by the life cycle of the
  /// CodelesslyWidget.
  Future<void> trackLayoutView(String label);

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
  CodelesslyStatTracker({required super.client});

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
      _kDisableStatReporting ||
      clientType == kCodelesslyEditor ||
      projectId == null ||
      serverUrl == null;

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

  @override
  Future<void> trackView() {
    if (disabled) return Future.value();

    incrementField(viewsField);
    return sendBatch();
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
  Future<void> trackPopulatedLayoutDownload(String label) {
    if (disabled) return Future.value();

    incrementField('$populatedLayoutDownloadsField/$label');
    return sendBatch();
  }

  @override
  Future<void> trackLayoutView(String label) {
    if (disabled) return Future.value();

    incrementField('$layoutViewsField/$label');
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
