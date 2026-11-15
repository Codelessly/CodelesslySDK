/// Storyboard Driver Extension Service
///
/// Provides Flutter Driver extension commands for AI/automation control of the storyboard.
/// This enables MCP servers to query storyboard state, navigate items, and capture screenshots.
///
/// Commands:
/// - get_state: Get current storyboard state (selected item, frame, theme)
/// - get_components: Get all components with metadata
/// - get_pages: Get all pages with metadata
/// - get_flows: Get all flow definitions
/// - get_frames: Get available device frames
/// - select_item:{route}: Navigate to an item by route
/// - set_frame:{frameName}: Change device frame
/// - set_status:{route}:{status}: Update item status
/// - capture_component: Capture screenshot of current component (component only)
/// - capture_viewer: Capture screenshot of entire viewer area
/// - get_runtime_errors: Get layout errors (RenderFlex overflow, etc.)
/// - clear_runtime_errors: Clear recorded runtime errors
/// - get_widget_tree: Get the widget tree of the current component
/// - tap_widget:{finderType}:{value}: Tap on a widget by key, text, or type
/// - enter_text:{finderType}:{value}:{text}: Enter text into a text field
/// - scroll_widget:{finderType}:{value}:{dx}:{dy}:{durationMs}: Scroll a widget
/// - wait_for_widget:{finderType}:{value}:{timeoutMs}: Wait for a widget to appear
/// - get_widget_text:{finderType}:{value}: Get text content from a widget
/// - get_annotations:{route?}:{filterByStatus?}: Get annotations for a component (pending only by default, supports 'pending', 'completed', 'all')
/// - get_annotations_summary: Get a summary of all annotations
/// - enable_inspect_mode: Enable widget inspector for annotations
/// - disable_inspect_mode: Disable widget inspector
/// - clear_annotations:{route?}: Clear annotations for a component (or all if no route)
/// - show_toast:{type}:{title}:{description?}: Show a toast notification (type: success, info, warning, error)
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';

import 'package:skip_shell/storyboard/data/storyboard_data.dart';
import 'package:skip_shell/storyboard/data/text_theme_data.dart';
import 'package:skip_shell/storyboard/data/color_theme_data.dart';
import 'package:skip_shell/storyboard/models/color_entry.dart';
import 'package:skip_shell/storyboard/models/item_status.dart';
import 'package:skip_shell/storyboard/models/phone_frame.dart';
import 'package:skip_shell/storyboard/models/storyboard_item.dart';
import 'status_service.dart';
import 'annotation_service.dart';
import 'toast_service.dart';
import 'widget_tree_builder.dart';

/// Direct reference to the storyboard driver state instance
/// Set by StoryboardApp during initialization
StoryboardDriverState? storyboardDriverStateInstance;

/// Global key for the component content area (for component-only screenshots)
final GlobalKey storyboardComponentKey = GlobalKey(debugLabel: 'storyboardComponent');

/// Global key for the viewer content area (for full viewer screenshots)
final GlobalKey storyboardViewerKey = GlobalKey(debugLabel: 'storyboardViewer');

/// List of captured runtime errors for driver inspection
final List<_CapturedError> _capturedErrors = [];

/// Maximum number of errors to keep
const int _maxCapturedErrors = 100;

/// Captured error data structure
class _CapturedError {
  final String message;
  final String? stackTrace;
  final String? errorType;
  final DateTime timestamp;
  final String? widgetPath;
  final String? fullDetails; // Full Flutter diagnostic output

  _CapturedError({
    required this.message,
    this.stackTrace,
    this.errorType,
    required this.timestamp,
    this.widgetPath,
    this.fullDetails,
  });

  Map<String, dynamic> toJson() => {
    'message': message,
    'stackTrace': stackTrace,
    'errorType': errorType,
    'timestamp': timestamp.toIso8601String(),
    'widgetPath': widgetPath,
    if (fullDetails != null) 'fullDetails': fullDetails,
  };
}

/// Initialize error capturing for the storyboard
/// Call this during app startup
void initializeStoryboardErrorCapture() {
  // Store the original error handler
  final originalOnError = FlutterError.onError;

  // Set up our error capturing handler
  FlutterError.onError = (FlutterErrorDetails details) {
    // Capture the error with full diagnostic details
    _capturedErrors.add(_CapturedError(
      message: details.exceptionAsString(),
      stackTrace: details.stack?.toString(),
      errorType: details.exception.runtimeType.toString(),
      timestamp: DateTime.now(),
      widgetPath: details.context?.toDescription(),
      // Capture the FULL Flutter diagnostic output including widget tree, constraints, etc.
      fullDetails: details.toString(),
    ));

    // Keep only the last N errors
    while (_capturedErrors.length > _maxCapturedErrors) {
      _capturedErrors.removeAt(0);
    }

    // Call the original handler (if any) to preserve default behavior
    originalOnError?.call(details);
  };
}

/// Mixin that provides state access for the driver extension
/// Add this to your StoryboardApp state class
mixin StoryboardDriverState<T extends StatefulWidget> on State<T> {
  /// Get the currently selected item
  StoryboardItem? get driverSelectedItem;

  /// Get the currently selected frame
  PhoneFrame get driverSelectedFrame;

  /// Get whether dark mode is enabled
  bool get driverIsDarkMode;

  /// Get all categories
  List<StoryboardCategory> get driverCategories;

  /// Navigate to an item by route
  void driverSelectItemByRoute(String route);

  /// Set the device frame
  void driverSetFrame(PhoneFrame frame);

  /// Set the theme mode
  void driverSetDarkMode(bool isDark);

  /// Enable/disable inspect mode for annotations
  void setInspectMode(bool enabled);
}

/// Handles Flutter Driver extension commands
class StoryboardDriverExtension {
  StoryboardDriverExtension._();

  /// Singleton instance
  static final StoryboardDriverExtension instance = StoryboardDriverExtension._();

