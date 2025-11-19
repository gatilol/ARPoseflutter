import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import '../models/ar_state.dart';
import '../services/ar_service.dart';
import '../services/photo_service.dart';
import '../widgets/ar_overlays.dart';
import '../widgets/circle_button.dart';
import 'package:ar_flutter_plugin_2/widgets/ar_view.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/datatypes/config_planedetection.dart';

class ArTestScreen extends StatefulWidget {
  const ArTestScreen({super.key});

  @override
  State<ArTestScreen> createState() => _ArTestScreenState();
}

class _ArTestScreenState extends State<ArTestScreen> {
  late final ARState arState;
  late final ARService arService;
  late final PhotoService photoService;
  final ScreenshotController screenshotController = ScreenshotController();
  final String modelPath = 'assets/models/eva_01_esg.glb';

  @override
  void initState() {
    super.initState();
    arState = ARState();
    arService = ARService(state: arState, modelPath: modelPath);
    photoService = PhotoService(state: arState);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: arState,
        builder: (context, _) {
          return Screenshot(
            controller: screenshotController,
            child: Stack(
              children: [
                ARView(
                  onARViewCreated: (sessionManager, objectManager, anchorManager, locationManager) {
                    arService.onARViewCreated(sessionManager, objectManager, anchorManager);
                  },
                  planeDetectionConfig: PlaneDetectionConfig.horizontal,
                ),
                AROverlays(
                  state: arState,
                  onClose: () => Navigator.pop(context),
                  onTakePhoto: () async {
                    try {
                      await photoService.takeAndSavePhoto(screenshotController);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  onDelete: () async {
                    await arService.removeAllModels();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    arService.dispose();
    super.dispose();
  }
}
