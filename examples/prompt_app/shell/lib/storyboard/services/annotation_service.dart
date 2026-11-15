import 'dart:convert';
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:uuid/uuid.dart';
import 'package:skip_shell/storyboard/models/annotation.dart';
import '../utils/annotation_constants.dart';

/// Service for managing and persisting widget annotations
///
/// Annotations are stored per-component and persisted to a JSON file.
/// This enables AI agents to read annotations and understand what changes
/// the user wants made to specific widgets.
class AnnotationService {
  static const String _fileName = 'storyboard_annotations.json';
  static const String _dataPath = 'lib/storyboard/data';
  static AnnotationService? _instance;

  /// Singleton instance
  static AnnotationService get instance {
    _instance ??= AnnotationService._();
    return _instance!;
  }

  AnnotationService._();

  /// In-memory cache of annotations by component route
  final Map<String, ComponentAnnotations> _annotationsCache = {};

  /// Listeners for annotation changes
  final List<VoidCallback> _listeners = [];

  /// Whether the service has been initialized

  /// Whether annotation badges are visible on components
  bool _badgesVisible = true;

  /// Currently highlighted annotation ID (for hover state)
  String? _highlightedAnnotationId;

  /// Window size when annotations were last saved (for detecting size changes)
  Size? _savedWindowSize;

  /// UUID generator
  final _uuid = const Uuid();

  /// Cached resolved file path
  String? _cachedFilePath;

  /// Get the absolute path to the JSON file
  String get _filePath {
    return _cachedFilePath ??= _resolveFilePath();
  }

  /// Resolve the file path by searching for the project directory
  String _resolveFilePath() {
    var dir = Directory.current;

    // Search up to 5 parent directories
    for (var i = 0; i < 5; i++) {
      final directPath = '${dir.path}/$_dataPath';
      if (Directory(directPath).existsSync()) {
        final path = '$directPath/$_fileName';
        debugPrint('AnnotationService: Using file path: $path');
        return path;
      }

      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }

    debugPrint('AnnotationService: WARNING - Could not find project root');
    return '$_dataPath/$_fileName';
  }

  /// Add a listener for annotation changes
  void addListener(VoidCallback listener) => _listeners.add(listener);

