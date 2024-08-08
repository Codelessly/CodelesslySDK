import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';

import '../constants.dart';
import '../utils/debouncer.dart';

/// A class that tracks statistics of various operations in the SDK.
abstract class StatTracker {
  /// The project ID to track the statistics for.
  String? projectId;

  bool get didInitialize => projectId != null;

  void init(String projectId) => this.projectId = projectId;

  /// Tracks one document read operation.
  Future<void> trackRead();

  /// Tracks one document write operation.
  Future<void> trackWrite();

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

  Future<void> sendBatch() => debouncer.run(
        () async {
          print('Sending stat batch: $statBatch');
          // No need to await it. Send it and immediately start collecting more
          // stats.
          ref.set(
            {
              for (final entry in statBatch.entries
                  .whereNot((entry) => entry.key == writesField))
                entry.key: FieldValue.increment(entry.value),

              // Account for this stat tracking operation as an additional write
              // operation.
              writesField:
                  FieldValue.increment((statBatch[writesField] ?? 0) + 1),
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
  Future<void> trackRead() {
    incrementField(readsField);
    return sendBatch();
  }

  @override
  Future<void> trackWrite() {
    incrementField(writesField);
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
