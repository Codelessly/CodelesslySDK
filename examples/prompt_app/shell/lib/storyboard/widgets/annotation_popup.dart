import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:skip_shell/storyboard/models/annotation.dart';
import '../utils/annotation_constants.dart';

/// Minimal hover card for adding or editing an annotation
/// Positioned near the clicked widget
class AnnotationPopup extends StatefulWidget {
  final String widgetType;
  final Rect? widgetBounds;
  final Size screenSize;
  final bool isDarkMode;

  /// Existing annotation for edit mode
  final WidgetAnnotation? existingAnnotation;

  /// Called when annotation is submitted
  final void Function(String text) onSubmit;

  /// Called when annotation is deleted (edit mode only)
  final VoidCallback? onDelete;

  /// Called when annotation is marked as completed/reopened (edit mode only)
  final VoidCallback? onToggleComplete;

  /// Called when popup is canceled/closed
  final VoidCallback onCancel;

  const AnnotationPopup({
    super.key,
    required this.widgetType,
    this.widgetBounds,
    required this.screenSize,
    required this.isDarkMode,
    this.existingAnnotation,
    required this.onSubmit,
    this.onDelete,
    this.onToggleComplete,
    required this.onCancel,
  });

  @override
  State<AnnotationPopup> createState() => _AnnotationPopupState();
}

class _AnnotationPopupState extends State<AnnotationPopup> {
  late final TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();

  bool get isEditMode => widget.existingAnnotation != null;
  bool get isCompletedMode => widget.existingAnnotation?.status == AnnotationStatus.completed;
  bool get _hasText => _textController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // If annotation is completed, show empty text for follow-up
    _textController = TextEditingController(
      text: isCompletedMode ? '' : (widget.existingAnnotation?.text ?? ''),
    );
    _textController.addListener(() => setState(() {}));

