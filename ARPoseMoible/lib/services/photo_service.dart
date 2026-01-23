import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:gal/gal.dart';
import 'package:screenshot/screenshot.dart';
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';

import '../config/app_config.dart';
import '../models/ar_state.dart';
import '../services/ar_service.dart';
import '../utils/snackbar_helper.dart';

/// Service responsible for capturing and saving AR photos
class PhotoService {
  final ARState state;
  ARSessionManager? sessionManager;
  final ARService arService;

  /// Minimum time (in milliseconds) to hide overlays during capture
  /// This ensures a smooth visual experience even if capture is fast
  static const int _minimumOverlayHideTime = 1000; // 1 seconde

  PhotoService({
    required this.state,
    required this.arService,
  });

  /// Set the AR session manager (call this after ARView is created)
  void setSessionManager(ARSessionManager manager) {
    sessionManager = manager;
  }

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
      // Start timing for minimum overlay hide duration
      final startTime = DateTime.now();

      // Hide planes before capture
      sessionManager?.showPlanes(false);

      // Hide UI overlays during capture
      state.setCapturing(true);

      // Wait for the next frame to ensure planes and UI are hidden
      await Future<void>.delayed(const Duration(milliseconds: 100));
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

      // Restore planes visibility
      sessionManager?.showPlanes(true);

      if (bytes == null) throw Exception('Capture failed');

      // Haptic feedback on capture (1st feedback - photo taken)
      HapticFeedback.mediumImpact();

      // Add watermark to the image
      final Uint8List watermarkedBytes = await _addWatermark(bytes);

      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = path.join(directory.path, 'ar_photo_$timestamp.png');
      final file = File(imagePath);
      await file.writeAsBytes(watermarkedBytes);

      // Save to gallery
      await Gal.putImage(imagePath);

      // Calculate remaining time to reach minimum overlay hide duration
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      final remainingTime = _minimumOverlayHideTime - elapsed;

      // Wait for remaining time if capture was faster than minimum duration
      if (remainingTime > 0) {
        await Future.delayed(Duration(milliseconds: remainingTime));
      }

      // Haptic feedback after wait (2nd feedback - overlays returning)
      HapticFeedback.mediumImpact();

      // Re-show overlays
      state.setCapturing(false);

      // Show success notification (longer duration for important feedback)
      if (context.mounted) {
        SnackBarHelper.showSuccess(
          context,
          message: 'Photo saved to gallery',
          duration: kSnackBarDurationLong,
        );
      }
    } catch (e) {
      // Restore planes visibility in case of error
      sessionManager?.showPlanes(true);
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

  /// Add watermark logo to the image
  Future<Uint8List> _addWatermark(Uint8List imageBytes) async {
    // Decode the captured image
    final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image originalImage = frameInfo.image;

    // Load logo from assets
    final ByteData logoData = await rootBundle.load('assets/images/logo.png');
    final Uint8List logoBytes = logoData.buffer.asUint8List();
    final ui.Codec logoCodec = await ui.instantiateImageCodec(logoBytes);
    final ui.FrameInfo logoFrameInfo = await logoCodec.getNextFrame();
    final ui.Image logoImage = logoFrameInfo.image;

    // Create a canvas to draw on
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    // Draw the original image
    canvas.drawImage(originalImage, Offset.zero, Paint());

    // Calculate watermark size and position
    final double watermarkWidth = originalImage.width * 0.35; // 35% de la largeur
    final double watermarkHeight = logoImage.height * (watermarkWidth / logoImage.width);

    final double padding = 40.0;
    final Offset watermarkPosition = Offset(
      originalImage.width - watermarkWidth - padding,
      originalImage.height - watermarkHeight - padding,
    );

    // Draw semi-transparent background for watermark
    final Paint backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0)
      ..style = PaintingStyle.fill;

    final RRect backgroundRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        watermarkPosition.dx - 10,
        watermarkPosition.dy - 10,
        watermarkWidth + 20,
        watermarkHeight + 20,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(backgroundRect, backgroundPaint);

    // Draw logo with slight transparency
    final Paint logoPaint = Paint()..color = Colors.white.withOpacity(0.9);

    canvas.drawImageRect(
      logoImage,
      Rect.fromLTWH(0, 0, logoImage.width.toDouble(), logoImage.height.toDouble()),
      Rect.fromLTWH(
        watermarkPosition.dx,
        watermarkPosition.dy,
        watermarkWidth,
        watermarkHeight,
      ),
      logoPaint,
    );

    // Convert to image
    final ui.Picture picture = recorder.endRecording();
    final ui.Image finalImage = await picture.toImage(
      originalImage.width,
      originalImage.height,
    );

    // Convert to bytes
    final ByteData? byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return byteData!.buffer.asUint8List();
  }
}