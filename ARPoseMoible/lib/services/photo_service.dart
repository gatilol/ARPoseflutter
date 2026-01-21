import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:gal/gal.dart';
import 'package:screenshot/screenshot.dart';

import '../config/app_config.dart';
import '../models/ar_state.dart';
import '../services/ar_service.dart';
import '../utils/snackbar_helper.dart';

/// Service responsible for capturing and saving AR photos
class PhotoService {
  final ARState state;
  final ARService arService;

  PhotoService({
    required this.state,
    required this.arService,
  });

  /// Capture the current AR view and save it to the device gallery
  /// 
  /// On iOS: Uses native sceneView.snapshot() via platform channel
  ///         (ScreenshotController cannot capture UiKitView/PlatformView)
  /// 
  /// On Android: Uses Flutter ScreenshotController
  ///             (Works with AndroidView/Hybrid Composition)
  Future<void> takeAndSavePhoto(
    ScreenshotController controller,
    BuildContext context,
  ) async {
    try {
      // Hide UI overlays during capture
      state.setCapturing(true);

      // Wait for the next frame to ensure UI is hidden
      await Future<void>.delayed(Duration.zero);
      await WidgetsBinding.instance.endOfFrame;

      // Platform-specific capture
      Uint8List? bytes;

      if (Platform.isIOS) {
        // iOS: Use native ARKit snapshot (captures camera + 3D content)
        bytes = await arService.captureSnapshot();
      } else {
        // Android: Use Flutter ScreenshotController
        bytes = await controller.capture();
      }

      state.setCapturing(false);

      if (bytes == null) throw Exception('Capture failed');

      // Haptic feedback on capture
      HapticFeedback.mediumImpact();

      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = path.join(directory.path, 'ar_photo_$timestamp.png');
      final file = File(imagePath);
      await file.writeAsBytes(bytes);

      // Save to gallery
      await Gal.putImage(imagePath);

      // Show success notification (longer duration for important feedback)
      if (context.mounted) {
        SnackBarHelper.showSuccess(
          context,
          message: 'Photo saved to gallery',
          duration: kSnackBarDurationLong,
        );
      }
    } catch (e) {
      state.setCapturing(false);

      // Show error notification
      if (context.mounted) {
        SnackBarHelper.showError(
          context,
          message: 'Error while saving',
        );
      }

      rethrow;
    }
  }
}