import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:flutter/services.dart';
import '../models/ar_state.dart';
import '../services/ar_service.dart';
import '../services/photo_service.dart';
import '../widgets/ar_overlays.dart';
import 'package:ar_flutter_plugin_2/widgets/ar_view.dart';
import 'package:ar_flutter_plugin_2/datatypes/config_planedetection.dart';

class ArScreen extends StatefulWidget {
  const ArScreen({super.key});

  @override
  State<ArScreen> createState() => _ArScreenState();
}

class _ArScreenState extends State<ArScreen> {
  late final ARState arState;
  late final ARService arService;
  late final PhotoService photoService;
  final ScreenshotController screenshotController = ScreenshotController();
  final String modelPath = 'assets/models/eva_01_esg.glb';
  final String reticlePath = 'assets/models/reticle.glb';

  @override
  void initState() {
    super.initState();
    arState = ARState();
    arService = ARService(state: arState, modelPath: modelPath, reticlePath: reticlePath);
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
                      await photoService.takeAndSavePhoto(screenshotController,context);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  onDelete: () async {
                    await arService.removeAllModels();
                  },
                  onPlaceModel: () async {
                    await arService.placeModelAtReticle();
                    HapticFeedback.mediumImpact();
                  }
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
