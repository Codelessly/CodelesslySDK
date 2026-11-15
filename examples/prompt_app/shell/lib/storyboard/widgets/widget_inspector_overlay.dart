import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
// ignore: implementation_imports
import 'package:inspector/src/utils.dart' as inspector_utils;
import '../utils/annotation_constants.dart';

/// Information about a selected/hovered widget
class WidgetInfo {
  final RenderBox renderBox;
  final Rect globalBounds;
  final String widgetType;
  final String? debugLabel;

  /// Raw debugCreator string from the widget
  /// Example: "ReboundDropdown<String>(hint: "Select a state", value: null)"
  final String? widgetDebugInfo;

  WidgetInfo({
    required this.renderBox,
    required this.globalBounds,
    required this.widgetType,
    this.debugLabel,
    this.widgetDebugInfo,
  });
}

/// A custom widget inspector overlay that provides hover-to-highlight functionality
/// similar to browser dev tools.
///
/// Uses the inspector package's InspectorUtils for proper render tree traversal.
class WidgetInspectorOverlay extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final bool isDarkMode;

  /// Called when a widget is selected (tapped)
  final void Function(WidgetInfo info)? onWidgetSelected;

  /// Called when inspect mode is exited via escape, right-click, or banner click
  final VoidCallback? onExit;

  /// The bounds to constrain hit testing (e.g., component viewer area)
  final GlobalKey? constraintKey;

  /// Highlight border color
  final Color? highlightColor;

  /// Highlight border width
  final double highlightBorderWidth;

  const WidgetInspectorOverlay({
    super.key,
    required this.child,
    this.enabled = false,
    this.isDarkMode = false,
    this.onWidgetSelected,
    this.onExit,
    this.constraintKey,
    this.highlightColor,
    this.highlightBorderWidth = 2.0,
  });

  @override
  State<WidgetInspectorOverlay> createState() => _WidgetInspectorOverlayState();
}

class _WidgetInspectorOverlayState extends State<WidgetInspectorOverlay> {
  WidgetInfo? _hoveredWidget;
  final GlobalKey _contentKey = GlobalKey();

