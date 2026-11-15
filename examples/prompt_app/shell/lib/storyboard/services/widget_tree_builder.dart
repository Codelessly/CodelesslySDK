import 'package:flutter/widgets.dart';

/// Builds a simplified widget tree representation for debugging and AI analysis.
/// Filters out framework internals to show only meaningful widgets.
class WidgetTreeBuilder {
  WidgetTreeBuilder._();

  /// Framework widgets to skip when building the tree (internal Flutter/Material)
  /// These add noise without meaningful information
  static const _skipWidgetTypes = <String>{
    // Scaffold internals
    '_ScaffoldScope',
    'ScrollNotificationObserver',
    '_ScrollNotificationObserverScope',
    // Material internals
    'AnimatedPhysicalModel',
    'PhysicalModel',
    '_InkFeatures',
    'AnimatedDefaultTextStyle',
    'DefaultTextStyle',
    // Animation/Builder wrappers
    'AnimatedBuilder',
    'Builder',
    'RepaintBoundary',
    // Action/Focus internals
    'Actions',
    '_ActionsScope',
    'FocusScope',
    '_FocusInheritedScope',
    'FocusTraversalGroup',
    '_FocusTraversalGroupScope',
    // Other framework widgets
    'Semantics',
    '_RawGestureDetectorState',
    'Listener',
    'PointerListener',
    '_ModalScopeStatus',
    'PrimaryScrollController',
    'ScrollConfiguration',
    '_InheritedTheme',
    '_MediaQueryFromView',
    // Layout wrappers that don't add meaning
    'CustomMultiChildLayout',
    'LayoutId',
    'KeyedSubtree',
    'MediaQuery',
    'InheritedCupertinoTheme',
    'CupertinoTheme',
    'AnimatedTheme',
    'Theme',
    'IconTheme',
    'DefaultSelectionStyle',
    'Focus',
    'MouseRegion',
    'IgnorePointer',
    'PhysicalShape',
    'CustomPaint',
    'ConstrainedBox',
    'Transform',
    'Scrollbar',
    'RawGestureDetector',
    // Private framework widgets (underscore-prefixed)
    '_Theater',
    '_GestureSemantics',
    '_ScrollSemantics',
    '_SingleChildViewport',
  };

  /// Sanitize a double value for JSON encoding
  /// Converts Infinity and NaN to a string representation
  static dynamic sanitizeDouble(double? value) {
    if (value == null) return null;
    if (value.isInfinite) return value.isNegative ? '-infinity' : 'infinity';
    if (value.isNaN) return 'NaN';
    return value;
  }

  /// Check if a widget type should be skipped
  static bool shouldSkipWidget(String typeName) {
    return _skipWidgetTypes.contains(typeName);
  }

  /// Build a simplified widget tree from an element
  /// [summaryOnly] - When true (default), skips framework internals
  /// [maxDepth] - Maximum depth to traverse (default 30)
  static Map<String, dynamic> build(
    Element element, {
    int depth = 0,
    int maxDepth = 30,
    bool summaryOnly = true,
  }) {
    if (depth >= maxDepth) {
      return {'widget': '... (max depth reached)', 'children': <dynamic>[]};
    }

    final widget = element.widget;
    final typeName = widget.runtimeType.toString();

    // Check if we should skip this widget
    if (summaryOnly && shouldSkipWidget(typeName)) {
      // Skip this widget but process children at the same depth
      final children = <Map<String, dynamic>>[];
      element.visitChildren((child) {
        final childResult = build(
          child,
          depth: depth, // Don't increment depth for skipped widgets
          maxDepth: maxDepth,
          summaryOnly: summaryOnly,
        );
        // If child returned meaningful content, add it
        if (childResult['widget'] != null) {
          // If the child is a direct passthrough (from another skip), flatten it
          if (childResult['widget'] == '(passthrough)') {
            final grandchildren = childResult['children'] as List?;
            if (grandchildren != null) {
              children.addAll(grandchildren.cast<Map<String, dynamic>>());
            }
          } else {
            children.add(childResult);
          }
        }
      });

      // Return passthrough marker with collected children
      if (children.isEmpty) {
        return {'widget': null, 'children': <dynamic>[]};
      } else if (children.length == 1) {
        return children.first;
      } else {
        return {'widget': '(passthrough)', 'children': children};
      }
    }

    // This is a meaningful widget - process normally
    final children = <Map<String, dynamic>>[];
    element.visitChildren((child) {
      final childResult = build(
        child,
        depth: depth + 1,
        maxDepth: maxDepth,
        summaryOnly: summaryOnly,
      );
      if (childResult['widget'] != null &&
          childResult['widget'] != '(passthrough)') {
        children.add(childResult);
      } else if (childResult['widget'] == '(passthrough)') {
        // Flatten passthrough children
        final grandchildren = childResult['children'] as List?;
        if (grandchildren != null) {
          children.addAll(grandchildren.cast<Map<String, dynamic>>());
        }
      }
    });

    // Get widget details
    final widgetInfo = _extractWidgetInfo(widget, typeName, element);

    return {
      'widget': widgetInfo,
      'children': children,
    };
  }

  /// Extract relevant properties from a widget
  static Map<String, dynamic> _extractWidgetInfo(
    Widget widget,
    String typeName,
    Element element,
  ) {
    final widgetInfo = <String, dynamic>{
      'type': typeName,
    };

    // Add relevant properties for common widgets
    if (widget is Text) {
      widgetInfo['text'] = widget.data ?? (widget.textSpan?.toPlainText());
      if (widget.style != null) {
        final style = widget.style!;
        if (style.fontSize != null) widgetInfo['fontSize'] = style.fontSize;
        if (style.fontWeight != null) {
          widgetInfo['fontWeight'] = style.fontWeight.toString();
        }
        if (style.color != null) {
          widgetInfo['color'] =
              '#${style.color!.toARGB32().toRadixString(16).padLeft(8, '0')}';
        }
      }
    } else if (widget is Container) {
      if (widget.constraints != null) {
        widgetInfo['constraints'] = widget.constraints.toString();
      }
      if (widget.padding != null) {
        widgetInfo['padding'] = widget.padding.toString();
      }
      if (widget.margin != null) {
        widgetInfo['margin'] = widget.margin.toString();
      }
    } else if (widget is SizedBox) {
      widgetInfo['width'] = sanitizeDouble(widget.width);
      widgetInfo['height'] = sanitizeDouble(widget.height);
    } else if (widget is Padding) {
      widgetInfo['padding'] = widget.padding.toString();
    } else if (widget is Expanded || widget is Flexible) {
      widgetInfo['flex'] = (widget as dynamic).flex;
    } else if (widget is Align) {
      widgetInfo['alignment'] = widget.alignment.toString();
    } else if (widget is Opacity) {
      widgetInfo['opacity'] = widget.opacity;
    }

    // Get render object size if available
    final renderObject = element.renderObject;
    if (renderObject is RenderBox && renderObject.hasSize) {
      widgetInfo['size'] = {
        'width': sanitizeDouble(renderObject.size.width),
        'height': sanitizeDouble(renderObject.size.height),
      };
    }

    return widgetInfo;
  }
}