  /// Handle a driver command and return the result
  Future<String> handleCommand(String command) async {
    try {
      final parts = command.split(':');
      final action = parts[0];
      final payload = parts.length > 1 ? parts.sublist(1).join(':') : '';

      switch (action) {
        case 'get_state':
          return _getState();
        case 'get_components':
          return _getComponents(payload.isNotEmpty ? payload : null);
        case 'get_pages':
          return _getPages(payload.isNotEmpty ? payload : null);
        case 'get_flows':
          return _getFlows();
        case 'get_frames':
          return _getFrames();
        case 'select_item':
          return await _selectItem(payload);
        case 'set_frame':
          return await _setFrame(payload);
        case 'set_status':
          return await _setStatus(payload);
        case 'capture_component':
          return await _captureComponent();
        case 'capture_viewer':
          return await _captureViewer();
        case 'get_runtime_errors':
          return _getRuntimeErrors();
        case 'clear_runtime_errors':
          return _clearRuntimeErrors();
        case 'get_widget_tree':
          // payload can be 'true' or 'false' for summaryOnly
          final summaryOnly = payload.isEmpty || payload != 'false';
          return _getWidgetTree(summaryOnly: summaryOnly);
        case 'tap_widget':
          return await _tapWidget(payload);
        case 'enter_text':
          return await _enterText(payload);
        case 'scroll_widget':
          return await _scrollWidget(payload);
        case 'wait_for_widget':
          return await _waitForWidget(payload);
        case 'get_widget_text':
          return _getWidgetText(payload);
        case 'get_annotations':
          return _getAnnotations(payload);
        case 'get_annotations_summary':
          return _getAnnotationsSummary();
        case 'enable_inspect_mode':
          return _setInspectMode(true);
        case 'disable_inspect_mode':
          return _setInspectMode(false);
        case 'clear_annotations':
          return await _clearAnnotations(payload);
        case 'set_annotation_status':
          return await _setAnnotationStatus(payload);
        case 'add_annotation_feedback':
          return await _addAnnotationFeedback(payload);
        case 'show_toast':
          return _showToast(payload);
        case 'get_text_styles':
          return _getTextStyles(payload);
        case 'get_colors':
          return _getColors(payload);
        default:
          return jsonEncode({'error': 'Unknown command: $action'});
      }
    } catch (e, stack) {
      return jsonEncode({
        'error': 'Command failed: $e',
        'stack': stack.toString(),
      });
    }
  }

  /// Get current storyboard state
  String _getState() {
    final state = storyboardDriverStateInstance;
    if (state == null) {
      return jsonEncode({'error': 'Storyboard not initialized'});
    }

    final item = state.driverSelectedItem;
    final frame = state.driverSelectedFrame;

    return jsonEncode({
      'selectedItem': item != null
          ? {
              'name': item.name,
              'route': item.route,
              'category': item.category,
              'subcategory': item.subcategory,
              'filePath': item.filePath,
              'status': StatusService.instance.getStatus(item.route)?.name,
            }
          : null,
      'selectedFrame': {
        'name': frame.name,
        'width': frame.width,
        'height': frame.height,
        'platform': frame.platform,
        'devicePixelRatio': frame.devicePixelRatio,
      },
      'isDarkMode': state.driverIsDarkMode,
      'categoryCount': state.driverCategories.length,
    });
  }

  /// Get all components with metadata
  String _getComponents(String? subcategoryFilter) {
    final categories = getStoryboardCategories();
    final componentsCategory = categories.firstWhere(
      (c) => c.name == 'Components',
      orElse: () => StoryboardCategory(name: 'Components', items: []),
    );

    var items = componentsCategory.items;
    if (subcategoryFilter != null && subcategoryFilter.isNotEmpty) {
      items = items.where((i) => i.subcategory == subcategoryFilter).toList();
    }

    // Group by subcategory
    final subcategories = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final sub = item.subcategory ?? 'Other';
      subcategories.putIfAbsent(sub, () => []);
      subcategories[sub]!.add({
        'name': item.name,
        'route': item.route,
        'subcategory': sub,
        'filePath': item.filePath,
        'status': StatusService.instance.getStatus(item.route)?.name,
      });
    }