  Color get _effectiveHighlightColor =>
      widget.highlightColor ??
      (widget.isDarkMode
          ? const Color(0xFF10B981) // Emerald green
          : const Color(0xFF059669));

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return _InspectorWrapper(
      contentKey: _contentKey,
      hoveredWidget: _hoveredWidget,
      highlightColor: _effectiveHighlightColor,
      highlightBorderWidth: widget.highlightBorderWidth,
      isDarkMode: widget.isDarkMode,
      onHover: _handleHover,
      onTap: _handleTap,
      onCancel: _handleCancel,
      onPointerExit: _handlePointerExit,
      child: widget.child,
    );
  }

  void _handleHover(Offset position) {
    final widgetInfo = _findWidgetAt(position);
    if (widgetInfo?.globalBounds != _hoveredWidget?.globalBounds) {
      setState(() {
        _hoveredWidget = widgetInfo;
      });
    }
  }

  void _handleTap(Offset position) {
    final widgetInfo = _findWidgetAt(position);
    if (widgetInfo != null) {
      widget.onWidgetSelected?.call(widgetInfo);
    }
  }

  void _handleCancel() {
    setState(() {
      _hoveredWidget = null;
    });
    widget.onExit?.call();
  }

  void _handlePointerExit() {
    setState(() {
      _hoveredWidget = null;
    });
  }

  WidgetInfo? _findWidgetAt(Offset position) {
    // Check if position is within constraint bounds
    if (widget.constraintKey != null) {
      final constraintContext = widget.constraintKey!.currentContext;
      if (constraintContext != null) {
        final constraintBox =
            constraintContext.findRenderObject() as RenderBox?;
        if (constraintBox != null) {
          final constraintOffset = constraintBox.localToGlobal(Offset.zero);
          final constraintBounds = constraintOffset & constraintBox.size;
          if (!constraintBounds.contains(position)) {
            return null;
          }
        }
      }
    }

    // Use the content key's context to find widgets
    final contentContext = _contentKey.currentContext;
    if (contentContext == null) return null;

    // Use the inspector package's utility to find render objects
    final boxes = inspector_utils.InspectorUtils.findRenderObjectsAt(
      contentContext,
      position,
    ).toList();

    if (boxes.isEmpty) return null;

    // Filter out very small widgets and sort by area (smallest first = most specific)
    final validBoxes = boxes.where((box) {
      if (!box.attached || !box.hasSize) return false;
      // Skip very small widgets (likely internal framework widgets)
      if (box.size.width < AnnotationConstants.inspectorMinWidgetSize ||
          box.size.height < AnnotationConstants.inspectorMinWidgetSize) {
        return false;
      }
      return true;
    }).toList();

    if (validBoxes.isEmpty) return null;

    // Sort by area (smallest first = most specific)
    validBoxes.sort((a, b) {
      final areaA = a.size.width * a.size.height;
      final areaB = b.size.width * b.size.height;
      return areaA.compareTo(areaB);
    });

    // Get the smallest non-trivial box
    final selectedBox = validBoxes.first;
    final globalOffset = selectedBox.localToGlobal(Offset.zero);
    final bounds = globalOffset & selectedBox.size;

    // Get widget type name from debug creator
    String widgetType = selectedBox.runtimeType.toString();
    if (selectedBox.debugCreator != null) {
      final creator = selectedBox.debugCreator.toString();
      // Extract widget name from debug creator string
      final match = RegExp(r'^(\w+)').firstMatch(creator);
      if (match != null) {
        widgetType = match.group(1) ?? widgetType;
      }
    }

    return WidgetInfo(
      renderBox: selectedBox,
      globalBounds: bounds,
      widgetType: widgetType,
      debugLabel: _buildDebugLabel(selectedBox, widgetType),
      widgetDebugInfo: _extractWidgetDebugInfo(selectedBox),
    );
  }

  /// Extract widget debug information including properties and hierarchy
  String? _extractWidgetDebugInfo(RenderBox box) {
    if (box.debugCreator == null) return null;

    try {
      // In Flutter, debugCreator is a DebugCreator object that contains the Element
      final creator = box.debugCreator as dynamic;

      // Access the element - DebugCreator has an 'element' property
      Element? element;
      try {
        element = creator.element as Element?;
      } catch (_) {
        // Fallback: try accessing as value or other property
        try {
          element = creator.value as Element?;
        } catch (_) {
          element = null;
        }
      }

      if (element != null) {
        final widget = element.widget;

        // Get detailed widget description with properties
        final widgetDescription = widget.toStringDeep(
          prefixLineOne: '',
          prefixOtherLines: '  ',
        );

        // Get the widget tree path with indices up to the component viewer boundary
        final List<String> treePath = [];

        // Add current widget with index (unless it should be skipped)
        final currentType = element.widget.runtimeType.toString();
        if (!_shouldSkipWidget(currentType)) {
          final currentIndex = _getElementSiblingIndex(element, currentType);
          treePath.add(currentIndex != null ? '$currentType[$currentIndex]' : currentType);
        }

        element.visitAncestorElements((ancestor) {
          final widgetType = ancestor.widget.runtimeType.toString();

          // Stop at storyboard boundaries
          if (_isBoundaryWidget(widgetType)) {
            return false; // Stop visiting
          }

          // Skip framework widgets but continue traversal
          if (_shouldSkipWidget(widgetType)) {
            return true; // Skip but continue visiting
          }

          // Add meaningful ancestor with index
          final index = _getElementSiblingIndex(ancestor, widgetType);
          treePath.add(index != null ? '$widgetType[$index]' : widgetType);
          return true; // Continue visiting
        });

        // Reverse the tree path to show parent > child (top-down)
        final treePathString = treePath.reversed.join(' > ');

        return 'Widget: ${widget.runtimeType}\n'
            'Properties: ${widget.toString()}\n'
            '---\n'
            'Tree: $treePathString\n'
            '---\n'
            'Details:\n$widgetDescription';
      }

      // Fallback to toString
      return box.debugCreator.toString();
    } catch (e, stackTrace) {
      // Fallback to safe toString on error, with error info for debugging
      return 'Error extracting debug info: $e\n'
          'Stack: ${stackTrace.toString().split('\n').take(3).join('\n')}\n'
          '---\n'
          '${box.debugCreator.toString()}';
    }
  }

  /// Build a human-readable debug label for the widget
  String _buildDebugLabel(RenderBox box, String widgetType) {
    if (box.debugCreator == null) return widgetType;

    final creator = box.debugCreator.toString();

    // Extract hint for dropdowns (simple regex)
    if (creator.contains('Dropdown') && creator.contains('hint:')) {
      final hintMatch = RegExp(r'hint:\s*"([^"]+)"').firstMatch(creator);
      if (hintMatch != null) {
        return '$widgetType: "${hintMatch.group(1)}"';
      }
    }

    // Extract text content for Text widgets
    if (box is RenderParagraph) {
      try {
        final text = box.text.toPlainText().trim();
        if (text.isNotEmpty) {
          final truncated = text.length > 30 ? '${text.substring(0, 27)}...' : text;
          return truncated;
        }
      } catch (e) {
        // Ignore
      }
    }

    return widgetType;
  }

  /// Framework widgets to skip in tree paths (internal Flutter/Material)
  /// Copied from WidgetTreeBuilder to keep filtering consistent
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

  /// Widget types that should stop tree traversal (storyboard boundaries)
  static const _boundaryWidgetTypes = <String>{
    'KeyedSubtree',
    'WidgetInspectorOverlay',
    '_InspectorWrapper',
  };

  /// Check if a widget type should be filtered from the tree
  bool _shouldSkipWidget(String typeName) {
    return _skipWidgetTypes.contains(typeName);
  }

  /// Check if a widget type is a storyboard boundary (stop traversal)
  bool _isBoundaryWidget(String typeName) {
    return _boundaryWidgetTypes.contains(typeName);
  }

  /// Get sibling index for an element with same type
  /// Returns null if this is the only element of this type
  int? _getElementSiblingIndex(Element element, String type) {
    Element? parent;
    element.visitAncestorElements((ancestor) {
      parent = ancestor;
      return false; // Stop after first parent
    });

    if (parent == null) return null;

    int sameTypeCount = 0;
    int? ourIndex;
    int currentIndex = 0;

    parent!.visitChildElements((child) {
      final childType = child.widget.runtimeType.toString();
      if (childType == type) {
        if (child == element) {
          ourIndex = currentIndex;
        }
        currentIndex++;
        sameTypeCount++;
      }
    });

    // Only include index if there are multiple of same type
    return (sameTypeCount > 1) ? ourIndex : null;
  }
}

