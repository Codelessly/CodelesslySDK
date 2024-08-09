import 'package:cloud_firestore/cloud_firestore.dart';
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
  /// The Firestore document reference to track the statistics.
  DocumentReference get ref => FirebaseFirestore.instance
      .collection(statsCollection)
      .doc(projectId ?? lostStatsDoc);

  /// The field name to track the number of each operation.
  final Map<String, int> statBatch = {};

  /// Debounces the batch sending of the stats to prevent spamming the Firestore
  /// with too many writes.
  final DeBouncer debouncer = DeBouncer(const Duration(seconds: 1));

  /// Sends the batch of stats to the Firestore.
  Future<void> sendBatch() => debouncer.run(
        () async {
          // No need to await it. Send it and immediately start collecting more
          // stats.
          ref.set(
            {
              for (final entry in statBatch.entries)
                entry.key: FieldValue.increment(entry.value),

              // Account for this stat tracking operation as an additional write
              // operation.
              '$writesField/stats': FieldValue.increment(1),
            },
            SetOptions(merge: true),
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