    // Auto-focus after popup is displayed
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Calculate popup position relative to widget bounds
  Offset _calculatePosition() {
    if (widget.widgetBounds == null) {
      // Center if no bounds
      return Offset(
        (widget.screenSize.width - AnnotationConstants.popupWidth) / 2,
        (widget.screenSize.height - AnnotationConstants.popupHeight) / 2,
      );
    }

    final bounds = widget.widgetBounds!;
    final screenWidth = widget.screenSize.width;
    final screenHeight = widget.screenSize.height;

    // Position to the right of the widget
    double left = bounds.right + AnnotationConstants.popupGap;

    // Vertically align with widget center
    double top = bounds.center.dy - AnnotationConstants.popupHeight / 2;

    // Clamp vertical position to screen bounds
    top = top.clamp(
      AnnotationConstants.popupScreenPadding,
      screenHeight - AnnotationConstants.popupHeight - AnnotationConstants.popupScreenPadding,
    );

    // Clamp horizontal position to screen bounds (keeps it on right side)
    left = left.clamp(
      AnnotationConstants.popupScreenPadding,
      screenWidth - AnnotationConstants.popupWidth - AnnotationConstants.popupScreenPadding,
    );

    return Offset(left, top);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkMode ? const Color(0xFF1F2937) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final hintColor = widget.isDarkMode ? Colors.white38 : Colors.black38;
    final subtitleColor = widget.isDarkMode ? Colors.white54 : Colors.black45;
    final borderColor = widget.isDarkMode
        ? Colors.white12
        : Colors.grey.shade300;

    final position = _calculatePosition();

    return GestureDetector(
      onTap: widget.onCancel,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Positioned popup card
          Positioned(
            left: position.dx,
            top: position.dy,
            child: GestureDetector(
              onTap: () {}, // Prevent tap from propagating to background
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: AnnotationConstants.popupWidth,
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border.all(color: borderColor, width: 1),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Text input area
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Focus(
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent) {
                              if (event.logicalKey == LogicalKeyboardKey.escape) {
                                widget.onCancel();
                                return KeyEventResult.handled;
                              }
                              // Submit on Enter without shift/ctrl/alt/meta
                              if (event.logicalKey == LogicalKeyboardKey.enter) {
                                final keyboard = HardwareKeyboard.instance;
                                final hasModifiers = keyboard.isShiftPressed ||
                                    keyboard.isControlPressed ||
                                    keyboard.isAltPressed ||
                                    keyboard.isMetaPressed;

                                if (!hasModifiers && _hasText) {
                                  _submit();
                                  return KeyEventResult.handled;
                                }
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            maxLines: 4,
                            minLines: 3,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              height: 1.5,
                            ),
                            decoration: InputDecoration(
                              hintText: isCompletedMode
                                  ? 'Add a follow-up comment...'
                                  : 'Describe what you\'d like to change, e.g.,\n"Update the skill description"',
                              hintStyle: TextStyle(
                                color: hintColor,
                                fontSize: 14,
                                height: 1.5,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              hoverColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              fillColor: Colors.transparent,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                          ),
                        ),
                      ),

                      // Footer
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 12, 12),
                        child: Row(
                          children: [
                            // Instruction text
                            Text(
                              isCompletedMode ? 'Add follow-up' : 'Add annotation',
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 13,
                              ),
                            ),

                            // Complete/Reopen button (show in edit mode when onToggleComplete is provided)
                            if (isEditMode && widget.onToggleComplete != null) ...[
                              const SizedBox(width: 8),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: widget.onToggleComplete,
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      isCompletedMode ? Icons.check_circle : Icons.check_circle_outline,
                                      size: 18,
                                      color: isCompletedMode ? const Color(0xFF6B7280) : subtitleColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            // Delete button (show in edit mode when onDelete is provided)
                            if (isEditMode && widget.onDelete != null) ...[
                              const SizedBox(width: 8),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: widget.onDelete,
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: subtitleColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            const Spacer(),

                            // Submit button (circle)
                            _SubmitButton(
                              hasText: _hasText,
                              isDarkMode: widget.isDarkMode,
                              onSubmit: _submit,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
  }
}

/// Shows the annotation popup as an overlay positioned near the widget
Future<void> showAnnotationPopup({
  required BuildContext context,
  required String widgetType,
  Rect? widgetBounds,
  required bool isDarkMode,
  WidgetAnnotation? existingAnnotation,
  required void Function(String text) onSubmit,
  VoidCallback? onDelete,
  VoidCallback? onToggleComplete,
  VoidCallback? onCancel,
}) async {
  final overlay = Overlay.of(context);
  final screenSize = MediaQuery.of(context).size;
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => AnnotationPopup(
      widgetType: widgetType,
      widgetBounds: widgetBounds,
      screenSize: screenSize,
      isDarkMode: isDarkMode,
      existingAnnotation: existingAnnotation,
      onSubmit: (text) {
        entry.remove();
        onSubmit(text);
      },
      onDelete: onDelete != null
          ? () {
              entry.remove();
              onDelete();
            }
          : null,
      onToggleComplete: onToggleComplete != null
          ? () {
              entry.remove();
              onToggleComplete();
            }
          : null,
      onCancel: () {
        entry.remove();
        onCancel?.call();
      },
    ),
  );

  overlay.insert(entry);
}

/// Submit button with hover and press effects
class _SubmitButton extends StatefulWidget {
  final bool hasText;
  final bool isDarkMode;
  final VoidCallback onSubmit;

  const _SubmitButton({
    required this.hasText,
    required this.isDarkMode,
    required this.onSubmit,
  });

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.hasText;
    final baseColor = isEnabled
        ? const Color(0xFF059669)
        : (widget.isDarkMode
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.08));

    // Hover effect: slightly brighter
    final hoverColor = isEnabled
        ? const Color(0xFF10B981) // Lighter green on hover
        : baseColor;

    // Press effect: slightly darker
    final pressColor = isEnabled
        ? const Color(0xFF047857) // Darker green on press
        : baseColor;

    final currentColor = _isPressed
        ? pressColor
        : (_isHovered ? hoverColor : baseColor);

    final scale = _isPressed ? 0.95 : 1.0;

    return MouseRegion(
      onEnter: isEnabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: isEnabled ? widget.onSubmit : null,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: currentColor,
              shape: BoxShape.circle,
              boxShadow: isEnabled && _isHovered
                  ? [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.arrow_upward_rounded,
              size: 18,
              color: isEnabled
                  ? Colors.white
                  : (widget.isDarkMode ? Colors.white24 : Colors.black26),
            ),
          ),
        ),
      ),
    );
  }
}