  /// Remove a listener
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  /// Notify all listeners
  void _notifyListeners() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  /// Initialize the service by loading from JSON
  Future<void> init() async {
    // Always reload to support hot restart
    _annotationsCache.clear();
    _savedWindowSize = null;

    try {
      final file = File(_filePath);
      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents) as Map<String, dynamic>;

        // Load saved window size
        final windowSizeJson = json['windowSize'] as Map<String, dynamic>?;
        if (windowSizeJson != null) {
          _savedWindowSize = Size(
            (windowSizeJson['width'] as num).toDouble(),
            (windowSizeJson['height'] as num).toDouble(),
          );
          debugPrint(
            'AnnotationService: Loaded saved window size: $_savedWindowSize',
          );
        }

        final components = json['components'] as Map<String, dynamic>? ?? {};

        for (final entry in components.entries) {
          final componentAnnotations = ComponentAnnotations.fromJson(
            entry.value as Map<String, dynamic>,
          );
          _annotationsCache[entry.key] = componentAnnotations;
        }

        debugPrint(
          'AnnotationService: Loaded annotations for ${_annotationsCache.length} components',
        );
      } else {
        debugPrint(
          'AnnotationService: No existing annotations file, starting fresh',
        );
      }
    } catch (e) {
      debugPrint('AnnotationService: Error loading annotations: $e');
    }

    // Notify listeners that annotations have been loaded
    _notifyListeners();
  }

  /// Get annotations for a component
  ComponentAnnotations? getAnnotations(String componentRoute) {
    return _annotationsCache[componentRoute];
  }

  /// Get annotation count for a component
  int getAnnotationCount(String componentRoute) {
    return _annotationsCache[componentRoute]?.count ?? 0;
  }

  /// Get pending annotation count for a component
  int getPendingAnnotationCount(String componentRoute) {
    final component = _annotationsCache[componentRoute];
    if (component == null) return 0;
    return component.annotations
        .where((a) => a.status == AnnotationStatus.pending)
        .length;
  }

  /// Get all pending annotations across all components
  Map<String, List<WidgetAnnotation>> getPendingAnnotations() {
    final pending = <String, List<WidgetAnnotation>>{};
    for (final entry in _annotationsCache.entries) {
      final pendingList = entry.value.annotations
          .where((a) => a.status == AnnotationStatus.pending)
          .toList();
      if (pendingList.isNotEmpty) {
        pending[entry.key] = pendingList;
      }
    }
    return pending;
  }

  /// Get all annotations across all components
  Map<String, ComponentAnnotations> get allAnnotations =>
      Map.unmodifiable(_annotationsCache);

  /// Whether annotation badges are visible
  bool get badgesVisible => _badgesVisible;

  /// Set annotation badges visibility
  set badgesVisible(bool visible) {
    if (_badgesVisible != visible) {
      _badgesVisible = visible;
      _notifyListeners();
    }
  }

  /// Get the currently highlighted annotation ID
  String? get highlightedAnnotationId => _highlightedAnnotationId;

  /// Set the highlighted annotation ID (for hover effects)
  set highlightedAnnotationId(String? id) {
    if (_highlightedAnnotationId != id) {
      _highlightedAnnotationId = id;
      _notifyListeners();
    }
  }

  /// Get the window size when annotations were last saved
  Size? get savedWindowSize => _savedWindowSize;

  /// Update the window size (called when saving after position refresh)
  set savedWindowSize(Size? size) {
    _savedWindowSize = size;
  }

  /// Check if window size has changed since annotations were saved
  bool hasWindowSizeChanged(Size currentSize) {
    if (_savedWindowSize == null) return true; // No saved size, assume changed
    // Allow small tolerance for floating point differences
    return (currentSize.width - _savedWindowSize!.width).abs() > 1 ||
        (currentSize.height - _savedWindowSize!.height).abs() > 1;
  }

  /// Add a new annotation to a component
  Future<WidgetAnnotation> addAnnotation({
    required String componentRoute,
    required String text,
    required String widgetType,
    Rect? bounds,
    String? widgetKey,
    String? widgetDebugInfo,
    String? authorName,
  }) async {
    final annotation = WidgetAnnotation(
      id: _uuid.v4(),
      text: text,
      createdAt: DateTime.now(),
      widgetType: widgetType,
      bounds: bounds,
      widgetKey: widgetKey,
      widgetDebugInfo: widgetDebugInfo,
      authorName: authorName,
    );

    final existing = _annotationsCache[componentRoute];
    if (existing != null) {
      _annotationsCache[componentRoute] = existing.copyWith(
        annotations: [...existing.annotations, annotation],
        lastModified: DateTime.now(),
      );
    } else {
      _annotationsCache[componentRoute] = ComponentAnnotations(
        componentRoute: componentRoute,
        annotations: [annotation],
        lastModified: DateTime.now(),
      );
    }

    _notifyListeners();
    await _saveToFile();
    return annotation;
  }

  /// Update an existing annotation
  Future<void> updateAnnotation({
    required String componentRoute,
    required String annotationId,
    required String newText,
  }) async {
    final component = _annotationsCache[componentRoute];
    if (component == null) return;

    final updatedAnnotations = component.annotations.map((a) {
      if (a.id == annotationId) {
        return a.copyWith(
          text: newText,
          updatedAt: DateTime.now(),
        );
      }
      return a;
    }).toList();

    _annotationsCache[componentRoute] = component.copyWith(
      annotations: updatedAnnotations,
      lastModified: DateTime.now(),
    );

    _notifyListeners();
    await _saveToFile();
  }

  /// Remove an annotation
  Future<void> removeAnnotation({
    required String componentRoute,
    required String annotationId,
  }) async {
    final component = _annotationsCache[componentRoute];
    if (component == null) return;

    final updatedAnnotations = component.annotations
        .where((a) => a.id != annotationId)
        .toList();

    if (updatedAnnotations.isEmpty) {
      _annotationsCache.remove(componentRoute);
    } else {
      _annotationsCache[componentRoute] = component.copyWith(
        annotations: updatedAnnotations,
        lastModified: DateTime.now(),
      );
    }

    _notifyListeners();
    await _saveToFile();
  }

  /// Mark an annotation as completed with feedback
  Future<void> completeAnnotation({
    required String componentRoute,
    required String annotationId,
    required String completedBy,
    required String feedbackText,
  }) async {
    final component = _annotationsCache[componentRoute];
    if (component == null) return;

    final updatedAnnotations = component.annotations.map((a) {
      if (a.id == annotationId) {
        final feedback = AnnotationFeedback(
          id: _uuid.v4(),
          author: completedBy,
          text: feedbackText,
          createdAt: DateTime.now(),
        );

        return a.copyWith(
          status: AnnotationStatus.completed,
          completedAt: DateTime.now(),
          completedBy: completedBy,
          feedback: [...a.feedback, feedback],
        );
      }
      return a;
    }).toList();

    _annotationsCache[componentRoute] = component.copyWith(
      annotations: updatedAnnotations,
      lastModified: DateTime.now(),
    );

    _notifyListeners();
    await _saveToFile();
  }

  /// Add feedback to an annotation (for multi-turn conversation)
  Future<void> addFeedback({
    required String componentRoute,
    required String annotationId,
    required String author,
    required String text,
  }) async {
    final component = _annotationsCache[componentRoute];
    if (component == null) return;

    final updatedAnnotations = component.annotations.map((a) {
      if (a.id == annotationId) {
        final newFeedback = AnnotationFeedback(
          id: _uuid.v4(),
          author: author,
          text: text,
          createdAt: DateTime.now(),
        );

        return a.copyWith(
          feedback: [...a.feedback, newFeedback],
          updatedAt: DateTime.now(),
        );
      }
      return a;
    }).toList();

    _annotationsCache[componentRoute] = component.copyWith(
      annotations: updatedAnnotations,
      lastModified: DateTime.now(),
    );

    _notifyListeners();
    await _saveToFile();
  }

  /// Reopen a completed annotation (change status back to pending)
  Future<void> reopenAnnotation({
    required String componentRoute,
    required String annotationId,
  }) async {
    final component = _annotationsCache[componentRoute];
    if (component == null) return;

    final updatedAnnotations = component.annotations.map((a) {
      if (a.id == annotationId) {
        return a.copyWith(
          status: AnnotationStatus.pending,
          updatedAt: DateTime.now(),
        );
      }
      return a;
    }).toList();

    _annotationsCache[componentRoute] = component.copyWith(
      annotations: updatedAnnotations,
      lastModified: DateTime.now(),
    );

    _notifyListeners();
    await _saveToFile();
  }

  /// Mark annotation as completed (simple toggle without feedback)
  Future<void> markAsCompleted({
    required String componentRoute,
    required String annotationId,
  }) async {
    final component = _annotationsCache[componentRoute];
    if (component == null) return;

    final updatedAnnotations = component.annotations.map((a) {
      if (a.id == annotationId) {
        return a.copyWith(
          status: AnnotationStatus.completed,
          completedAt: DateTime.now(),
          completedBy: 'User',
          updatedAt: DateTime.now(),
        );
      }
      return a;
    }).toList();

    _annotationsCache[componentRoute] = component.copyWith(
      annotations: updatedAnnotations,
      lastModified: DateTime.now(),
    );

    _notifyListeners();
    await _saveToFile();
  }

  /// Clear all annotations for a component
  Future<void> clearAnnotations(String componentRoute) async {
    _annotationsCache.remove(componentRoute);
    _notifyListeners();
    await _saveToFile();
  }

  /// Clear all annotations
  Future<void> clearAllAnnotations() async {
    _annotationsCache.clear();
    _notifyListeners();
    await _saveToFile();
  }

  /// Update the bounds of an annotation (used for position refresh)
  Future<void> updateAnnotationBounds({
    required String componentRoute,
    required String annotationId,
    required Rect newBounds,
  }) async {
    final component = _annotationsCache[componentRoute];
    if (component == null) return;

    final updatedAnnotations = component.annotations.map((a) {
      if (a.id == annotationId) {
        return a.copyWith(
          bounds: newBounds,
          updatedAt: DateTime.now(),
        );
      }
      return a;
    }).toList();

    _annotationsCache[componentRoute] = component.copyWith(
      annotations: updatedAnnotations,
      lastModified: DateTime.now(),
    );

    _notifyListeners();
    await _saveToFile();
  }

  /// Refresh annotation positions by re-detecting widget bounds.
  ///
  /// This method is critical for maintaining accurate annotation positions when:
  /// - The component layout changes due to content updates
  /// - The window is resized
  /// - The component is navigated to after being away
  ///
  /// Algorithm:
  /// 1. Uses the provided [boundsLookup] function to find current widget bounds
  /// 2. For each annotation, looks up the widget by type and attempts to match
  ///    the original widget by comparing size and position
  /// 3. Updates annotation bounds if the widget is found
  /// 4. Saves the [currentWindowSize] for future resize detection
  ///
  /// Parameters:
  /// - [componentRoute]: The route of the component to refresh (e.g., "/component_button")
  /// - [boundsLookup]: Async function that finds a widget's current bounds given an annotation.
  ///   Should return null if widget not found. Typically uses grid-scan + size/position matching.
  /// - [currentWindowSize]: Optional current window size to save for resize detection
  ///
  /// Returns:
  /// The number of annotations whose positions were successfully updated.
  ///
  /// Note: Annotations without updated positions are kept but won't display badges
  /// until their widget is found.
  Future<int> refreshAnnotationPositions({
    required String componentRoute,
    required Future<Rect?> Function(WidgetAnnotation annotation) boundsLookup,
    Size? currentWindowSize,
  }) async {
    final component = _annotationsCache[componentRoute];

    // Track if we need to save (either positions changed or window size provided)
    bool needsSave = false;

    // Update saved window size if provided
    if (currentWindowSize != null && currentWindowSize != _savedWindowSize) {
      _savedWindowSize = currentWindowSize;
      needsSave = true;
    }

    if (component == null) {
      // No annotations for this component, but still save window size if needed
      if (needsSave) {
        await _saveToFile();
      }
      return 0;
    }

    int updatedCount = 0;
    final updatedAnnotations = <WidgetAnnotation>[];

    for (final annotation in component.annotations) {
      final newBounds = await boundsLookup(annotation);
      if (newBounds != null && newBounds != annotation.bounds) {
        updatedAnnotations.add(annotation.copyWith(
          bounds: newBounds,
          updatedAt: DateTime.now(),
        ));
        updatedCount++;
      } else {
        updatedAnnotations.add(annotation);
      }
    }

    if (updatedCount > 0) {
      _annotationsCache[componentRoute] = component.copyWith(
        annotations: updatedAnnotations,
        lastModified: DateTime.now(),
      );
      needsSave = true;
    }

    if (needsSave) {
      _notifyListeners();
      await _saveToFile();
      debugPrint(
        'AnnotationService: Refreshed $updatedCount annotation positions for $componentRoute',
      );
    }

    return updatedCount;
  }

  /// Save all annotations to the JSON file
  Future<void> _saveToFile() async {
    try {
      final file = File(_filePath);

      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final json = {
        'version': AnnotationConstants.jsonVersion,
        'lastModified': DateTime.now().toIso8601String(),
        if (_savedWindowSize != null)
          'windowSize': {
            'width': _savedWindowSize!.width,
            'height': _savedWindowSize!.height,
          },
        'components': _annotationsCache.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      };

      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(json),
      );
      debugPrint(
        'AnnotationService: Saved annotations for ${_annotationsCache.length} components',
      );
    } catch (e, stackTrace) {
      debugPrint('AnnotationService: Error saving: $e');
      debugPrint('AnnotationService: Stack: $stackTrace');
    }
  }

  /// Export annotations as JSON string (for MCP/AI consumption)
  ///
  /// By default, only pending annotations are returned to improve usability.
  ///
  /// Parameters:
  /// - [componentRoute]: Optional specific component to query
  /// - [includeCompleted]: Legacy boolean flag (deprecated, use [filterByStatus])
  /// - [filterByStatus]: Status filter: 'pending' (default), 'completed', or 'all'
  String exportAsJson({
    String? componentRoute,
    @Deprecated('Use filterByStatus instead') bool includeCompleted = false,
    String? filterByStatus,
  }) {
    // Determine the status filter to use
    // Priority: filterByStatus > includeCompleted > default to 'pending'
    final String statusFilter;
    if (filterByStatus != null) {
      statusFilter = filterByStatus.toLowerCase();
    } else if (includeCompleted) {
      statusFilter = 'all';
    } else {
      statusFilter = 'pending';
    }

    // Validate status filter
    if (!['pending', 'completed', 'all'].contains(statusFilter)) {
      return jsonEncode({
        'error': 'Invalid filterByStatus. Must be: pending, completed, or all',
        'providedValue': statusFilter,
      });
    }

    if (componentRoute != null) {
      final component = _annotationsCache[componentRoute];
      if (component == null) {
        return jsonEncode({
          'componentRoute': componentRoute,
          'annotations': [],
          'message': 'No annotations found for this component',
        });
      }

      // Filter by status
      final filteredAnnotations = _filterAnnotationsByStatus(
        component.annotations,
        statusFilter,
      );

      return jsonEncode({
        'componentRoute': component.componentRoute,
        'annotations': filteredAnnotations.map((a) => a.toJson()).toList(),
        'lastModified': component.lastModified?.toIso8601String(),
        'filteredByStatus': statusFilter,
        'totalCount': component.annotations.length,
        'returnedCount': filteredAnnotations.length,
      });
    }

    // Export all - filter by status if needed
    final filteredComponents = <String, Map<String, dynamic>>{};
    int totalAnnotations = 0;
    int returnedAnnotations = 0;

    for (final entry in _annotationsCache.entries) {
      final annotations = _filterAnnotationsByStatus(
        entry.value.annotations,
        statusFilter,
      );

      totalAnnotations += entry.value.annotations.length;
      returnedAnnotations += annotations.length;

      // Only include components that have annotations after filtering
      if (annotations.isNotEmpty) {
        filteredComponents[entry.key] = {
          'componentRoute': entry.value.componentRoute,
          'annotations': annotations.map((a) => a.toJson()).toList(),
          'lastModified': entry.value.lastModified?.toIso8601String(),
        };
      }
    }

    return jsonEncode({
      'totalComponents': filteredComponents.length,
      'totalAnnotations': totalAnnotations,
      'returnedAnnotations': returnedAnnotations,
      'filteredByStatus': statusFilter,
      'components': filteredComponents,
    });
  }

  /// Helper method to filter annotations by status
  List<WidgetAnnotation> _filterAnnotationsByStatus(
    List<WidgetAnnotation> annotations,
    String statusFilter,
  ) {
    switch (statusFilter) {
      case 'pending':
        return annotations
            .where((a) => a.status == AnnotationStatus.pending)
            .toList();
      case 'completed':
        return annotations
            .where((a) => a.status == AnnotationStatus.completed)
            .toList();
      case 'all':
      default:
        return annotations;
    }
  }

  /// Get a summary of all annotations (useful for AI context)
  Map<String, dynamic> getSummary() {
    final componentSummaries = <Map<String, dynamic>>[];

    for (final entry in _annotationsCache.entries) {
      final annotations = entry.value.annotations;
      componentSummaries.add({
        'route': entry.key,
        'count': annotations.length,
        'annotations': annotations.map((a) => {
          'id': a.id,
          'text': a.text,
          'widgetType': a.widgetType,
          'createdAt': a.createdAt.toIso8601String(),
        }).toList(),
      });
    }

    return {
      'totalAnnotations': _annotationsCache.values
          .fold<int>(0, (sum, c) => sum + c.count),
      'componentsWithAnnotations': _annotationsCache.length,
      'components': componentSummaries,
    };
  }
}