    return jsonEncode({
      'total': items.length,
      'subcategories': subcategories.entries
          .map((e) => {
                'name': e.key,
                'count': e.value.length,
                'items': e.value,
              })
          .toList(),
    });
  }

  /// Get all pages with metadata
  String _getPages(String? subcategoryFilter) {
    final categories = getStoryboardCategories();
    final pagesCategory = categories.firstWhere(
      (c) => c.name == 'Pages',
      orElse: () => StoryboardCategory(name: 'Pages', items: []),
    );

    var items = pagesCategory.items;
    if (subcategoryFilter != null && subcategoryFilter.isNotEmpty) {
      items = items.where((i) => i.subcategory == subcategoryFilter).toList();
    }

    // Group by subcategory
    final subcategories = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final sub = item.subcategory ?? 'Other';
      subcategories.putIfAbsent(sub, () => []);
      subcategories[sub]!.add({
        'name': item.name,
        'route': item.route,
        'subcategory': sub,
        'filePath': item.filePath,
        'status': StatusService.instance.getStatus(item.route)?.name,
      });
    }

    return jsonEncode({
      'total': items.length,
      'subcategories': subcategories.entries
          .map((e) => {
                'name': e.key,
                'count': e.value.length,
                'items': e.value,
              })
          .toList(),
    });
  }

  /// Get all flow definitions
  String _getFlows() {
    final categories = getStoryboardCategories();
    final flowsCategory = categories.firstWhere(
      (c) => c.name == 'Flows',
      orElse: () => StoryboardCategory(name: 'Flows', items: []),
    );

    return jsonEncode({
      'total': flowsCategory.items.length,
      'flows': flowsCategory.items
          .map((item) => {
                'name': item.name,
                'route': item.route,
                'filePath': item.filePath,
                'status': StatusService.instance.getStatus(item.route)?.name,
              })
          .toList(),
    });
  }

  /// Get available device frames
  String _getFrames() {
    return jsonEncode({
      'frames': PhoneFrames.all
          .map((f) => {
                'name': f.name,
                'width': f.width,
                'height': f.height,
                'platform': f.platform,
                'description': f.description,
                'devicePixelRatio': f.devicePixelRatio,
              })
          .toList(),
    });
  }

  /// Select an item by route
  Future<String> _selectItem(String route) async {
    final state = storyboardDriverStateInstance;
    if (state == null) {
      return jsonEncode({'error': 'Storyboard not initialized'});
    }

    state.driverSelectItemByRoute(route);

    // Wait for UI to update
    await Future.delayed(const Duration(milliseconds: 500));

    return jsonEncode({
      'success': true,
      'selectedItem': state.driverSelectedItem?.name,
    });
  }

  /// Set the device frame
  Future<String> _setFrame(String frameName) async {
    final state = storyboardDriverStateInstance;
    if (state == null) {
      return jsonEncode({'error': 'Storyboard not initialized'});
    }

    final frame = PhoneFrames.all.firstWhere(
      (f) => f.name.toLowerCase() == frameName.toLowerCase(),
      orElse: () => PhoneFrames.none,
    );

    state.driverSetFrame(frame);

    // Wait for UI to update
    await Future.delayed(const Duration(milliseconds: 300));

    return jsonEncode({
      'success': true,
      'frame': frame.name,
      'dimensions': '${frame.width}x${frame.height}',
    });
  }

  /// Set item status
  Future<String> _setStatus(String payload) async {
    // payload format: route:status
    final parts = payload.split(':');
    if (parts.length < 2) {
      return jsonEncode({'error': 'Invalid payload format. Expected route:status'});
    }

    final route = parts[0];
    final statusName = parts[1];

    try {
      final status = ItemStatus.values.firstWhere(
        (s) => s.name.toLowerCase() == statusName.toLowerCase(),
      );

      await StatusService.instance.setStatus(route, status);

      return jsonEncode({
        'success': true,
        'route': route,
        'status': status.name,
      });
    } catch (e) {
      return jsonEncode({'error': 'Invalid status: $statusName'});
    }
  }

  /// Capture screenshot of the component content only (not the frame/chrome)
  Future<String> _captureComponent() async {
    try {
      final boundary = storyboardComponentKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        return jsonEncode({'error': 'Component not found or not rendered yet'});
      }

      // Get the device pixel ratio for high-quality capture
      final context = storyboardComponentKey.currentContext!;
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        return jsonEncode({'error': 'Failed to convert image to bytes'});
      }

      final base64Data = base64Encode(byteData.buffer.asUint8List());
      return jsonEncode({
        'success': true,
        'data': base64Data,
        'width': image.width,
        'height': image.height,
        'pixelRatio': pixelRatio,
        'captureType': 'component',
      });
    } catch (e) {
      return jsonEncode({'error': 'Capture failed: $e'});
    }
  }

  /// Capture screenshot of the entire viewer area
  Future<String> _captureViewer() async {
    try {
      final boundary = storyboardViewerKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        return jsonEncode({'error': 'Viewer not found or not rendered yet'});
      }

      // Get the device pixel ratio for high-quality capture
      final context = storyboardViewerKey.currentContext!;
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        return jsonEncode({'error': 'Failed to convert image to bytes'});
      }

      final base64Data = base64Encode(byteData.buffer.asUint8List());
      return jsonEncode({
        'success': true,
        'data': base64Data,
        'width': image.width,
        'height': image.height,
        'pixelRatio': pixelRatio,
        'captureType': 'viewer',
      });
    } catch (e) {
      return jsonEncode({'error': 'Capture failed: $e'});
    }
  }

  /// Get captured runtime errors (RenderFlex overflow, etc.)
  String _getRuntimeErrors() {
    return jsonEncode({
      'success': true,
      'errorCount': _capturedErrors.length,
      'errors': _capturedErrors.map((e) => e.toJson()).toList(),
      'hasOverflowErrors': _capturedErrors.any((e) =>
        e.message.contains('overflowed') ||
        e.message.contains('RenderFlex') ||
        e.errorType?.contains('FlutterError') == true
      ),
    });
  }

  /// Clear captured runtime errors
  String _clearRuntimeErrors() {
    final count = _capturedErrors.length;
    _capturedErrors.clear();

    // Show success toast if errors were cleared
    if (count > 0) {
      ToastService.instance.showSuccess(
        title: 'Errors Cleared',
        description: 'Cleared $count runtime error${count == 1 ? '' : 's'}',
      );
    }

    return jsonEncode({
      'success': true,
      'clearedCount': count,
      'message': 'Cleared $count errors',
    });
  }

  /// Get the widget tree of the current component
  /// [summaryOnly] - When true (default), skips framework internals for cleaner output
  String _getWidgetTree({bool summaryOnly = true}) {
    final state = storyboardDriverStateInstance;
    if (state == null) {
      return jsonEncode({'error': 'Storyboard not initialized'});
    }

    try {
      // Get the component's context
      final componentContext = storyboardComponentKey.currentContext;
      if (componentContext == null) {
        return jsonEncode({'error': 'Component not found or not rendered yet'});
      }

      // Build a simplified widget tree, skipping framework internals by default
      final tree = WidgetTreeBuilder.build(
        componentContext as Element,
        maxDepth: 30,
        summaryOnly: summaryOnly,
      );

      return jsonEncode({
        'success': true,
        'selectedItem': state.driverSelectedItem?.name,
        'summaryOnly': summaryOnly,
        'tree': tree,
      });
    } catch (e) {
      return jsonEncode({'error': 'Failed to get widget tree: $e'});
    }
  }

  /// Tap on a widget by finder
  /// Format: tap_widget:key:submit_button or tap_widget:text:Sign In
  Future<String> _tapWidget(String payload) async {
    try {
      final parts = payload.split(':');
      if (parts.length < 2) {
        return jsonEncode({'error': 'Invalid format. Expected: finderType:value'});
      }

      final finderType = parts[0];
      final value = parts.sublist(1).join(':'); // Handle colons in value

      // Find the widget
      final element = _findWidget(finderType, value);
      if (element == null) {
        return jsonEncode({'error': 'Widget not found: $finderType=$value'});
      }

      // Get render object and position
      final renderObject = element.renderObject as RenderBox?;
      if (renderObject == null || !renderObject.hasSize) {
        return jsonEncode({'error': 'Widget has no render object or size'});
      }

      // Get center position
      final center = renderObject.localToGlobal(renderObject.size.center(Offset.zero));

      // Simulate tap
      await _simulateTap(center);

      // Wait for frame
      await Future.delayed(const Duration(milliseconds: 100));

      return jsonEncode({
        'success': true,
        'message': 'Tapped $finderType=$value at (${center.dx.toInt()}, ${center.dy.toInt()})',
        'position': {'x': center.dx, 'y': center.dy},
      });
    } catch (e, stack) {
      return jsonEncode({
        'error': 'Tap failed: $e',
        'stack': stack.toString(),
      });
    }
  }

  /// Enter text into a text field
  /// Format: enter_text:key:email_field:user@example.com
  Future<String> _enterText(String payload) async {
    try {
      final parts = payload.split(':');
      if (parts.length < 3) {
        return jsonEncode({'error': 'Invalid format. Expected: finderType:value:text'});
      }

      final finderType = parts[0];
      final fieldId = parts[1];
      final text = parts.sublist(2).join(':'); // Handle colons in text

      // First tap to focus
      await _tapWidget('$finderType:$fieldId');
      await Future.delayed(const Duration(milliseconds: 100));

      // Find the text field
      final element = _findWidget(finderType, fieldId);
      if (element == null) {
        return jsonEncode({'error': 'Text field not found: $finderType=$fieldId'});
      }

      // Try to find and update the text controller
      bool updated = false;

      // Visit all descendants to find EditableText
      void findEditableText(Element e) {
        if (e.widget is EditableText) {
          final editableText = e.widget as EditableText;
          editableText.controller.text = text;
          // Trigger rebuild
          e.markNeedsBuild();
          updated = true;
          return;
        }
        e.visitChildren(findEditableText);
      }

      element.visitChildren(findEditableText);
      if (updated) {
        await Future.delayed(const Duration(milliseconds: 100));
        return jsonEncode({
          'success': true,
          'message': 'Entered text into $finderType=$fieldId',
          'text': text,
        });
      }

      // Try finding TextField or TextFormField ancestor
      Element? foundTextField;
      element.visitAncestorElements((ancestor) {
        final widget = ancestor.widget;
        if (widget is TextField && widget.controller != null) {
          foundTextField = ancestor;
          return false; // Stop visiting
        }
        if (widget is TextFormField && widget.controller != null) {
          foundTextField = ancestor;
          return false; // Stop visiting
        }
        return true; // Continue visiting
      });

      if (foundTextField != null) {
        final widget = foundTextField!.widget;
        if (widget is TextField && widget.controller != null) {
          widget.controller!.text = text;
          foundTextField!.markNeedsBuild();
          await Future.delayed(const Duration(milliseconds: 100));
          return jsonEncode({
            'success': true,
            'message': 'Entered text into TextField',
            'text': text,
          });
        }
        if (widget is TextFormField && widget.controller != null) {
          widget.controller!.text = text;
          foundTextField!.markNeedsBuild();
          await Future.delayed(const Duration(milliseconds: 100));
          return jsonEncode({
            'success': true,
            'message': 'Entered text into TextFormField',
            'text': text,
          });
        }
      }

      return jsonEncode({'error': 'Widget is not a text field or has no controller'});
    } catch (e, stack) {
      return jsonEncode({
        'error': 'Enter text failed: $e',
        'stack': stack.toString(),
      });
    }
  }

  /// Scroll a widget
  /// Format: scroll_widget:type:ListView:-300:0:300
  Future<String> _scrollWidget(String payload) async {
    try {
      final parts = payload.split(':');
      if (parts.length < 5) {
        return jsonEncode({'error': 'Invalid format. Expected: finderType:value:dx:dy:durationMs'});
      }

      final finderType = parts[0];
      final value = parts[1];
      final dx = double.parse(parts[2]);
      final dy = double.parse(parts[3]);
      final durationMs = int.parse(parts[4]);

      // Find the widget
      final element = _findWidget(finderType, value);
      if (element == null) {
        return jsonEncode({'error': 'Widget not found: $finderType=$value'});
      }

      // Get render object
      final renderObject = element.renderObject as RenderBox?;
      if (renderObject == null || !renderObject.hasSize) {
        return jsonEncode({'error': 'Widget has no render object or size'});
      }

      // Get center position for start of scroll
      final center = renderObject.localToGlobal(renderObject.size.center(Offset.zero));
      final endPosition = Offset(center.dx + dx, center.dy + dy);

      // Simulate scroll gesture
      await _simulateScroll(center, endPosition, Duration(milliseconds: durationMs));

      return jsonEncode({
        'success': true,
        'message': 'Scrolled $finderType=$value by ($dx, $dy)',
        'offset': {'dx': dx, 'dy': dy},
      });
    } catch (e, stack) {
      return jsonEncode({
        'error': 'Scroll failed: $e',
        'stack': stack.toString(),
      });
    }
  }

  /// Wait for a widget to appear
  /// Format: wait_for_widget:key:success_message:5000
  Future<String> _waitForWidget(String payload) async {
    try {
      final parts = payload.split(':');
      if (parts.length < 3) {
        return jsonEncode({'error': 'Invalid format. Expected: finderType:value:timeoutMs'});
      }

      final finderType = parts[0];
      final value = parts[1];
      final timeoutMs = int.parse(parts[2]);

      final startTime = DateTime.now();
      Element? element;

      // Poll for the widget
      while (DateTime.now().difference(startTime).inMilliseconds < timeoutMs) {
        element = _findWidget(finderType, value);
        if (element != null) {
          return jsonEncode({
            'success': true,
            'message': 'Found $finderType=$value',
            'elapsed': DateTime.now().difference(startTime).inMilliseconds,
          });
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }

      return jsonEncode({
        'error': 'Timeout waiting for $finderType=$value after ${timeoutMs}ms',
        'timeout': timeoutMs,
      });
    } catch (e, stack) {
      return jsonEncode({
        'error': 'Wait failed: $e',
        'stack': stack.toString(),
      });
    }
  }

  /// Get text content from a widget
  /// Format: get_widget_text:key:error_message
  String _getWidgetText(String payload) {
    try {
      final parts = payload.split(':');
      if (parts.length < 2) {
        return jsonEncode({'error': 'Invalid format. Expected: finderType:value'});
      }

      final finderType = parts[0];
      final value = parts.sublist(1).join(':'); // Handle colons in value

      // Find the widget
      final element = _findWidget(finderType, value);
      if (element == null) {
        return jsonEncode({'error': 'Widget not found: $finderType=$value'});
      }

      // Extract text from the widget tree
      final texts = <String>[];
      void collectText(Element e) {
        if (e.widget is Text) {
          final text = e.widget as Text;
          final textData = text.data ?? text.textSpan?.toPlainText();
          if (textData != null && textData.isNotEmpty) {
            texts.add(textData);
          }
        }
        e.visitChildren(collectText);
      }

      collectText(element);

      if (texts.isEmpty) {
        return jsonEncode({'error': 'No text found in widget'});
      }

      return jsonEncode({
        'success': true,
        'text': texts.join(' '),
        'textParts': texts,
      });
    } catch (e, stack) {
      return jsonEncode({
        'error': 'Get text failed: $e',
        'stack': stack.toString(),
      });
    }
  }

  // =============================================================================
  // HELPER METHODS
  // =============================================================================

  /// Find a widget by finder type and value
  Element? _findWidget(String finderType, String value) {
    final componentContext = storyboardComponentKey.currentContext;
    if (componentContext == null) return null;

    Element? found;

    void visitor(Element element) {
      if (found != null) return;

      final widget = element.widget;

      switch (finderType) {
        case 'key':
          if (widget.key is ValueKey && (widget.key as ValueKey).value == value) {
            found = element;
            return;
          }
          if (widget.key is Key && widget.key.toString() == "[$value]") {
            found = element;
            return;
          }
          break;

        case 'text':
          if (widget is Text) {
            final textData = widget.data ?? widget.textSpan?.toPlainText();
            if (textData == value) {
              found = element;
              return;
            }
          }
          break;

        case 'type':
          if (widget.runtimeType.toString() == value) {
            found = element;
            return;
          }
          break;
      }

      element.visitChildren(visitor);
    }

    componentContext.visitChildElements(visitor);
    return found;
  }

  /// Simulate a tap at a specific position
  Future<void> _simulateTap(Offset position) async {
    final binding = WidgetsBinding.instance;

    // Create pointer down event
    final pointer = 1;
    final downEvent = PointerDownEvent(
      pointer: pointer,
      position: position,
      timeStamp: Duration(milliseconds: DateTime.now().millisecondsSinceEpoch),
    );

    // Dispatch down event
    binding.handlePointerEvent(downEvent);

    // Small delay
    await Future.delayed(const Duration(milliseconds: 50));

    // Create pointer up event
    final upEvent = PointerUpEvent(
      pointer: pointer,
      position: position,
      timeStamp: Duration(milliseconds: DateTime.now().millisecondsSinceEpoch),
    );

    // Dispatch up event
    binding.handlePointerEvent(upEvent);

    // Wait for tap to process
    await Future.delayed(const Duration(milliseconds: 50));
  }

  /// Simulate a scroll gesture from start to end
  Future<void> _simulateScroll(Offset start, Offset end, Duration duration) async {
    final binding = WidgetsBinding.instance;
    final pointer = 1;

    // Send down event
    binding.handlePointerEvent(PointerDownEvent(
      pointer: pointer,
      position: start,
      timeStamp: Duration(milliseconds: DateTime.now().millisecondsSinceEpoch),
    ));

    // Simulate movement in steps
    const steps = 10;
    for (int i = 1; i <= steps; i++) {
      final progress = i / steps;
      final position = Offset(
        start.dx + (end.dx - start.dx) * progress,
        start.dy + (end.dy - start.dy) * progress,
      );

      binding.handlePointerEvent(PointerMoveEvent(
        pointer: pointer,
        position: position,
        timeStamp: Duration(milliseconds: DateTime.now().millisecondsSinceEpoch),
      ));

      await Future.delayed(Duration(milliseconds: duration.inMilliseconds ~/ steps));
    }

    // Send up event
    binding.handlePointerEvent(PointerUpEvent(
      pointer: pointer,
      position: end,
      timeStamp: Duration(milliseconds: DateTime.now().millisecondsSinceEpoch),
    ));
  }

  // =============================================================================
  // ANNOTATION METHODS
  // =============================================================================

  /// Get annotations for a component (or all if no route provided)
  /// Payload format: [componentRoute][:filterByStatus]
  /// filterByStatus can be: 'pending' (default), 'completed', or 'all'
  /// Legacy format also supported: [componentRoute]:true (for includeCompleted=true)
  String _getAnnotations(String payload) {
    try {
      String? componentRoute;
      String? filterByStatus;

      if (payload.isNotEmpty) {
        final parts = payload.split(':');
        componentRoute = parts[0].isNotEmpty ? parts[0] : null;

        // Parse the second parameter (status filter)
        if (parts.length > 1 && parts[1].isNotEmpty) {
          final param = parts[1].toLowerCase();

          // Support legacy boolean format (true = all, false = pending)
          if (param == 'true') {
            filterByStatus = 'all';
          } else if (param == 'false') {
            filterByStatus = 'pending';
          } else if (['pending', 'completed', 'all'].contains(param)) {
            filterByStatus = param;
          } else {
            return jsonEncode({
              'error': 'Invalid status filter. Must be: pending, completed, all, true, or false',
              'providedValue': parts[1],
            });
          }
        }
      }

      return AnnotationService.instance.exportAsJson(
        componentRoute: componentRoute,
        filterByStatus: filterByStatus,
      );
    } catch (e, stack) {
      return jsonEncode({
        'error': 'Get annotations failed: $e',
        'stack': stack.toString(),
      });
    }
  }

  /// Get a summary of all annotations
  String _getAnnotationsSummary() {
    try {
      return jsonEncode(AnnotationService.instance.getSummary());
    } catch (e, stack) {
      return jsonEncode({
        'error': 'Get annotations summary failed: $e',
        'stack': stack.toString(),
      });
    }
  }

  /// Enable or disable inspect mode
  String _setInspectMode(bool enabled) {
    final state = storyboardDriverStateInstance;
    if (state == null) {
      return jsonEncode({'error': 'Storyboard not initialized'});
    }

    state.setInspectMode(enabled);
    return jsonEncode({
      'success': true,
      'inspectMode': enabled,
      'message': enabled ? 'Inspect mode enabled' : 'Inspect mode disabled',
    });
  }

  /// Clear annotations for a component (or all if no route provided)
  Future<String> _clearAnnotations(String payload) async {
    try {
      if (payload.isEmpty) {
        await AnnotationService.instance.clearAllAnnotations();

        // Show success toast
        ToastService.instance.showSuccess(
          title: 'Annotations Cleared',
          description: 'Cleared all annotations',
        );

        return jsonEncode({
          'success': true,
          'message': 'Cleared all annotations',
        });
      } else {
        await AnnotationService.instance.clearAnnotations(payload);

        // Show success toast
        ToastService.instance.showSuccess(
          title: 'Annotations Cleared',
          description: 'Cleared annotations for component',
        );

        return jsonEncode({
          'success': true,
          'message': 'Cleared annotations for $payload',
        });
      }
    } catch (e, stack) {
      return jsonEncode({
        'error': 'Clear annotations failed: $e',
        'stack': stack.toString(),
      });
    }
  }

  /// Set annotation status (pending or completed)
  Future<String> _setAnnotationStatus(String payload) async {
    try {
      final parts = payload.split(':');
      if (parts.length < 3) {
        return jsonEncode({'error': 'Invalid payload format. Expected: componentRoute:annotationId:status'});
      }

      final componentRoute = parts[0];
      final annotationId = parts[1];
      final status = parts[2];

      if (status == 'completed') {
        await AnnotationService.instance.markAsCompleted(
          componentRoute: componentRoute,
          annotationId: annotationId,
        );

        // Show success toast
        ToastService.instance.showSuccess(
          title: 'Annotation Completed',
          description: 'Marked annotation as completed',
        );

        return jsonEncode({
          'success': true,
          'message': 'Annotation marked as completed',
          'componentRoute': componentRoute,
          'annotationId': annotationId,
          'status': status,
        });
      } else if (status == 'pending') {
        await AnnotationService.instance.reopenAnnotation(
          componentRoute: componentRoute,
          annotationId: annotationId,
        );

        // Show info toast
        ToastService.instance.showInfo(
          title: 'Annotation Reopened',
          description: 'Status set to pending',
        );

        return jsonEncode({
          'success': true,
          'message': 'Annotation reopened (status set to pending)',
          'componentRoute': componentRoute,
          'annotationId': annotationId,
          'status': status,
        });
      } else {
        return jsonEncode({'error': 'Invalid status. Must be "pending" or "completed"'});
      }
    } catch (e, stack) {
      return jsonEncode({
        'error': 'Set annotation status failed: $e',
        'stack': stack.toString(),
      });
    }
  }

  /// Add feedback to an annotation and optionally mark as completed
  Future<String> _addAnnotationFeedback(String payload) async {
    try {
      final parts = payload.split(':');
      if (parts.length < 5) {
        return jsonEncode({'error': 'Invalid payload format. Expected: componentRoute:annotationId:author:text:markAsCompleted'});
      }

      final componentRoute = parts[0];
      final annotationId = parts[1];
      final author = parts[2];
      final markAsCompleted = parts[parts.length - 1] == 'true';
      // Text is everything between author and markAsCompleted flag
      final text = parts.sublist(3, parts.length - 1).join(':');

      if (markAsCompleted) {
        // Use completeAnnotation which adds feedback and marks as completed
        await AnnotationService.instance.completeAnnotation(
          componentRoute: componentRoute,
          annotationId: annotationId,
          completedBy: author,
          feedbackText: text,
        );

        // Show success toast
        ToastService.instance.showSuccess(
          title: 'Annotation Completed',
          description: 'Feedback added and marked as completed',
        );

        return jsonEncode({
          'success': true,
          'message': 'Feedback added and annotation marked as completed',
          'componentRoute': componentRoute,
          'annotationId': annotationId,
        });
      } else {
        // Just add feedback without marking as completed
        await AnnotationService.instance.addFeedback(
          componentRoute: componentRoute,
          annotationId: annotationId,
          author: author,
          text: text,
        );

        // Show info toast
        ToastService.instance.showInfo(
          title: 'Feedback Added',
          description: 'Added feedback to annotation',
        );

        return jsonEncode({
          'success': true,
          'message': 'Feedback added to annotation',
          'componentRoute': componentRoute,
          'annotationId': annotationId,
        });
      }
    } catch (e, stack) {
      return jsonEncode({
        'error': 'Add annotation feedback failed: $e',
        'stack': stack.toString(),
      });
    }
  }

  // =============================================================================
  // TOAST NOTIFICATION METHODS
  // =============================================================================

  /// Show a toast notification
  /// Format: show_toast:success:Title:Optional description
  /// Format: show_toast:info:Title
  /// Format: show_toast:warning:Title:Description
  /// Format: show_toast:error:Title:Error message
  String _showToast(String payload) {
    try {
      final parts = payload.split(':');
      if (parts.isEmpty) {
        return jsonEncode({'error': 'Invalid format. Expected: type:title:description?'});
      }

      final type = parts[0];
      final title = parts.length > 1 ? parts[1] : '';
      final description = parts.length > 2 ? parts.sublist(2).join(':') : null;

      if (title.isEmpty) {
        return jsonEncode({'error': 'Title is required'});
      }

      switch (type.toLowerCase()) {
        case 'success':
          ToastService.instance.showSuccess(
            title: title,
            description: description,
          );
          break;
        case 'info':
          ToastService.instance.showInfo(
            title: title,
            description: description,
          );
          break;
        case 'warning':
          ToastService.instance.showWarning(
            title: title,
            description: description,
          );
          break;
        case 'error':
          ToastService.instance.showError(
            title: title,
            description: description,
          );
          break;
        default:
          return jsonEncode({'error': 'Invalid toast type. Must be: success, info, warning, or error'});
      }

      return jsonEncode({
        'success': true,
        'type': type,
        'title': title,
        'description': description,
      });
    } catch (e, stack) {
      return jsonEncode({
        'error': 'Show toast failed: $e',
        'stack': stack.toString(),
      });
    }
  }

  // =============================================================================
  // DESIGN SYSTEM METHODS
  // =============================================================================

  /// Get text styles from the design system
  /// Optional payload is a search query to filter results
  String _getTextStyles(String payload) {
    try {
      final provider = ReboundTextThemeProvider();
      final allEntries = provider.getAllEntries();
      final query = payload.toLowerCase();

      // Filter by query if provided
      final entries = query.isEmpty
          ? allEntries
          : allEntries.where((entry) {
              return entry.name.toLowerCase().contains(query) ||
                  entry.extension.toLowerCase().contains(query) ||
                  entry.size.toLowerCase().contains(query) ||
                  entry.weight.toLowerCase().contains(query);
            }).toList();

      // Convert to JSON-serializable format
      final result = entries.map((entry) {
        return {
          'name': entry.name,
          'extension': entry.extension,
          'size': entry.size,
          'sizeValue': entry.sizeValue,
          'weight': entry.weight,
          'weightValue': entry.weightValue,
          'usages': entry.usages
              .map((u) => {
                    'componentName': u.componentName,
                    'filePath': u.filePath,
                  })
              .toList(),
          // Extract style properties
          'style': {
            'fontSize': entry.style.fontSize,
            'fontWeight': entry.style.fontWeight?.value,
            'fontFamily': entry.style.fontFamily,
            'letterSpacing': entry.style.letterSpacing,
            'height': entry.style.height,
          },
        };
      }).toList();

      return jsonEncode({
        'success': true,
        'query': query.isEmpty ? null : query,
        'count': result.length,
        'totalCount': allEntries.length,
        'styles': result,
      });
    } catch (e, stack) {
      return jsonEncode({
        'error': 'Get text styles failed: $e',
        'stack': stack.toString(),
      });
    }
  }

  /// Get colors from the design system
  /// Payload can be:
  /// - Empty: returns all colors
  /// - Simple string: text search across all fields
  /// - JSON object: property-based search with optional closest match
  ///   {
  ///     "hex": "#237B6E",        // Search by hex color (exact or closest)
  ///     "name": "border",        // Search by name (contains)
  ///     "semanticRole": "border" // Search by semantic role (contains)
  ///   }
  String _getColors(String payload) {
    try {
      final provider = ReboundColorProvider();
      final allEntries = provider.getAllEntries();
      final gradients = provider.getGradients();

      // Try to parse as JSON, fall back to simple string query
      Map<String, dynamic>? searchParams;
      String? simpleQuery;

      if (payload.isNotEmpty) {
        if (payload.startsWith('{')) {
          try {
            searchParams = jsonDecode(payload) as Map<String, dynamic>;
          } catch (_) {
            simpleQuery = payload.toLowerCase();
          }
        } else {
          simpleQuery = payload.toLowerCase();
        }
      }

      List<ColorEntry> entries;
      Map<String, dynamic>? closestMatch;
      String? searchedHex;

      if (searchParams != null) {
        // Property-based search
        entries = allEntries.where((entry) {
          bool matches = true;

          // Search by hex
          if (searchParams!.containsKey('hex')) {
            final searchHex = (searchParams['hex'] as String).toLowerCase().replaceAll('#', '');
            final entryHex = entry.color.value.toRadixString(16).padLeft(8, '0').toLowerCase();
            // Also check without alpha (last 6 chars)
            final entryHexNoAlpha = entryHex.substring(2);
            matches = matches && (entryHex.contains(searchHex) || entryHexNoAlpha == searchHex || searchHex == entryHexNoAlpha);
          }

          // Search by name
          if (searchParams.containsKey('name')) {
            final searchName = (searchParams['name'] as String).toLowerCase();
            matches = matches && entry.name.toLowerCase().contains(searchName);
          }

          // Search by semantic role
          if (searchParams.containsKey('semanticRole')) {
            final searchRole = (searchParams['semanticRole'] as String).toLowerCase();
            matches = matches && (entry.semanticRole?.toLowerCase().contains(searchRole) ?? false);
          }

          // Search by description
          if (searchParams.containsKey('description')) {
            final searchDesc = (searchParams['description'] as String).toLowerCase();
            matches = matches && (entry.description?.toLowerCase().contains(searchDesc) ?? false);
          }

          return matches;
        }).toList();

        // If searching by hex and no exact match, find closest color
        if (searchParams.containsKey('hex') && entries.isEmpty) {
          searchedHex = (searchParams['hex'] as String).toLowerCase().replaceAll('#', '');
          closestMatch = _findClosestColor(searchedHex, allEntries);
        }
      } else if (simpleQuery != null && simpleQuery.isNotEmpty) {
        // Simple text search across all fields
        entries = allEntries.where((entry) {
          final hexValue = '#${entry.color.value.toRadixString(16).padLeft(8, '0')}';
          return entry.name.toLowerCase().contains(simpleQuery!) ||
              entry.accessor.toLowerCase().contains(simpleQuery) ||
              (entry.description?.toLowerCase().contains(simpleQuery) ?? false) ||
              (entry.semanticRole?.toLowerCase().contains(simpleQuery) ?? false) ||
              hexValue.toLowerCase().contains(simpleQuery);
        }).toList();

        // If looks like a hex search and no match, find closest
        if (entries.isEmpty && (simpleQuery.startsWith('#') || RegExp(r'^[0-9a-f]{6}$').hasMatch(simpleQuery))) {
          searchedHex = simpleQuery.replaceAll('#', '');
          closestMatch = _findClosestColor(searchedHex, allEntries);
        }
      } else {
        entries = allEntries;
      }

      // Convert colors to JSON-serializable format
      final colorResult = entries.map((entry) {
        return _colorEntryToJson(entry);
      }).toList();

      // Convert gradients to JSON-serializable format
      final gradientResult = gradients.map((g) {
        return {
          'name': g.name,
          'accessor': g.accessor,
          'description': g.description,
          'direction': g.direction,
          'colors': g.colors
              .map((c) => '#${c.value.toRadixString(16).padLeft(8, '0')}')
              .toList(),
        };
      }).toList();

      final result = <String, dynamic>{
        'success': true,
        'searchParams': searchParams,
        'query': simpleQuery,
        'count': colorResult.length,
        'totalCount': allEntries.length,
        'colors': colorResult,
        'gradients': gradientResult,
      };

      // Add closest match info if no exact match was found
      if (closestMatch != null) {
        result['exactMatch'] = false;
        result['closestMatch'] = closestMatch;
        final closestName = closestMatch['name'] as String?;
        result['suggestion'] = 'Color #$searchedHex not found. Closest: $closestName. Consider adding to palette.';
      } else if (entries.isEmpty && (searchParams != null || (simpleQuery != null && simpleQuery.isNotEmpty))) {
        result['suggestion'] = 'No colors found. Consider adding to ReboundColors.';
      }

      return jsonEncode(result);
    } catch (e, stack) {
      return jsonEncode({
        'error': 'Get colors failed: $e',
        'stack': stack.toString(),
      });
    }
  }

  /// Convert a ColorEntry to JSON-serializable map
  Map<String, dynamic> _colorEntryToJson(ColorEntry entry) {
    return {
      'name': entry.name,
      'accessor': entry.accessor,
      'description': entry.description,
      'semanticRole': entry.semanticRole,
      'hex': '#${entry.color.value.toRadixString(16).padLeft(8, '0')}',
      'hexNoAlpha': '#${entry.color.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      'rgba': {
        'r': entry.color.red,
        'g': entry.color.green,
        'b': entry.color.blue,
        'a': entry.color.alpha,
      },
    };
  }

  /// Find the closest color using RGB Euclidean distance
  /// Returns the closest match with distance info
  Map<String, dynamic>? _findClosestColor(String searchHex, List<ColorEntry> entries) {
    if (entries.isEmpty) return null;

    // Parse search hex to RGB
    final searchRgb = _hexToRgb(searchHex);
    if (searchRgb == null) return null;

    ColorEntry? closest;
    double minDistance = double.infinity;

    for (final entry in entries) {
      final r = entry.color.red;
      final g = entry.color.green;
      final b = entry.color.blue;

      // Euclidean distance in RGB space
      final distance = _colorDistance(searchRgb, [r, g, b]);

      if (distance < minDistance) {
        minDistance = distance;
        closest = entry;
      }
    }

    if (closest == null) return null;

    // Max squared distance is 255^2 * 3 = 195075
    // Take sqrt for actual distance
    final sqrtDistance = math.sqrt(minDistance);

    return {
      ..._colorEntryToJson(closest),
      'distance': sqrtDistance.round(),
      'distancePercent': ((sqrtDistance / 441.67) * 100).round(), // 441.67 = max distance (sqrt(255^2 * 3))
      'searchedHex': '#$searchHex',
    };
  }

  /// Parse hex string to RGB values [r, g, b]
  List<int>? _hexToRgb(String hex) {
    // Remove # if present and handle various formats
    var cleanHex = hex.replaceAll('#', '').toLowerCase();

    // Handle 8-char ARGB format (skip alpha)
    if (cleanHex.length == 8) {
      cleanHex = cleanHex.substring(2);
    }

    // Handle 3-char shorthand (#RGB -> #RRGGBB)
    if (cleanHex.length == 3) {
      cleanHex = cleanHex.split('').map((c) => '$c$c').join();
    }

    if (cleanHex.length != 6) return null;

    try {
      final r = int.parse(cleanHex.substring(0, 2), radix: 16);
      final g = int.parse(cleanHex.substring(2, 4), radix: 16);
      final b = int.parse(cleanHex.substring(4, 6), radix: 16);
      return [r, g, b];
    } catch (_) {
      return null;
    }
  }

  /// Calculate Euclidean distance between two RGB colors
  double _colorDistance(List<int> rgb1, List<int> rgb2) {
    final dr = rgb1[0] - rgb2[0];
    final dg = rgb1[1] - rgb2[1];
    final db = rgb1[2] - rgb2[2];
    return (dr * dr + dg * dg + db * db).toDouble();
  }
}
