import 'package:flutter/material.dart';

import '../config/app_config.dart';

/// Helper class for displaying snackbars consistently across the app
class SnackBarHelper {
  /// Show a snackbar with icon and message
  static void show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color color,
    Duration? duration,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        duration: duration ?? kSnackBarDuration,
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show a success snackbar (green)
  static void showSuccess(
    BuildContext context, {
    required String message,
    IconData icon = Icons.check_circle,
    Duration? duration,
  }) {
    show(
      context,
      message: message,
      icon: icon,
      color: Colors.green,
      duration: duration,
    );
  }

  /// Show an error snackbar (red)
  static void showError(
    BuildContext context, {
    required String message,
    IconData icon = Icons.error,
    Duration? duration,
  }) {
    show(
      context,
      message: message,
      icon: icon,
      color: Colors.red,
      duration: duration,
    );
  }

  /// Show an info snackbar (blue)
  static void showInfo(
    BuildContext context, {
    required String message,
    IconData icon = Icons.info,
    Duration? duration,
  }) {
    show(
      context,
      message: message,
      icon: icon,
      color: Colors.blue,
      duration: duration,
    );
  }
}