/// Internal wrapper that captures events and renders the overlay
class _InspectorWrapper extends StatefulWidget {
  final GlobalKey contentKey;
  final Widget child;
  final WidgetInfo? hoveredWidget;
  final Color highlightColor;
  final double highlightBorderWidth;
  final bool isDarkMode;
  final void Function(Offset) onHover;
  final void Function(Offset) onTap;
  final VoidCallback onCancel;
  final VoidCallback onPointerExit;

  const _InspectorWrapper({
    required this.contentKey,
    required this.child,
    required this.hoveredWidget,
    required this.highlightColor,
    required this.highlightBorderWidth,
    required this.isDarkMode,
    required this.onHover,
    required this.onTap,
    required this.onCancel,
    required this.onPointerExit,
  });

  @override
  State<_InspectorWrapper> createState() => _InspectorWrapperState();
}

class _InspectorWrapperState extends State<_InspectorWrapper> {
  final GlobalKey _stackKey = GlobalKey();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Request focus immediately when the overlay appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Convert global bounds to local coordinates relative to the stack
  Rect? _toLocalBounds(Rect globalBounds) {
    final stackContext = _stackKey.currentContext;
    if (stackContext == null) return null;

    final stackBox = stackContext.findRenderObject() as RenderBox?;
    if (stackBox == null) return null;

    final stackOffset = stackBox.localToGlobal(Offset.zero);
    return globalBounds.shift(-stackOffset);
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onCancel();
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    // Right click (secondary button) cancels
    if (event.buttons == kSecondaryMouseButton) {
      widget.onCancel();
      return;
    }
    // Left click selects widget
    widget.onTap(event.position);
  }

  @override
  Widget build(BuildContext context) {
    final localBounds = widget.hoveredWidget != null
        ? _toLocalBounds(widget.hoveredWidget!.globalBounds)
        : null;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Stack(
        key: _stackKey,
        children: [
          // Content wrapped with event capture
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerHover: (e) => widget.onHover(e.position),
            onPointerDown: _handlePointerDown,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onExit: (_) => widget.onPointerExit(),
              child: AbsorbPointer(
                absorbing: true,
                child: KeyedSubtree(
                  key: widget.contentKey,
                  child: widget.child,
                ),
              ),
            ),
          ),

          // Highlight overlay
          if (widget.hoveredWidget != null && localBounds != null)
            Positioned.fromRect(
              rect: localBounds,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: widget.highlightColor,
                      width: widget.highlightBorderWidth,
                    ),
                    color: widget.highlightColor.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),

          // Widget type label
          if (widget.hoveredWidget != null && localBounds != null)
            Positioned(
              left: localBounds.left,
              top: (localBounds.top - AnnotationConstants.inspectorLabelOffset)
                  .clamp(0, double.infinity),
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.highlightColor,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.hoveredWidget!.widgetType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

          // Mode indicator banner (clickable to cancel)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: widget.onCancel,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.highlightColor,
                          widget.highlightColor.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.touch_app,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Click to annotate',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'ESC to exit',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
