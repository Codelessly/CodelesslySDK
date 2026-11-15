import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing and persisting pinned items to a JSON file
///
/// Pinned items appear at the top of the sidebar in a dedicated "Pinned" section.
/// This service follows the same patterns as StatusService for consistency.
class PinnedService {
  static const String _fileName = 'storyboard_pinned.json';
  static const String _dataPath = 'lib/storyboard/data';
  static const String _prefsKeyJsonPath = 'storyboard_pinned_json_path';
  static PinnedService? _instance;

  /// Singleton instance
  static PinnedService get instance {
    _instance ??= PinnedService._();
    return _instance!;
  }

  PinnedService._();

  /// In-memory cache of pinned item routes
  final Set<String> _pinnedRoutes = {};

  /// Listeners for pinned changes
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

  /// Resolve the file path by searching for the project directory
  String _resolveFilePath() {
    var dir = Directory.current;

    // Search up to 5 parent directories
    for (var i = 0; i < 5; i++) {
      // Check direct path
      final directPath = '${dir.path}/$_dataPath';
      if (Directory(directPath).existsSync()) {
        final path = '$directPath/$_fileName';
        debugPrint('PinnedService: Using file path: $path');
        return path;
      }

      // Move up one directory
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }

    // Fallback
    debugPrint('PinnedService: WARNING - Could not find project root');
    debugPrint('PinnedService: Current directory: ${Directory.current.path}');
    return '$_dataPath/$_fileName';
  }

  /// Add a listener for pinned changes
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
  Future<void> init() async {
    if (_initialized) return;

    // First, load any custom path from preferences
    await _loadCustomJsonPath();

    try {
      final file = File(_filePath);
      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents) as Map<String, dynamic>;
        final pinnedList = json['pinned'] as List<dynamic>? ?? [];

        _pinnedRoutes.clear();
        for (final route in pinnedList) {
          if (route is String) {
            _pinnedRoutes.add(route);
          }
        }

        debugPrint(
            'PinnedService: Loaded ${_pinnedRoutes.length} pinned items from $_filePath');
      } else {
        debugPrint(
            'PinnedService: No existing pinned file at $_filePath, starting fresh');
      }
    } catch (e) {
      debugPrint('PinnedService: Error loading pinned file: $e');
    }

    _initialized = true;
  }

  /// Load custom JSON path from SharedPreferences
  Future<void> _loadCustomJsonPath() async {
    final prefs = await SharedPreferences.getInstance();
    _customJsonPath = prefs.getString(_prefsKeyJsonPath);
    if (_customJsonPath != null) {
      debugPrint('PinnedService: Loaded custom JSON path: $_customJsonPath');
    }
  }

  /// Check if an item is pinned by its route
  bool isPinned(String route) => _pinnedRoutes.contains(route);

  /// Get all pinned routes (in order they were added)
  List<String> get pinnedRoutes => _pinnedRoutes.toList();

  /// Pin an item
  Future<void> pin(String route) async {
    if (_pinnedRoutes.contains(route)) return;
    _pinnedRoutes.add(route);
    _notifyListeners();
    await _saveToFile();
    debugPrint('PinnedService: Pinned $route');
  }

  /// Unpin an item
  Future<void> unpin(String route) async {
    if (!_pinnedRoutes.contains(route)) return;
    _pinnedRoutes.remove(route);
    _notifyListeners();
    await _saveToFile();
    debugPrint('PinnedService: Unpinned $route');
  }

  /// Toggle pin state for an item
  Future<void> togglePin(String route) async {
    if (_pinnedRoutes.contains(route)) {
      await unpin(route);
    } else {
      await pin(route);
    }
  }

  /// Save pinned items to the JSON file
  Future<void> _saveToFile() async {
    try {
      final file = File(_filePath);

      // Ensure the directory exists
      final dir = file.parent;
      if (!await dir.exists()) {
        debugPrint('PinnedService: Creating directory: ${dir.path}');
        await dir.create(recursive: true);
      }

      final json = {
        'version': 1,
        'lastModified': DateTime.now().toIso8601String(),
        'pinned': _pinnedRoutes.toList(),
      };

      await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(json));
      debugPrint('PinnedService: Saved ${_pinnedRoutes.length} pinned items');
    } catch (e, stackTrace) {
      debugPrint('PinnedService: Error saving pinned file: $e');
      debugPrint('PinnedService: Stack trace: $stackTrace');
    }
  }

  /// Clear all pinned items
  Future<void> clearAll() async {
    _pinnedRoutes.clear();
    _notifyListeners();
    await _saveToFile();
  }
}
