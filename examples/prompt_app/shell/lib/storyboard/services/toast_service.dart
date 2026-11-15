/// Toast Notification Service for Storyboard
///
/// Provides toast notifications for MCP server updates and other storyboard events.
/// Uses toastification package to display non-intrusive notifications in the top-right corner.
library;

import 'package:material_ui/material_ui.dart';
import 'package:toastification/toastification.dart';

/// Service for managing toast notifications in the storyboard
class ToastService {
  ToastService._();

  /// Singleton instance
  static final ToastService instance = ToastService._();

  /// Show a success toast notification
  /// Used for successful operations like hot restart, annotation updates
  void showSuccess({
    required String title,
    String? description,
    Duration? duration,
  }) {
    toastification.show(
      type: ToastificationType.success,
      style: ToastificationStyle.flat,
      title: Text(title),
      description: description != null ? Text(description) : null,
      alignment: Alignment.topRight,
      autoCloseDuration: duration ?? const Duration(seconds: 5),
      showProgressBar: true,
      closeButtonShowType: CloseButtonShowType.onHover,
      closeOnClick: false,
      pauseOnHover: true,
      dragToClose: true,
    );
  }

  /// Show an info toast notification
  /// Used for informational updates like navigation, status changes
  void showInfo({
    required String title,
    String? description,
    Duration? duration,
  }) {
    toastification.show(
      type: ToastificationType.info,
      style: ToastificationStyle.flat,
      title: Text(title),
      description: description != null ? Text(description) : null,
      alignment: Alignment.topRight,
      autoCloseDuration: duration ?? const Duration(seconds: 5),
      showProgressBar: true,
      closeButtonShowType: CloseButtonShowType.onHover,
      closeOnClick: false,
      pauseOnHover: true,
      dragToClose: true,
    );
  }

  /// Show a warning toast notification
  /// Used for warnings like missing data, recoverable errors
  void showWarning({
    required String title,
    String? description,
    Duration? duration,
  }) {
    toastification.show(
      type: ToastificationType.warning,
      style: ToastificationStyle.flat,
      title: Text(title),
      description: description != null ? Text(description) : null,
      alignment: Alignment.topRight,
      autoCloseDuration: duration ?? const Duration(seconds: 6),
      showProgressBar: true,
      closeButtonShowType: CloseButtonShowType.onHover,
      closeOnClick: false,
      pauseOnHover: true,
      dragToClose: true,
    );
  }

  /// Show an error toast notification
  /// Used for errors and failures
  void showError({
    required String title,
    String? description,
    Duration? duration,
  }) {
    toastification.show(
      type: ToastificationType.error,
      style: ToastificationStyle.flat,
      title: Text(title),
      description: description != null ? Text(description) : null,
      alignment: Alignment.topRight,
      autoCloseDuration: duration ?? const Duration(seconds: 7),
      showProgressBar: true,
      closeButtonShowType: CloseButtonShowType.onHover,
      closeOnClick: false,
      pauseOnHover: true,
      dragToClose: true,
    );
  }

  /// Dismiss all active toast notifications
  void dismissAll() {
    toastification.dismissAll();
  }
}
