import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:gal/gal.dart';
import 'package:screenshot/screenshot.dart';
import 'package:flutter/services.dart';
import '../models/ar_state.dart';

class PhotoService {
  final ARState state;

  PhotoService({required this.state});

  Future<void> takeAndSavePhoto(ScreenshotController controller,BuildContext context) async {
    try {
      // 1. Masquer overlays
      state.setCapturing(true);

      // 2. Attendre la prochaine frame proprement
      await Future<void>.delayed(Duration.zero);
      await WidgetsBinding.instance.endOfFrame;

      // 3. Capturer
      final Uint8List? bytes = await controller.capture();
      state.setCapturing(false);

      if (bytes == null) throw Exception('Capture failed');

      // 🔊 VIBRATION lors de la capture
      HapticFeedback.mediumImpact();

      // 4. Sauvegarder
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = path.join(directory.path, 'ar_photo_$timestamp.png');
      final file = File(imagePath);
      await file.writeAsBytes(bytes);

      await Gal.putImage(imagePath);

      // ✅ NOTIFICATION de succès
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Photo saved to gallery'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }


    } catch (e) {
      state.setCapturing(false);
      // ❌ Notification d'erreur
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 12),
                Text('Error while saving'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }


      rethrow;
    }
  }
}
