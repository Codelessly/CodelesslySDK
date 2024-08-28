import 'package:codelessly_api/codelessly_api.dart';

import '../constants.dart';
import '../utils/debouncer.dart';

/// A class that tracks statistics of various operations in the SDK.
abstract class StatTracker {
  /// The project ID to track the statistics for.
  String? projectId;

  bool get didInitialize => projectId != null;

  void init(String projectId) => this.projectId = projectId;

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

/// A [StatTracker] implementation that utilizes Firestore to track the
/// statistics.
final class FirestoreStatTracker extends StatTracker {

  /// The field name to track the number of each operation.
  final Map<String, int> statBatch = {};

  /// Debounces the batch sending of the stats to prevent spamming the Firestore
  /// with too many writes.
  final DeBouncer debouncer = DeBouncer(const Duration(seconds: 1));

  /// Sends the batch of stats to the Firestore.
  Future<void> sendBatch() => debouncer.run(
        () async {
          // TODO: call api endpoint.
          statBatch.clear();
        },
        forceRunAfter: 20,
      );

  void incrementField(String field) {
    statBatch[field] = (statBatch[field] ?? 0) + 1;
  }

  @override
  Future<void> trackRead(String label) {
    incrementField('$readsField/$label');
    return sendBatch();
  }

  @override
  Future<void> trackWrite(String label) {
    incrementField('$writesField/$label');
    return sendBatch();
  }

  @override
  Future<void> trackBundleDownload() {
    incrementField(bundleDownloadsField);
    return sendBatch();
  }

  @override
  Future<void> trackFontDownload() {
    incrementField(fontDownloadsField);
    return sendBatch();
  }

  @override
  Future<void> trackAction(ActionModel action) {
    incrementField('$actionsField/${action.type.name}');
    return sendBatch();
  }

  @override
  Future<void> trackCloudAction(ActionModel action) {
    incrementField('$cloudActionsField/${action.type.name}');
    return sendBatch();
  }
}
