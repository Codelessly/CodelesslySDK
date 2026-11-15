import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skip_shell/storyboard/models/item_status.dart';

/// Service for managing and persisting status values to a JSON file
///
/// The JSON file location can be configured via [setCustomJsonPath] and is
/// persisted via SharedPreferences. By default, it searches for the file
/// in the storyboard data directory relative to the project root.
class StatusService {
  static const String _fileName = 'storyboard_status.json';
  static const String _dataPath = 'lib/storyboard/data';
  static const String _prefsKeyJsonPath = 'storyboard_status_json_path';
  static StatusService? _instance;

  /// Singleton instance
  static StatusService get instance {
    _instance ??= StatusService._();
    return _instance!;
  }

  StatusService._();

  /// In-memory cache of status values (route -> status)
  final Map<String, ItemStatus> _statusCache = {};

  /// Listeners for status changes
  final List<VoidCallback> _listeners = [];

  /// Whether the service has been initialized
  bool _initialized = false;

  /// Custom JSON file path (set via SharedPreferences or setCustomJsonPath)
  String? _customJsonPath;

  /// Cached resolved file path
  String? _cachedFilePath;

  /// Get the current JSON file path
  String get currentJsonPath => _filePath;

  /// Get the absolute path to the JSON file
  String get _filePath {
    // Use custom path if set
    if (_customJsonPath != null && _customJsonPath!.isNotEmpty) {
      return _customJsonPath!;
    }
    // Otherwise resolve from project structure
    return _cachedFilePath ??= _resolveFilePath();
  }

  /// Set a custom JSON file path and persist it
  ///
  /// Pass null or empty string to reset to default behavior
  Future<void> setCustomJsonPath(String? path) async {
    _customJsonPath = path;
    _cachedFilePath = null;

    // Persist to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    if (path != null && path.isNotEmpty) {
      await prefs.setString(_prefsKeyJsonPath, path);
      debugPrint('StatusService: Custom JSON path set: $path');
    } else {
      await prefs.remove(_prefsKeyJsonPath);
      debugPrint('StatusService: Custom JSON path cleared, using default');
    }

    // Reload statuses from new path
    _initialized = false;
    _statusCache.clear();
    await init();
  }

  /// Load custom JSON path from SharedPreferences
  Future<void> loadCustomJsonPath() async {
    final prefs = await SharedPreferences.getInstance();
    _customJsonPath = prefs.getString(_prefsKeyJsonPath);
    if (_customJsonPath != null) {
      debugPrint('StatusService: Loaded custom JSON path: $_customJsonPath');
    }
  }

  /// Resolve the file path by searching for the project directory
  String _resolveFilePath() {
    var dir = Directory.current;

    // Search up to 5 parent directories
    for (var i = 0; i < 5; i++) {
      // Check direct path
      final directPath = '${dir.path}/$_dataPath';
      if (Directory(directPath).existsSync()) {
        final path = '$directPath/$_fileName';
        debugPrint('StatusService: Using file path: $path');
        return path;
      }

      // Move up one directory
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }

    // Fallback
    debugPrint('StatusService: WARNING - Could not find project root');
    debugPrint('StatusService: Current directory: ${Directory.current.path}');
    return '$_dataPath/$_fileName';
  }

  /// Add a listener for status changes
  void addListener(VoidCallback listener) => _listeners.add(listener);

  /// Remove a listener
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  /// Notify all listeners of a change (defensive copy to allow removal during iteration)
  void _notifyListeners() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  /// Initialize the service by loading from JSON
  ///
  /// Call this after the app starts. It will:
  /// 1. Load any custom JSON path from SharedPreferences
  /// 2. Load status data from the JSON file
  Future<void> init() async {
    if (_initialized) return;

    // First, load any custom path from preferences
    await loadCustomJsonPath();

    try {
      final file = File(_filePath);
      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents) as Map<String, dynamic>;
        final statuses = json['statuses'] as Map<String, dynamic>? ?? {};

        for (final entry in statuses.entries) {
          final status = ItemStatusExtension.fromJson(entry.value as String);
          if (status != null) {
            _statusCache[entry.key] = status;
          }
        }

        debugPrint(
            'StatusService: Loaded ${_statusCache.length} status entries from $_filePath');
      } else {
        debugPrint(
            'StatusService: No existing status file at $_filePath, starting fresh');
      }
    } catch (e) {
      debugPrint('StatusService: Error loading status file: $e');
    }

    _initialized = true;
  }

  /// Check if a JSON file exists at the given path
  static Future<bool> isValidJsonPath(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;

    try {
      final contents = await file.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      // Check for required structure
      return json.containsKey('statuses');
    } catch (e) {
      return false;
    }
  }

  /// Create a new status JSON file at the given path
  static Future<void> createStatusFile(String path) async {
    final file = File(path);
    final dir = file.parent;

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final initialJson = {
      'version': 1,
      'lastModified': DateTime.now().toIso8601String(),
      'statuses': <String, String>{},
    };

    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(initialJson));
    debugPrint('StatusService: Created new status file at $path');
  }

  /// Get the status for an item by its route
  ItemStatus? getStatus(String route) => _statusCache[route];

  /// Set the status for an item and persist to JSON
  Future<void> setStatus(String route, ItemStatus status) async {
    _statusCache[route] = status;
    _notifyListeners();
    await _saveToFile();
  }

  /// Save all statuses to the JSON file
  Future<void> _saveToFile() async {
    try {
      final file = File(_filePath);

      // Ensure the directory exists
      final dir = file.parent;
      if (!await dir.exists()) {
        debugPrint('StatusService: Creating directory: ${dir.path}');
        await dir.create(recursive: true);
      }

      final json = {
        'version': 1,
        'lastModified': DateTime.now().toIso8601String(),
        'statuses':
            _statusCache.map((key, value) => MapEntry(key, value.name)),
      };

      await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(json));
      debugPrint('StatusService: Saved ${_statusCache.length} status entries');
    } catch (e, stackTrace) {
      debugPrint('StatusService: Error saving status file: $e');
      debugPrint('StatusService: Stack trace: $stackTrace');
    }
  }

  /// Bulk update statuses (useful for initial setup)
  Future<void> bulkSetStatuses(Map<String, ItemStatus> statuses) async {
    _statusCache.addAll(statuses);
    _notifyListeners();
    await _saveToFile();
  }

  /// Get all cached statuses
  Map<String, ItemStatus> get allStatuses => Map.unmodifiable(_statusCache);
}
