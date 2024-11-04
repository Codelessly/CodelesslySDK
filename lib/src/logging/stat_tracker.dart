import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import '../utils/debouncer.dart';

/// A class that tracks statistics of various operations in the SDK.
///
/// This tracker sends stats to Codelessly's server to help monitor usage and performance.
/// Stats are batched and debounced to prevent overwhelming the server with requests.
///
/// Tracking can be disabled per instance via [enabled].
class StatTracker {
  static final StatTracker _instance = StatTracker._();

  /// The global instance of the StatTracker
  static StatTracker get instance => _instance;

  final http.Client client = http.Client();

  /// Whether this tracker should collect and send stats.
  /// Defaults to true. Set to false to disable all tracking for this instance.
  final bool enabled;

  StatTracker._({this.enabled = true});

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

  /// Sends the batch of stats to the server with retry logic.
  Future<void> sendBatch() => debouncer.run(
        () async {
          int maxRetries = 3;
          int baseDelaySeconds = 2;

          for (int attempt = 0; attempt < maxRetries; attempt++) {
            try {
              final response = await client.post(
                serverUrl!,
                headers: <String, String>{'Content-Type': 'application/json'},
                body: jsonEncode({
                  'projectId': projectId,
                  'stats': statBatch,
                }),
              );

              if (response.statusCode == 200) {
                statBatch.clear();
                return; // Exit the function if successful
              }
            } catch (e) {
              // Handle exception silently
            }
            await Future.delayed(Duration(
                seconds:
                    baseDelaySeconds * (1 << attempt))); // Exponential backoff
          }
        },
        forceRunAfter: 20,
      );

  /// Tracks a stat with optional sublabel and count
  ///
  /// Example usages:
  /// ```dart
  /// // Track view
  /// track(StatType.view);
  ///
  /// // Track read with label
  /// track(StatType.read, 'cloudDatabase/init');
  ///
  /// // Track multiple downloads
  /// track(StatType.bundleDownload, null, 5);
  /// ```
  Future<void> track(StatType type, [String? sublabel, int count = 1]) {
    if (disabled) return Future.value();

    final field = sublabel != null ? '${type.path}/$sublabel' : type.path;
    statBatch[field] = (statBatch[field] ?? 0) + count;
    return sendBatch();
  }
}

/// Types of statistics that can be tracked
enum StatType {
  view('views'),
  read('reads'),
  write('writes'),
  bundleDownload('bundle_downloads'),
  fontDownload('font_downloads'),
  action('actions'),
  cloudAction('cloud_actions'),
  populatedLayoutDownload('populated_layout_downloads'),
  layoutView('layout_views');

  final String path;
  const StatType(this.path);
}
